terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "absenteeism-api"
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}

# ==============================================================================
# RESILIENT DEPLOYMENT: Uses existing resources or creates new ones automatically
# ==============================================================================
# This configuration is designed to work both from local deployment and GitHub Actions.
# It will:
# 1. Try to use existing VPC with tag Name=absenteeism-vpc if use_existing_vpc=true
# 2. Create a new VPC if no existing one is found (resilient to VPC limit issues)
# 3. Use existing security groups if available, otherwise create new ones
# 4. Works whether resources exist or not (idempotent)

# Try to find existing VPC (get the most recent one)
data "aws_vpcs" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["absenteeism-vpc"]
  }
}

# Get the first VPC ID (or use a specific one)
# Only use existing VPC if one was found
locals {
  vpc_exists = var.use_existing_vpc && length(data.aws_vpcs.existing) > 0 && length(data.aws_vpcs.existing[0].ids) > 0
}

data "aws_vpc" "existing" {
  count = local.vpc_exists ? 1 : 0
  id    = local.vpc_exists ? data.aws_vpcs.existing[0].ids[0] : null
}

# VPC (only create if not using existing or if existing not found)
resource "aws_vpc" "main" {
  count                = local.vpc_exists ? 0 : 1
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "absenteeism-vpc"
  }
}

# Get the VPC ID and subnet ID (either existing or new)
locals {
  vpc_id = local.vpc_exists ? data.aws_vpc.existing[0].id : aws_vpc.main[0].id
}

# Find existing subnet or create new
data "aws_subnets" "existing" {
  count = local.vpc_exists ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

# Get subnet ID (either existing or new)
# Handle case when vpc_exists is false (data.aws_subnets.existing won't exist)
locals {
  # Check if subnets exist - need to verify data source exists first
  has_existing_subnets = local.vpc_exists && length(data.aws_subnets.existing) > 0 && try(length(data.aws_subnets.existing[0].ids) > 0, false)
  subnet_id = local.has_existing_subnets ? data.aws_subnets.existing[0].ids[0] : aws_subnet.public[0].id
}

# Internet Gateway (only create if not using existing VPC)
resource "aws_internet_gateway" "main" {
  count  = local.vpc_exists ? 0 : 1
  vpc_id = local.vpc_id

  tags = {
    Name = "absenteeism-igw"
  }
}

# Public Subnet (only create if not using existing VPC)
resource "aws_subnet" "public" {
  count                   = local.vpc_exists ? 0 : 1
  vpc_id                  = local.vpc_id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "absenteeism-public-subnet"
  }
}

# Route Table (only create if not using existing VPC)
resource "aws_route_table" "public" {
  count  = local.vpc_exists ? 0 : 1
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name = "absenteeism-public-rt"
  }
}

# Route Table Association (only create if not using existing VPC)
resource "aws_route_table_association" "public" {
  count          = local.vpc_exists ? 0 : 1
  subnet_id      = local.subnet_id
  route_table_id = aws_route_table.public[0].id
}

# Try to find existing security group
data "aws_security_groups" "existing" {
  count = local.vpc_exists ? 1 : 0
  filter {
    name   = "group-name"
    values = ["absenteeism-api-sg"]
  }
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

locals {
  # Check if security group exists - need to verify data source exists first
  sg_exists = local.vpc_exists && length(data.aws_security_groups.existing) > 0 && try(length(data.aws_security_groups.existing[0].ids) > 0, false)
}

data "aws_security_group" "existing" {
  count  = local.sg_exists ? 1 : 0
  id     = local.sg_exists ? data.aws_security_groups.existing[0].ids[0] : null
}

# Security Group (create only if doesn't exist)
resource "aws_security_group" "api" {
  count       = local.sg_exists ? 0 : 1
  name        = "absenteeism-api-sg"
  description = "Security group for absenteeism API"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "API Port"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MLflow UI"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "absenteeism-api-sg"
  }
}

# Key Pair (uses existing key if specified)
data "aws_key_pair" "existing" {
  count    = var.ec2_key_name != "" ? 1 : 0
  key_name = var.ec2_key_name
}

# Get latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==============================================================================
# AWS Systems Manager (SSM) Setup - No SSH Keys Required!
# ==============================================================================

# IAM Role for EC2 instance to use SSM
resource "aws_iam_role" "ec2_ssm_role" {
  name = "absenteeism-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "absenteeism-ec2-ssm-role"
  }
}

# Attach AWS managed policy for SSM agent
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Additional policy for S3 access (for deployment)
resource "aws_iam_role_policy" "s3_deployment_access" {
  name = "absenteeism-s3-deployment-access"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::absenteeism-deployment-*",
          "arn:aws:s3:::absenteeism-deployment-*/*"
        ]
      }
    ]
  })
}

# Instance Profile to attach IAM role to EC2
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "absenteeism-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# EC2 Instance
resource "aws_instance" "api" {
  ami                    = var.ec2_ami_id != "" ? var.ec2_ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.ec2_instance_type
  key_name               = var.ec2_key_name != "" ? var.ec2_key_name : null
  vpc_security_group_ids = local.sg_exists ? [data.aws_security_group.existing[0].id] : [aws_security_group.api[0].id]
  subnet_id              = local.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name
  
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              # Install SSM agent (pre-installed in Amazon Linux, needs installation in Ubuntu)
              snap install amazon-ssm-agent --classic
              systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
              systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
              # Install Docker and dependencies
              apt-get install -y docker.io docker-compose git python3 python3-pip curl
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu
              EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "absenteeism-api"
  }
}

# Note: Outputs are defined in outputs.tf

