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

        stage('Wait for Instances') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    dir('terraform') {
                        def webInstanceIds = sh(
                            script: 'terraform output -json web_server_instance_ids',
                            returnStdout: true
                        ).trim()
                        
                        def backendInstanceIds = sh(
                            script: 'terraform output -json backend_server_instance_ids',
                            returnStdout: true
                        ).trim()
                        
                        env.WEB_INSTANCE_IDS = webInstanceIds
                        env.BACKEND_INSTANCE_IDS = backendInstanceIds
                        
                        // Wait for web servers
                        sh "aws ec2 wait instance-status-ok --instance-ids \$(echo '${webInstanceIds}' | jq -r '.[]')"
                        
                        // Wait for backend servers
                        sh "aws ec2 wait instance-status-ok --instance-ids \$(echo '${backendInstanceIds}' | jq -r '.[]')"
                    }
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
                        def webIps = sh(
                            script: 'terraform output -json web_server_ips',
                            returnStdout: true
                        ).trim()
                        
                        def backendIp1 = sh(
                            script: 'terraform output -raw backend_server_1_ip',
                            returnStdout: true
                        ).trim()
                        
                        def backendIp2 = sh(
                            script: 'terraform output -raw backend_server_2_ip',
                            returnStdout: true
                        ).trim()
                        
                        env.WEB_IPS = webIps
                        env.BACKEND_IP1 = backendIp1
                        env.BACKEND_IP2 = backendIp2
                        
                        echo "Web Server IPs: ${webIps}"
                        echo "Backend IP1: ${backendIp1}"
                        echo "Backend IP2: ${backendIp2}"
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
                                echo "Deploying to \$ip..."

                                # Copy files to temporary writable location
                                scp -o StrictHostKeyChecking=no \
                                    nginx/nginx.conf ec2-user@\$ip:/tmp/nginx.conf

                                scp -o StrictHostKeyChecking=no \
                                    application/frontend/index.html ec2-user@\$ip:/tmp/index.html

                                # Move files to nginx directories and update values
                                ssh -o StrictHostKeyChecking=no ec2-user@\$ip \\
                                    "sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf && \
                                    sudo mv /tmp/index.html /usr/share/nginx/html/index.html && \
                                    sudo sed -i 's|#BACKEND_SERVERS#|server '${BACKEND_IP1}':8000; server '${BACKEND_IP2}':8000;|g' /etc/nginx/nginx.conf"


                                # Validate and reload nginx
                                ssh -o StrictHostKeyChecking=no ec2-user@\$ip \\
                                    "sudo nginx -t && (sudo nginx -s reload || sudo nginx)"

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
                    echo "Application deployed successfully!"
                    echo "Access your application at: http://${env.DB_ENDPOINT}"
                    echo ""
                    echo "Test the backend API at: http://${env.DB_ENDPOINT}/api/products"
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