#!/bin/bash
set -e

# Create application directory
cd /home/ec2-user/app

# Clone application code (replace with your repo)
# git clone https://github.com/your-repo/app.git .

# For now, we'll assume code is deployed separately
# Create .env file
cat > .env << EOF
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
EOF

pip install fastapi uvicorn psycopg python-dotenv

cat > /etc/systemd/system/backend-api.service << 'EOF'
[Unit]
Description=FastAPI Backend Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/app
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=/home/ec2-user/app/.env
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "Backend server environment configured"