# NLB removido — nova conta AWS sem suporte a ELB.
# A integração do API Gateway aponta diretamente para o Elastic IP do EC2
# via HTTP_PROXY + INTERNET (ver api_gateway.tf).
# Quando o suporte a load balancers for habilitado, restaurar este arquivo
# e migrar para VPC Link para que o tráfego nunca saia da VPC.
