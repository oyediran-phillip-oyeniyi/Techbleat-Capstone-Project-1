data "aws_ami" "web_server" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["web-server-AMI-*"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
  
  filter {
    name   = "tag:Name"
    values = ["WebServerAMI"]
  }
}

data "aws_ami" "backend_server" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["backend-server-AMI-*"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
  
  filter {
    name   = "tag:Name"
    values = ["BackendServerAMI"]
  }
}


resource "aws_instance" "web_server_1" {
  ami           = data.aws_ami.web_server.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_1.id
  
  vpc_security_group_ids = [aws_security_group.web_server.id]
  key_name              = var.key_name
  
  user_data = file("${path.module}/user-data/web-server.sh")

  tags = {
    Name = "web-server-az1"
    Tier = "Web"
  }
}

resource "aws_instance" "web_server_2" {
  ami           = data.aws_ami.web_server.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_2.id
  
  vpc_security_group_ids = [aws_security_group.web_server.id]
  key_name              = var.key_name
  
  user_data = file("${path.module}/user-data/web-server.sh")

  tags = {
    Name = "web-server-az2"
    Tier = "Web"
  }
}

# Backend Server Instances
resource "aws_instance" "backend_server_1" {
  ami           = data.aws_ami.backend_server.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.private_1.id
  
  vpc_security_group_ids = [aws_security_group.backend_server.id]
  key_name              = var.key_name
  
  user_data = templatefile("${path.module}/user-data/backend-server.sh", {
    db_host     = aws_db_instance.postgres.address
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_password
  })

  tags = {
    Name = "backend-server-az1"
    Tier = "Application"
  }
  
  depends_on = [
    aws_db_instance.postgres,
    aws_nat_gateway.nat_1
  ]
}

resource "aws_instance" "backend_server_2" {
  ami           = data.aws_ami.backend_server.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.private_2.id
  
  vpc_security_group_ids = [aws_security_group.backend_server.id]
  key_name              = var.key_name
  
  user_data = templatefile("${path.module}/user-data/backend-server.sh", {
    db_host     = aws_db_instance.postgres.address
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_password
  })

  tags = {
    Name = "backend-server-az2"
    Tier = "Application"
  }
  
  depends_on = [
    aws_db_instance.postgres,
    aws_nat_gateway.nat_1
  ]
}