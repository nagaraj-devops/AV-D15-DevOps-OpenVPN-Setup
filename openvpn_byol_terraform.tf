# OpenVPN Access Server (BYOL) — Terraform (example)
# NOTE: Fill in variable values (ami, key_name) before apply.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "ami" {
  type    = string
  description = "Ubuntu 22.04 AMI ID for the region (set before apply)"
  default = ""
}

variable "key_name" {
  type    = string
  description = "EC2 key pair name (set before apply)"
  default = ""
}

resource "aws_security_group" "openvpn_sg" {
  name        = "openvpn-byol-sg"
  description = "Allow OpenVPN Access Server traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Admin UI"
    from_port   = 943
    to_port     = 943
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "OpenVPN TCP/UDP"
    from_port   = 1194
    to_port     = 1194
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_instance" "openvpn" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.openvpn_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
#!/bin/bash
set -e
# Update and install dependencies
apt-get update -y
apt-get upgrade -y
# Install wget & unzip
apt-get install -y wget unzip
# Download and install OpenVPN Access Server (latest - Ubuntu 22.04)
wget https://openvpn.net/downloads/openvpn-as-latest-ubuntu22.amd_64.deb -O /tmp/openvpn-as.deb
apt-get install -y /tmp/openvpn-as.deb
# Ensure service enabled
systemctl enable openvpnas
systemctl start openvpnas
EOF

  tags = {
    Name = "openvpn-byol"
  }
}

resource "aws_eip" "openvpn_eip" {
  instance = aws_instance.openvpn.id
  vpc      = true
  depends_on = [aws_instance.openvpn]
}

output "public_ip" {
  value = aws_eip.openvpn_eip.public_ip
}

output "instance_id" {
  value = aws_instance.openvpn.id
}
