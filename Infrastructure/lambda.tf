# IAM Role for video-upload-handler
resource "aws_iam_role" "video_upload_lambda_exec_role" {
  name = "video-upload-handler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach basic logging
resource "aws_iam_role_policy_attachment" "upload_lambda_logging" {
  role       = aws_iam_role.video_upload_lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy: S3 + SQS Access for Upload Lambda
resource "aws_iam_role_policy" "upload_lambda_policy" {
  name = "video-upload-handler-policy"
  role = aws_iam_role.video_upload_lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage"
        ],
        Resource = "${aws_sqs_queue.video_transcriber_notifier.arn}"
      }
    ]
  })
}

# CloudWatch Log Group for video-upload-handler
resource "aws_cloudwatch_log_group" "video_upload_lambda_logs" {
  name              = "/aws/lambda/video-upload-handler"
  retention_in_days = 7
}

# Lambda Function: video-upload-handler
resource "aws_lambda_function" "video_upload_handler" {
  function_name    = var.video_upload_lambda_name
  filename         = "${path.module}/lambda/upload_handler.zip"
  handler          = "main.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.video_upload_lambda_exec_role.arn
  timeout          = 30
  memory_size      = 256
  source_code_hash = filebase64sha256("${path.module}/lambda/upload_handler.zip")

environment {
  variables = {
    BUCKET_NAME     = var.bucket_name
    S3_FOLDER       = "input/"
    SQS_QUEUE_URL   = aws_sqs_queue.video_transcriber_notifier.id
  }
}

  depends_on = [
    aws_iam_role_policy.upload_lambda_policy,
    aws_cloudwatch_log_group.video_upload_lambda_logs
  ]
}
