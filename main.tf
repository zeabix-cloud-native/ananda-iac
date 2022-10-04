provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "group" {
  name     = "${var.anotation_name}-group"
  location = var.azure_region
}
### APIM GROUP ####
resource "azurerm_api_management" "apim" {
  name                = "${var.anotation_name}-apim"
  location            = azurerm_resource_group.group.location
  resource_group_name = azurerm_resource_group.group.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email

  sku_name = var.apim_tier
}
### END APIM ###

### ACR ####
resource "azurerm_container_registry" "acr" {
  name                = "${var.anotation_name}acr"
  resource_group_name = azurerm_resource_group.group.name
  location            = azurerm_resource_group.group.location
  sku                 = var.registry_type
  admin_enabled       = false
}
#### AKS #####
resource "azurerm_kubernetes_cluster" "cluster" {
  kubernetes_version  = var.cluster_version
  name                = "${var.cluster_name}-cluster"
  location            = azurerm_resource_group.group.location
  resource_group_name = azurerm_resource_group.group.name
  dns_prefix           = var.dns_prefix

  default_node_pool {
    name       = var.pool_name
    node_count = 1
    vm_size    = var.vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Development"
  }
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.cluster.kube_config_raw

  sensitive = true
}
### Storage ####
resource "azurerm_storage_account" "db" {
  name                     = "${var.anotation_name}"
  resource_group_name      = azurerm_resource_group.group.name
  location                 = azurerm_resource_group.group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_mssql_server" "db_server" {
  name                         = "${var.anotation_name}-db-server"
  resource_group_name          = azurerm_resource_group.group.name
  location                     = azurerm_resource_group.group.location
  version                      = "12.0"
  administrator_login          = var.user
  administrator_login_password = var.password
  minimum_tls_version          = var.minimum_tls_version

  tags = {
    environment = "development"
  }
}