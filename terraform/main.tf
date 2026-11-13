/**
 * @author Andrea C. Crawford
 * @email acm@us.ibm.com
 * @create date 2025-03-20 11:06:00
 * @desc [description]
 */


###############################################################################
## Resource Group
##
## Gets reference to an existing resource group, specified in terraform.tfvars
###############################################################################
data "ibm_resource_group" "resource_group" {
   name   = var.resource_group
}

###############################################################################
###############################################################################
##########
########## PowerVS setup
##########
###############################################################################
###############################################################################

###############################################################################
## Create a Power VS Workspace
##
## pi_plan: "public" is for IBM Cloud PowerVS (use "private" for client data center)
###############################################################################
resource ibm_pi_workspace "powervs_workspace" {
  pi_name          = join("-", [var.prefix, "power-workspace"])
  pi_datacenter    = lower(var.zone)
  pi_resource_group_id  = data.ibm_resource_group.resource_group.id
  pi_plan = "public"
}

###############################################################################
## Create an ssh key in the PowerVS workspace
##
## This assumes there is a public key available in Secrets Manager as an
## arbitraty secret. This will pull the secret (public key payload) and create
## an ssh key object in the PowerVS workspace. This will be used to provision
## a PowerVS instance later.
###############################################################################

# gets reference to an existing Secrets Manager instance
# CRN of Secrets Manager should be specified in terraform.tfvars
data "ibm_resource_instance" "secrets_manager" {
  identifier = var.secrets_manager_instance_crn
}

data "ibm_sm_secret_group" "secret_group"{
   instance_id = data.ibm_resource_instance.secrets_manager.guid
   region = var.region
   endpoint_type = "private"
   secret_group_id = var.secrets_group_id
}

#get reference to an rsa encrypted key for PowerVS LPARs
data "ibm_sm_arbitrary_secret" "ssh_key_rsa_secret" {
  instance_id   = data.ibm_resource_instance.secrets_manager.guid
  region        = var.region
  endpoint_type = "private"
  name          = var.ssh_key_powervs_secret_name
  secret_group_name = data.ibm_sm_secret_group.secret_group.name
}

# Create SSH Key object in PowerVS workspace, based on the ssh public key
# payload from Secrets Manager
resource "ibm_pi_key" "power_vsi_ssh_key" {
  pi_key_name       = var.ssh_key_powervs_secret_name
  pi_ssh_key        = data.ibm_sm_arbitrary_secret.ssh_key_rsa_secret.payload
  pi_cloud_instance_id = ibm_pi_workspace.powervs_workspace.id
}

###############################################################################
## Create a subnet in the PowerVS workspace
##
## This creates a PRIVATE vlan (or subnet) in the PowerVS workspace
###############################################################################
resource "ibm_pi_network" "workload-subnet" {
  pi_network_name      = "workload-subnet"
  pi_cloud_instance_id = ibm_pi_workspace.powervs_workspace.id
  pi_network_type      = "vlan"
  pi_cidr              = var.powervs_subnet_cidr
}


###############################################################################
## Create a PowerVS instance
##
## This creates a PowerVS instance (or a vm) using the ssh key and subnet above
###############################################################################
resource "ibm_pi_instance" "powervs_instance" {
    pi_memory             = var.powervs_instance_memory
    pi_processors         = var.powervs_instance_cores
    pi_instance_name      = join("-", [var.prefix, "power-vsi"])
    pi_proc_type          = "shared"
    pi_image_id           = ibm_pi_image.ibm_i_image.image_id
    pi_key_pair_name      = ibm_pi_key.power_vsi_ssh_key.pi_key_name
    pi_sys_type           = var.powervs_system_type
    pi_cloud_instance_id  = ibm_pi_workspace.powervs_workspace.id
    pi_pin_policy         = "none"
    pi_health_status      = "OK"
    pi_network {
      network_id = ibm_pi_network.workload-subnet.network_id
    }
}

resource "ibm_pi_volume" "data0_volume"{
  pi_cloud_instance_id = ibm_pi_workspace.powervs_workspace.id
  pi_volume_size       = var.powervs_instance_data0_volume
  pi_volume_name       = "data0-volume"
  pi_volume_type       = var.powervs_instance_data0_tier
  pi_volume_shareable  = false
}

