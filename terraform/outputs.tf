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
