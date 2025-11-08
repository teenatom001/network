terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.4.0"
}

provider "aws" {
  region = "eu-north-1"
}

# --- SSH Key Pair ---
resource "aws_key_pair" "deploy_key" {
  key_name   = "sample-key"
  public_key = file("${path.module}/keys/sample-key.pub")
}

# --- Use Default VPC ---
data "aws_vpc" "default" {
  default = true
}

# --- Security Group ---
resource "aws_security_group" "web_sg" {
  name        = "sample-web-sg-1"
  description = "Allow SSH and HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

# --- EC2 Instance ---
resource "aws_instance" "web" {
  ami                    = "ami-0b751bf99d3fe2510" # ✅ Ubuntu Server 24.04 LTS (eu-north-1)
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deploy_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "sample-ec2"
  }

  # --- Create user "hanubunu" after instance is up ---
  provisioner "remote-exec" {
    inline = [
      "sudo adduser --disabled-password --gecos '' hanubunu",
      "sudo mkdir -p /home/hanubunu/.ssh",
      "sudo cp /home/ubuntu/.ssh/authorized_keys /home/hanubunu/.ssh/",
      "sudo chown -R hanubunu:hanubunu /home/hanubunu/.ssh",
      "sudo chmod 700 /home/hanubunu/.ssh",
      "sudo chmod 600 /home/hanubunu/.ssh/authorized_keys"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/keys/sample-key")
      host        = self.public_ip
    }
  }
}

# --- Output ---
output "public_ip" {
  value = aws_instance.web.public_ip
}
