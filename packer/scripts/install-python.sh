#!/bin/bash
set -e
sudo yum update -y
sudo yum install -y python3 python3-pip git
sudo amazon-linux-extras install postgresql14 -y
sudo yum install -y gcc python3-devel postgresql-dev
sudo mkdir -p /home/ec2-user/app
sudo chown ec2-user:ec2-user /home/ec2-user/app

echo "Backend server setup completed"