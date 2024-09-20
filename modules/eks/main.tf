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

  depends_on = [
    aws_iam_role.eks-iam-role
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

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
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
    desired_size = 3
    max_size     = 5
    min_size     = 2
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


resource "null_resource" "aws_ebs_csi_driver" {
  provisioner "local-exec" {
    command = <<-EOT
      helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
      helm repo update
      helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
                                --namespace kube-system \
                                --set enableVolumeScheduling=true \
                                --set enableVolumeResizing=true \
                                --set enableVolumeSnapshot=true
    EOT
  }

  depends_on = [null_resource.kubeconfig_update, null_resource.cilium_install]
}


resource "null_resource" "prometheus" {
   provisioner "local-exec" {
    command = <<-EOT
      kubectl create namespace argocd
      helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
      helm install prometheus prometheus-community/prometheus \
                               --namespace prometheus \
                               --set alertmanager.persistentVolume.existingClaim="alertmanager-pvc" \
                               --set server.persistentVolume.existingClaim="server-pvc" \
                               --set pushgateway.persistentVolume.existingClaim="pushgateway-pvc" \
                               --set alertmanager.persistentVolume.enabled=true \
                               --set server.persistentVolume.enabled=true \
                               --set pushgateway.persistentVolume.enabled=true
    EOT
  }
  depends_on = [null_resource.kubeconfig_update, null_resource.cilium_install, null_resource.aws_ebs_csi_driver]
}