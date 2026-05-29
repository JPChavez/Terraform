output "public_ip_address" {
  value = azurerm_public_ip.aiagents.ip_address
}

output "fqdn" {
  value = azurerm_public_ip.aiagents.fqdn
}
