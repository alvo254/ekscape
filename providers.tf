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
  config_context = "Alvo@ekscape.us-east-1.eksctl.io"
}