#!/bin/bash
set -e
sudo amazon-linux-extras install nginx1 -y
sudo mkdir -p /usr/share/nginx/html
sudo systemctl enable nginx
sudo systemctl start nginx

echo "Nginx installation completed"