locals {
  name = "pollinate-technical"
}

data "azurerm_key_vault" "kv" {
  name                = "pollinate-tf-secrets"
  resource_group_name = "rg-pollinate-platform-dev"
}

data "azurerm_key_vault_secret" "tenant_id" {
  name         = "tenant-id"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "subscription_id" {
  name         = "subscription-id"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "sp_client_id" {
  name         = "sp-client-id"
  key_vault_id = data.azurerm_key_vault.kv.id
}

resource "azurerm_resource_group" "pollinate-rg" {
  name     = "rg-${local.name}-${terraform.workspace}"
  location = "West Europe"

  tags = {
    environment = terraform.workspace
  }
}

resource "azurerm_log_analytics_workspace" "pollinate-la" {
  name                = "pollinate-ca-la"
  location            = azurerm_resource_group.pollinate-rg.location
  resource_group_name = azurerm_resource_group.pollinate-rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "pollinate-cae" {
  name                           = "cae-${local.name}-${terraform.workspace}"
  location                       = azurerm_resource_group.pollinate-rg.location
  resource_group_name            = azurerm_resource_group.pollinate-rg.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.pollinate-la.id
  infrastructure_subnet_id       = azurerm_subnet.container_apps.id
  internal_load_balancer_enabled = true
  public_network_access          = "Disabled"
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "app-identity-${local.name}"
  location            = azurerm_resource_group.pollinate-rg.location
  resource_group_name = azurerm_resource_group.pollinate-rg.name
}

resource "azurerm_role_assignment" "app_kv_reader" {
  scope                = azurerm_key_vault.pollinate-kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

resource "azurerm_container_app" "pollinate-ca" {
  name                         = "ca-${local.name}-${terraform.workspace}"
  container_app_environment_id = azurerm_container_app_environment.pollinate-cae.id
  resource_group_name          = azurerm_resource_group.pollinate-rg.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  secret {
    name                = "app-secret-${local.name}"
    key_vault_secret_id = azurerm_key_vault_secret.app_secret.versionless_id
    identity            = azurerm_user_assigned_identity.app.id
  }

  template {
    container {
      name   = "risk-validation-container-app"
      image  = "acrpollinatetechnical.azurecr.io/pollinate/risk-validation-app:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env {
        name        = "VALIDATION_SERVICE_API-KEY"
        secret_name = "app-secret-${local.name}"
      }
    }
  }
  depends_on = [azurerm_role_assignment.app_kv_reader]
}

resource "azurerm_container_registry" "pollinate-acr" {
  name                = "acrPollinateTechnical${terraform.workspace}"
  resource_group_name = azurerm_resource_group.pollinate-rg.name
  location            = azurerm_resource_group.pollinate-rg.location
  sku                 = "Premium"
  admin_enabled       = false
}

resource "azurerm_key_vault" "pollinate-kv" {
  name                        = "kv-polli-tech-${terraform.workspace}"
  location                    = azurerm_resource_group.pollinate-rg.location
  resource_group_name         = azurerm_resource_group.pollinate-rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_key_vault_secret.tenant_id.value
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"

  public_network_access_enabled = false
  rbac_authorization_enabled    = true
}

# Random api key since I wasn't provided with one
resource "random_string" "api-key" {
  length  = 64
  special = true
}

resource "azurerm_key_vault_secret" "app_secret" {
  name         = "app-secret-${local.name}"
  value        = random_string.api-key.result
  key_vault_id = azurerm_key_vault.pollinate-kv.id

  depends_on = [azurerm_role_assignment.terraform_kv_admin]
}

resource "azurerm_role_assignment" "terraform_kv_admin" {
  scope                = azurerm_key_vault.pollinate-kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_key_vault_secret.sp_client_id.value
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "keyvault-pe"
  location            = azurerm_resource_group.pollinate-rg.location
  resource_group_name = azurerm_resource_group.pollinate-rg.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "keyvault-psc"
    private_connection_resource_id = azurerm_key_vault.pollinate-kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "keyvault-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }
}

resource "azurerm_application_insights" "pollinate-insights" {
  name                = "insights-${local.name}"
  location            = azurerm_resource_group.pollinate-rg.location
  resource_group_name = azurerm_resource_group.pollinate-rg.name
  application_type    = "web"
}

output "instrumentation_key" {
  sensitive = true
  value     = azurerm_application_insights.pollinate-insights.instrumentation_key
}

output "app_id" {
  value = azurerm_application_insights.pollinate-insights.app_id
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.pollinate-rg.location
  resource_group_name = azurerm_resource_group.pollinate-rg.name
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "pe-${local.name}"
  resource_group_name  = azurerm_resource_group.pollinate-rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "container_apps" {
  name                 = "ca-subnet-${local.name}"
  resource_group_name  = azurerm_resource_group.pollinate-rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/23"]

  delegation {
    name = "Microsoft.App.environments"
    service_delegation {
      name = "Microsoft.App/environments"
    }
  }
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.pollinate-rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "keyvault-dns-link"
  resource_group_name   = azurerm_resource_group.pollinate-rg.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

data "azurerm_resources" "acrs" {
  type = "Microsoft.ContainerRegistry/registries"
}

resource "azurerm_role_assignment" "contributor" {
  scope                = data.azurerm_key_vault_secret.subscription_id.value
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_key_vault_secret.sp_client_id.value
}

resource "azurerm_role_assignment" "acr_push" {
  for_each = { for acr in data.azurerm_resources.acrs.resources : acr.name => acr.id }

  scope                = each.value
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_key_vault_secret.sp_client_id.value
}