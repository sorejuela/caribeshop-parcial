resource "azurerm_virtual_network" "app" {
  name                = "vnet-${var.name}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "app" {
  name                            = "snet-app"
  resource_group_name             = azurerm_resource_group.app.name
  virtual_network_name            = azurerm_virtual_network.app.name
  address_prefixes                = ["10.20.1.0/24"]
  default_outbound_access_enabled = false
  service_endpoints               = ["Microsoft.KeyVault", "Microsoft.Storage"]
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-${var.name}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
}

locals {
  network_rules = {
    http         = { priority = 100, direction = "Inbound", access = "Allow", source = "Internet", destination = "10.20.1.0/24", port = "8080" }
    probes       = { priority = 110, direction = "Inbound", access = "Allow", source = "AzureLoadBalancer", destination = "10.20.1.0/24", port = "8080" }
    deny_inbound = { priority = 4000, direction = "Inbound", access = "Deny", source = "*", destination = "*", port = "*" }
    keyvault     = { priority = 100, direction = "Outbound", access = "Allow", source = "10.20.1.0/24", destination = "AzureKeyVault", port = "443" }
    # El agente de Azure descarga las extensiones de Run Command desde Storage.
    storage       = { priority = 110, direction = "Outbound", access = "Allow", source = "10.20.1.0/24", destination = "Storage", port = "443" }
    deny_outbound = { priority = 4000, direction = "Outbound", access = "Deny", source = "*", destination = "*", port = "*" }
  }
}

resource "azurerm_network_security_rule" "app" {
  for_each                    = local.network_rules
  name                        = each.key
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.access == "Deny" ? "*" : "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value.port
  source_address_prefix       = each.value.source
  destination_address_prefix  = each.value.destination
  resource_group_name         = azurerm_resource_group.app.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_public_ip" "lb" {
  name                = "pip-${var.name}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_lb" "app" {
  name                = "lb-${var.name}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "app" {
  name            = "app"
  loadbalancer_id = azurerm_lb.app.id
}

resource "azurerm_lb_probe" "health" {
  name                = "health"
  loadbalancer_id     = azurerm_lb.app.id
  protocol            = "Http"
  port                = 8080
  request_path        = "/health"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http" {
  name                           = "http"
  loadbalancer_id                = azurerm_lb.app.id
  frontend_ip_configuration_name = "public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.app.id]
  probe_id                       = azurerm_lb_probe.health.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 8080
  disable_outbound_snat          = true
}

resource "azurerm_lb_outbound_rule" "app" {
  name                     = "azure-services"
  loadbalancer_id          = azurerm_lb.app.id
  backend_address_pool_id  = azurerm_lb_backend_address_pool.app.id
  protocol                 = "Tcp"
  allocated_outbound_ports = 1024
  frontend_ip_configuration {
    name = "public"
  }
}
