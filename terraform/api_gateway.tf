# ---------------------------------------------------------------------------
# HTTP API Gateway — direct HTTP integration to EC2 Elastic IP
#
# Architecture (MVP — sem NLB):
#   Internet → API Gateway HTTPS (savewithme.api.lorixlabs.com)
#            → HTTP_PROXY INTERNET → EC2 Elastic IP :8080 (Spring Boot)
#
# Nota: o tráfego Gateway → EC2 atravessa a internet pública (HTTP).
# O HTTPS é terminado no Gateway; o JWT garante autenticação na camada
# de aplicação. Quando o suporte a ELB for habilitado na conta, migrar
# para VPC Link + NLB (ver nlb.tf).
#
# CORS é gerenciado pelo Spring Boot — não configurado aqui para evitar
# headers duplicados. O $default catch-all encaminha OPTIONS pre-flight
# e recursos estáticos do Swagger UI diretamente ao backend.
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
  description   = "SaveWithMe HTTP API — proxy to EC2 backend"

  tags = { Name = "${var.app_name}-api" }
}

# ---------------------------------------------------------------------------
# Integration — HTTP_PROXY direto para o Elastic IP do EC2
#
# `overwrite:path` garante que o path completo da requisição original
# seja repassado ao backend (ex: /api/v1/accounts → EC2:8080/api/v1/accounts).
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_integration" "app" {
  api_id             = aws_apigatewayv2_api.app.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = "http://${aws_eip.app.public_ip}:8080"
  connection_type    = "INTERNET"

  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path" = "$request.path"
  }
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
# Routes — Budgets  (/api/v1/user/{userId}/budgets)
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_route" "put_budgets" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "PUT /api/v1/user/{userId}/budgets"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "get_budget_progress" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "GET /api/v1/user/{userId}/budgets/{year}/{month}/progress"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "delete_budget" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "DELETE /api/v1/user/{userId}/budgets/{budgetId}"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_route" "get_budget_alerts_stream" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "GET /api/v1/user/{userId}/budgets/alerts/stream"
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
#   - OPTIONS pre-flight requests (CORS gerenciado pelo backend)
#   - Swagger UI static resources (/swagger-ui/*)
#   - Qualquer rota futura não listada acima
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

# ---------------------------------------------------------------------------
# Default stage com auto-deploy
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.app.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      routeKey           = "$context.routeKey"
      status             = "$context.status"
      httpMethod         = "$context.httpMethod"
      path               = "$context.path"
      responseLength     = "$context.responseLength"
      integrationLatency = "$context.integrationLatency"
      responseLatency    = "$context.responseLatency"
      ip                 = "$context.identity.sourceIp"
      userAgent          = "$context.identity.userAgent"
      errorMessage       = "$context.error.message"
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
