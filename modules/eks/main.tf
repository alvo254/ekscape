# EKS Cluster IAM Role
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


# EKS Cluster
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

# Add EBS CSI Driver policy to node role
resource "aws_iam_role_policy_attachment" "AmazonEBSCSIDriverPolicy-Node" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
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



data "aws_caller_identity" "current" {}


# OIDC Provider for EKS
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.ekscape.identity[0].oidc[0].issuer
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.ekscape.identity[0].oidc[0].issuer
}

# EBS CSI Driver IAM Role
resource "aws_iam_role" "ebs_csi_role" {
  name = "ebs-csi-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.ekscape.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.ekscape.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_role.name
}

# EBS CSI Driver Node IAM Role
resource "aws_iam_role" "ebs_csi_node_role" {
  name = "ebs-csi-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.ekscape.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.ekscape.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:kube-system:ebs-csi-node-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ebs_csi_ec2_policy" {
  name = "ebs_csi_ec2_policy"
  role = aws_iam_role.ebs_csi_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_node_role.name
}

# Kubernetes provider configuration
data "aws_eks_cluster_auth" "cluster_auth" {
  name = aws_eks_cluster.ekscape.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.ekscape.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.ekscape.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
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



# Install EBS CSI Driver
resource "null_resource" "install_ebs_csi_driver" {
  provisioner "local-exec" {
    command = <<-EOT
      helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
      helm repo update
      helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
        --namespace kube-system \
        --set enableVolumeScheduling=true \
        --set enableVolumeResizing=true \
        --set enableVolumeSnapshot=true \
        --set controller.serviceAccount.create=true \
        --set controller.serviceAccount.name=ebs-csi-controller-sa \
        --set node.serviceAccount.create=true \
        --set node.serviceAccount.name=ebs-csi-node-sa \
        --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${aws_iam_role.ebs_csi_role.arn} \
        --set node.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${aws_iam_role.ebs_csi_node_role.arn} \
        --set node.tolerateAllTaints=true \
        --set node.env[0].name=AWS_EC2_ENDPOINT \
        --set node.env[0].value="https://ec2.${var.region}.amazonaws.com" \
        --set node.env[1].name=AWS_METADATA_IP \
        --set node.env[1].value="169.254.169.254" 
    EOT
  }

  depends_on = [
    aws_eks_cluster.ekscape,
    aws_eks_node_group.eks_nodes,
    aws_iam_role.ebs_csi_role,
    aws_iam_role.ebs_csi_node_role,
    null_resource.kubeconfig_update,
    aws_iam_openid_connect_provider.eks
  ]
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



# resource "null_resource" "prometheus" {
#    provisioner "local-exec" {
#     command = <<-EOT
#       kubectl create namespace prometheus
#       helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
#       helm install prometheus prometheus-community/prometheus \
#                                --namespace prometheus \
#                                --set alertmanager.persistentVolume.existingClaim="alertmanager-pvc" \
#                                --set server.persistentVolume.existingClaim="server-pvc" \
#                                --set pushgateway.persistentVolume.existingClaim="pushgateway-pvc" \
#                                --set alertmanager.persistentVolume.enabled=true \
#                                --set server.persistentVolume.enabled=true \
#                                --set pushgateway.persistentVolume.enabled=true
#     EOT
#   }
#   depends_on = [null_resource.kubeconfig_update, null_resource.cilium_install, null_resource.aws_ebs_csi_driver]
# }



//Testing cloudnativePG
# resource "null_resource" "cloudnative_pg_test" {
#   provisioner "local-exec" {
#      command = <<-EOT
#             helm repo add cnpg https://cloudnative-pg.github.io/charts
#             helm upgrade --install cnpg \
#               --namespace cnpg-system \
#               --create-namespace \
#               cnpg/cloudnative-pg
#       EOT
#    }
#  }

