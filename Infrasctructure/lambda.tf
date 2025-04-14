# ECR Repository
resource "aws_ecr_repository" "whisper_repo" {
  name                 = "whisper-lambda-repo"
  image_tag_mutability = "MUTABLE"

  lifecycle_policy {
    policy = jsonencode({
      rules = [
        {
          rulePriority = 1,
          description  = "Expire untagged images older than 7 days",
          selection    = {
            tagStatus     = "untagged",
            countType     = "sinceImagePushed",
            countUnit     = "days",
            countNumber   = 7
          },
          action = {
            type = "expire"
          }
        }
      ]
    })
  }
}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "whisper-lambda-role"

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

# Attach basic logging policy
resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach S3 access policy
resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "lambda-s3-access"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      }
    ]
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/whisper-lambda"
  retention_in_days = 7
}

# Lambda Function from Docker Image
resource "aws_lambda_function" "whisper_lambda" {
  function_name = "whisper-lambda"
  package_type  = "Image"
  image_uri     = var.lambda_image_uri
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 300
  memory_size   = 2048

  environment {
    variables = {
      BUCKET_NAME   = var.bucket_name
      MODEL_PREFIX  = "models/"
      OUTPUT_PREFIX = "intermediate/"
      LOG_LEVEL     = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_s3_access,
    aws_cloudwatch_log_group.lambda_logs
  ]
}
