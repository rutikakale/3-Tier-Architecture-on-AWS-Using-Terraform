terraform {
  backend "s3" {
    bucket = "rutikakale15"
    key    = "terraform.tfstate"
    region = "ap-south-1"
  }
}

provider "aws" {
  region = var.region
}

# -----------------------
# VPC + Subnets
# -----------------------
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags = { Name = "${var.project_name}-vpc" }
}

# Public subnet (web)
resource "aws_subnet" "web_subnet" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.web_cidr
  availability_zone = var.az1
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-web-subnet" }
}

# Private subnet (app)
resource "aws_subnet" "app_subnet" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.app_cidr
  availability_zone = var.az1
  map_public_ip_on_launch = false
  tags = { Name = "${var.project_name}-app-subnet" }
}

# Private subnet (db)
resource "aws_subnet" "db_subnet" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.db_cidr
  availability_zone = var.az1
  map_public_ip_on_launch = false
  tags = { Name = "${var.project_name}-db-subnet" }
}

# -----------------------
# Internet Gateway + Public Route Table
# -----------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "web_assoc" {
  subnet_id      = aws_subnet.web_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# -----------------------
# NAT Gateway + Private Route Table (for app & db)
# -----------------------
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.web_subnet.id
  depends_on    = [aws_internet_gateway.igw]
  tags = { Name = "${var.project_name}-nat" }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route" "private_to_internet" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
  depends_on             = [aws_nat_gateway.nat]
}

resource "aws_route_table_association" "app_assoc" {
  subnet_id      = aws_subnet.app_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "db_assoc" {
  subnet_id      = aws_subnet.db_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# -----------------------
# Security Groups (web, app, db)
# -----------------------
# Web SG: allow SSH/HTTP/HTTPS from anywhere
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Allow SSH/HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-web-sg" }
}

# App SG: allow app port from web_sg only
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Allow traffic from web tier"
  vpc_id      = aws_vpc.this.id

  # allow outbound to anywhere (so app can reach other services)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-app-sg" }
}

resource "aws_security_group_rule" "app_ingress_from_web" {
  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.web_sg.id
  description              = "Allow app port from web SG"
}

# DB SG: allow DB port from app_sg only
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Allow DB traffic from app tier only"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-db-sg" }
}

resource "aws_security_group_rule" "db_ingress_from_app" {
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_sg.id
  source_security_group_id = aws_security_group.app_sg.id
  description              = "Allow DB port from app SG"
}

# -----------------------
# EC2 Instances (web, app, db)
# -----------------------
# Web (public) EC2
resource "aws_instance" "web" {
  ami                         = var.ami
  instance_type               = var.instance
  subnet_id                   = aws_subnet.web_subnet.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = { Name = "${var.project_name}-web" }
  depends_on = [ aws_route.public_internet_access ]
}

# App (private) EC2
resource "aws_instance" "app" {
  ami                    = var.ami
  instance_type          = var.instance
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.key_name
  associate_public_ip_address = false

  tags = { Name = "${var.project_name}-app" }
  depends_on = [ aws_nat_gateway.nat ]
}

# DB (private) EC2
resource "aws_instance" "db" {
  ami                    = var.ami
  instance_type          = var.instance
  subnet_id              = aws_subnet.db_subnet.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name               = var.key_name
  associate_public_ip_address = false

  tags = { Name = "${var.project_name}-db" }
  depends_on = [ aws_nat_gateway.nat ]
}
