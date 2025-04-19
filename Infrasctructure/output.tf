# Output: S3 Bucket
output "s3_bucket_name" {
  description = "The name of the S3 bucket used for video uploads"
  value       = aws_s3_bucket.minute_maker.bucket
}

# Output: video-upload-handler Lambda function name
output "video_upload_lambda_function_name" {
  description = "The name of the video uploader Lambda function"
  value       = aws_lambda_function.video_upload_handler.function_name
}

# Output: Main queue from uploader → transcriber
output "video_transcriber_queue_url" {
  description = "URL of the SQS queue for the video transcriber"
  value       = aws_sqs_queue.video_transcriber_notifier.id
}

# Output: Dead Letter Queue for uploader → transcriber
output "video_transcriber_dlq_url" {
  description = "URL of the Dead Letter Queue for video transcriber"
  value       = aws_sqs_queue.video_transcriber_notifier_dlq.id
}

# Output: Queue from transcriber → summarizer
output "summary_generator_queue_url" {
  description = "URL of the SQS queue for summary generation"
  value       = aws_sqs_queue.summary_generator_notifier.id
}
