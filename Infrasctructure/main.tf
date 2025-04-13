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

resource "aws_s3_bucket" "minute_maker" {
  bucket = var.bucket_name

  tags = {
    Project     = "MinuteMaker"
    Environment = "Dev"
  }
}

resource "aws_s3_object" "folders" {
  for_each = toset(["models/", "input/", "intermediate/", "output/"])

  bucket  = aws_s3_bucket.minute_maker.id
  key     = each.key
  content = "" # creates a 0-byte object directly
}



