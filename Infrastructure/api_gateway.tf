# --- API Gateway: HTTP API for video uploading ---
resource "aws_apigatewayv2_api" "video_upload_http_api" {
  name          = "video-upload-http-api"
  protocol_type = "HTTP"
}

# --- API Gateway: Lambda Integration ---
resource "aws_apigatewayv2_integration" "video_upload_lambda_integration" {
  api_id                 = aws_apigatewayv2_api.video_upload_http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.video_uploader_lambda.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# --- API Gateway: POST /upload route ---
resource "aws_apigatewayv2_route" "video_upload_route" {
  api_id    = aws_apigatewayv2_api.video_upload_http_api.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.video_upload_lambda_integration.id}"
}

# --- API Gateway: GET /status route ---
resource "aws_apigatewayv2_route" "video_upload_get_status_route" {
  api_id    = aws_apigatewayv2_api.video_upload_http_api.id
  route_key = "GET /status"
  target    = "integrations/${aws_apigatewayv2_integration.video_upload_lambda_integration.id}"
}

# --- API Gateway: Deployment Stage ---
resource "aws_apigatewayv2_stage" "video_upload_api_stage" {
  api_id      = aws_apigatewayv2_api.video_upload_http_api.id
  name        = "prod"
  auto_deploy = true
}

# --- Lambda Permission: Allow API Gateway to invoke the uploader Lambda ---
resource "aws_lambda_permission" "video_upload_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.video_uploader_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.video_upload_http_api.execution_arn}/*/*"
}