# attach data volume to PowerVS instance
resource "ibm_pi_volume_attach" "data0_volume_attach"{
  pi_cloud_instance_id = ibm_pi_workspace.powervs_workspace.id
  pi_volume_id = ibm_pi_volume.data0_volume.volume_id
  pi_instance_id = ibm_pi_instance.powervs_instance.instance_id
}

# Imports the stock catalog image (IBMi-74-12-2984-2) into the new workspace.
# A data source can't be used here: a new workspace has no images until they
# are imported from the catalog.
resource "ibm_pi_image" "ibm_i_image" {
  pi_image_id           = var.powervs_image_id
  pi_cloud_instance_id = ibm_pi_workspace.powervs_workspace.id
}

data "ibm_pi_catalog_images" "catalog" {
  pi_cloud_instance_id = ibm_pi_workspace.powervs_workspace.id
}

output "catalog_image_ids" {
  description = "Map of catalog image name => image_id (use image_id for pi_image_id)"
  value       = { for i in data.ibm_pi_catalog_images.catalog.images : i.name => i.image_id }
}


###############################################################################
###############################################################################
##########
########## Client to Site VPN Setup
##########
###############################################################################
###############################################################################


###############################################################################
## Create a VPC on IBM Cloud
## Availability Zones: 1 (no need for failover in Dev)
## Name: edge-vpc
## IP Address Range: 10.80.0.0/24 (256 IP addresses across all subnets)
###############################################################################
resource "ibm_is_vpc" "edge_vpc" {
  name = "edge-vpc"
  resource_group = data.ibm_resource_group.resource_group.id
  address_prefix_management = "manual"
  default_routing_table_name = join("-", ["edge-vpc", "rt", "default"])
  default_security_group_name = join("-", ["edge-vpc", "sg", "default"])
  default_network_acl_name = join("-", ["edge-vpc", "acl", "default"])
}

#set VPC Address prefix (all subnets in this vpc will derive from this range)
resource "ibm_is_vpc_address_prefix" "edge_prefix" {
  name = "edge-address-prefix"
  zone = var.vpc_zone
  vpc  = ibm_is_vpc.edge_vpc.id
  cidr = var.edge_vpc_address_prefix
}

## Advertise the VPN client pool to the Transit Gateway.
## The TGW only learns VPC address prefixes. Without this prefix, PowerVS has no
## return route to VPN clients, so traffic from a laptop to 10.90.0.0/24 times out.
resource "ibm_is_vpc_address_prefix" "vpn_client_pool_prefix" {
  name = "vpn-client-pool-prefix"
  zone = var.vpc_zone
  vpc  = ibm_is_vpc.edge_vpc.id
  cidr = var.edge_vpc_public_cidr
}

## Routing table for traffic entering the VPC from the Transit Gateway.
## Ingress flags can't be enabled on a table attached to a subnet (the default
## table is), so this is a separate table that no subnet uses. It accepts VPN
## server routes so replies for the VPN client pool are delivered to the VPN server.
resource "ibm_is_vpc_routing_table" "tgw_ingress" {
  vpc                              = ibm_is_vpc.edge_vpc.id
  name                             = "edge-vpc-rt-tgw-ingress"
  route_transit_gateway_ingress    = true
  accept_routes_from_resource_type = ["vpn_server"]
}

###############################################################################
## Create Subnet #1: VPN Server Subnet
## Name: vpn-server-subnet
## CIDR: 10.80.0.0/25 (128 IP addresses in the VPN Server subnet)
## Language: Terraform
###############################################################################
resource "ibm_is_subnet" "vpn_server_subnet" {
  depends_on = [
    ibm_is_vpc_address_prefix.edge_prefix
  ]
  ipv4_cidr_block = var.edge_vpc_vpn_cidr
  name            = "vpn-server-subnet"
  vpc             = ibm_is_vpc.edge_vpc.id
  zone            = var.vpc_zone
  resource_group = data.ibm_resource_group.resource_group.id
}

