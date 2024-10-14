resource "aws_iam_role" "eks_cluster_role" {
  name = "ekscape-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_eks_cluster" "ekscape" {
  name                      = "ekscape"
  role_arn                  = aws_iam_role.eks_cluster_role.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids         = [var.pub_sub1, var.pub_sub2]
    security_group_ids = [var.security_group_id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly-EKS,
  ]
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly-EKS" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_cluster_role.name
}


# EKS Node Group
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.ekscape.name
  node_group_name = "ekscape-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [var.pub_sub1, var.pub_sub2]

  scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 2
  }

  launch_template {
    id      = aws_launch_template.eks_launch_template.id # Use the launch template ID
    version = "$Latest"                                  # Or specify a version
  }

  instance_types = ["t3.medium"]

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}

# EKS Node IAM Role
resource "aws_iam_role" "eks_node_role" {
  name = "ekscape-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}


data "template_file" "deployment" {
  template = file("${path.module}/templates/deployment_template.yaml")

  vars = {
    name            = "ekscape-deployment"
    namespace       = "default"
    app_label       = "ekscape-app"
    replicas        = 3
    container_name  = "ekscape-container"
    container_image = "alvin254/car-app:v1.0.0"
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
    service_type   = "LoadBalancer" #"ClusterIP"  # or "LoadBalancer", "NodePort", depending on your needs
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


resource "aws_launch_template" "eks_launch_template" {
  name_prefix = "eks-node-launch-template"
  # image_id      = "ami-05ac7467eb3204c31"   # Replace with a valid EKS-optimized AMI
  # instance_type = "t3.medium"

  # Metadata Options for IMDSv2
  metadata_options {
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1          # Optional: limits the number of network hops
    http_endpoint               = "enabled"  # Ensure the metadata service is enabled
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "eks-node"
    }
  }
}


resource "null_resource" "cilium_install" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl delete daemonset aws-node -n kube-system
      helm repo add cilium https://helm.cilium.io/
      helm repo update
      helm install cilium cilium/cilium --version 1.16.1 \
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
                    --set hubble.peer.target="hubble-peer.kube-system.svc.cluster.local:4244" \
                    --set eni.updateEC2AdapterLimitViaAPI=true \
                    --set nodePort.enabled=true \
                    --set directRoutingDevice=eth0 
    EOT
  }

  depends_on = [null_resource.kubeconfig_update, aws_eks_cluster.ekscape, aws_eks_node_group.eks_nodes]
}


resource "null_resource" "tetragon_install" {
  provisioner "local-exec" {
    command = <<-EOT
      helm repo add cilium https://helm.cilium.io/
      helm repo update
      helm install tetragon cilium/tetragon --version 1.2.0 \
          --namespace kube-system \
                    --set crds.install=true \
                    --set tetragon.enabled=true \
                    --set nodePort.enabled=true \
                    --set tetragon.export.pprof.enabled=true \
                    --set tetragon.export.hubble.enabled=true \
                    --set tetragon.resources.requests.cpu=100m \
                    --set tetragon.resources.requests.memory=100Mi \
                    --set tetragon.resources.limits.cpu=500m \
                    --set tetragon.resources.limits.memory=500Mi \
    EOT
  }

  depends_on = [null_resource.kubeconfig_update, aws_eks_cluster.ekscape, aws_eks_node_group.eks_nodes, null_resource.cilium_install]
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
