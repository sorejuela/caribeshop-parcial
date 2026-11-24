resource "azurerm_key_vault" "app" {
  #checkov:skip=CKV2_AZURE_32:El enunciado permite service endpoint; firewall Deny con subred e IP /32, TLS y RBAC. R7 en docs/riesgos.md.
  name                       = "kv-${var.name}"
  location                   = azurerm_resource_group.app.location
  resource_group_name        = azurerm_resource_group.app.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 7
  network_acls {
    default_action             = "Deny"
    bypass                     = "None"
    ip_rules                   = [var.operator_ip]
    virtual_network_subnet_ids = [azurerm_subnet.app.id]
  }
}

resource "azurerm_role_assignment" "operator_secrets" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "app_secrets" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.app.identity[0].principal_id
}

resource "random_password" "demo" {
  length  = 32
  special = false
}

resource "azurerm_key_vault_secret" "demo" {
  name            = "demo-token"
  value           = random_password.demo.result
  key_vault_id    = azurerm_key_vault.app.id
  content_type    = "text/plain"
  expiration_date = var.secret_expiration_date
  depends_on      = [azurerm_role_assignment.operator_secrets]
}

resource "azurerm_policy_definition" "no_storage_keys" {
  name         = "${var.name}-deny-storage-keys"
  display_name = "CaribeShop: impedir Shared Key en Storage"
  policy_type  = "Custom"
  mode         = "All"
  policy_rule = jsonencode({
    "if" = { allOf = [
      { field = "type", equals = "Microsoft.Storage/storageAccounts" },
      { field = "Microsoft.Storage/storageAccounts/allowSharedKeyAccess", notEquals = false }
    ] }
    "then" = { effect = "Deny" }
  })
}

resource "azurerm_resource_group_policy_assignment" "no_storage_keys" {
  name                 = "deny-storage-keys"
  resource_group_id    = azurerm_resource_group.app.id
  policy_definition_id = azurerm_policy_definition.no_storage_keys.id
}
