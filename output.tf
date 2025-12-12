output "web_public_ip" {
  description = "Public IP of web instance"
  value       = aws_instance.web.public_ip
}

output "app_private_ip" {
  description = "Private IP of app instance"
  value       = aws_instance.app.private_ip
}

output "db_private_ip" {
  description = "Private IP of db instance"
  value       = aws_instance.db.private_ip
}

output "vpc_id" {
  value = aws_vpc.this.id
}
