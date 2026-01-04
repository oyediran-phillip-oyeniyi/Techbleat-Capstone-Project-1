packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "instance_type" {
  type    = string
  default = "c7i-flex.large"
}

source "amazon-ebs" "nginx_web" {
  ami_name      = "web-server-AMI-{{timestamp}}"
  instance_type = var.instance_type
  region        = var.aws_region
  
  source_ami_filter {
    filters = {
      name                = "amzn2-ami-hvm-*-x86_64-gp2"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  
  ssh_username = "ec2-user"
  
  tags = {
    Name        = "WebServerAMI"
    Environment = "Production"
    ManagedBy   = "Packer"
    BuildDate   = "{{timestamp}}"
  }
}

build {
  sources = ["source.amazon-ebs.nginx_web"]
  
  provisioner "shell" {
    script = "scripts/install-nginx.sh"
  }
  
  provisioner "file" {
    source      = "../application/frontend/"
    destination = "/tmp/frontend"
  }
  
  provisioner "file" {
    source      = "../nginx/default.conf"
    destination = "/tmp/default.conf"
  }
  
  provisioner "shell" {
    inline = [
      "sudo mv /tmp/frontend/* /usr/share/nginx/html/",
      "sudo chown -R nginx:nginx /usr/share/nginx/html/",
      "sudo mv /tmp/default.conf /etc/nginx/conf.d/default.conf",
      "sudo systemctl enable nginx"
    ]
  }
}