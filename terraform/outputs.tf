output "backend_server_1_ip" {
  description = "Private IP of backend server 1"
  value       = aws_instance.backend_server_1.private_ip
}

output "backend_server_2_ip" {
  description = "Private IP of backend server 2"
  value       = aws_instance.backend_server_2.private_ip
}

output "web_server_ips" {
  description = "Public IPs of web servers"
  value       = [aws_instance.web_server_1.public_ip, aws_instance.web_server_2.public_ip]
}

output "backend_server_ips" {
  description = "Private IPs of backend servers"
  value       = [aws_instance.backend_server_1.private_ip, aws_instance.backend_server_2.private_ip]
}

output "web_server_instance_ids" {
  description = "Instance IDs of web servers"
  value       = [aws_instance.web_server_1.id, aws_instance.web_server_2.id]
}

output "backend_server_instance_ids" {
  description = "Instance IDs of backend servers"
  value       = [aws_instance.backend_server_1.id, aws_instance.backend_server_2.id]
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "domain_name" {
  description = "The domain name"
  value       = var.domain_name
}

output "email" {
  description = "The email for Let's Encrypt"
  value       = var.email
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.web_nlb.dns_name
}