###############################################################################
## Create NACL for Subnet #1
## Name: vpn-server-subnet-acl
## Rules:
##  #   | Direction | Action    | Protocol  | Source        | Destination
##  1   | inbound   | Allow     | UDP       | 0.0.0.0/0 any | 10.80.0.0/25 443
##  2   | inbound   | Allow     | ALL       | 10.80.0.0/24  | 192.168.0.0/22
##  3   | inbound   | Deny      | ALL       | 0.0.0.0/0 any | 0.0.0.0/0 any
##
##  1   | outbound  | Allow     | UDP       | 10.80.0.0/25 443 | 0.0.0.0/0 any
##  2   | outbound  | Allow     | ALL       | 192.168.0.0/22 | 10.80.0.0/24
##  3   | outbound  | Deny      | ALL       | 0.0.0.0/0 any | 0.0.0.0/0 any
###############################################################################
resource "ibm_is_network_acl" "vpn_server_subnet_acl" {
  name = "vpn-server-subnet-acl"
  vpc  = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  rules {
    name        = "inbound-allow-same-subnet-ssh"
    action      = "allow"
    source      = "0.0.0.0/0"
    destination = var.edge_vpc_vpn_cidr
    direction   = "inbound"
    protocol    = "udp"
    port_min = 443
    port_max = 443
  }
  rules {
    name        = "inbound-allow-vpc-to-public-all"
    action      = "allow"
    source      = var.edge_vpc_address_prefix
    destination = var.edge_vpc_public_cidr
    direction   = "inbound"
  }
  # return traffic from the PowerVS subnet to VPN clients
  rules {
    name        = "inbound-allow-powervs-to-public"
    action      = "allow"
    source      = var.powervs_subnet_cidr
    destination = var.edge_vpc_public_cidr
    direction   = "inbound"
  }
    rules {
    name        = "inbound-deny-all"
    action      = "deny"
    source      = "0.0.0.0/0"
    destination = "0.0.0.0/0"
    direction   = "inbound"
  }
  rules {
    name        = "oubbound-allow-same-subnet-ssh"
    action      = "allow"
    source      = var.edge_vpc_vpn_cidr
    destination = "0.0.0.0/0"
    direction   = "outbound"
    protocol    = "udp"
    source_port_max = 443
    source_port_min = 443
  }
  rules {
    name        = "outbound-allow-public-to-vpc"
    action      = "allow"
    source      = var.edge_vpc_public_cidr
    destination = var.edge_vpc_address_prefix
    direction   = "outbound"
  }
  # VPN client traffic delivered to the PowerVS subnet (via Transit Gateway)
  rules {
    name        = "outbound-allow-public-to-powervs"
    action      = "allow"
    source      = var.edge_vpc_public_cidr
    destination = var.powervs_subnet_cidr
    direction   = "outbound"
  }
  rules {
    name        = "outbound-deny-all"
    action      = "deny"
    source      = "0.0.0.0/0"
    destination = "0.0.0.0/0"
    direction   = "outbound"
  }
}


###############################################################################
## Attach the NACL to the VPN Server subnet
###############################################################################
resource "ibm_is_subnet_network_acl_attachment" "vpn_server_subnet_acl_attachment" {
  subnet      = ibm_is_subnet.vpn_server_subnet.id
  network_acl = ibm_is_network_acl.vpn_server_subnet_acl.id
}


###############################################################################
## Create Security Group for VPN Server
## Name: vpn-server-sg
## Rules:
##  Direction | Protocol  | Source Type | Source        | Destination
##  inbound   | UDP       | Any         | 0.0.0.0/0     | 0.0.0.0/0 443
##  inbound   | ALL       | CIDR block  | 10.80.0.0/24  | 0.0.0.0/0
##
##  Direction | Protocol  | Source Type | Source        | Destination
##  egress    | UDP       | Any         | 0.0.0.0/0     | 0.0.0.0/0 443
##  egress    | ALL       | CIDR block  | 0.0.0.0/0     | 10.80.0.0/24
###############################################################################
resource "ibm_is_security_group" "vpn_server_sg" {
  name = "vpn-server-sg"
  vpc = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
}

resource "ibm_is_security_group_rule" "vpn_server_rule_1" {
  name = "inbound-allow-udp-443-from-any"
  group = ibm_is_security_group.vpn_server_sg.id
  direction = "inbound"
  remote = "0.0.0.0/0"
  protocol  = "udp"
  port_min = 443
  port_max = 443
}

resource "ibm_is_security_group_rule" "vpn_server_rule_2" {
  name = "inbound-allow-all-from-vpc-prefix"
  group = ibm_is_security_group.vpn_server_sg.id
  direction = "inbound"
  remote = var.edge_vpc_address_prefix
}

