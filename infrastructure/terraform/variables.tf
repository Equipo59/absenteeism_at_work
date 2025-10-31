variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_ami_id" {
  description = "AMI ID for EC2 instance (Ubuntu 22.04 LTS). Leave empty to auto-detect."
  type        = string
  default     = ""
}

variable "ec2_key_name" {
  description = "Name of existing AWS key pair for SSH access"
  type        = string
  default     = ""
}

