# --- Pull the latest ECR image digest for Transcriber ---
data "aws_ecr_image" "video_transcriber_image" {
  repository_name = "minute-maker-video-transcriber"
  image_tag       = var.video_transcriber_image_tag
}

# --- Pull the latest ECR image digest for Summarizer ---
data "aws_ecr_image" "summarizer_image" {
  repository_name = "minute-maker-summarizer"
  image_tag       = var.summarizer_image_tag
}

# --- Lambda definition for Video Transcriber using Docker image ---
resource "aws_lambda_function" "video_transcriber" {
  function_name = "video-transcriber"
  role          = aws_iam_role.lambda_transcriber_role.arn

  package_type  = "Image"
  image_uri     = "${var.ecr_image_uri}@${data.aws_ecr_image.video_transcriber_image.image_digest}"
  timeout       = 900
  memory_size   = 1024
  architectures = ["x86_64"]

  environment {
    variables = {
      MODEL_BUCKET             = var.model_bucket_name
      MODEL_PREFIX             = "video-transcriber-models/"
      VIDEO_BUCKET             = var.input_bucket_name
      INTERMEDIATE_BUCKET      = var.intermediate_bucket_name
      SQS_SUMMARIZER_QUEUE_URL = aws_sqs_queue.summary_generator_notifier.id
    }
  }

  depends_on = [data.aws_ecr_image.video_transcriber_image]
}

# --- Lambda definition for Summarizer using Docker image ---
resource "aws_lambda_function" "summarizer" {
  function_name = "summarizer"
  role          = aws_iam_role.lambda_summarizer_role.arn

  package_type  = "Image"
  image_uri     = "${var.summarizer_ecr_image_uri}@${data.aws_ecr_image.summarizer_image.image_digest}"
  timeout       = 900
  memory_size   = 1024
  architectures = ["x86_64"]

  environment {
    variables = {
      MODEL_BUCKET        = var.model_bucket_name
      MODEL_PREFIX        = "summarizer-models/"
      INTERMEDIATE_BUCKET = var.intermediate_bucket_name
      OUTPUT_BUCKET       = var.output_bucket_name
    }
  }

  depends_on = [data.aws_ecr_image.summarizer_image]
}

# --- IAM Role for Video Transcriber Lambda ---
resource "aws_iam_role" "lambda_transcriber_role" {
  name = "lambda_transcriber_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# --- IAM Role for Summarizer Lambda ---
resource "aws_iam_role" "lambda_summarizer_role" {
  name = "lambda_summarizer_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# --- IAM Policy for Video Transcriber Lambda ---
resource "aws_iam_role_policy" "lambda_transcriber_policy" {
  name = "lambda-transcriber-permissions"
  role = aws_iam_role.lambda_transcriber_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = ["s3:ListBucket"],
        Resource = ["arn:aws:s3:::${var.model_bucket_name}"]
      },
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:PutObject"],
        Resource = [
          "arn:aws:s3:::${var.model_bucket_name}/*",
          "arn:aws:s3:::${var.input_bucket_name}/*",
          "arn:aws:s3:::${var.intermediate_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = ["sqs:SendMessage"],
        Resource = aws_sqs_queue.summary_generator_notifier.arn
      },
      {
        Effect = "Allow",
        Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
        Resource = aws_sqs_queue.video_transcriber_notifier.arn
      }
    ]
  })
}

# --- IAM Policy for Summarizer Lambda ---
resource "aws_iam_role_policy" "lambda_summarizer_policy" {
  name = "lambda-summarizer-permissions"
  role = aws_iam_role.lambda_summarizer_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = ["s3:ListBucket"],
        Resource = ["arn:aws:s3:::${var.model_bucket_name}"]
      },
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:PutObject"],
        Resource = [
          "arn:aws:s3:::${var.model_bucket_name}/*",
          "arn:aws:s3:::${var.intermediate_bucket_name}/*",
          "arn:aws:s3:::${var.output_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
        Resource = aws_sqs_queue.summary_generator_notifier.arn
      }
    ]
  })
}

# --- SQS trigger for Video Transcriber Lambda ---
resource "aws_lambda_event_source_mapping" "sqs_transcriber_trigger" {
  event_source_arn = aws_sqs_queue.video_transcriber_notifier.arn
  function_name    = aws_lambda_function.video_transcriber.arn
  batch_size       = 1
  enabled          = true
}

# --- SQS trigger for Summarizer Lambda ---
resource "aws_lambda_event_source_mapping" "sqs_summarizer_trigger" {
  event_source_arn = aws_sqs_queue.summary_generator_notifier.arn
  function_name    = aws_lambda_function.summarizer.arn
  batch_size       = 1
  enabled          = true
}