resource "ibm_is_security_group_rule" "vpn_server_rule_3" {
  name = "outbound-allow-udp-443-to-any"
  group = ibm_is_security_group.vpn_server_sg.id
  direction = "outbound"
  remote = "0.0.0.0/0"
  protocol = "udp"
  port_min = 443
  port_max = 443
}

resource "ibm_is_security_group_rule" "vpn_server_rule_4" {
  name = "outbound-allow-all-to-vpc-prefix"
  group = ibm_is_security_group.vpn_server_sg.id
  direction = "outbound"
  remote = var.edge_vpc_address_prefix
}

resource "ibm_is_security_group_rule" "vpn_server_rule_powervs" {
  name = "outbound-allow-all-to-powervs-subnet"
  group = ibm_is_security_group.vpn_server_sg.id
  direction = "outbound"
  remote = var.powervs_subnet_cidr
}


###############################################################################
## Create a Client to Site VPN service
###############################################################################
# Get vpn server cert (stored in Secrets Manager)
data "ibm_sm_imported_certificate" "imported_vpn_certificate" {
  instance_id   = data.ibm_resource_instance.secrets_manager.guid
  region        = var.region
  name          = var.vpn_certificate_name
  secret_group_name = "vpn-certificates"
  endpoint_type = "private"
}

## Create client to site VPN
resource "ibm_is_vpn_server" "vpn_server" {
  certificate_crn = data.ibm_sm_imported_certificate.imported_vpn_certificate.crn
  client_authentication {
    method    = "certificate"
    client_ca_crn = data.ibm_sm_imported_certificate.imported_vpn_certificate.crn
  }
  client_ip_pool         = var.edge_vpc_public_cidr
  client_idle_timeout    = 600
  enable_split_tunneling = true
  name                   = join("-", [var.prefix, "vpn-server"])
  port                   = 443
  protocol               = "udp"
  subnets                = [ibm_is_subnet.vpn_server_subnet.id]
  resource_group = data.ibm_resource_group.resource_group.id
  security_groups = [ibm_is_security_group.vpn_server_sg.id]
}

## VPN Server route -- deliver traffic for the PowerVS subnet (reached via Transit Gateway)
resource "ibm_is_vpn_server_route" "vpn_server_route_powervs" {
  vpn_server    = ibm_is_vpn_server.vpn_server.vpn_server
  destination   = var.powervs_subnet_cidr
  action        = "deliver"
  name          = "deliver-powervs-subnet"
}

## Create a service authorization so the VPN can consume Secrets Manager for it's cert
resource "ibm_iam_authorization_policy" "vpn_server_to_secrets_manager" {
  source_service_name         = "is"                      # source service
  source_resource_type        = "vpn-server"       # narrows the source to VPN servers
  target_service_name         = "secrets-manager"         # target service
  target_resource_instance_id = data.ibm_resource_instance.secrets_manager.guid
  roles                       = ["SecretsReader"]         # what the source may do on the target
  description                 = "Allow VPN servers to read certificates from Secrets Manager"
}

###############################################################################
###############################################################################
##########
########## Transit Gateway setup
##########
###############################################################################
###############################################################################

###############################################################################
## Transit Gateway
## If the intention is to interconnect this VSI with another VPC, Direct Link,
## IBM Cloud account, or PowerVS workspace, you will need a Transit Gateway
###############################################################################
resource "ibm_tg_gateway" "transit_gateway"{
  name  = join ("-", [var.prefix, "transit-gateway"])
  location=var.region
  global=false
  resource_group=data.ibm_resource_group.resource_group.id
}
#connect the edge-vpc with the VPN
resource "ibm_tg_connection" "edge_vpc_connection" {
  gateway      = ibm_tg_gateway.transit_gateway.id
  network_type = "vpc"
  name         = "edge-vpc-conn"
  network_id   = ibm_is_vpc.edge_vpc.resource_crn
}
#connect the PowerVS workspace with Power LPARs
resource "ibm_tg_connection" "powervs_connection" {
  gateway      = ibm_tg_gateway.transit_gateway.id
  network_type = "power_virtual_server"
  name         = "powervs_conn"
  network_id   = ibm_pi_workspace.powervs_workspace.crn
}

#generate Transit Gateway Routing report
resource "ibm_tg_route_report" "tg_route_report" {
    gateway = ibm_tg_gateway.transit_gateway.id
}
