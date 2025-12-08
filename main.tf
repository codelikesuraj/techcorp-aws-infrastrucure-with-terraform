terraform {
  required_version = ">=1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
}

#####################################
# AWS provider
#####################################

provider "aws" {
  region = var.region
}

#####################################
# VPC
#####################################

resource "aws_vpc" "vpc_main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "techcorp-vpc"
  }
}

#####################################
# Availability Zones
#####################################

data "aws_availability_zones" "available" {
  state = "available"
}

#####################################
# Subnets 
#####################################

# Public subnet 1
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc_main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "techcorp-public-subnet-1"
  }
}

# Public subnet 2
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.vpc_main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "techcorp-public-subnet-2"
  }
}

# Private subnet 1
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.vpc_main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "techcorp-private-subnet-1"
  }
}

# Private subnet 2
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.vpc_main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "techcorp-private-subnet-2"
  }
}

#####################################
# Internet Gateway
#####################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_main.id

  tags = {
    Name = "techcorp-igw"
  }
}

#####################################
# Elastic IPs for NAT Gateways
#####################################

# Elastic IP 1
resource "aws_eip" "eip_nat_1" {
  domain = "vpc"

  tags = {
    Name = "techcorp-eip-nat-1"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Elastic IP 2
resource "aws_eip" "eip_nat_2" {
  domain = "vpc"

  tags = {
    Name = "techcorp-eip-nat-2"
  }
  depends_on = [aws_internet_gateway.igw]
}

#####################################
# NAT Gateways
#####################################

# NAT Gateway 1
resource "aws_nat_gateway" "nat_1" {
  allocation_id     = aws_eip.eip_nat_1.id
  connectivity_type = "public"
  subnet_id         = aws_subnet.public_subnet_1.id

  tags = {
    Name = "techcorp-nat-1"
  }

  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway 2
resource "aws_nat_gateway" "nat_2" {
  allocation_id     = aws_eip.eip_nat_2.id
  connectivity_type = "public"
  subnet_id         = aws_subnet.public_subnet_2.id

  tags = {
    Name = "techcorp-nat-2"
  }

  depends_on = [aws_internet_gateway.igw]
}

#####################################
# Route Tables
#####################################

# Public Route Table with Association
resource "aws_route_table" "rt_public" {
  vpc_id = aws_vpc.vpc_main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "techcorp-rt-public"
  }
}

resource "aws_route_table_association" "rt_assoc_public_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.rt_public.id
}

resource "aws_route_table_association" "rt_assoc_public_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.rt_public.id
}

# Private Route Tables (one per AZ) with Association
resource "aws_route_table" "rt_private_1" {
  vpc_id = aws_vpc.vpc_main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1.id
  }

  tags = {
    Name = "techcorp-rt-private-1"
  }
}

resource "aws_route_table_association" "rt_assoc_private_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.rt_private_1.id
}

resource "aws_route_table" "rt_private_2" {
  vpc_id = aws_vpc.vpc_main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_2.id
  }

  tags = {
    Name = "techcorp-rt-private-2"
  }
}

resource "aws_route_table_association" "rt_assoc_private_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.rt_private_2.id
}

#####################################
# Security Groups
#####################################

# Bastion Security Group
resource "aws_security_group" "sg_bastion" {
  name        = "bastion"
  description = "Allow SSH (22) from your current IP address only"
  vpc_id      = aws_vpc.vpc_main.id

  tags = {
    Name = "techcorp-sg-bastion"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_ingress_bastion" {
  security_group_id = aws_security_group.sg_bastion.id
  cidr_ipv4         = var.my_ip
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "sg_egress_bastion" {
  security_group_id = aws_security_group.sg_bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Web Security Group
resource "aws_security_group" "sg_web" {
  name        = "web"
  description = "Allow HTTP (80), HTTPS (443) from anywhere, SSH (22) from Bastion Security Group."
  vpc_id      = aws_vpc.vpc_main.id

  tags = {
    Name = "techcorp-sg-web"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_ingress_web_http" {
  security_group_id = aws_security_group.sg_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "sg_ingress_web_https" {
  security_group_id = aws_security_group.sg_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "sg_ingress_web_ssh" {
  security_group_id            = aws_security_group.sg_web.id
  referenced_security_group_id = aws_security_group.sg_bastion.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "sg_egress_web" {
  security_group_id = aws_security_group.sg_web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Database Security Group
resource "aws_security_group" "sg_db" {
  name        = "db"
  description = "Allow PostgreSQL(5432) from web security group and SSH(22) from Bastion Security Group."
  vpc_id      = aws_vpc.vpc_main.id

  tags = {
    Name = "techcorp-sg-db"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_ingress_db_pgsql" {
  security_group_id            = aws_security_group.sg_db.id
  referenced_security_group_id = aws_security_group.sg_web.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "sg_ingress_db_ssh" {
  security_group_id            = aws_security_group.sg_db.id
  referenced_security_group_id = aws_security_group.sg_bastion.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "sg_egress_db" {
  security_group_id = aws_security_group.sg_db.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

#####################################
# EC2 Instances
#####################################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_instance" "instance_bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type_bastion
  subnet_id              = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.sg_bastion.id]

  tags = {
    Name = "techcorp-ec2-bastion"
  }
}

resource "aws_eip" "eip_bastion" {
  domain   = "vpc"
  instance = aws_instance.instance_bastion.id

  tags = {
    Name = "techcorp-eip-bastion"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_instance" "instance_web_1" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type_web
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.sg_web.id]

  tags = {
    Name = "techcorp-ec2-web-1"
  }
}

resource "aws_instance" "instance_web_2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type_web
  subnet_id              = aws_subnet.private_subnet_2.id
  vpc_security_group_ids = [aws_security_group.sg_web.id]

  tags = {
    Name = "techcorp-ec2-web-2"
  }
}

resource "aws_instance" "instance_db" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type_db
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.sg_db.id]

  tags = {
    Name = "techcorp-ec2-db"
  }
}
