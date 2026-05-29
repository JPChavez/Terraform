# ── Azure Logic Apps (Consumption) ───────────────────────────────────────────
# Consumption plan — multi-tenant, serverless. No dedicated compute or VNet integration.
# For single-tenant isolation use azurerm_logic_app_standard + App Service Plan.

resource "azurerm_logic_app_workflow" "main" {
  name                = local.logic_app_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  identity {
    type = "SystemAssigned"
  }

  # Restrict which IPs can invoke triggers — tighten per-connector in production
  access_control {
    trigger {
      allowed_caller_ip_address_range = ["${var.terraform_operator_ip}/32"]
    }
    action {
      allowed_caller_ip_address_range = ["${var.terraform_operator_ip}/32"]
    }
  }

  tags = local.common_tags
}
