output "chef_automate_private_key" {
  value     = tls_private_key.chef_automate.private_key_pem
  sensitive = true
}

output "chef_automate_ip" {
  value = data.azurerm_public_ip.chef_automate.ip_address
}
