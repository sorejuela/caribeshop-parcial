terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Solo el primer apply usa estado local. Migrarlo con backend.tf.example al terminar.
provider "azurerm" {
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  storage_use_azuread             = true
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "state" {
  name     = "rg-caribeshop-state"
  location = var.location
}

resource "azurerm_storage_account" "state" {
  #checkov:skip=CKV_AZURE_33:No se utiliza Queue; Shared Key está deshabilitado y el único contenedor es privado. R1 en docs/riesgos.md.
  #checkov:skip=CKV_AZURE_59:Endpoint público limitado a la IPv4 del operador; acceso mediante Entra ID. R2 en docs/riesgos.md.
  #checkov:skip=CKV_AZURE_206:ZRS protege frente a falla zonal; recuperación regional fuera del alcance del laboratorio. R3 en docs/riesgos.md.
  #checkov:skip=CKV_AZURE_36:No se requiere bypass de servicios Microsoft; None restringe más que AzureServices. R4 en docs/riesgos.md.
  #checkov:skip=CKV2_AZURE_33:Firewall con una IP y RBAC evita añadir VPN y endpoint privado al laboratorio. R2 en docs/riesgos.md.
  #checkov:skip=CKV2_AZURE_1:Cifrado de plataforma y de infraestructura; no añadir dependencia circular de una CMK en Key Vault. R5 en docs/riesgos.md.
  name                              = var.storage_account_name
  resource_group_name               = azurerm_resource_group.state.name
  location                          = azurerm_resource_group.state.location
  account_tier                      = "Standard"
  account_replication_type          = "ZRS"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
  network_rules {
    default_action = "Deny"
    bypass         = ["None"]
    ip_rules       = [var.operator_ip]
  }
  blob_properties {
    versioning_enabled = true
    delete_retention_policy { days = 7 }
    container_delete_retention_policy { days = 7 }
  }
}

resource "azurerm_storage_container" "state" {
  #checkov:skip=CKV2_AZURE_21:Auditoría de lecturas del estado pendiente para producción; versiones y soft delete no sustituyen auditoría. R6 en docs/riesgos.md.
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "operator_state" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

output "backend_config" {
  value = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.state.name}"
    key                  = "caribeshop.tfstate"
    use_azuread_auth     = true
  EOT
}
