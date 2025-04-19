variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket used for video uploads"
  type        = string
  default     = "minute-maker-resources"
}

variable "video_upload_lambda_name" {
  description = "Name of the Lambda function that uploads videos to S3 and notifies transcriber"
  type        = string
  default     = "video-upload-handler"
}

variable "transcription_queue_url" {
  description = "URL of the SQS queue that the video uploader sends messages to"
  type        = string
}
