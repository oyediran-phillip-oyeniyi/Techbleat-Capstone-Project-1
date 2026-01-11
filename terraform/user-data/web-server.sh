#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Configure backend servers in nginx.conf
for ip in ${backend_ips_string}; do
  sed -i "/#BACKEND_SERVERS#/a server $ip:8000;" /etc/nginx/nginx.conf
done
sed -i "/#BACKEND_SERVERS#/d" /etc/nginx/nginx.conf

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