variable "function_name" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "environment_vars" {
  type = map(string)
  default = {}
}