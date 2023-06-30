#############
# TERRAFORM #
#############

terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "2.38.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.55.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
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

provider "azuread" {
}

provider "azurerm" {
  features {}
}

provider "local" {
}

provider "random" {
}

provider "tls" {
}

#############
# VARIABLES #
#############

variable "resource_group_name" {
  default = "rg-boundary"
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
  name                = "vnet-public"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Ensure private virtual network for egress worker
resource "azurerm_virtual_network" "private" {
  name                = "vnet-private"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["100.0.0.0/16"]
}

###########
# SUBNETS #
###########

# Ensure subnet for public network
resource "azurerm_subnet" "public" {
  name                 = "subnet-public"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.public.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Ensure subnet for private network
resource "azurerm_subnet" "private" {
  name                 = "subnet-private"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.private.name
  address_prefixes     = ["100.0.1.0/24"]
}

##########################
# NETWORK SECURITY GROUP #
##########################

# Ensure NSG for public subnet
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-boundary"
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
  name                = "ip-worker-ingress"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

######################
# NETWORK INTERFACES #
######################

# Ensure NIC for worker-ingress
resource "azurerm_network_interface" "worker-ingress" {
  name                = "nic-worker-ingress"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public.id
  }
}

# Ensure NIC for worker-egress
resource "azurerm_network_interface" "worker-egress" {
  name                = "nic-worker-egress"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Ensure NIC for server01
resource "azurerm_network_interface" "server01" {
  name                = "nic-server01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Ensure NIC for server02
resource "azurerm_network_interface" "server02" {
  name                = "nic-server02"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Ensure NIC for server3
resource "azurerm_network_interface" "server03" {
  name                = "nic-server03"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Ensure NIC for server4-win
resource "azurerm_network_interface" "server04" {
  name                = "nic-server04"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
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

# Ensure a random string to be sure it is unique
resource "random_string" "storage_account" {
  length  = 10
  lower   = true
  numeric = true
  special = false
  upper   = false
}

# Ensure storage account
resource "azurerm_storage_account" "boundary" {
  name                     = "storage${random_string.storage_account.id}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

############################
# CLOUD INIT FOR WEBSERVER #
############################

# Ensure cloud-init file
resource "local_file" "cloudinit" {
  filename = "${path.module}/cloudinit.yaml"
  content  = <<-EOT
    #cloud-config
    packages:
      - nginx
    write_files:
      - owner: root:root
        path: /usr/share/nginx/html/index.html
        content: |
          You are accessing this page through Boundary.
    runcmd:
      - firewall-cmd --add-service=http --zone=public --permanent
      - firewall-cmd --reload
      - echo "You are accessing this page through Boundary." > /usr/share/nginx/html/index.html
      - restorecon -Rv /usr/share/nginx/html
      - systemctl enable --now nginx
  EOT
}

####################
# VIRTUAL MACHINES #
####################

# worker-ingress
resource "azurerm_linux_virtual_machine" "worker-ingress" {
  name                = "vm-worker-ingress"
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
    name                 = "disk-os-worker-ingress"
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

# worker-egress
resource "azurerm_linux_virtual_machine" "worker-egress" {
  name                = "vm-worker-egress"
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
    name                 = "disk-os-worker-egress"
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

# server01
resource "azurerm_linux_virtual_machine" "server01" {
  name                = "vm-server01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.server_username
  network_interface_ids = [
    azurerm_network_interface.server01.id
  ]

  admin_ssh_key {
    username   = var.server_username
    public_key = tls_private_key.servers.public_key_openssh
  }

  os_disk {
    name                 = "disk-os-server01"
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

# server02
resource "azurerm_linux_virtual_machine" "server02" {
  name                = "vm-server02"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.server_username
  network_interface_ids = [
    azurerm_network_interface.server02.id
  ]

  admin_ssh_key {
    username   = var.server_username
    public_key = tls_private_key.servers.public_key_openssh
  }

  os_disk {
    name                 = "disk-os-server02"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-11"
    sku       = "11"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.boundary.primary_blob_endpoint
  }
}

# server03
resource "azurerm_linux_virtual_machine" "server03" {
  name                = "vm-server03"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.server_username
  network_interface_ids = [
    azurerm_network_interface.server03.id
  ]

  custom_data = base64encode(local_file.cloudinit.content)

  admin_ssh_key {
    username   = var.server_username
    public_key = tls_private_key.servers.public_key_openssh
  }

  os_disk {
    name                 = "disk-os-server03"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9_1"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.boundary.primary_blob_endpoint
  }
}

# server04

resource "random_password" "password" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = false
}
resource "azurerm_windows_virtual_machine" "server04" {
  name                = "vm-server04"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS1_v2"
  admin_username      = var.server_username
  admin_password      = random_password.password.result
  network_interface_ids = [
    azurerm_network_interface.server04.id
  ]

  os_disk {
    name                 = "disk-os-server04"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }


  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.boundary.primary_blob_endpoint
  }
}

###########
# OUTPUTS #
###########

output "vm-server01" {
  value = "${var.server_username}@${azurerm_linux_virtual_machine.server01.private_ip_address}"
}

output "vm-server02" {
  value = "${var.server_username}@${azurerm_linux_virtual_machine.server02.private_ip_address}"
}

output "vm-server03" {
  value = "${var.server_username}@${azurerm_linux_virtual_machine.server03.private_ip_address}"
}

output "vm-server04" {
  value = "${var.server_username}@${azurerm_windows_virtual_machine.server04.private_ip_address}"
}

output "vm-server04-password" {
  value     = random_password.password.result
  sensitive = true
}

output "vm-worker-egress" {
  value = "${var.worker_username}@${azurerm_linux_virtual_machine.worker-egress.private_ip_address}"
}

output "vm-worker-ingress" {
  value = "${var.worker_username}@${azurerm_linux_virtual_machine.worker-ingress.public_ip_address}"
}

/*
################################################################################
################################################################################
#    BELOW ARE OPTIONAL RESOURCES TO EXPERIMENT WITH DYNAMIC HOST CATALOGS     #
#                  THIS SECTION IS COMMENTED OUT BY DEFAULT                    #
################################################################################
################################################################################

#################################
# DATA SOURCES FOR SUBSCRIPTION #
#################################

data "azurerm_subscription" "primary" {}
data "azuread_client_config" "current" {}

#############################
#   APP REGISTRATION AND    #
#     SERVICE PRINCIPAL     #
#############################

# Ensure random ID for app_role
resource "random_uuid" "boundary_app_role" {}

# Ensure app registration
resource "azuread_application" "boundary_app" {
  display_name = "Boundary App"
  owners       = [data.azuread_client_config.current.object_id]

  app_role {
    allowed_member_types = ["Application"]
    description          = "Reader role enabling app to read subscription details"
    display_name         = "Reader"
    enabled              = true
    id                   = random_uuid.boundary_app_role.result
    value                = "Read.All"
  }
}

# Create a client secret
resource "azuread_application_password" "client_secret" {
  application_object_id = azuread_application.boundary_app.object_id
}

# Create a service principle for the application
resource "azuread_service_principal" "boundary_service_principal" {
  application_id = azuread_application.boundary_app.application_id
}

# Assign the Contributor role to the application service principle
resource "azurerm_role_assignment" "contributor_role_assignment" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.boundary_service_principal.object_id
}

#####################
# EXTRA CLIENTS FOR #
# DYNAMIC HOST SET  #
#####################
variable "client_username" {
  default = "johndoe"
}
variable "client_count" {
  type    = number
  default = 5
}

# Ensure NIC for clients
resource "azurerm_network_interface" "clients" {
  name                = format("nic-client%02d", count.index + 1)
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  count               = var.client_count

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Ensure creation of SSH keypairs for clients
resource "tls_private_key" "clients" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Write private key to disk
resource "local_file" "clients_private_key" {
  content         = tls_private_key.clients.private_key_pem
  filename        = "${path.module}/clients.pem"
  file_permission = "0600"
}

# Ensure client VM's
resource "azurerm_linux_virtual_machine" "clients" {
  name                = format("vm-client%02d", count.index + 1)
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.client_username
  count               = var.client_count
  network_interface_ids = [
    azurerm_network_interface.clients[count.index].id
  ]

  tags = {
    service-type = "client"
  }

  admin_ssh_key {
    username   = var.client_username
    public_key = tls_private_key.clients.public_key_openssh
  }

  os_disk {
    name                 = format("disk-os-client%02d", count.index + 1)
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

output "azure-tenant-id" {
  value = data.azurerm_subscription.primary.tenant_id
}

output "azure-subscription-id" {
  value = data.azurerm_subscription.primary.subscription_id
}

output "azure-client-id" {
  value = data.azuread_client_config.current.client_id
}

output "azure-client-secret" {
  value     = azuread_application_password.client_secret.value
  sensitive = true
}
*/
