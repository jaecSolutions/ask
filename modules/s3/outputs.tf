output "bucket_name" {
  value = aws_s3_bucket.s3.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.s3.arn
}

output "bucket_name_domain_name" {
  value = aws_s3_bucket.s3.bucket_domain_name
}

output "bucket_name_regional_domain_name" {
  value = aws_s3_bucket.s3.bucket_regional_domain_name
}
