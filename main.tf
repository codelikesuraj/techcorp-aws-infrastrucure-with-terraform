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

resource "aws_vpc" "main" {
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
  region = var.region
  state  = "available"
}

#####################################
# Subnets 
#####################################

# Public subnet 1
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "techcorp-public-subnet-1"
  }
}

# Public subnet 2
resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "techcorp-public-subnet-2"
  }
}

# Private subnet 1
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "techcorp-private-subnet-1"
  }
}

# Private subnet 2
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "techcorp-private-subnet-2"
  }
}

#####################################
# Internet Gateway
#####################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "techcorp-igw"
  }
}

#####################################
# Elastic IPs for NAT Gateways
#####################################

# Elastic IP 1
resource "aws_eip" "eip_1" {
  domain = "vpc"

  tags = {
    Name = "techcorp-nat-eip-1"
  }

  depends_on = [aws_internet_gateway.main]
}

# Elastic IP 2
resource "aws_eip" "eip_2" {
  domain = "vpc"

  tags = {
    Name = "techcorp-nat-eip-2"
  }
  depends_on = [aws_internet_gateway.main]
}

#####################################
# NAT Gateways
#####################################

# NAT Gateway 1
resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.eip_1.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "techcorp-nat-1"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway 2
resource "aws_nat_gateway" "nat_2" {
  allocation_id = aws_eip.eip_2.id
  subnet_id     = aws_subnet.public_2.id

  tags = {
    Name = "techcorp-nat-2"
  }

  depends_on = [aws_internet_gateway.main]
}

#####################################
# Route Tables
#####################################

# Public Route Table with Association
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "techcorp-rt-public"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (one per AZ) with Association
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1.id
  }

  tags = {
    Name = "techcorp-rt-private-1"
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_2.id
  }

  tags = {
    Name = "techcorp-rt-private-2"
  }
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_2.id
}

#####################################
# Security Groups
#####################################

# Bastion Security Group
resource "aws_security_group" "bastion" {
  name        = "bastion"
  description = "Allow SSH (22) from your current IP address only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "techcorp-sg-bastion"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = var.my_ip
  from_port         = 22
  to_port           = 22
  ip_protocol       = "ssh"
}

resource "aws_vpc_security_group_egress_rule" "bastion" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Web Security Group
resource "aws_security_group" "web" {
  name        = "web"
  description = "Allow HTTP (80), HTTPS (443) from anywhere, SSH (22) from Bastion Security Group."
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "techcorp-sg-web"
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_http" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "web_https" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "web_ssh" {
  security_group_id            = aws_security_group.web.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "web" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Database Security Group
resource "aws_security_group" "db" {
  name        = "db"
  description = "Allow PostgreSQL(3306) from web security group and SSH(22) from Bastion Security Group."
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "techcorp-sg-db"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_pgsql" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "db_ssh" {
  security_group_id            = aws_security_group.web.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "db" {
  security_group_id = aws_security_group.db.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}