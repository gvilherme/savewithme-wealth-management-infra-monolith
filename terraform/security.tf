# ---------------------------------------------------------------------------
# Security Group — EC2 application instance
#
# Porta 8080 aberta para 0.0.0.0/0 porque o API Gateway (HTTP_PROXY INTERNET)
# se conecta ao Elastic IP do EC2 pela internet pública.
# A autenticação real ocorre na camada de aplicação via JWT Supabase.
#
# TODO (pós-MVP): quando o suporte a ELB for habilitado na conta, migrar
# para VPC Link + NLB e restringir a porta 8080 ao CIDR da VPC novamente.
# ---------------------------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${var.app_name}-sg"
  description = "Security group for SaveWithMe app"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  ingress {
    description = "App HTTP — API Gateway internet integration"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-sg" }
}

variable "ssh_allowed_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access the instance via SSH (port 22)."
  default     = ["10.0.0.0/16"]
}
