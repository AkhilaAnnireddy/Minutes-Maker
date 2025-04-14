variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "minute-maker-resources"
}

variable "lambda_image_uri" {
  description = "ECR URI for the Whisper Lambda Docker image"
  type        = string
}
