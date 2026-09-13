output "server_public_ip" {
  description = "Public IP of the k3s control-plane node"
  value       = aws_instance.server.public_ip
}

output "server_private_ip" {
  description = "Private IP of the k3s control-plane node, used by agents to join"
  value       = aws_instance.server.private_ip
}

output "worker_public_ips" {
  description = "Public IPs of the k3s agent nodes, for Ansible SSH"
  value       = aws_instance.worker[*].public_ip
}

output "worker_private_ips" {
  description = "Private IPs of the k3s agent nodes"
  value       = aws_instance.worker[*].private_ip
}

output "ssh_key_name" {
  description = "Name of the EC2 key pair attached to all nodes"
  value       = aws_key_pair.cluster.key_name
}