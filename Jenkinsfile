pipeline {
    agent any
    
    environment {
        AWS_SECRET_ACCESS_KEY = credentials ('AWS_SECRET_ACCESS_KEY')
        AWS_ACCESS_KEY_ID = credentials ('AWS_ACCESS_KEY_ID')
        AWS_DEFAULT_REGION = 'eu-west-1'
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
                            sed -i 's/admin_ip\\s*=.*/admin_ip = \"${adminIp}\\/32\"/' phil.tfvars
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
                        echo 'Building Web Server AMI...'
                        sh '''
                            packer init web-server.pkr.hcl
                            packer build -var "aws_region=${AWS_REGION}" web-server.pkr.hcl
                        '''
                        
                        echo 'Building Backend Server AMI...'
                        sh '''
                            packer init backend-server.pkr.hcl
                            packer build -var "aws_region=${AWS_REGION}" backend-server.pkr.hcl
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

        stage ('Terraform Validate'){
                steps{
                    dir('terraform'){
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
                        
                        def backendIps = sh(
                            script: 'terraform output -json backend_server_ips',
                            returnStdout: true
                        ).trim()
                        
                        def webIps = sh(
                            script: 'terraform output -json web_server_ips',
                            returnStdout: true
                        ).trim()
                        
                        env.DB_ENDPOINT = dbEndpoint
                        env.BACKEND_IPS = backendIps
                        env.WEB_IPS = webIps
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
                    def dbCreds = sh(
                        script: '''
                            cd terraform
                            DB_USER=$(grep db_username phil.tfvars | cut -d'"' -f2)
                            DB_PASS=$(grep db_password phil.tfvars | cut -d'"' -f2)
                            DB_NAME=$(grep db_name phil.tfvars | cut -d'"' -f2)
                            echo "${DB_USER}:${DB_PASS}:${DB_NAME}"
                        ''',
                        returnStdout: true
                    ).trim()
                    
                    def (dbUser, dbPass, dbName) = dbCreds.split(':')
                    
                    echo 'Deploying backend application...'
                    sh """
                        for ip in \$(echo '${env.BACKEND_IPS}' | jq -r '.[]'); do
                            echo "Deploying to backend server: \$ip"
                            
                            scp -o StrictHostKeyChecking=no -r application/backend/* ec2-user@\$ip:/home/ec2-user/app/
                            
                            ssh -o StrictHostKeyChecking=no ec2-user@\$ip "cat > /home/ec2-user/app/.env << 'ENVEOF'
DB_HOST=${env.DB_ENDPOINT}
DB_NAME=${dbName}
DB_USER=${dbUser}
DB_PASSWORD=${dbPass}
ENVEOF"
                            
                            ssh ec2-user@\$ip 'cd /home/ec2-user/app && pip install -r requirements.txt'
                            ssh ec2-user@\$ip 'sudo systemctl restart backend-api'
                            ssh ec2-user@\$ip 'sudo systemctl enable backend-api'
                            
                            echo "Backend server \$ip deployed successfully"
                        done
                    """
                    
                    echo 'Deploying frontend application...'
                    sh """
                        for ip in \$(echo '${env.WEB_IPS}' | jq -r '.[]'); do
                            echo "Deploying to web server: \$ip"
                            
                            scp -o StrictHostKeyChecking=no -r application/frontend/* ec2-user@\$ip:/usr/share/nginx/html/
                            
                            # Reload nginx
                            ssh -o StrictHostKeyChecking=no ec2-user@\$ip 'sudo systemctl reload nginx'
                            
                            echo "Web server \$ip deployed successfully"
                        done
                    """
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
                    sh 'terraform destroy -auto-approve'
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