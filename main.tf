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
    state = "available"
}

#####################################
# Subnets 
#####################################

# Public subnet 1
resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "techcorp-public-subnet-1"
  }
}

# Public subnet 2
resource "aws_subnet" "public_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  
  tags = {
    Name = "techcorp-public-subnet-2"
  }
}

# Private subnet 1
resource "aws_subnet" "private_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "techcorp-private-subnet-1"
  }
}

# Private subnet 2
resource "aws_subnet" "private_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_2_cidr
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

    tags =  {
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
    subnet_id = aws_subnet.public_1.id

    tags = {
        Name = "techcorp-nat-1"
    }

    depends_on = [aws_internet_gateway.main]
}

# NAT Gateway 2
resource "aws_nat_gateway" "nat_2" {
    allocation_id = aws_eip.eip_2.id
    subnet_id = aws_subnet.public_2.id

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
    subnet_id = aws_subnet.public_1.id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
    subnet_id = aws_subnet.public_2.id
    route_table_id = aws_route_table.public.id
}

# Private Route Tables (one per AZ) with Association
resource "aws_route_table" "private_1" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_1.id
    }

    tags = {
        Name = "techcorp-rt-private-1"
    }
}

resource "aws_route_table_association" "private_1" {
    subnet_id = aws_subnet.private_1.id
    route_table_id = aws_route_table.private_1.id
}

resource "aws_route_table" "private_2" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_2.id
    }

    tags = {
        Name = "techcorp-rt-private-2"
    }
}

resource "aws_route_table_association" "private_2" {
    subnet_id = aws_subnet.private_2.id
    route_table_id = aws_route_table.private_2.id
}