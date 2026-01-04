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
    type = string
    default = "c7i-flex.large"
}

source "amazon-ebs" "nginx_web" {
  ami_name      = "web-server-AMI"
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
  }
}

build {
  sources = ["source.amazon-ebs.nginx_web"]
  
  provisioner "shell" {
    script = "scripts/install-nginx.sh"
  }
  
//   provisioner "file" {
    source      = "../nginx/default.conf"
    destination = "/tmp/default.conf"
  }
  
  provisioner "shell" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y certbot python3-certbot-nginx",
      "sudo mv /tmp/default.conf /etc/nginx/conf.d/",
      "sudo systemctl enable nginx"
    ]
  }
}