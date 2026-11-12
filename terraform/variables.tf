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
  default     = "demo-rg"
  description = "Name of the resource group"
}

variable "region" {
  type        = string
  description = "IBM Cloud region to provision the resources."
  default     = "us-south"
}

variable "zone" {
  type        = string
  description = "PowerVS zone within a region to provision the resources."
  default     = "DAL12"
}

variable "vpc_zone" {
  type        = string
  description = "IBM Cloud VPC availability zone within a region to provision the resources."
  default     = "us-south-1"
}

variable "secrets_manager_instance_crn" {
  type        = string
  description = "CRN of existing Secrets Manager instance"
}

variable "secrets_group_id" {
  type = string
  description = "ID of the secrets group"
}

variable "ssh_key_powervs_secret_group_name" {
  type        = string
  description = "Secret Group Name holding the SSH keys for PowerVS instances"
}

variable "ssh_key_powervs_secret_name" {
  type        = string
  description = "NAME of the Arbitrary Secret in Secrets Manager that contains the public ssh key contents that will be used to provision the Power instance"
}

variable "vpn_certificate_name" {
  type = string
  description = "Name of specific secret for the VPN server certificate stored in Secrets Manager"
}

variable "powervs_subnet_cidr" {
  type        = string
  description = "IP Address CIDR for PowerVS workspace"
}

variable "powervs_instance_cores" {
  type        = string
  description =  "number of physical cores (can be fractional to 0.25)"
  default = "0.25"
}

variable "powervs_instance_memory" {
  type        = number
  description =  "amount of memory (GB)"
  default = 2
}

variable "powervs_instance_data0_volume" {
  type        = number
  description =  "amount of storage (GB)"
  default = 50
}

variable "powervs_instance_data0_tier" {
  type        = string
  description =  "storage tier (tier0, tier1, tier3, fixed)"
  default = "tier3"
}

variable "powervs_system_type" {
  type = string
  description = "Power System type: 1022, 1080, Power11. Check data centers for availability. Defaults to Power11 scale-out (1122)"
  default = "Power11"
}

variable "powervs_image_id" {
  type = string
  description = "Image Id (based on Power Zone,like DAL12). Default is DAL14(IBMi-76-01-2984-1)"
  default = "ed45fe21-95a7-43da-9f8a-19e1288af69b"
}

variable "edge_vpc_address_prefix" {
  type        = string
  description = "IP Address prefix (CIDR)"
}

variable "edge_vpc_vpn_cidr" {
  type = string
}

variable "edge_vpc_public_cidr" {
  type = string
  default = "192.168.0.0/24"
}
