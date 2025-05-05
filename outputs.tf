output "nbc_ssm_command" {
  value = "aws --region us-east-1 ssm start-session --target ${aws_instance.nbc_instance.id}"
}

output "nbc_url" {
  value = "https://${aws_instance.nbc_instance.public_ip}"
}

output "nbe_ssm_command" {
  value = "aws --region us-east-1 ssm start-session --target ${aws_instance.nbe_instance.id}"
}

output "nbe_console_url" {
  value = "https://${aws_instance.nbe_instance.public_ip}:30000"
}