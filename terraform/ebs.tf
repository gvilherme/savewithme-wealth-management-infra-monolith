# ---------------------------------------------------------------------------
# EBS data volume — persiste entre destroy/recreate da stack.
#
# O prevent_destroy = true impede que `terraform destroy` apague este volume.
# O workflow stack-control.yml contorna isso via `terraform state rm` antes
# do destroy e `terraform import` depois, preservando o volume físico na AWS.
#
# Para deletar explicitamente, use o label `ebs:destroy` na issue.
# ---------------------------------------------------------------------------

resource "aws_ebs_volume" "data" {
  availability_zone = aws_subnet.public.availability_zone
  size              = 20
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.app_name}-data"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "data" {
  device_name  = "/dev/xvdf"
  volume_id    = aws_ebs_volume.data.id
  instance_id  = aws_instance.app.id
  force_detach = true
}
