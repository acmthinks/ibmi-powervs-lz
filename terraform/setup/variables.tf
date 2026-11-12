variable "ibmcloud_api_key" {
  type        = string
  description = "IBM Cloud API key"
}

variable "prefix" {
  type        = string
  default = "demo"
  description = "The string that needs to be attached to every resource created"
}

variable "resource_group" {
  type        = string
  default = "demo-rg"
  description = "Name of the resource group"
}

variable "region" {
  type        = string
  description = "IBM Cloud region to provision the resources."
  default     = "us-south"
}

variable "zone" {
  type        = string
  description = "IBM Cloud availability zone within a region to provision the resources."
  default     = "us-south-1"
}

variable "secret_group_name" {
  type = string
  description = "Group name of the collection of secrets in the Secrets Manager instance. This is where public ssh keys for provisioning PowerVS instances should go."
  default = "powervs-ssh-keys"
}

## Reserved Endpoints

#Must also leave open: port 53/UDP/DNS, port 80/TCP/HTTP, port 443/TCP/HTTPS, port 8443/TCP/HTTPS (for linux) for IaaS service endpoints to work
#more info at https://cloud.ibm.com/docs/vpc?topic=vpc-service-endpoints-for-vpc
variable "iaas-service-endpoint-cidr" {
  type = string
  description = "Infrastructure services are available by using certain DNS names from the adn.networklayer.com domain, and they resolve to 161.26.0.0/16 addresses. Services that you can reach include: DNS resolvers, Ubuntu and Debian APT mirrors, NTP, IBM COS."
  default = "161.26.0.0/16"
}
