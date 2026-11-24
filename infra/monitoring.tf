resource "azurerm_log_analytics_workspace" "app" {
  name                = "logs-${var.name}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1
}

resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "keyvault-audit"
  target_resource_id         = azurerm_key_vault.app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.app.id
  enabled_log { category = "AuditEvent" }
}

resource "azurerm_monitor_diagnostic_setting" "autoscale" {
  name                       = "autoscale-history"
  target_resource_id         = azurerm_monitor_autoscale_setting.app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.app.id
  enabled_log { category = "AutoscaleEvaluations" }
  enabled_log { category = "AutoscaleScaleActions" }
}

resource "azurerm_monitor_action_group" "email" {
  name                = "alerts-${var.name}"
  resource_group_name = azurerm_resource_group.app.name
  short_name          = "caribeshop"
  email_receiver {
    name                    = "equipo"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "health" {
  name                = "unhealthy-${var.name}"
  resource_group_name = azurerm_resource_group.app.name
  scopes              = [azurerm_lb.app.id]
  description         = "Al menos una sonda del balanceador está fallando."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT1M"
  criteria {
    metric_namespace = "Microsoft.Network/loadBalancers"
    metric_name      = "DipAvailability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }
  action { action_group_id = azurerm_monitor_action_group.email.id }
}
