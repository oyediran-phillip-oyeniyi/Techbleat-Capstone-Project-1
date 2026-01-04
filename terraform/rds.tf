# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "Main DB subnet group"
  }
}


resource "aws_db_instance" "postgres" {
  identifier             = "production-postgres"
  engine                 = "postgres"
  engine_version         = "14.19"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_encrypted      = false
  
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  backup_retention_period = 0 
  backup_window          = null
  maintenance_window     = "mon:04:00-mon:05:00"
  
  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = true

  enabled_cloudwatch_logs_exports = []
  
  performance_insights_enabled = false
  
  deletion_protection = false

  tags = {
    Name        = "Production PostgreSQL"
    Environment = "production"
    Tier        = "Free"
  }
}