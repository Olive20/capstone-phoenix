variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "eu-north-1"
}
variable "aws_instance_type" {
  description = "The AWS instance type to use for EC2 instances"
  type        = string
  default     = "t3.small"
}
variable "worker_count" {
  description = "The number of worker nodes to create"
  type        = number
  default     = 2
}
variable "admin_cidr" {
  description = "Your public IP in CIDR notation, for SSH and Kubernetes API access"
  type        = string
}
variable "project" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "phoenix"
}
variable "ssh_public_key" {
  description = "The public SSH key to use for EC2 instances"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}