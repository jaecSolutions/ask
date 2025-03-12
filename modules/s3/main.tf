
resource "aws_s3_bucket" "s3" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_ownership_controls" "cf-s3-ownership" {
  bucket = aws_s3_bucket.s3.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_cors_configuration" "s3" {
  bucket = aws_s3_bucket.s3.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
  }
}
