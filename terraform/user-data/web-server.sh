#!/bin/bash
set -e
sed -i "s|BACKEND_LB_DNS|${backend_lb_dns}|g" /etc/nginx/conf.d/default.conf
nginx -t
systemctl restart nginx
systemctl enable nginx
echo "Web server configured with backend LB: ${backend_lb_dns}"