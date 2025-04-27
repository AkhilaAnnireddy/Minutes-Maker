##############################################
# --- Pull latest ECR image digests ---
##############################################

data "aws_ecr_image" "video_transcriber_image" {
  repository_name = "minute-maker-video-transcriber"
  image_tag       = var.video_transcriber_image_tag
}

data "aws_ecr_image" "summarizer_image" {
  repository_name = "minute-maker-summarizer"
  image_tag       = var.summarizer_image_tag
}

##############################################
# --- Lambda: Video Uploader
##############################################

resource "aws_lambda_function" "video_uploader_lambda" {
  function_name    = var.video_uploader_lambda_name
  filename         = "${path.module}/lambda/upload_handler.zip"
  handler          = "main.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.video_uploader_role.arn
  timeout          = 30
  memory_size      = 256
  source_code_hash = filebase64sha256("${path.module}/lambda/upload_handler.zip")

  environment {
    variables = {
      BUCKET_NAME   = var.input_bucket_name
      S3_FOLDER     = "input/"
      SQS_QUEUE_URL = aws_sqs_queue.video_transcriber_notifier.id
    }
  }

  depends_on = [
    aws_iam_role_policy.video_uploader_lambda_policy,
    aws_cloudwatch_log_group.video_uploader_lambda_logs
  ]
}

resource "aws_cloudwatch_log_group" "video_uploader_lambda_logs" {
  name              = "/aws/lambda/${var.video_uploader_lambda_name}"
  retention_in_days = 7
}

resource "aws_iam_role" "video_uploader_role" {
  name = "video-uploader-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "video_uploader_lambda_policy" {
  name = "video-uploader-permissions"
  role = aws_iam_role.video_uploader_role.id

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
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
        Resource = [
          "arn:aws:s3:::${var.input_bucket_name}",
          "arn:aws:s3:::${var.input_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = ["sqs:SendMessage"],
        Resource = aws_sqs_queue.video_transcriber_notifier.arn
      }
    ]
  })
}

##############################################
# --- Lambda: Video Transcriber
##############################################

resource "aws_lambda_function" "video_transcriber_lambda" {
  function_name = "video-transcriber"
  role          = aws_iam_role.transcriber_lambda_role.arn

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

resource "aws_iam_role" "transcriber_lambda_role" {
  name = "video-transcriber-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "transcriber_lambda_policy" {
  name = "video-transcriber-permissions"
  role = aws_iam_role.transcriber_lambda_role.id

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

resource "aws_lambda_event_source_mapping" "sqs_transcriber_trigger" {
  event_source_arn = aws_sqs_queue.video_transcriber_notifier.arn
  function_name    = aws_lambda_function.video_transcriber_lambda.arn
  batch_size       = 1
  enabled          = true
}

##############################################
# --- Lambda: Summarizer
##############################################

resource "aws_lambda_function" "summarizer_lambda" {
  function_name = "summarizer"
  role          = aws_iam_role.summarizer_lambda_role.arn

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

resource "aws_iam_role" "summarizer_lambda_role" {
  name = "summarizer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "summarizer_lambda_policy" {
  name = "summarizer-permissions"
  role = aws_iam_role.summarizer_lambda_role.id

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

resource "aws_lambda_event_source_mapping" "sqs_summarizer_trigger" {
  event_source_arn = aws_sqs_queue.summary_generator_notifier.arn
  function_name    = aws_lambda_function.summarizer_lambda.arn
  batch_size       = 1
  enabled          = true
}
