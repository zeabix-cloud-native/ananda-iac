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
### Cert mTLS ###
resource "azurerm_api_management_certificate" "tls" {
  name                = "${var.anotation_name}-cert"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.group.name
  data                = filebase64("./Certificates_ananda.cer")
}
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
  name                = "${var.anotation_name}-cluster"
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
resource "azurerm_mysql_server" "db" {
  name                = "${var.anotation_name}-mysqlserver"
  location            = azurerm_resource_group.group.location
  resource_group_name = azurerm_resource_group.group.name

  administrator_login          = var.user
  administrator_login_password = var.password

  sku_name   = "B_Gen5_2"
  storage_mb = 5120
  version    = "5.7"

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
}
