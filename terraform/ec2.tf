data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name = "${var.app_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.app_name}-ec2-ssm-role" }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.app_name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}

resource "aws_key_pair" "app" {
  key_name   = "${var.app_name}-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.app.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # ── 1. Aguardar e montar o volume EBS de dados (/dev/xvdf → nvme1n1 em Nitro)
    DATA_DEVICE=""
    for attempt in $(seq 1 30); do
      for dev in /dev/nvme1n1 /dev/xvdf /dev/sdb; do
        [ -b "$dev" ] && { DATA_DEVICE="$dev"; break 2; }
      done
      sleep 5
    done

    if [ -n "$DATA_DEVICE" ]; then
      # Formatar apenas se não houver filesystem
      if ! blkid "$DATA_DEVICE" &>/dev/null; then
        mkfs.ext4 "$DATA_DEVICE"
      fi
      mkdir -p /mnt/data
      mount "$DATA_DEVICE" /mnt/data
      echo "$DATA_DEVICE /mnt/data ext4 defaults,nofail 0 2" >> /etc/fstab
    fi

    # ── 2. Instalar Docker
    apt-get update
    apt-get install -y ca-certificates curl

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # ── 3. Apontar Docker data-root para o EBS de dados (persiste entre recreates)
    if [ -n "$DATA_DEVICE" ]; then
      mkdir -p /mnt/data/docker
      mkdir -p /etc/docker
      echo '{"data-root": "/mnt/data/docker"}' > /etc/docker/daemon.json
    fi

    systemctl enable docker
    systemctl restart docker

    usermod -aG docker ubuntu

    mkdir -p /opt/savewithme
    chown ubuntu:ubuntu /opt/savewithme
  EOF

  tags = { Name = "${var.app_name}-ec2" }
}
