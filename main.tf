module "vpc" {
  source = "./modules/vpc"
}

module "sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
}

module "eks" {
  source = "./modules/eks"
  pub_sub1 = module.vpc.pub_sub1
  pub_sub2 = module.vpc.pub_sub2
}