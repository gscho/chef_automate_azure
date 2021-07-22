terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "chef_automate" {
  name     = "chef-automate"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "chef_automate" {
  name                = "chef-automate-network"
  resource_group_name = azurerm_resource_group.chef_automate.name
  location            = azurerm_resource_group.chef_automate.location
  address_space       = ["10.1.2.0/24"]
  tags                = var.tags
}

resource "azurerm_subnet" "chef_automate" {
  name                 = "chef-automate-internal"
  resource_group_name  = azurerm_resource_group.chef_automate.name
  virtual_network_name = azurerm_virtual_network.chef_automate.name
  address_prefixes     = ["10.1.2.0/24"]
}

resource "azurerm_public_ip" "chef_automate" {
  name                = "chef-automate-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.chef_automate.name
  allocation_method   = "Static"
  tags                = var.tags
}

resource "azurerm_network_interface" "chef_automate" {
  name                = "chef-automate-nic"
  location            = azurerm_resource_group.chef_automate.location
  resource_group_name = azurerm_resource_group.chef_automate.name

  ip_configuration {
    name                          = "chef-automate-ip-configuration"
    subnet_id                     = azurerm_subnet.chef_automate.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.chef_automate.id
  }
  tags = var.tags
}

resource "azurerm_network_security_group" "chef_automate" {
  name                = "chef-automate-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.chef_automate.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "chef_automate" {
  network_interface_id      = azurerm_network_interface.chef_automate.id
  network_security_group_id = azurerm_network_security_group.chef_automate.id
}

resource "tls_private_key" "chef_automate" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "chef_automate" {
  name                  = "chef-automate-vm"
  location              = azurerm_resource_group.chef_automate.location
  resource_group_name   = azurerm_resource_group.chef_automate.name
  network_interface_ids = [azurerm_network_interface.chef_automate.id]
  size                  = "Standard_D2s_v3"

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    name                 = "chef-automate-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  computer_name                   = "chef-automate"
  admin_username                  = "ubuntu"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "ubuntu"
    public_key = tls_private_key.chef_automate.public_key_openssh
  }

  tags = var.tags

  connection {
    user        = "ubuntu"
    host        = azurerm_public_ip.chef_automate.ip_address
    type        = "ssh"
    timeout     = "5m"
    private_key = tls_private_key.chef_automate.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "curl https://packages.chef.io/files/current/latest/chef-automate-cli/chef-automate_linux_amd64.zip | gunzip - > chef-automate && chmod +x chef-automate",
      "sudo ./chef-automate init-config --fqdn automate.azure.chefsuccess.io",
      "sudo sysctl -w vm.max_map_count=262144",
      "sudo sysctl -w vm.dirty_expire_centisecs=20000",
      "sudo ./chef-automate deploy --product automate --product infra-server --accept-terms-and-mlsa config.toml"
    ]
  }
}

resource "azurerm_dns_a_record" "chef_automate" {
  name                = "automate"
  zone_name           = "azure.chefsuccess.io"
  resource_group_name = "cs-shared-resources"
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.chef_automate.id
}

data "azurerm_public_ip" "chef_automate" {
  name                = azurerm_public_ip.chef_automate.name
  resource_group_name = azurerm_linux_virtual_machine.chef_automate.resource_group_name
}

