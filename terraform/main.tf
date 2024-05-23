terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }

    
  }
  
  backend "s3" { 
    region = "us-east-1"
  }
}

provider "aws" {
  region  = var.aws_region
}

resource "aws_db_subnet_group" "rds_subnet_group" {
    name = "shawn_sesna_rds_subnet_group"
    subnet_ids = aws_subnet.public-sb.*.id
}



resource "aws_security_group" "security_group" {
  name        = "security-group"
  description = "Security group for Shawn Sesna resources."
  vpc_id      = aws_vpc.shawn_sesna_vpc.id

  ingress {
    description      = "PostgreSQL default port"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    #cidr_blocks      = [aws_vpc.tenant_vpc.cidr_block]
    cidr_blocks      = ["0.0.0.0/0", "73.221.47.206/32"]
    #ipv6_cidr_blocks = [aws_vpc.solutions_vpc.ipv6_cidr_block]
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "shawn-sesna-security-group"
  }

}

resource "aws_rds_cluster" "cluster" {
  vpc_security_group_ids = [aws_security_group.security_group.id]
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "15.4"
  cluster_identifier      = var.aws_postgresql_name
  master_username         = var.aws_postgresql_administrator_name
  master_password         = var.aws_postgresql_administrator_password
  
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  
  
  backup_retention_period = 7
  skip_final_snapshot     = true
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  identifier         = "${var.aws_postgresql_name}-${count.index}"
  count              = 1
  cluster_identifier = aws_rds_cluster.cluster.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.cluster.engine
  engine_version     = aws_rds_cluster.cluster.engine_version
  
  publicly_accessible = true
}

# VPC
resource "aws_vpc" "shawn_sesna_vpc" {
  cidr_block       = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "shawn-sesna-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "shawn_sesna_igw" {
  vpc_id = aws_vpc.shawn_sesna_vpc.id
  tags = {
    Name = "shawn-sesna-igw"
  }
}

# Subnets : public
resource "aws_subnet" "public-sb" {
  count = length(var.subnets_cidr)
  vpc_id = aws_vpc.shawn_sesna_vpc.id
  cidr_block = element(var.subnets_cidr,count.index)
  availability_zone = element(var.azs,count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "shawn-sesna-Subnet-${count.index+1}"
  }
}

# Route table: attach Internet Gateway 
resource "aws_route_table" "solutions_rt" {
  vpc_id = aws_vpc.shawn_sesna_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.shawn_sesna_igw.id
  }
  tags = {
    Name = "shawn-sesna-prt"
  }
}

# Route table association with public subnets
resource "aws_route_table_association" "a" {
  count = length(var.subnets_cidr)
  subnet_id      = element(aws_subnet.public-sb.*.id,count.index)
  route_table_id = aws_route_table.solutions_rt.id
}

variable "aws_region" {
	default = "us-east-1"
}

variable "vpc_cidr" {
	default = "10.20.0.0/16"
}

variable "subnets_cidr" {
	type = list
	default = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "azs" {
	type = list
	default = ["us-east-1a", "us-east-1b"]
}

variable "aws_postgresql_name" {
    type = string
}

variable "aws_postgresql_administrator_name" {
    type = string
}

variable "aws_postgresql_administrator_password" {
    type = string
}

variable "octopus_cloud_static_cidr" {
    type = string
    default = "0.0.0.0/0"
}
