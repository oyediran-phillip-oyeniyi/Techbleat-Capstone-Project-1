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
  
  user_data = templatefile("${path.module}/user-data/web-server.sh", {
    backend_ips_string = join(" ", [aws_instance.backend_server_1.private_ip, aws_instance.backend_server_2.private_ip])
  })

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
  
  user_data = templatefile("${path.module}/user-data/web-server.sh", {
    backend_ips_string = join(" ", [aws_instance.backend_server_1.private_ip, aws_instance.backend_server_2.private_ip])
  })

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

# Network Load Balancer
resource "aws_lb" "web_nlb" {
  name               = "web-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = false

  tags = {
    Name = "Web NLB"
  }
}

# Target Group for Web Servers
resource "aws_lb_target_group" "web_servers" {
  name     = "web-servers-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    protocol            = "TCP"
  }

  tags = {
    Name = "Web Servers Target Group"
  }
}

# Listener for NLB
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_servers.arn
  }
}

# Attach Web Servers to Target Group
resource "aws_lb_target_group_attachment" "web_server_1" {
  target_group_arn = aws_lb_target_group.web_servers.arn
  target_id        = aws_instance.web_server_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_server_2" {
  target_group_arn = aws_lb_target_group.web_servers.arn
  target_id        = aws_instance.web_server_2.id
  port             = 80
}