#!/bin/bash
set -e
export BACKEND_LB_DNS="my-alb-123.eu-west-1.elb.amazonaws.com"
envsubst < /etc/nginx/conf.d/default.conf > /etc/nginx/conf.d/default.conf.tmp
mv /etc/nginx/conf.d/default.conf.tmp /etc/nginx/conf.d/default.conf
nginx -t
systemctl restart nginx
systemctl enable nginx
echo "Web server configured with backend LB: $BACKEND_LB_DNS"
