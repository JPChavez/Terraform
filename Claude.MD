# Terraform Development Instructions for Claude Code

## Overview
This guide defines how to work with Terraform code targeting Azure, emphasising multi-file coordination, linting with tflint, and security scanning with checkov.

## Project Context — JProject

- **Owner**: Juan Pablo Chavez
- **Tenant ID**: `596ec0e5-bae9-4225-ac7f-f7d848f35d8b`
- **Subscription**: JPSubscription (`8e6e7086-4417-46a9-8ff8-30b45add5c61`)
- **Provider version**: `azurerm ~> 3.110` (currently installed: 3.117.1)
- **Terraform version**: `>= 1.5.0`
- **Default region**: `eastus`

## Naming Convention

All resources follow the format: **`<project_acronym>-<resource-abbreviation>-<environment>`**

Examples for JProject dev:
| Resource | Name |
|---|---|
| Resource Group | `jp-rg-dev` |
| AKS Cluster | `jp-aks-dev` |
| Key Vault | `jp-kv-dev` |
| VNet | `jp-vnet-dev` |
| ACR | `jpacrdev` *(alphanumeric only — no hyphens)* |
| Storage Account | `jpstdev` *(alphanumeric only, max 24 chars)* |

Naming is centralised in `locals.tf` using `var.project_acronym` and `var.environment`. **Never hardcode resource names** — always derive from locals.

## Standard Tags

All resources must include `tags = local.common_tags`. Tags are defined in `locals.tf`:

```hcl
common_tags = {
  project     = var.project       # "JProject"
  environment = var.environment   # "dev" | "uat" | "prod"
  region      = var.location      # "eastus"
  owner       = var.owner         # "Juan Pablo Chavez"
  managed_by  = "terraform"
}
```

**Resources that do NOT support tags** (Azure limitation):
- `azurerm_subnet`
- `azurerm_role_assignment`
- `azurerm_subnet_network_security_group_association`

## File Organisation

```
.
├── versions.tf          # Terraform + provider versions + backend config
├── providers.tf         # azurerm provider (features, subscription_id, tenant_id)
├── locals.tf            # Naming convention locals + common_tags
├── variables.tf         # All variable declarations with descriptions and validations
├── data.tf              # Data sources (azurerm_client_config.current)
├── resource_group.tf    # Main resource group
├── network.tf           # VNet, subnets, NSG
├── aks.tf               # AKS cluster + user node pool + Log Analytics
├── acr.tf               # Container Registry + AcrPull role assignment
├── keyvault.tf          # Key Vault + RBAC role assignments
├── storage.tf           # Storage Account + role assignments
├── cmk.tf               # Customer Managed Keys (KV keys, Disk Encryption Set, managed identity)
├── private_endpoints.tf # Private endpoints + DNS zones for KV, Storage, ACR
├── outputs.tf           # All outputs
├── dev.tfvars           # Dev environment variable values
├── uat.tfvars           # UAT environment variable values (to be created)
├── prod.tfvars          # Prod environment variable values (to be created)
├── .tflint.hcl          # tflint config with azurerm plugin
└── azure-pipelines.yml  # Azure DevOps CI/CD pipeline
```

## Terraform Backend

State is stored in Azure Blob Storage — already provisioned:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-tfstate-jproject"
  storage_account_name = "stjprojecttfstate"
  container_name       = "tfstate"
  key                  = "jproject.terraform.tfstate"
}
```

To create the backend infrastructure from scratch:
```bash
az group create --name rg-tfstate-jproject --location eastus
az storage account create --name stjprojecttfstate --resource-group rg-tfstate-jproject \
  --location eastus --sku Standard_LRS --kind StorageV2 --https-only true --min-tls-version TLS1_2
