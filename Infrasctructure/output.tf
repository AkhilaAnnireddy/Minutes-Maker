output "s3_bucket_name" {
  description = "The name of the S3 bucket created"
  value       = aws_s3_bucket.minute_maker.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.whisper_lambda.function_name
}
