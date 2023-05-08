# HCP Boundary with self managed workers

## Synopsis

Get secure access to your private resources through HCP Boundary.  
In stead of traditional solutions like jump-boxes or VPN's, (a part of)  
Boundary does not need any ingress firewall rules. In stead, it only needs  
egress access to an upstream worker.  

## Requirements

This repository is meant for using during a live demo and expects:

- You have Terraform installed locally
- You have access to HCP
- You have a valid Azure subscription
  - You are already authenticated through `az login`

## Terraform

Terraform will provision the following:  

### Azure

- 1 resource group
- 2 virtual networks
- 2 virtual subnets
- 1 network security group
- 1 public IP address
- 5 network interfaces
- 2 tls keys
- 1 storage account
- 5 Linux virtual machines

### Local

- 3 local files

## Post deployment

### HCP (1)

1. Navigate to <https://portal.cloud.hashicorp.com>
2. Create HCP Boundary Cluster
3. Copy Cluster URL
   ```shell
   export BOUNDARY_ADDR=<cluster_url>
   ```
4. Click on Auth Methods and copy the ID for the *password* auth method
   ```shell
   export BOUNDARY_AUTH_METHOD_ID=<auth_method_id>
   ```
   
### Ingress worker

1. Log into the ingress worker with SSH
2. Install the `boundary-worker-hcp` package
   ```shell
   wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install boundary-worker-hcp
   ```
3. Ensure directory structure
4. Create configuration
5. Create systemd unit file
6. Ensure service
7. Copy *Worker Auth Registration Request*
