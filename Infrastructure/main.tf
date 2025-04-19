terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket for Minute Maker (input bucket)
resource "aws_s3_bucket" "minute_maker" {
  bucket = var.input_bucket_name

  tags = {
    Project     = "MinuteMaker"
    Environment = "Dev"
  }
}
