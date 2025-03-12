variable "domain" {
  type = string
}

variable "s3_documents_name_prefix" {
  type = string
}

variable "s3_analyzed_documents_name_prefix" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "cloudflare_token" {
  description = "The token to use to connect to Cloudflare"
  type        = string
  sensitive   = true
}