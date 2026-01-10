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

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}