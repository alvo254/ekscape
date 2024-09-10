resource "aws_iam_role" "eks-iam-role" {
  name = "ekscape-cluster-role"

  path = "/"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
  {
   "Effect": "Allow",
   "Principal": {
    "Service": "eks.amazonaws.com"
   },
   "Action": "sts:AssumeRole"
  }
 ]
}
EOF

}

resource "aws_eks_cluster" "ekscape" {
  name     = "ekscape"
  role_arn = aws_iam_role.eks-iam-role.arn

  vpc_config {
    subnet_ids = [var.pub_sub1, var.pub_sub2]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role.eks-iam-role
    # aws_iam_role_policy_attachment.ekscape-AmazonEKSClusterPolicy,
    # aws_iam_role_policy_attachment.ekscape-AmazonEKSVPCResourceController,
  ]
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-iam-role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly-EKS" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-iam-role.name
}

resource "aws_iam_role" "eks_node_role" {
  name = "ekscape-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}


resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.ekscape.id
  node_group_name = "ekscape-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [var.pub_sub1, var.pub_sub2]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  #   remote_access {
  #   ec2_ssh_key = var.ssh_key_name
  # }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_node_AmazonEC2ContainerRegistryReadOnly,
  ]
}


resource "kubernetes_namespace" "test_namespace" {
  metadata {
    name = "test-namespace"
  }
}

data "template_file" "deployment" {
  template = file("${path.module}/templates/deployment_template.yaml")

  vars = {
    name            = "ekscape-deployment"
    namespace       = "default"
    app_label       = "ekscape-app"
    replicas        = 3
    container_name  = "ekscape-container"
    container_image = "nginx:latest"
    container_port  = 80
  }
}

resource "kubernetes_manifest" "deployment" {
  manifest = yamldecode(data.template_file.deployment.rendered)
}

data "template_file" "service" {
  template = file("${path.module}/templates/service_template.yaml")

  vars = {
    name           = "ekscape-service"
    namespace      = "default"
    app_label      = "ekscape-app"
    service_port   = 80
    container_port = 80
    service_type   = "LoadBalancer"  #"ClusterIP"  # or "LoadBalancer", "NodePort", depending on your needs
  }
}

resource "kubernetes_manifest" "service" {
  manifest = yamldecode(data.template_file.service.rendered)
}


# resource "kubernetes_deployment" "ekscape" {
#   metadata {
#     name      = "ekscape-deployment"
#     namespace = "default"  # Replace with your namespace
#     labels = {
#       app = "ekscape-app"
#     }
#   }

#   spec {
#     replicas = 3  # Number of replicas

#     selector {
#       match_labels = {
#         app = "ekscape-app"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "ekscape-app"
#         }
#       }

#       spec {
#         container {
#           name  = "ekscape-container"
#           image = "nginx:latest"  # Replace with your container image
#         }
#       }
#     }
#   }
# }



# resource "null_resource" "cilium_install" {
#   provisioner "local-exec" {
#     command = <<-EOT
#       aws eks update-kubeconfig --name ${aws_eks_cluster.ekscape.name} --region us-east-1
#       helm repo add cilium https://helm.cilium.io/
#       helm repo update
#       helm install cilium cilium/cilium --version 1.14.2 \
#         --namespace kube-system \
#         --set eks.enabled=true \
#         --set nodeinit.enabled=true \
#         --set nodeinit.restartPods=true
#     EOT
#   }

#   depends_on = [aws_eks_cluster.ekscape, aws_eks_node_group.eks_nodes]
# }


# resource "null_resource" "argocd_install" {
#   provisioner "local-exec" {
#     command = <<-EOT
#       aws eks update-kubeconfig --name ${aws_eks_cluster.ekscape.name} --region us-east-1
#       helm repo add argo https://argoproj.github.io/argo-helm
#       helm repo update
        #kubectl create namespace argocd
        # helm install argocd argo/argo-cd --namespace argocd 

#   }

#   depends_on = [aws_eks_cluster.ekscape, aws_eks_node_group.eks_nodes]
# }