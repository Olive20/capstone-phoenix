variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
variable "subnet_cidr" {
  description = "The CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}
variable "project" {
  description = "Name prefix applied to all resources"
  type        = string
}
variable "availability_zone" {
  description = "The availability zone to deploy resources in"
  type        = string
  default     = "eu-north-1a"
}