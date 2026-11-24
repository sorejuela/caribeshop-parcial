# Prueba negativa D1. Esta regla nunca debe aplicarse en Azure ni llegar a main.
resource "azurerm_network_security_rule" "insecure_demo" {
  name                        = "demo-insecure-ssh"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.app.name
  network_security_group_name = azurerm_network_security_group.app.name
}