az storage container create --name tfstate --account-name stjprojecttfstate --auth-mode login
```

## Deployed Resources

The following resources are defined for each environment:

| Resource | File | Notes |
|---|---|---|
| Resource Group | `resource_group.tf` | All resources deploy here |
| VNet + Subnets + NSG | `network.tf` | 3 subnets: aks, system, private-endpoints |
| AKS Cluster | `aks.tf` | K8s 1.32, Standard tier, Defender enabled, public API server + IP restrictions |
| AKS User Node Pool | `aks.tf` | Autoscaling, Managed OS disk |
| Log Analytics Workspace | `aks.tf` | OMS agent + Defender backend |
| Container Registry | `acr.tf` | Premium SKU, public access disabled |
| Key Vault | `keyvault.tf` | Purge protection, RBAC, network deny |
| Storage Account | `storage.tf` | CMK, blob soft-delete + versioning, public access disabled |
| Disk Encryption Set | `cmk.tf` | RSA-HSM key, for AKS disk encryption |
| KV Keys (x2) | `cmk.tf` | Disk encryption key + Storage CMK key |
| User-Assigned Identity | `cmk.tf` | For storage CMK access |
| Private Endpoints (x3) | `private_endpoints.tf` | KV, Storage, ACR |
| Private DNS Zones (x3) | `private_endpoints.tf` | vaultcore, blob, azurecr.io |

## Provider Attribute Gotchas (azurerm 3.117.1)

The VS Code IDE schema is often wrong. Use `terraform validate` as the authoritative source. Known issues:

| Attribute | Wrong (IDE suggests) | Correct (azurerm 3.x) |
|---|---|---|
| AKS upgrade channel | `automatic_upgrade_channel` | `automatic_channel_upgrade` |
| AKS host encryption | `host_encryption_enabled` | `enable_host_encryption` |
| AKS autoscaling | `auto_scaling_enabled` | `enable_auto_scaling` |
| ACR retention | `retention_policy_in_days` (flat) | `retention_policy { days = 7; enabled = true }` |
| ACR trust policy | `trust_policy_enabled` (flat) | `trust_policy { enabled = true }` |

## AKS Deployment Gotchas

| Issue | Cause | Fix |
|---|---|---|
| `K8sVersionNotSupported` | K8s 1.30 is LTS-only; requires Premium tier | Use 1.32 (Standard tier supported) |
| `ServiceCidrOverlapExistingSubnetsCidr` | AKS default service CIDR `10.0.0.0/16` overlaps VNet | Set `service_cidr = "10.1.0.0/16"`, `dns_service_ip = "10.1.0.10"` |
| `VMCannotFitEphemeralOSDisk` | Standard_D2s_v3 cache (~50GB) < 128GB OS disk | Use `os_disk_type = "Managed"` |
| `Private cluster cannot be enabled with AuthorizedIPRanges` | Hardcoded `private_cluster_enabled = true` conflicts with `api_server_access_profile` | Use `var.aks_private_cluster_enabled` consistently |
| `you must specify client_app_id...` | Missing `managed = true` in AAD RBAC block | Add `managed = true` to `azure_active_directory_role_based_access_control` |
| `SubscriptionNotEnabledEncryptionAtHost` | Feature not registered | Run `az feature register --name EncryptionAtHost --namespace Microsoft.Compute` |
| DES `auto_key_rotation_enabled` error | Versioned key ID used | Use `azurerm_key_vault_key.disk_encryption.versionless_id` |

## Storage Account — azurerm 3.x Limitations

azurerm 3.x uses **key-based auth** (storage account key) for:
- Verifying blob service availability after `create` (including when CMK is set)
- Reading/writing `queue_properties` during refresh

Both fail when `shared_access_key_enabled = false`. **Workaround**: do not set `shared_access_key_enabled = false` in Terraform; enforce via Azure Policy instead. Upgrade to azurerm 4.x to fix natively.

## Key Vault — RBAC Note

`enable_rbac_authorization = true` is deprecated in the IDE but still functional in azurerm 3.117.1. It **must be kept** — without it, `azurerm_role_assignment` resources will not control Key Vault data plane access.

## checkov Results (baseline)

Last scan: **~62 passed, 0 failed, 2 skipped**

Skipped checks with justification:
- `CKV_AZURE_206` — Storage replication: ZRS is used (zone-redundant); cross-region GRS not required for this workload.
- `CKV_AZURE_33` — Queue logging: azurerm 3.x uses key-based auth to read/write queue_properties; disabled when shared_access_key_enabled=false (CMK + private endpoint compensate).
- `CKV2_AZURE_40` — Shared access key: azurerm 3.x requires key auth to verify blob service after CMK setup; upgrade to azurerm 4.x to enforce.

All skips added inline with `#checkov:skip=` and justification comments.

## Linting with tflint

### Setup Check
```bash
which tflint || echo "tflint not installed"
ls -la .tflint.hcl
```

### Azure tflint Plugin Configuration
```hcl
plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
```

### Standard Linting Process
```bash
tflint --init        # First time or when plugins change
tflint --recursive   # Run on all modules
```

## Security Scanning with checkov

