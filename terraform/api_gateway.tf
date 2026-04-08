# ---------------------------------------------------------------------------
# HTTP API Gateway — VPC Link to EC2 backend
#
# Architecture:
#   Internet → API Gateway (savewithme.api.lorixlabs.com)
#            → VPC Link (private ENI in the VPC)
#            → NLB (internal, port 8080)
#            → EC2 instance (port 8080, Spring Boot)
#
# CORS is intentionally NOT configured at the gateway level; the Spring Boot
# backend owns that responsibility via its SecurityConfig. The $default
# catch-all route forwards OPTIONS pre-flight requests (and any other
# unmatched paths such as Swagger sub-resources) straight to the backend.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# CloudWatch Log Group
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.app_name}"
  retention_in_days = 30

  tags = { Name = "${var.app_name}-api-logs" }
}

# ---------------------------------------------------------------------------
# HTTP API
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "app" {
  name          = "${var.app_name}-api"
  protocol_type = "HTTP"
  description   = "SaveWithMe HTTP API — VPC Link proxy to EC2 backend"

  tags = { Name = "${var.app_name}-api" }
}

# ---------------------------------------------------------------------------
# VPC Link  (uses the SG defined in security.tf)
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_vpc_link" "app" {
  name               = "${var.app_name}-vpc-link"
  subnet_ids         = [aws_subnet.public.id]
  security_group_ids = [aws_security_group.vpc_link.id]

  tags = { Name = "${var.app_name}-vpc-link" }
}

# ---------------------------------------------------------------------------
# Integration — HTTP_PROXY through VPC Link → NLB listener
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_integration" "app" {
  api_id             = aws_apigatewayv2_api.app.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = aws_lb_listener.app.arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.app.id

  # 1.0 keeps the original request path intact (no transformation)
  payload_format_version = "1.0"
}

# ---------------------------------------------------------------------------
# Routes — Accounts  (/api/v1/accounts)
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_route" "post_accounts" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "POST /api/v1/accounts"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "get_accounts" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "GET /api/v1/accounts"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "get_account_by_id" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "GET /api/v1/accounts/{accountId}"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "patch_account_name" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "PATCH /api/v1/accounts/{accountId}/name"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "post_account_deactivate" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "POST /api/v1/accounts/{accountId}/deactivate"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "post_account_activate" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "POST /api/v1/accounts/{accountId}/activate"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

# ---------------------------------------------------------------------------
# Routes — Categories  (/api/v1/categories)
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_route" "get_categories" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "GET /api/v1/categories"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "get_category_by_id" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "GET /api/v1/categories/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "post_category" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "POST /api/v1/categories"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "patch_category" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "PATCH /api/v1/categories/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "post_category_deactivate" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "POST /api/v1/categories/{id}/deactivate"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "post_category_activate" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "POST /api/v1/categories/{id}/activate"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "delete_category" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "DELETE /api/v1/categories/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

# ---------------------------------------------------------------------------
# Routes — Transactions  (/api/v1/transactions)
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_route" "post_transaction" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "POST /api/v1/transactions"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "get_transactions" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "GET /api/v1/transactions"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "get_transaction_by_id" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "GET /api/v1/transactions/{transactionId}"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "delete_transaction" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "DELETE /api/v1/transactions/{transactionId}"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

# ---------------------------------------------------------------------------
# Routes — Observability & Docs
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_route" "get_health" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "GET /actuator/health"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "get_api_docs" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "GET /api-docs"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "get_swagger_ui" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "GET /swagger-ui.html"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

# ---------------------------------------------------------------------------
# $default catch-all route
#
# Handles:
#   - OPTIONS pre-flight requests (CORS managed by backend)
#   - Swagger UI static resources (/swagger-ui/*)
#   - Any future route not yet listed above
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

# ---------------------------------------------------------------------------
# Default stage with auto-deploy
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.app.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      httpMethod     = "$context.httpMethod"
      path           = "$context.path"
      responseLength = "$context.responseLength"
      integrationLatency = "$context.integrationLatency"
      responseLatency    = "$context.responseLatency"
      ip             = "$context.identity.sourceIp"
      userAgent      = "$context.identity.userAgent"
      errorMessage   = "$context.error.message"
    })
  }

  tags = { Name = "${var.app_name}-api-stage" }
}

# ---------------------------------------------------------------------------
# Custom domain name
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_domain_name" "app" {
  domain_name = "savewithme.api.lorixlabs.com"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = { Name = "${var.app_name}-api-domain" }
}

# Map the API + stage to the custom domain
resource "aws_apigatewayv2_api_mapping" "app" {
  api_id      = aws_apigatewayv2_api.app.id
  domain_name = aws_apigatewayv2_domain_name.app.id
  stage       = aws_apigatewayv2_stage.default.id
}
