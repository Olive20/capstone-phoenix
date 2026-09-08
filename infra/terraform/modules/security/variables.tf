variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}
variable "project" {
  description = "Name prefix applied to all resources"
  type        = string
}
variable "admin_cidr" {
  description = "Your public IPv4 in CIDR notation (e.g. 1.2.3.4/32). Restricts SSH (22) and Kubernetes API (6443) to this address only. Never set to 0.0.0.0/0."
  type        = string
}
