# Primary outputs for GitHub Actions
output "instance_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.api.public_ip
}

output "instance_id" {
  description = "ID of EC2 instance"
  value       = aws_instance.api.id
}

output "api_url" {
  description = "API URL"
  value       = "http://${aws_instance.api.public_ip}:8000"
}

# Alternative named outputs for clarity
output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.api.public_ip
}

output "ec2_instance_id" {
  description = "Instance ID of the EC2 instance"
  value       = aws_instance.api.id
}

output "api_endpoint" {
  description = "API endpoint URL"
  value       = "http://${aws_instance.api.public_ip}:8000"
}

output "api_docs" {
  description = "API documentation URL"
  value       = "http://${aws_instance.api.public_ip}:8000/docs"
}

