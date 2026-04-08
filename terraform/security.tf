# ---------------------------------------------------------------------------
# Security Group — VPC Link ENIs
#
# API Gateway creates an ENI in the VPC for each VPC Link. This SG is
# attached to those ENIs and only needs egress to the EC2 on port 8080.
# Inbound to the ENI is handled by AWS internally (no explicit rule needed).
# ---------------------------------------------------------------------------

resource "aws_security_group" "vpc_link" {
  name        = "${var.app_name}-vpc-link-sg"
  description = "Security group for API Gateway VPC Link ENIs"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow outbound to backend EC2 on port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = { Name = "${var.app_name}-vpc-link-sg" }
}

# ---------------------------------------------------------------------------
# Security Group — EC2 application instance
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
    description = "App HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
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
