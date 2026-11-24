resource "azurerm_linux_virtual_machine_scale_set" "app" {
  name                            = "vmss-${var.name}"
  location                        = azurerm_resource_group.app.location
  resource_group_name             = azurerm_resource_group.app.name
  sku                             = var.vm_size
  instances                       = var.capacity_test ? 1 : 2
  zones                           = var.zones
  zone_balance                    = true
  admin_username                  = "azureuser"
  disable_password_authentication = true
  upgrade_mode                    = "Automatic"
  health_probe_id                 = azurerm_lb_probe.health.id
  overprovision                   = false
  encryption_at_host_enabled      = true
  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }
  identity { type = "SystemAssigned" }
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = var.image_sku
    version   = var.image_version
  }
  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
  boot_diagnostics {}
  network_interface {
    name    = "app"
    primary = true
    ip_configuration {
      name                                   = "private"
      primary                                = true
      subnet_id                              = azurerm_subnet.app.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.app.id]
    }
  }
  automatic_instance_repair {
    enabled      = true
    grace_period = "PT10M"
    action       = "Replace"
  }
  custom_data = base64encode(templatefile("${path.module}/../app/cloud-init.yaml.tftpl", {
    app_source = file("${path.module}/../app/server.py")
    vault_url  = azurerm_key_vault.app.vault_uri
  }))
  lifecycle {
    ignore_changes = [instances]
  }
  depends_on = [azurerm_subnet_network_security_group_association.app, azurerm_lb_rule.http]
}

resource "azurerm_monitor_autoscale_setting" "app" {
  name                = "autoscale-${var.name}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.app.id
  profile {
    name = "cpu"
    capacity {
      minimum = var.capacity_test ? "1" : "2"
      default = var.capacity_test ? "1" : "2"
      maximum = var.capacity_test ? "1" : tostring(var.max_instances)
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT3M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 65
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT3M"
      }
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
  notification {
    email {
      custom_emails                         = [var.alert_email]
      send_to_subscription_administrator    = false
      send_to_subscription_co_administrator = false
    }
  }
}
