# Automated AWS EKS Deployment using Terraform, Helm, and Cilium

## Table of Contents

1. [Project Overview](#project-overview)
2. [Project Details](#project-details)
3. [Project Structure](#project-structure)
4. [Pre-Requisites](#pre-requisites)
5. [Getting Started](#getting-started)
    - [Cloning the Repository](#cloning-the-repository)
    - [Running Terraform](#running-terraform)
6. [Terraform Modules](#terraform-modules)
    - [VPC Module](#vpc-module)
    - [Security Group Module](#security-group-module)
    - [EKS Module](#eks-module)
7. [Documentation](#documentation)
8. [Troubleshooting](#troubleshooting)
9. [Contributing](#contributing)
10. [License](#license)

## Project Overview

This project sets up an AWS EKS (Elastic Kubernetes Service) cluster using Terraform, including IAM roles, node groups, and Kubernetes manifests. It also configures Cilium as the CNI (Container Network Interface) for advanced networking and security, and integrates ArgoCD for GitOps to automate application deployments.

## Project Details

- **Name**: EKS Terraform Setup
- **Description**: A Terraform-based solution to deploy and manage an AWS EKS cluster with associated networking, security, and Kubernetes configurations. Includes setup for Cilium networking policies and ArgoCD for continuous deployment.
- **Key Components**:
    - **AWS EKS Cluster**: Managed Kubernetes service for container orchestration.
    - **Cilium**: CNI plugin for advanced networking and security.
    - **ArgoCD**: GitOps tool for continuous deployment and application management.
- **Purpose**: To provide a scalable and secure Kubernetes environment with automated deployment capabilities.

This project creates an Amazon EKS cluster with necessary IAM roles, policies, VPC, and security groups using Terraform modules. The configuration provisions the EKS control plane, node groups, and attaches necessary policies to enable the EKS cluster to operate securely and efficiently. VPC and security group configurations are modularized for reuse.

## Project Structure

```
├── Docs/
│   ├── cilium.md
│   ├── technical-docs.md
│   └── sad.md
├── frontend/
│   └── (frontend application code and configuration)
├── modules/
│   ├── eks/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── templates/
│   │       ├── deployment_template.yaml
│   │       └── service_template.yaml
│   ├── sg/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── vpc/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── main.tf
├── providers.tf
└── README.md
```


## Pre-Requisites

Before running the Terraform configuration, ensure the following tools are installed:

- **Terraform**: Infrastructure as code tool to manage and provision your infrastructure.
- **Helm**: Package manager for Kubernetes used to manage Kubernetes applications.
- **Kubectl**: Command-line tool for interacting with Kubernetes clusters.
- **Cilium**: Networking and security project for Kubernetes and other containerized environments.
- **[AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)**: Command-line tool for interacting with AWS services.

## Getting Started

### Cloning the Repository

To get started, first clone the repository:

`git clone https://github.com/alvo254/ekscape`

### Running Terraform

Before running Terraform, ensure that you have the tools listed in the [Pre-Requisites](#pre-requisites) installed and configured with AWS credentials.

1. **Initialize Terraform**: This command sets up the working directory and downloads the necessary providers.
    
    `terraform init`
    
2. **Plan Infrastructure Changes**: This command shows what actions Terraform will take without making any changes.

    `terraform plan`
    
3. **Apply Infrastructure Changes**: This command applies the changes required to reach the desired state of the configuration.
    
    `terraform apply --auto-approve`
    
4. **Destroy Infrastructure**: This command removes all the resources defined in the configuration.
    
    `terraform destroy --auto-approve`
    

## Terraform Modules

Terraform modules are used to organize and encapsulate Terraform configurations. Here’s a breakdown of the modules used in this project:

### VPC Module

- **Path**: `modules/vpc/`
- **Files**:
    - `main.tf`: Defines the VPC, subnets, and any related networking resources.
    - `variables.tf`: Declares input variables used by the VPC module.
    - `outputs.tf`: Specifies output values that can be used by other modules or configurations.

### Security Group Module

- **Path**: `modules/sg/`
- **Files**:
    - `main.tf`: Defines the security groups and their rules.
    - `variables.tf`: Declares input variables for security group configuration.
    - `outputs.tf`: Provides output values such as security group IDs for use in other modules.

### EKS Module

- **Path**: `modules/eks/`
- **Files**:
    - `main.tf`: Sets up the EKS cluster, node groups, and associated IAM roles and policies.
    - `variables.tf`: Declares input variables for the EKS module, including VPC and subnet IDs, node roles, etc.
    - `outputs.tf`: Outputs the EKS cluster name and other relevant details.
    - **templates/**: Contains YAML files for Kubernetes manifests and Cilium network policies.
        - `deployment_template.yaml`: Template for Kubernetes deployment manifests.
        - `service_template.yaml`: Template for Kubernetes service manifests.

## Documentation

- **Cilium Documentation**: [Docs/cilium.md](Docs/cilium.md)
- **Technical Documentation**: Docs/technical-docs.md
- **Solution Architect Documentation**: [Docs/sad.md](Docs/sad.md)

## Troubleshooting

Ensure that IAM roles and policies are correctly applied. Verify that the EKS cluster and node group are fully operational before applying Kubernetes manifests.

## Contributing

Contributions are welcome! Please submit pull requests or raise issues if you encounter problems or have suggestions.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

