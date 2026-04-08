output "ec2_public_ip" {
  description = "Elastic IP of the EC2 instance — use this as EC2_HOST in the app repo secrets"
  value       = aws_eip.app.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i <sua-chave-privada>.pem ubuntu@${aws_eip.app.public_ip}"
}

output "api_gateway_url" {
  description = "Default API Gateway invoke URL (before custom domain is active)"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_base_url" {
  description = "Public API base URL via custom domain"
  value       = "https://savewithme.api.lorixlabs.com"
}

output "route53_nameservers" {
  description = "Nameservers to configure at your domain registrar for lorixlabs.com. Set these as the authoritative NS records at the registrar after the first apply."
  value       = aws_route53_zone.lorixlabs.name_servers
}
