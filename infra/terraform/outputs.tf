output "server_public_ip" {
  description = "Public IP of the k3s control-plane node"
  value       = module.compute.server_public_ip
}

output "server_private_ip" {
  description = "Private IP of the control-plane node, used by agents to join"
  value       = module.compute.server_private_ip
}

output "worker_public_ips" {
  description = "Public IPs of the k3s agent nodes"
  value       = module.compute.worker_public_ips
}

output "worker_private_ips" {
  description = "Private IPs of the k3s agent nodes"
  value       = module.compute.worker_private_ips
}

output "vpc_id" {
  description = "ID of the cluster VPC"
  value       = module.network.vpc_id
}