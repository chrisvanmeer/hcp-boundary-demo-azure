#############
# TERRAFORM #
#############

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.55.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }
  }
}

#############
# PROVIDERS #
#############

provider "azurerm" {
  features {}
}

provider "local" {
}

provider "tls" {
}

#############
# VARIABLES #
#############

variable "resource_group_name" {
  default = "rg_boundary"
}
variable "resource_group_location" {
  default = "West Europe"
}
variable "worker_username" {
  default = "boundary"
}
variable "server_username" {
  default = "serveradmin"
}
variable "worker_ssh_pubkey" {
  default = "~/.ssh/id_rsa.pub"
}
variable "storage_account_name" {
  default = "boundary"
}

##################
# RESOURCE GROUP #
##################

# Ensure resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

############
# NETWORKS #
############

# Ensure public virtual network for ingress worker
resource "azurerm_virtual_network" "public" {
  name                = "public-network"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Ensure private virtual network for egress worker
resource "azurerm_virtual_network" "private" {
  name                = "private-network"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["100.0.0.0/16"]
}

###########
# SUBNETS #
###########

# Ensure subnet for public network
resource "azurerm_subnet" "public" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.public.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Ensure subnet for private network
resource "azurerm_subnet" "private" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.private.name
  address_prefixes     = ["100.0.1.0/24"]
}

##########################
# NETWORK SECURITY GROUP #
##########################

# Ensure NSG for public subnet
resource "azurerm_network_security_group" "nsg" {
  name                = "boundary-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Boundary"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "9202"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Ensure association of NSG to public subnet
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

#############
# PUBLIC IP #
#############

# Ensure public IP address for ingress worker
resource "azurerm_public_ip" "public" {
  name                = "worker-ingress-public-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

######################
# NETWORK INTERFACES #
######################

# Ensure NIC for worker-ingress
resource "azurerm_network_interface" "worker-ingress" {
  name                = "worker-ingress-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "public-internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public.id
  }
}

# Ensure NIC for worker-egress
resource "azurerm_network_interface" "worker-egress" {
  name                = "worker-egress-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "private-internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Ensure NIC for server1
resource "azurerm_network_interface" "server1" {
  name                = "server1-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "private-internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Ensure NIC for server2
resource "azurerm_network_interface" "server2" {
  name                = "server2-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "private-internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Ensure NIC for server3
resource "azurerm_network_interface" "server3" {
  name                = "server3-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "private-internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

##########################
# SSH KEYPAIR FOR EGRESS #
##########################

# Ensure creation of SSH keypairs for servers
resource "tls_private_key" "egress" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Write private key to disk
resource "local_file" "egress_private_key" {
  content         = tls_private_key.egress.private_key_pem
  filename        = "${path.module}/egress.pem"
  file_permission = "0600"
}

###########################
# SSH KEYPAIR FOR SERVERS #
###########################

# Ensure creation of SSH keypairs for servers
resource "tls_private_key" "servers" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Write private key to disk
resource "local_file" "servers_private_key" {
  content         = tls_private_key.servers.private_key_pem
  filename        = "${path.module}/servers.pem"
  file_permission = "0600"
}

#######################
# STORAGE ACCOUNT FOR #
#  BOOT DIAGNOSTICS   #
#######################

resource "azurerm_storage_account" "boundary" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

############################
# CLOUD INIT FOR WEBSERVER #
############################

resource "local_file" "cloudinit" {
  filename = "${path.module}/cloudinit.yaml"
  content  = <<-EOT
    #cloud-config
    package_upgrade: true
    packages:
      - nginx
    write_files:
      - owner: root:root
        path: /usr/share/nginx/index.html
        content: |
          You are accessing this page through Boundary.
      - owner: root:root
        path: /var/www/html/index.html
        content: |
          You are accessing this page through Boundary.
    runcmd:
      - service nginx restart
  EOT
}

####################
# VIRTUAL MACHINES #
####################

# worker-ingress
resource "azurerm_linux_virtual_machine" "worker-ingress" {
  name                = "worker-ingress"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.worker_username
  network_interface_ids = [
    azurerm_network_interface.worker-ingress.id
  ]

  admin_ssh_key {
    username   = var.worker_username
    public_key = file(var.worker_ssh_pubkey)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# worker-egress
resource "azurerm_linux_virtual_machine" "worker-egress" {
  name                = "worker-egress"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.worker_username
  network_interface_ids = [
    azurerm_network_interface.worker-egress.id
  ]

  admin_ssh_key {
    username   = var.worker_username
    public_key = tls_private_key.egress.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.boundary.primary_blob_endpoint
  }
}

# server1
resource "azurerm_linux_virtual_machine" "server1" {
  name                = "server1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.server_username
  network_interface_ids = [
    azurerm_network_interface.server1.id
  ]

  admin_ssh_key {
    username   = var.server_username
    public_key = tls_private_key.servers.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# server2
resource "azurerm_linux_virtual_machine" "server2" {
  name                = "server2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.server_username
  network_interface_ids = [
    azurerm_network_interface.server2.id
  ]

  admin_ssh_key {
    username   = var.server_username
    public_key = tls_private_key.servers.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-11"
    sku       = "11"
    version   = "latest"
  }
}

# server3
resource "azurerm_linux_virtual_machine" "server3" {
  name                = "server3"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.server_username
  network_interface_ids = [
    azurerm_network_interface.server3.id
  ]

  custom_data = base64encode(local_file.cloudinit.content)

  admin_ssh_key {
    username   = var.server_username
    public_key = tls_private_key.servers.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9_1"
    version   = "latest"
  }

}

###########
# OUTPUTS #
###########

output "worker-ingress" {
  value = azurerm_linux_virtual_machine.worker-ingress.public_ip_address
}

output "worker-egress" {
  value = azurerm_linux_virtual_machine.worker-egress.private_ip_address
}

output "server1" {
  value = azurerm_linux_virtual_machine.server1.private_ip_address
}

output "server2" {
  value = azurerm_linux_virtual_machine.server2.private_ip_address
}

output "server3" {
  value = azurerm_linux_virtual_machine.server3.private_ip_address
}
