#!/bin/bash
set -e
sudo yum install -y python3 python3-pip git gcc python3-devel postgresql-devel
if command -v amazon-linux-extras >/dev/null 2>&1; then
  sudo amazon-linux-extras install postgresql14 -y
fi
sudo -u ec2-user python3 -m pip install --upgrade pip
sudo mkdir -p /home/ec2-user/app
sudo chown -R ec2-user:ec2-user /home/ec2-user/app

echo "Backend server setup completed"