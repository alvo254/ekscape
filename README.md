# AWS EKS Cluster with IAM Roles, VPC, Security Groups, and Modules

This project creates an Amazon EKS cluster with necessary IAM roles, policies, VPC, and security groups using Terraform modules. The configuration provisions the EKS control plane, node groups, and attaches necessary policies to enable the EKS cluster to operate securely and efficiently. VPC and security group configurations are modularized for reuse.

## Prerequisites

Before using this configuration, ensure you have:

- **Terraform** installed.
- **AWS CLI** configured with appropriate permissions.
- Necessary **IAM permissions** for managing EKS, EC2, and IAM resources.
- **VPC and subnets** set up for the EKS cluster.

## Modules

The following modules are included in the configuration:

1. **VPC Module (`vpc`)**: Creates the VPC and subnets for the EKS cluster.
    
    - Outputs:
        - `vpc_id`: ID of the VPC.
        - `pub_sub1`: First public subnet.
        - `pub_sub2`: Second public subnet.
2. **Security Group Module (`sg`)**: Creates security groups for the EKS cluster, linked to the VPC.
    
    - Input:
        - `vpc_id`: The ID of the VPC created by the `vpc` module.
3. **EKS Module (`eks`)**: Provisions the EKS cluster and node groups.
    
    - Inputs:
        - `pub_sub1`: First public subnet (output from the `vpc` module).
        - `pub_sub2`: Second public subnet (output from the `vpc` module).

## Resources

### IAM Roles

1. **EKS Cluster Role (`ekscape-cluster-role`)**:
    
    - Role trusted by the EKS service to manage cluster-related resources.
    - Policies attached:
        - `AmazonEKSClusterPolicy`
        - `AmazonEC2ContainerRegistryReadOnly`
2. **EKS Node Role (`ekscape-node-role`)**:
    
    - Role assigned to EC2 instances acting as worker nodes in the EKS cluster.
    - Policies attached:
        - `AmazonEKSWorkerNodePolicy`
        - `AmazonEKS_CNI_Policy`
        - `AmazonEC2ContainerRegistryReadOnly`

### EKS Cluster

- **EKS Cluster (`ekscape`)**: This resource creates the EKS cluster using the IAM role `ekscape-cluster-role` and attaches VPC subnets for the cluster, utilizing the `eks` module.

### EKS Node Group

- **EKS Node Group (`ekscape-nodes`)**: Defines a managed node group for the EKS cluster. It provisions EC2 instances as worker nodes with the IAM role `ekscape-node-role` and scaling settings, also within the `eks` module.

### IAM Policies

- The following AWS managed policies are attached to the roles:
    - `AmazonEKSClusterPolicy`: Grants permissions to manage EKS resources.
    - `AmazonEC2ContainerRegistryReadOnly`: Provides read-only access to Amazon ECR.
    - `AmazonEKSWorkerNodePolicy`: Grants necessary permissions for worker nodes.
    - `AmazonEKS_CNI_Policy`: Allows worker nodes to manage network interfaces.

## Variables

- **`module.vpc.pub_sub1`**: First public subnet ID from the VPC module.
- **`module.vpc.pub_sub2`**: Second public subnet ID from the VPC module.


## Interacting with the EKS Cluster

Once the EKS cluster is created and provisioned, you will need to configure your local environment to interact with the cluster. Follow these steps:

### 1. Configure `kubectl`

Ensure you have `kubectl` installed. You can install it from Kubernetes documentation.

Run the following command to configure `kubectl` to use your EKS cluster:

`aws eks --region <region> update-kubeconfig --name <cluster-name>`

Replace `<region>` with the AWS region where your EKS cluster is deployed and `<cluster-name>` with the name of your EKS cluster.

### 2. Verify Cluster Connection

To verify that `kubectl` is properly configured and can communicate with your EKS cluster, run:

`kubectl get nodes`

This command should list the nodes in your EKS cluster.


### 3. Expose argocd


```
kubectl create ns argocd
```

This command create argocd namespace

```
helm install argocd argo/argo-cd --namespace argocd \
                                 --set server.service.type=LoadBalancer
```

This command installs argocd into the cluster and exposes it as loadbalance to access the argocd ui via exteranlIP

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

This command get the initial admin password for you to access argocd ui
