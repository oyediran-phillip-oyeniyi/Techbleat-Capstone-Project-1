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

source "amazon-ebs" "backend_app" {
  ami_name      = "backend-server-AMI-{{timestamp}}"
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
    Name        = "BackendServerAMI"
    Environment = "Production"
    ManagedBy   = "Packer"
    BuildDate   = "{{timestamp}}"
  }
}

build {
  sources = ["source.amazon-ebs.backend_app"]
  
  provisioner "shell" {
    script = "scripts/install-python.sh"
  }
  
  provisioner "file" {
    source      = "../application/backend"
    destination = "/tmp/backend"
  }
  
  provisioner "shell" {
    inline = [
      "set -e",
      "sudo mkdir -p /home/ec2-user/app",
      "sudo cp -r /tmp/backend/. /home/ec2-user/app/",
      "sudo chown -R ec2-user:ec2-user /home/ec2-user/app",
      "cd /home/ec2-user/app",
      "pip3 install --user -r requirements.txt",
      "echo 'Backend application setup completed'"
    ]
  }
  
  provisioner "shell" {
    inline = [
      "set -e",
      "sudo tee /etc/systemd/system/backend-api.service > /dev/null <<'EOF'",
      "[Unit]",
      "Description=FastAPI Backend Service",
      "After=network.target",
      "",
      "[Service]",
      "Type=simple",
      "User=ec2-user",
      "WorkingDirectory=/home/ec2-user/app",
      "Environment=\"PATH=/home/ec2-user/.local/bin:/usr/local/bin:/usr/bin:/bin\"",
      "EnvironmentFile=/home/ec2-user/app/.env",
      "ExecStart=/home/ec2-user/.local/bin/uvicorn main:app --host 0.0.0.0 --port 8000",
      "Restart=always",
      "RestartSec=10",
      "",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable backend-api",
      "echo 'Systemd service created and enabled'"
    ]
  }
}