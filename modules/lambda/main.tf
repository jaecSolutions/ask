resource "aws_lambda_function" "lambda" {
  function_name    = var.function_name
  role             = var.role_arn
  runtime          = "python3.12"
  handler          = "src/lambda_function.handler"
  filename         = "${path.module}/lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")
  environment {
    variables = var.environment_vars
  }
  layers = [
    "arn:aws:lambda:ca-central-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python312-x86_64:2"
  ]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = aws_cloudwatch_log_group.lambda.arn
}