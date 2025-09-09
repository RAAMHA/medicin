#!/bin/bash

# Local deployment script for testing
set -e

echo "🚀 Starting local deployment..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not installed. Please install Terraform first."
    exit 1
fi

# Build frontend
echo "📦 Building frontend..."
npm install
npm run build

# Prepare Lambda package
echo "📦 Preparing Lambda package..."
cd lambda
zip -r ../terraform/prescription_analyzer.zip . -x "*.pyc" "__pycache__/*"
cd ..

# Deploy infrastructure
echo "🏗️ Deploying infrastructure..."
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Get outputs
echo "📋 Getting deployment outputs..."
API_URL=$(terraform output -raw api_gateway_invoke_url)
WEBSITE_BUCKET=$(terraform output -raw website_bucket_name)
CLOUDFRONT_URL=$(terraform output -raw cloudfront_url)
PRESCRIPTION_BUCKET=$(terraform output -raw s3_bucket_name)

cd ..

# Update configuration
echo "⚙️ Updating configuration..."
sed -i.bak "s|https://your-api-gateway-url.amazonaws.com/prod/analyze|${API_URL}/analyze|g" script.js
sed -i.bak "s|your-prescription-bucket|${PRESCRIPTION_BUCKET}|g" script.js

# Rebuild with updated config
echo "🔄 Rebuilding with updated configuration..."
npm run build

# Deploy frontend
echo "🌐 Deploying frontend..."
aws s3 sync dist/ s3://${WEBSITE_BUCKET}/ --delete

# Invalidate CloudFront
echo "🔄 Invalidating CloudFront cache..."
DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[0].DomainName=='${WEBSITE_BUCKET}.s3.amazonaws.com'].Id" --output text)
if [ ! -z "$DISTRIBUTION_ID" ]; then
    aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*"
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo "📱 Frontend URL: $CLOUDFRONT_URL"
echo "🔗 API URL: $API_URL"
echo "📦 Prescription Bucket: $PRESCRIPTION_BUCKET"
echo ""
echo "🎯 Test your application by visiting the CloudFront URL!"