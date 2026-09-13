module "network" {
  source = "./modules/network"

  project           = var.project
  availability_zone = "${var.aws_region}a"
}

module "security" {
  source = "./modules/security"

  project    = var.project
  vpc_id     = module.network.vpc_id
  admin_cidr = var.admin_cidr
}

module "compute" {
  source = "./modules/compute"

  project             = var.project
  instance_type       = var.aws_instance_type
  worker_count        = var.worker_count
  subnet_id           = module.network.subnet_id
  security_group_id   = module.security.security_group_id
  ssh_public_key_path = var.ssh_public_key
}