#!/bin/bash
set -e
cat > /home/ec2-user/app/.env << 'EOF'
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
EOF
chmod 600 /home/ec2-user/app/.env
cat > /etc/systemd/system/backend-api.service << 'EOF'
[Unit]
Description=FastAPI Backend Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/app
Environment="PATH=/home/ec2-user/.local/bin:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=/home/ec2-user/app/.env
ExecStart=/home/ec2-user/.local/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start backend-api
systemctl enable backend-api

echo "Backend API service started"