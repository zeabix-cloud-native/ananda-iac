# Ananda IaC
![Terraform](https://github.com/zeabix-cloud-native/ananda-iac/actions/workflows/terraform.yml/badge.svg)

## Requirements
- [Terraform](https://www.terraform.io/downloads.html)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Openssl](https://www.openssl.org/)
- [Helm](https://helm.sh/docs/intro/install)

## Prepare X.509 Certificates


Name   | Purpose              | Environment              | Private Key Required	| Required Format 
 :---: | :---:                | :---:                    | :---:                | :---:
CA     | Certificate Authority | Kubernetes Secrets       | Yes                  | .crt,.key
Client | Server Certificate    | Kubernetes Secrets, APIM | Yes                  | .csr,.key



### Generate self-sign certificate
CA cert
```sh
$ openssl req -x509 -sha256 -newkey rsa:4096 -keyout ca.key -out ca.crt -days 356 -nodes -subj '/CN=Fern Cert Authority'
```
Client Cert
```sh
$ openssl req -new -newkey rsa:4096 -keyout cleint.key -out cleint.csr -nodes -subj '/CN=z-unified.com'
```
Clent cert sign with CA cert
```sh
$ openssl x509 -req -sha256 -days 365 -in cleint.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt
```
Convert .crt + .key to .pfx (format use for microsoft)
```sh
$ cat server.crt server.key > server.pem 
$ openssl pkcs12 -export -out server.pfx -inkey sever.key -in server.pem    
```
## Provision
Provision APIM to the prepared lab environment (AKS, Ingress Nginx, DB, and deployed applications). Import the first API to APIM and verify
Teraform APIM (Tier Basic) + AKS Cluster + Database TBD + ACR + Helm
- custom certificate to APIM

```terraform
resource "azurerm_api_management_certificate" "tls" {
  name                = "${var.anotation_name}-cert"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.group.name
  ### .pfx from client self-sign generate
  data                = filebase64("./server.pfx")
}
```
Azure Login & Provisioner
```sh
$ export SUBSCRIBTION_ID=*****-*****-*****-****-*******
$ cd terraform
$ az login --scope https://graph.microsoft.com//.default
$ az account set --subscription $SUBSCRIBTION_ID
$ terraform init
$ terraform plan
$ terraform apply
```
## Destroy Resource
Once `terraform apply` has successfully completed, to destroy the all resource run these commands
```sh
terraform destroy
```
