variable "project" {
  description = "Name prefix applied to all resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for all cluster nodes"
  type        = string
}

variable "worker_count" {
  description = "Number of k3s agent nodes to create"
  type        = number
}

variable "subnet_id" {
  description = "ID of the subnet to launch instances into"
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group to attach to all nodes"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the public SSH key registered as the EC2 key pair"
  type        = string
}