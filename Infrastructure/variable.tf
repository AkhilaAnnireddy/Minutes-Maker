# --- AWS General Variables ---

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# --- S3 Bucket Names ---

variable "input_bucket_name" {
  description = "S3 bucket for uploaded videos"
  type        = string
  default     = "minute-maker-input"
}

variable "intermediate_bucket_name" {
  description = "S3 bucket for intermediate data (audio, transcripts)"
  type        = string
  default     = "minute-maker-intermediate"
}

variable "output_bucket_name" {
  description = "S3 bucket for final meeting minutes"
  type        = string
  default     = "minute-maker-output"
}

variable "model_bucket_name" {
  description = "S3 bucket for ML models (Whisper, FLAN-T5, etc.)"
  type        = string
  default     = "minute-maker-models"
}

# --- Lambda Names ---

variable "video_uploader_lambda_name" {
  description = "Name of the Lambda function that uploads videos to S3 and notifies SQS"
  type        = string
}

# --- ECR Details for Docker Lambdas ---

variable "ecr_image_uri" {
  description = "ECR image URI for video transcriber Lambda"
  type        = string
}

variable "video_transcriber_image_tag" {
  description = "Docker image tag for video transcriber"
  type        = string
  default     = "latest"
}

variable "summarizer_ecr_image_uri" {
  description = "ECR image URI for summarizer Lambda"
  type        = string
}

variable "summarizer_image_tag" {
  description = "Docker image tag for summarizer"
  type        = string
  default     = "latest"
}
