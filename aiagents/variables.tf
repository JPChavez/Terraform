variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "dns_label" {
  description = "DNS label for the AIAgentsPortal public IP"
  type        = string
  default     = "aiagents-ce63041a"
}

variable "aks_node_rg" {
  description = "AKS node resource group (MC_...)"
  type        = string
  default     = "MC_infraportal-rg_infraportal-aks_eastus"
}
