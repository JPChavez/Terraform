tenant_id       = "596ec0e5-bae9-4225-ac7f-f7d848f35d8b"
subscription_id = "8e6e7086-4417-46a9-8ff8-30b45add5c61"
environment     = "dev"
location        = "eastus"
project         = "JProject"
project_acronym = "jp"
owner           = "Juan Pablo Chavez"

# Network
vnet_address_space   = "10.0.0.0/16"
aks_subnet_prefix    = "10.0.1.0/24"
system_subnet_prefix = "10.0.2.0/24"

# AKS
aks_kubernetes_version = "1.32"
aks_system_node_count  = 1
aks_system_vm_size     = "Standard_D2s_v3"
aks_user_min_count     = 1
aks_user_max_count     = 3
aks_user_vm_size       = "Standard_D4s_v3"

# ACR
acr_sku = "Premium"

# Key Vault
kv_sku = "premium"

# Storage Account
storage_account_tier     = "Standard"
storage_replication_type = "ZRS"

# AKS (extended)
aks_private_cluster_enabled = false
aks_authorized_ip_ranges    = ["0.0.0.0/0"]

# Private Endpoints
pe_subnet_prefix = "10.0.3.0/24"

# ACR (extended)
acr_georeplica_location = ""
terraform_operator_ip   = "189.217.80.179"
