terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}


provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

# Kubernetes Provider to manage resources inside the EKS cluster
provider "kubernetes" {
  config_path = "~/.kube/config" # or use a Kubeconfig provider block to specify the cluster config
  config_context = "arn:aws:eks:us-east-1:221114290054:cluster/ekscape"
}