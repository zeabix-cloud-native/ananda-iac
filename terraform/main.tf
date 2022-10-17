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
resource "azurerm_application_insights" "insights" {
  name                = "${var.anotation_name}-appinsights"
  location            = azurerm_resource_group.group.location
  resource_group_name = azurerm_resource_group.group.name
  application_type    = "web"
}
resource "azurerm_api_management_logger" "logger" {
  name                = "${var.anotation_name}-apimlogger"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.group.name

  application_insights {
    instrumentation_key = azurerm_application_insights.insights.instrumentation_key
  }
}
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "${var.anotation_name}-demo-workspace"
  location            = azurerm_resource_group.group.location
  resource_group_name = azurerm_resource_group.group.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting" {
  name                       = "${var.anotation_name}-diagnostic-settings"
  target_resource_id         = azurerm_api_management.apim.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.workspace.id
  log {
    category = "GatewayLogs"
    enabled  = false

    retention_policy {
      enabled = false
    }
  }

  log {
    category = "WebSocketConnectionLogs"
    enabled = false
    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_api_management_diagnostic" "diagnostic" {
  identifier               = "applicationinsights"
  resource_group_name      = azurerm_resource_group.group.name
  api_management_name      = azurerm_api_management.apim.name
  api_management_logger_id = azurerm_api_management_logger.logger.id

  sampling_percentage       = 5.0
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "verbose"
  http_correlation_protocol = "W3C"

  frontend_request {
    body_bytes = 32
    headers_to_log = [
      "content-type",
      "accept",
      "origin",
    ]
  }

  frontend_response {
    body_bytes = 32
    headers_to_log = [
      "content-type",
      "content-length",
      "origin",
    ]
  }

  backend_request {
    body_bytes = 32
    headers_to_log = [
      "content-type",
      "accept",
      "origin",
    ]
  }

  backend_response {
    body_bytes = 32
    headers_to_log = [
      "content-type",
      "content-length",
      "origin",
    ]
  }
}
### END APIM ###
data "azurerm_client_config" "current" {}
### Cert mTLS ###
resource "azurerm_api_management_certificate" "tls" {
  name                = "${var.anotation_name}-cert"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.group.name
  data                = filebase64("./Certificates_ananda.cer")
}

### Key Vault ###
resource "azurerm_key_vault" "vault" {
  name                        = "${var.anotation_name}-demo-01-keyvault"
  location                    = azurerm_resource_group.group.location
  resource_group_name         = azurerm_resource_group.group.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
  }
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
resource "random_string" "unique" {
  length  = 6
  special = false
  upper   = false
}
provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.cluster.kube_config.0.host
    username               = azurerm_kubernetes_cluster.cluster.kube_config.0.username
    password               = azurerm_kubernetes_cluster.cluster.kube_config.0.password
    client_certificate      = base64decode(azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.cluster.kube_config.0.client_key)
    cluster_ca_certificate  = base64decode(azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate)
  }
}
resource "azurerm_public_ip" "ingress" {
  name                = "pip-${var.anotation_name}-ingress"
  location            = azurerm_resource_group.group.location
  resource_group_name = azurerm_kubernetes_cluster.cluster.node_resource_group
  domain_name_label   = "${var.anotation_name}-${random_string.unique.result}"
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Add the role to the identity the kubernetes cluster was assigned
resource "azurerm_role_assignment" "aks_to_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.cluster.kubelet_identity[0].object_id
}
### HELM RELEASE ####

provider "kubernetes" {
  config_path            = local_sensitive_file.kube_config.filename
}
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = var.cert_manager_ns
  create_namespace = true
  version          = "v1.9.1"

  set {
    name  = "installCRDs"
    value = true
  }
}
resource "helm_release" "ingress" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = var.ingress_ns
  version          = "4.1.3"
  create_namespace = true
  wait = false
  set {
    name  = "controller.replicaCount"
    value = var.ingress_replica_count
  }

  set {
    name  = "controller.service.loadBalancerIP"
    value = azurerm_public_ip.ingress.ip_address
  }
  
  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }
  set {
    name  = "controller.nodeSelector\\.kubernetes\\.io/os"
    value = "linux"
    type  = "string"
  }
  set {
    name = "controller.admissionWebhooks.patch.nodeSelector\\.kubernetes\\.io/os"
    value = "linux"
    type =  "string"
  }
  set {
    name  = "defaultBackend.nodeSelector\\.kubernetes\\.io/os"
    value = "linux"
    type  = "string"
  }

  set {
    name  = "controller.extraArgs.default-ssl-certificate"
    value = "${helm_release.cert_manager.namespace}/${var.default_cert_secret_name}"
  }
  
}

resource "helm_release" "argocd" {
# https://bitnami.com/stack/argo-cd/helm
  count = 1
  name  = "argocd"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true

}
resource "local_sensitive_file" "kube_config" {
  filename          = "${path.module}/kubeconfig"
  content           = azurerm_kubernetes_cluster.cluster.kube_config_raw
}

locals {
  cert_manager_yaml = "${path.module}/cert-manager.yml"
}

resource "null_resource" "cert_manager" {
  triggers = {
    kube_config               = sha1(azurerm_kubernetes_cluster.cluster.kube_config_raw)
    cert_manager_ns          = helm_release.cert_manager.namespace
    default_cert_secret_name = var.default_cert_secret_name
    fqdn                     = azurerm_public_ip.ingress.fqdn
    cert_manager_sha1        = filesha1(local.cert_manager_yaml)
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG               = local_sensitive_file.kube_config.filename
      DEFAULT_CERT_SECRET_NAME = var.default_cert_secret_name
      FQDN                     = azurerm_public_ip.ingress.fqdn
      EMAIL_ISSUE              = var.publisher_email
    }
    command = <<EOF
      envsubst < ${local.cert_manager_yaml} | kubectl apply -n ${helm_release.cert_manager.namespace} -f -
      EOF
  }

  depends_on = [
    helm_release.ingress,
    helm_release.cert_manager
  ]
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

resource "azurerm_mysql_database" "dbname" {
  name                = "${var.anotation_name}-mockservdb-db"
  resource_group_name = azurerm_resource_group.group.name
  server_name         = azurerm_mysql_server.db.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}
