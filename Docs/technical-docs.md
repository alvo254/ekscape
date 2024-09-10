# not yet in an order

The `ipv6_cidr_block = cidrsubnet(aws_vpc.ekscape.ipv6_cidr_block, 8, 1)` line in Terraform is generating an IPv6 CIDR block for the subnet based on the VPC's IPv6 CIDR block.

Let's break down the `cidrsubnet` function in this context:

### Syntax of `cidrsubnet`:

`cidrsubnet(base_cidr_block, new_bits, subnet_num)`

- **`base_cidr_block`**: This is the base CIDR block from which new subnets will be created. In this case, `aws_vpc.ekscape.ipv6_cidr_block` is the IPv6 CIDR block assigned to the VPC.
- **`new_bits`**: The number of additional bits to extend the subnet mask. For IPv6, a CIDR block is often allocated with `/56` or `/64`. Here, you're specifying 8 additional bits, which allows for creating up to 256 (2^8) subnets within the base IPv6 range.
- **`subnet_num`**: This determines which subnet to create. It’s a number that Terraform uses to create a specific range of addresses within the larger IPv6 block. The number `1` in this case indicates the first subnet within the `cidrsubnet` function's output.

### Example:

Assume your VPC has an IPv6 CIDR block like `2600:1f18:17ac::/56`.

When you use:

`ipv6_cidr_block = cidrsubnet(aws_vpc.ekscape.ipv6_cidr_block, 8, 1)`

This means:

1. **Base CIDR block**: `2600:1f18:17ac::/56`
2. **New subnet mask**: `/56 + 8 = /64` (because the `new_bits` is 8, it extends the CIDR block by 8 bits, creating subnets with a `/64` prefix).
3. **Subnet number 1**: The function generates the first subnet in the range, for example, `2600:1f18:17ac:1::/64`.

If you change the `subnet_num` (e.g., `2`), it will generate a different range, for example, `2600:1f18:17ac:2::/64`.

### Why use `cidrsubnet`?

The `cidrsubnet` function allows you to programmatically and predictably split a larger CIDR block (like your VPC's IPv6 block) into smaller subnets without manually calculating the new IPv6 ranges. By adjusting the `subnet_num`, you ensure that each subnet gets a unique, non-overlapping IPv6 range.

## How Helm Works

- Helm uses a packaging format called charts. A chart is a collection of files that describe a related set of Kubernetes resources.
- Helm is primarily a client-side tool. You install it on your local machine or the machine you use to manage your Kubernetes clusters.
- How to check to context you are connected to you can use `kubect config current-context` or `helm version --short`

## Key Concepts

1. **Charts**:
    - Helm packages are called charts
    - They contain all resource definitions necessary to run an application, tool, or service inside a Kubernetes cluster
    - Charts are created as files laid out in a particular directory tree, then packaged into versioned archives to be deployed
2. **Releases**:
    - When a chart is installed, the Helm library creates a release to track that installation
    - One chart can be installed multiple times into the same cluster, and each can be independently managed and upgraded
3. **Repositories**:
    - Places where charts can be collected and shared
    - They're similar to Perl's CPAN archive or the Fedora Package Database, but for Kubernetes packages

## How It Works

1. **Chart Development**:
    - Developers create Helm charts that define Kubernetes resources
    - Charts include templates and default values
2. **Chart Storage**:
    - Charts are stored in Helm repositories or local directories
3. **Installation**:
    - Users install charts into Kubernetes clusters using Helm CLI
    - Helm renders the templates using the provided or default values
    - Helm uses the Kubernetes API to create the resources in the cluster
4. **Release Management**:
    - Helm keeps track of each installation, allowing for upgrades and rollbacks
5. **Templating**:
    - Helm uses Go templates to enable dynamic generation of manifest files
    - This allows for customization and reuse of charts across different environments
6. **How it works**:
    - You run Helm commands on your local machine.
	- Helm uses your local Kubernetes configuration (usually in `~/.kube/config`) to connect to your EKS cluster.
	- When you install or upgrade charts, Helm sends the rendered Kubernetes manifests to the Kubernetes API server of your EKS cluster.


## Key Components

1. **Helm CLI**: The command-line client that sends commands to the Kubernetes API server
2. **Charts**: The Helm packaging format
3. **Kubernetes API Server**: Helm interacts with the Kubernetes cluster through the API server

## Workflow Example

1. `helm repo add`: Add a chart repository
2. `helm search`: Search for charts
3. `helm install`: Install a chart into the cluster, creating a new release
4. `helm status`: Check the release status
5. `helm upgrade`: Upgrade a release to a new version of the chart
6. `helm rollback`: Roll back a release to a previous version

# kubernetes manifest

The `kubernetes_manifest` resource in Terraform allows you to apply Kubernetes manifests directly from a YAML or JSON configuration to your Kubernetes cluster. This resource is particularly useful for managing Kubernetes resources that may not be covered by other Terraform Kubernetes resources or when you want to use custom YAML or JSON configurations.

Here’s a breakdown of the `kubernetes_manifest` resource you provided:

### Resource Block

```
resource "kubernetes_manifest" "deployment" {
  manifest = yamldecode(data.template_file.deployment.rendered)
}
```

### Components

1. **Resource Type**: `kubernetes_manifest`
    
    - This specifies that you are defining a Kubernetes manifest resource, which can handle any Kubernetes object using YAML or JSON format.
2. **Resource Name**: `deployment`
    
    - This is a unique identifier for this resource instance within the Terraform configuration.
3. **Attribute**: `manifest`
    
    - This attribute is where you provide the actual Kubernetes manifest that you want to apply to the cluster.

### Detailed Explanation

1. **`manifest`**:
    
    - **Definition**: The `manifest` attribute accepts the YAML or JSON representation of the Kubernetes object you want to deploy.
    - **Usage**: The `manifest` field is populated with the output of the `yamldecode` function applied to the rendered template from the `template_file` data source.
2. **`yamldecode`**:
    
    - **Function**: `yamldecode` is a Terraform function that converts a YAML string into a Terraform map or list. This is necessary because Terraform processes configurations as HCL (HashiCorp Configuration Language) and needs to interpret YAML configurations as data structures.
    - **Usage**: `yamldecode(data.template_file.deployment.rendered)` converts the YAML string rendered by the `template_file` data source into a format Terraform can work with.
3. **`data.template_file.deployment.rendered`**:
    
    - **Data Source**: `data.template_file.deployment` refers to the `template_file` data source that renders a YAML template with specified variables.
    - **Attribute**: `.rendered` is the attribute of the `template_file` data source that contains the final rendered YAML as a string.

### Example Workflow

1. **Define a YAML Template**: You create a YAML template with placeholders for dynamic values.
    
2. **Render the Template**: Using the `template_file` data source, you render the YAML template by substituting placeholders with actual values.
    
3. **Apply the Manifest**: The `kubernetes_manifest` resource applies the rendered YAML configuration to your Kubernetes cluster.
    

### Use Cases

- **Custom Resources**: Manage Kubernetes resources that are not supported by Terraform’s native Kubernetes resources.
- **Complex Configurations**: Deploy configurations that are easier to manage or are more complex when defined as YAML or JSON.