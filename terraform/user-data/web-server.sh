#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Configure backend servers in nginx.conf
backend_servers=""
for ip in ${backend_ips}; do
  backend_servers="${backend_servers}server ${ip}:8000;\n"
done
sed -i "s|#BACKEND_SERVERS#|${backend_servers}|" /etc/nginx/nginx.conf

echo "Setting permissions for deployment..."
chown -R ec2-user:nginx /usr/share/nginx/html/
chmod -R 775 /usr/share/nginx/html/
if nginx -t; then
else
    exit 1
fi
echo "Starting Nginx..."
systemctl restart nginx
systemctl enable nginx
if systemctl is-active --quiet nginx; then
else
    systemctl status nginx
    exit 1
fi