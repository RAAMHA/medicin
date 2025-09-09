# Terraform Backend Configuration (Optional but Recommended)
terraform {
  required_version = ">= 1.0"

  # Uncomment and configure for remote state storage
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "medicine-analyzer/terraform.tfstate"
  #   region = "us-east-1"
  # }
}