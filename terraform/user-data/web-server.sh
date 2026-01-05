#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Backend LB DNS: ${backend_lb_dns}"
if [ -f /etc/nginx/conf.d/default.conf ]; then
    sed -i "s|BACKEND_LB_DNS|${backend_lb_dns}|g" /etc/nginx/conf.d/default.conf
    if grep -q "BACKEND_LB_DNS" /etc/nginx/conf.d/default.conf; then
        cat /etc/nginx/conf.d/default.conf
        exit 1
    else
        echo "Nginx config updated successfully"
    fi
else
    ls -la /etc/nginx/conf.d/
    exit 1
fi
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