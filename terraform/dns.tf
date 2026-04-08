# ---------------------------------------------------------------------------
# DNS & TLS — lorixlabs.com / savewithme.api.lorixlabs.com
#
# After a successful `terraform apply`, copy the nameserver values from the
# `route53_nameservers` output and set them as the authoritative NS records
# at your domain registrar (where you bought lorixlabs.com).
# ACM validation and the API domain record only resolve after that change
# propagates — which typically takes a few minutes to a couple of hours.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Route53 Hosted Zone
# ---------------------------------------------------------------------------

resource "aws_route53_zone" "lorixlabs" {
  name = "lorixlabs.com"

  tags = { Name = "lorixlabs-zone" }
}

# ---------------------------------------------------------------------------
# ACM Certificate for the API subdomain
#
# Certificate is in the same region as the API Gateway (REGIONAL endpoint).
# DNS validation is used so it can be automated without human interaction.
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "api" {
  domain_name       = "savewithme.api.lorixlabs.com"
  validation_method = "DNS"

  # Replace before destroy avoids downtime during cert rotation
  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.app_name}-api-cert" }
}

# CNAME records that ACM uses to prove domain ownership
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.lorixlabs.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# Block until the certificate is fully issued
resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}

# ---------------------------------------------------------------------------
# DNS alias record — savewithme.api.lorixlabs.com → API Gateway domain
# ---------------------------------------------------------------------------

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.lorixlabs.zone_id
  name    = "savewithme.api.lorixlabs.com"
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.app.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.app.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = true
  }
}
