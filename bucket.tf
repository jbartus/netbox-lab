resource "aws_s3_bucket" "files" {
  bucket_prefix = "lab-files-"
  force_destroy = true
}

resource "aws_iam_role_policy" "s3_read" {
  role = aws_iam_role.ssm_instance_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [aws_s3_bucket.files.arn, "${aws_s3_bucket.files.arn}/*"]
    }]
  })
}

output "bucket_name" {
  value = aws_s3_bucket.files.id
}
