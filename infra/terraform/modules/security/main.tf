resource "aws_security_group" "cluster" {
  name        = "${var.project}-cluster"
  description = "Security group for k3s cluster nodes"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-cluster-sg"
  }
}

# --- Public ingress: web traffic only ---

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.cluster.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.cluster.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# --- Restricted ingress: admin only ---

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.cluster.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "k8s_api_admin" {
  security_group_id = aws_security_group.cluster.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
}

# --- Internal: node-to-node, never public ---

resource "aws_vpc_security_group_ingress_rule" "k8s_api_internal" {
  security_group_id            = aws_security_group.cluster.id
  referenced_security_group_id = aws_security_group.cluster.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "flannel_vxlan" {
  security_group_id            = aws_security_group.cluster.id
  referenced_security_group_id = aws_security_group.cluster.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "kubelet" {
  security_group_id            = aws_security_group.cluster.id
  referenced_security_group_id = aws_security_group.cluster.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
}

# --- Egress: nodes need to pull images and reach Let's Encrypt ---

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.cluster.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}