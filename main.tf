 terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  
  # S3 backend configuration
  backend "s3" {
    bucket = "BUCKETNAME_TO_BE_REPLACED"
    key    = "api-lambda/terraform.tfstate"
    region = "eu-west-1"
    encrypt = true
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "crud_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function
resource "aws_lambda_function" "crud_lambda" {
  filename          = "lambda_function.zip"
  function_name     = "crud_operations"
  role              = aws_iam_role.lambda_role.arn
  handler           = "index.handler"
  runtime           = "python3.9"
  
  source_code_hash = filebase64sha256("lambda_function.zip")
}

# API Gateway
resource "aws_api_gateway_rest_api" "crud_api" {
  name        = "crud-api"
  description = "CRUD API Gateway"
}

# API Gateway resource
resource "aws_api_gateway_resource" "items" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  parent_id   = aws_api_gateway_rest_api.crud_api.root_resource_id
  path_part   = "items"
}

# GET method
resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.crud_api.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "GET"
  authorization = "NONE"
}

# POST method
resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.crud_api.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "POST"
  authorization = "NONE"
}

# PUT method
resource "aws_api_gateway_method" "put" {
  rest_api_id   = aws_api_gateway_rest_api.crud_api.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "PUT"
  authorization = "NONE"
}

# DELETE method
resource "aws_api_gateway_method" "delete" {
  rest_api_id   = aws_api_gateway_rest_api.crud_api.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "DELETE"
  authorization = "NONE"
}

# Lambda integration for GET
resource "aws_api_gateway_integration" "lambda_get" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.items.id
  http_method = aws_api_gateway_method.get.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.crud_lambda.invoke_arn
}

# Lambda integration for POST
resource "aws_api_gateway_integration" "lambda_post" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.items.id
  http_method = aws_api_gateway_method.post.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.crud_lambda.invoke_arn
}

# Lambda integration for PUT
resource "aws_api_gateway_integration" "lambda_put" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.items.id
  http_method = aws_api_gateway_method.put.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.crud_lambda.invoke_arn
}

# Lambda integration for DELETE
resource "aws_api_gateway_integration" "lambda_delete" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.items.id
  http_method = aws_api_gateway_method.delete.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.crud_lambda.invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crud_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.crud_api.execution_arn}/*/*"
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "crud_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_get,
    aws_api_gateway_integration.lambda_post,
    aws_api_gateway_integration.lambda_put,
    aws_api_gateway_integration.lambda_delete
  ]

  rest_api_id = aws_api_gateway_rest_api.crud_api.id
}

# API Gateway stage
resource "aws_api_gateway_stage" "crud_stage" {
  deployment_id = aws_api_gateway_deployment.crud_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.crud_api.id
  stage_name    = "prod"
}

# Output the API Gateway URL
output "api_url" {
  value = "${aws_api_gateway_stage.crud_stage.invoke_url}/items"
}