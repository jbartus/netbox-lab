output "ssm_command" {
  value = "aws --region us-east-1 ssm start-session --target ${aws_instance.lab_instance.id}"
}

output "netbox_url" {
  value = "https://${aws_instance.lab_instance.public_ip}"
}