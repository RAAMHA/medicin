# Configure AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "medicine-prescription-analyzer"
}

# S3 Bucket for prescriptions
resource "aws_s3_bucket" "prescription_bucket" {
  bucket = "${var.project_name}-prescriptions-${random_string.bucket_suffix.result}"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "prescription_bucket_versioning" {
  bucket = aws_s3_bucket.prescription_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "prescription_bucket_encryption" {
  bucket = aws_s3_bucket.prescription_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket for static website
resource "aws_s3_bucket" "website_bucket" {
  bucket = "${var.project_name}-website-${random_string.website_suffix.result}"
}

resource "random_string" "website_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website_pab" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website_pab]
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.prescription_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:AnalyzeDocument"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "prescription_analyzer" {
  filename         = "prescription_analyzer.zip"
  function_name    = "${var.project_name}-analyzer"
  role            = aws_iam_role.lambda_role.arn
  handler         = "prescription-analyzer.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.lambda_logs,
  ]
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-analyzer"
  retention_in_days = 14
}

# API Gateway
resource "aws_api_gateway_rest_api" "prescription_api" {
  name        = "${var.project_name}-api"
  description = "API for prescription analysis"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "analyze_resource" {
  rest_api_id = aws_api_gateway_rest_api.prescription_api.id
  parent_id   = aws_api_gateway_rest_api.prescription_api.root_resource_id
  path_part   = "analyze"
}

resource "aws_api_gateway_method" "analyze_method" {
  rest_api_id   = aws_api_gateway_rest_api.prescription_api.id
  resource_id   = aws_api_gateway_resource.analyze_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "analyze_options" {
  rest_api_id   = aws_api_gateway_rest_api.prescription_api.id
  resource_id   = aws_api_gateway_resource.analyze_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.prescription_api.id
  resource_id = aws_api_gateway_resource.analyze_resource.id
  http_method = aws_api_gateway_method.analyze_method.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.prescription_analyzer.invoke_arn
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.prescription_api.id
  resource_id = aws_api_gateway_resource.analyze_resource.id
  http_method = aws_api_gateway_method.analyze_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.prescription_api.id
  resource_id = aws_api_gateway_resource.analyze_resource.id
  http_method = aws_api_gateway_method.analyze_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.prescription_api.id
  resource_id = aws_api_gateway_resource.analyze_resource.id
  http_method = aws_api_gateway_method.analyze_options.http_method
  status_code = aws_api_gateway_method_response.options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.prescription_analyzer.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.prescription_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "prescription_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.options_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.prescription_api.id
  stage_name  = "prod"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "website_distribution" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website_bucket.bucket}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Outputs
output "s3_bucket_name" {
  value = aws_s3_bucket.prescription_bucket.bucket
}

output "website_bucket_name" {
  value = aws_s3_bucket.website_bucket.bucket
}

output "api_gateway_url" {
  value = "${aws_api_gateway_rest_api.prescription_api.execution_arn}/prod"
}

output "api_gateway_invoke_url" {
  value = "https://${aws_api_gateway_rest_api.prescription_api.id}.execute-api.${var.aws_region}.amazonaws.com/prod"
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.website_distribution.domain_name}"
}

output "lambda_function_name" {
  value = aws_lambda_function.prescription_analyzer.function_name
}