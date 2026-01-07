pipeline {
    agent any
    
    environment {
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
        AWS_REGION = 'eu-west-1'
    }
    
    parameters {
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform action to perform')
        booleanParam(name: 'BUILD_AMIS', defaultValue: false, description: 'Build new AMIs with Packer')
        string(name: 'ADMIN_IP', defaultValue: '', description: 'Admin IP for SSH access (leave empty to use Jenkins server IP)')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Set Admin IP') {
            steps {
                script {
                    def adminIp = params.ADMIN_IP
                    if (adminIp == '') {
                        adminIp = sh(
                            script: 'curl -s http://checkip.amazonaws.com',
                            returnStdout: true
                        ).trim()
                        echo "Using Jenkins server IP: ${adminIp}"
                    }

                    dir('terraform') {
                        sh """
                            sed -i 's|admin_ip\\s*=.*|admin_ip = \"${adminIp}/32\"|' phil.tfvars
                        """
                    }
                }
            }
        }
        
        stage('Build AMIs') {
            when {
                expression { params.BUILD_AMIS == true }
            }
            steps {
                script {
                    dir('packer') {
                        echo 'Building Backend Server AMI...'
                        sh '''
                            packer init backend-server.pkr.hcl
                            packer build -var "aws_region=${AWS_REGION}" backend-server.pkr.hcl
                        '''
                        
                        echo 'Building Web Server AMI...'
                        sh '''
                            packer init web-server.pkr.hcl
                            packer build -var "aws_region=${AWS_REGION}" web-server.pkr.hcl
                        '''
                    }
                }
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh 'terraform init -reconfigure'
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    sh 'terraform validate'
                }
            }
        }
        
        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'plan' || params.ACTION == 'apply' }
            }
            steps {
                dir('terraform') {
                    sh 'terraform plan -var-file="phil.tfvars"'
                }
            }
        }
        
        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir('terraform') {
                    sh 'terraform apply -var-file="phil.tfvars" -auto-approve'
                }
            }
        }

        stage('Retrieve Outputs') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    dir('terraform') {
                        def dbEndpoint = sh(
                            script: 'terraform output -raw rds_endpoint',
                            returnStdout: true
                        ).trim()
                        
                        def webIps = sh(
                            script: 'terraform output -json web_server_ips',
                            returnStdout: true
                        ).trim()
                        
                        env.DB_ENDPOINT = dbEndpoint
                        env.WEB_IPS = webIps
                        
                        echo "Database Endpoint: ${dbEndpoint}"
                        echo "Web Server IPs: ${webIps}"
                    }
                }
            }
        }
        
        stage('Deploy Application Code') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    sshagent(credentials: ['AWS_SSH_KEY']) {
                        sh """
                            set -e

                            for ip in \$(echo '${env.WEB_IPS}' | jq -r '.[]'); do
                                ssh -o StrictHostKeyChecking=no ec2-user@\$ip "mkdir -p /tmp/frontend_deploy"

                                scp -o StrictHostKeyChecking=no \
                                    -r application/frontend/* ec2-user@\$ip:/tmp/frontend_deploy/

                                echo "Installing files and setting permissions..."
                                ssh -o StrictHostKeyChecking=no ec2-user@\$ip << 'EOF'
sudo rm -rf /usr/share/nginx/html/*
sudo cp -r /tmp/frontend_deploy/* /usr/share/nginx/html/
sudo chown -R nginx:nginx /usr/share/nginx/html/
sudo chmod -R 755 /usr/share/nginx/html/
rm -rf /tmp/frontend_deploy
EOF

                                ssh -o StrictHostKeyChecking=no ec2-user@\$ip \
                                    "sudo systemctl daemon-reload && (sudo systemctl restart nginx || sudo systemctl start nginx)"
                            done
                        """
                    }
                }

            }
        }

        stage('Configure Nginx') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {                   
                    def backendAlbDns = sh(
                        script: 'cd terraform && terraform output -raw backend_alb_dns',
                        returnStdout: true
                    ).trim()
                    
                    echo "Backend ALB DNS: ${backendAlbDns}"
                    
                    sshagent(credentials: ['AWS_SSH_KEY']) {
                        sh """
                            set -e
                            for ip in \$(echo '${env.WEB_IPS}' | jq -r '.[]'); do
                                ssh -o StrictHostKeyChecking=no \
                                    # -o UserKnownHostsFile=/dev/null \
                                    ec2-user@\$ip "
                                    sudo sed -i 's|BACKEND_LB_DNS|${backendAlbDns}|g' /etc/nginx/nginx.conf
                                    sudo nginx -t
                                "
                                ssh -o StrictHostKeyChecking=no \
                                    # -o UserKnownHostsFile=/dev/null \
                                    ec2-user@\$ip "
                                    sudo systemctl restart nginx
                                    sudo systemctl status nginx --no-pager -l
                                "
                            done
                        """
                    }
                }
            }
        }
        
        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                dir('terraform') {
                    input message: 'Are you sure you want to destroy?', ok: 'Destroy'
                    sh 'terraform destroy -var-file="phil.tfvars" -auto-approve'
                }
            }
        }
        
        stage('Verify Deployment') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    def albDns = sh(
                        script: 'cd terraform && terraform output -raw web_alb_dns',
                        returnStdout: true
                    ).trim()
                    
                    echo "Application deployed successfully!"
                    echo "Access your application at: http://${albDns}"
                    echo ""
                    echo "Test the backend API at: http://${albDns}/api/products"
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed. Check logs for details.'
        }
    }
}