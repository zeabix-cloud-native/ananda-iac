variable "anotation_name" {
  description = "Name of Resource"
}
variable "azure_region" {
  description = "Azure region to use."
  type        = string
  default = "Southeast Asia"
}

variable "publisher_name" {
  description = "Name of publisher"
  type = string
  default = "Zeabix Co.,Ltd"
}
variable "publisher_email" {
  description = "Emain of publisher"
  type = string
}

variable "apim_tier" {
  description = "Azure Pricing Tier"
  type = string
  default = "Basic_1"
}
## Registry
variable "registry_type" {
    description = "Azure Container Registry type"
    type = string
    default = "Basic"
  
}
## AKS
variable "cluster_name" {
  description = "Cluster name"
  type = string
  default = "ananda-cluster-demo"
}
variable "cluster_version" {
    description = "Cluster version"
    type = string
    default = "1.23.8"
  
}
variable "dns_prefix" {
  description = "Cluster DNS prefix"
  type = string
  default = "ananda"
}
variable "pool_name" {
  description = "Node pool name"
  type = string
  default = "default"
}
variable "vm_size" {
    description = "Type machine provide"
    type = string
    default = "Standard_D2_v2"
}
## DB ### 
variable "user" {
  description = "User for Login SQL"
  type = string
  default = "mariadbadmin"
}
variable "password" {
  description = "Root Password fo SQL"
  type = string
}