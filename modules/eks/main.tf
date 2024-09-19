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
    security_group_ids = [var.security_group_id]
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


# resource "kubernetes_namespace" "test_namespace" {
#   metadata {
#     name = "test-namespace"
#   }
# }

data "template_file" "deployment" {
  template = file("${path.module}/templates/deployment_template.yaml")

  vars = {
    name            = "ekscape-deployment"
    namespace       = "default"
    app_label       = "ekscape-app"
    replicas        = 3
    container_name  = "ekscape-container"
    container_image = "car-app:v1.0.0"
    container_port  = 3000
  }
}

//For some reason this wount wait for the cluster to stand-up..........Why? 
# resource "kubernetes_manifest" "deployment" {
#   manifest = yamldecode(data.template_file.deployment.rendered)
# }

data "template_file" "service" {
  template = file("${path.module}/templates/service_template.yaml")

  vars = {
    name           = "ekscape-service"
    namespace      = "default"
    app_label      = "ekscape-app"
    service_port   = 3000
    container_port = 3000
    service_type   = "LoadBalancer"  #"ClusterIP"  # or "LoadBalancer", "NodePort", depending on your needs
  }
}


resource "null_resource" "apply_k8s_manifests" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<EOF
      ${data.template_file.deployment.rendered}
      ---
      ${data.template_file.service.rendered}
      EOF
    EOT
  }

  depends_on = [null_resource.kubeconfig_update, null_resource.cilium_install]
}


resource "null_resource" "kubeconfig_update" {
  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --name ${aws_eks_cluster.ekscape.name} --region us-east-1
    EOT
  }

  depends_on = [aws_eks_cluster.ekscape, aws_eks_node_group.eks_nodes]
}

# resource "kubernetes_manifest" "service" {
#   manifest = yamldecode(data.template_file.service.rendered)
# }

resource "null_resource" "cilium_install" {
  provisioner "local-exec" {
    command = <<-EOT
      helm repo add cilium https://helm.cilium.io/
      helm repo update
      helm install cilium cilium/cilium --version 1.15.6 \
          --namespace kube-system \
                    --set eni.enabled=true \
                    --set ipam.mode=eni \
                    --set egressMasqueradeInterfaces=eth0 \
                    --set routingMode=native \
                    --set eks.enabled=true \
                    --set nodeinit.enabled=true \
                    --set nodeinit.restartPods=true \
                    --set tunnel=disabled \
                    --set installNoConntrackIptablesRules=true \
                    --set bpf.masquerade=false \
                    --set prometheus.enabled=true \
                    --set operator.prometheus.enabled=true \
                    --set hubble.enabled=true \
                    --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,http}" \
                    --set hubble.relay.enabled=true \
                    --set hubble.ui.enabled=true \
                    --set tetragon.enabled=true \
                    --set nodePort.enabled=true \
                    --set tetragon.export.pprof.enabled=true \
                    --set tetragon.export.hubble.enabled=true \
                    --set tetragon.resources.requests.cpu=100m \
                    --set tetragon.resources.requests.memory=100Mi \
                    --set tetragon.resources.limits.cpu=500m \
                    --set tetragon.resources.limits.memory=500Mi \
                    --set directRoutingDevice=eth0
    EOT
  }

  depends_on = [null_resource.kubeconfig_update, aws_eks_cluster.ekscape, aws_eks_node_group.eks_nodes]
}


resource "null_resource" "argocd_install" {
  provisioner "local-exec" {
    command = <<-EOT
      helm repo add argo https://argoproj.github.io/argo-helm
      helm repo update
      kubectl create namespace argocd
      helm install argocd argo/argo-cd --namespace argocd \
                              --set server.service.type=LoadBalancer
    EOT
  }

  depends_on = [null_resource.kubeconfig_update, null_resource.cilium_install]
}
