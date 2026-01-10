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
                        
                        def backendAlbDns = sh(
                            script: 'terraform output -raw backend_alb_dns',
                            returnStdout: true
                        ).trim()
                        
                        env.DB_ENDPOINT = dbEndpoint
                        env.WEB_IPS = webIps
                        env.BACKEND_LB_DNS = backendAlbDns
                        
                        echo "Database Endpoint: ${dbEndpoint}"
                        echo "Web Server IPs: ${webIps}"
                        echo "Backend ALB DNS: ${backendAlbDns}"
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
            if (!env.BACKEND_LB_DNS || env.BACKEND_LB_DNS == 'null') {
                error "BACKEND_LB_DNS is not set or is null. Cannot proceed with deployment."
            }
            
            echo "Deploying with Backend LB DNS: ${env.BACKEND_LB_DNS}"
            
            sshagent(credentials: ['AWS_SSH_KEY']) {
                sh """
                    set -e

                    for ip in \$(echo '${env.WEB_IPS}' | jq -r '.[]'); do
                        echo "Deploying to \$ip..."
                        
                        ssh -o StrictHostKeyChecking=no ec2-user@\$ip "mkdir -p /tmp/frontend_deploy /tmp/nginx_deploy"
                        
                        # Copy frontend files
                        scp -o StrictHostKeyChecking=no \
                            -r application/frontend/* ec2-user@\$ip:/tmp/frontend_deploy/

                        # Copy nginx configuration
                        scp -o StrictHostKeyChecking=no \
                            nginx/nginx.conf ec2-user@\$ip:/tmp/nginx_deploy/

                        echo "Installing frontend files on \$ip..."
                        ssh -o StrictHostKeyChecking=no ec2-user@\$ip "sudo rm -rf /usr/share/nginx/html/* && \
                            sudo cp -r /tmp/frontend_deploy/* /usr/share/nginx/html/ && \
                            sudo chown -R nginx:nginx /usr/share/nginx/html/ && \
                            sudo chmod -R 755 /usr/share/nginx/html/"

                        echo "Checking and fixing main nginx.conf on \$ip..."
                        ssh -o StrictHostKeyChecking=no ec2-user@\$ip "\
                            if sudo grep -q '^upstream' /etc/nginx/nginx.conf; then \
                                echo 'WARNING: /etc/nginx/nginx.conf is corrupted. Restoring default...'; \
                                sudo yum reinstall -y nginx || sudo amazon-linux-extras install nginx1 -y; \
                            fi"

                        echo "Deploying nginx configuration on \$ip..."
                        ssh -o StrictHostKeyChecking=no ec2-user@\$ip "\
                            sudo rm -f /etc/nginx/conf.d/default.conf && \
                            sudo rm -f /etc/nginx/conf.d/*.conf && \
                            sed 's/\\\${BACKEND_LB_DNS}/${env.BACKEND_LB_DNS}/g' /tmp/nginx_deploy/nginx.conf | \
                            sudo tee /etc/nginx/conf.d/app.conf > /dev/null && \
                            sudo chown root:root /etc/nginx/conf.d/app.conf && \
                            sudo chmod 644 /etc/nginx/conf.d/app.conf && \
                            rm -rf /tmp/frontend_deploy /tmp/nginx_deploy"

                        echo "Verifying nginx configurations on \$ip..."
                        ssh -o StrictHostKeyChecking=no ec2-user@\$ip "\
                            echo '=== Main nginx.conf (first 30 lines) ===' && \
                            sudo head -30 /etc/nginx/nginx.conf && \
                            echo '' && \
                            echo '=== App configuration ===' && \
                            sudo cat /etc/nginx/conf.d/app.conf"

                        echo "Testing nginx configuration on \$ip..."
                        ssh -o StrictHostKeyChecking=no ec2-user@\$ip "sudo nginx -t"
                        
                        echo "Restarting nginx on \$ip..."
                        ssh -o StrictHostKeyChecking=no ec2-user@\$ip \
                            "sudo systemctl daemon-reload && sudo systemctl restart nginx"
                        
                        echo "Verifying nginx status on \$ip..."
                        ssh -o StrictHostKeyChecking=no ec2-user@\$ip \
                            "sudo systemctl status nginx --no-pager -l"
                    done
                    
                    echo "Deployment completed successfully!"
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