```bash
checkov -d . --framework terraform --quiet --compact
checkov -d . --skip-check CKV_AZURE_206  # skip justified checks
```

### Critical Azure Security Checks
- Encryption at rest (storage, managed disks, databases)
- Encryption in transit (HTTPS only, TLS 1.2 minimum)
- Public access disabled (storage, Key Vault, ACR)
- Azure RBAC least privilege
- Diagnostic logging and Azure Monitor enabled
- Soft delete and backup configured
- No hardcoded secrets — use Key Vault
- Private endpoints for all PaaS services
- Customer Managed Keys for sensitive data

## Development Workflow

### 1. Before Starting Changes
```bash
az login --tenant 596ec0e5-bae9-4225-ac7f-f7d848f35d8b
az account set --subscription 8e6e7086-4417-46a9-8ff8-30b45add5c61
terraform init
terraform validate
tflint --recursive
checkov -d . --framework terraform --quiet --compact
```

### 2. Making Changes
1. **Plan the change**: Identify all affected files
2. **Search for dependencies**:
   ```bash
   grep -r "azurerm_network_security_group" --include="*.tf"
   grep -r "network_security_group_id" --include="*.tf"
   ```
3. **Update systematically**: `variables.tf` → resources → `outputs.tf`
4. **Maintain naming convention**: always use `local.prefix` or `var.project_acronym`
5. **Always add tags**: `tags = local.common_tags` on every supported resource

### 3. After Changes
```bash
terraform fmt -recursive
terraform validate
tflint --recursive
checkov -d . --framework terraform --quiet --compact
terraform plan -var-file="dev.tfvars"
```

## Variable Conventions

Every variable must have:
- `description`
- `type`
- `default` (where sensible)
- `validation` block for constrained values

Core variables (always required):
| Variable | Description | Example |
|---|---|---|
| `tenant_id` | Azure AD Tenant ID | `596ec0e5-...` |
| `subscription_id` | Azure Subscription ID | `8e6e7086-...` |
| `environment` | dev / uat / prod | `"dev"` |
| `location` | Azure region | `"eastus"` |
| `project` | Full project name | `"JProject"` |
| `project_acronym` | Short acronym for naming | `"jp"` |
| `owner` | Resource owner full name | `"Juan Pablo Chavez"` |

## Common Pitfalls

1. **Partial Updates**: Changing a resource name but not its references
2. **Missing Tags**: Always add `tags = local.common_tags` to every new resource
3. **Hardcoded Names**: Never hardcode — always use `locals.tf` naming locals
4. **NSG Association Conflicts**: Multiple NSG associations on the same subnet
5. **Count/For_each Changes**: Cause resource recreation — use `moved` blocks
6. **Provider Aliases**: Forgetting to pass providers to modules
7. **Resource Group Dependency**: Most Azure resources require `resource_group_name` — ensure it exists first
8. **Storage Account Constraints**: Globally unique, lowercase, 3-24 chars, alphanumeric only
9. **ACR/Storage Naming**: No hyphens allowed — use `replace(..., "-", "")`
10. **IDE vs validate conflict**: Trust `terraform validate`, not the IDE schema

## CI/CD Pipeline

`azure-pipelines.yml` is configured for 3-stage deployment: dev → uat → prod.
Each stage: `init` → `plan` → approval gate → `apply`.

Environments to create in Azure DevOps:
- `dev`, `uat`, `prod` — each with approval gates configured

Pipeline variables to update:
- `serviceConnection` — Azure DevOps service connection name
- `backendResourceGroup`, `backendStorageAccount`, `backendContainer` — already provisioned

## Testing Checklist

Before considering any Terraform change complete:

- [ ] `terraform fmt -recursive` passes
- [ ] `terraform validate` passes
- [ ] `tflint --recursive` shows no errors
- [ ] `checkov -d . --framework terraform` — no new failures
- [ ] All resources have `tags = local.common_tags`
- [ ] Naming follows `<project_acronym>-<resource>-<environment>` convention
- [ ] All variable references resolved
- [ ] All output consumers checked
- [ ] Change tested with `terraform plan -var-file="dev.tfvars"`

## Emergency Procedures

If terraform plan shows unexpected destruction:
1. **STOP** — Do not apply
2. Check for renamed resources, modified count/for_each, or moved resources
3. Use `terraform state mv` to rename state entries without destroying
4. Use `-target` for partial applies if needed

# Live Changes

Claude CAN execute `terraform apply` when explicitly instructed by Juan Pablo Chavez.
