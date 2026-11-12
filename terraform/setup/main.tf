/**
 * @author Andrea C. Crawford
 * @email acm@us.ibm.com
 * @create date 2025-03-20 11:06:00
 * @desc [description]
 */

###############################################################################
## ENSURE Cloud Service Endpoints ARE ENABLED ON IBM CLOUD ACCOUNT
## ENSURE Vrirtual Routing Functions ARE ENABLED ON IBM CLOUD ACCOUNT
###############################################################################



###############################################################################
## Resource Group
##
## Create resource group, specified in terraform.tfvars
###############################################################################
resource "ibm_resource_group" "resource_group" {
   name   = var.resource_group
}

###############################################################################
## Secrets Manager
##
## Creates vault service. Note if the service_endpoint is set to "private",
## the SM instance will not bea accessible from a local workstation or from the
## Internet. Accessibility will only be from the IBM Cloud private network and
## requires VRF and CSE enabled on the account.
###############################################################################
resource "ibm_resource_instance" "sm_instance" {
  name              = "secrets-vault"
  service           = "secrets-manager"
  plan              = "standard"      # "standard" or "trial"
  location          = var.region
  service_endpoints = "private"
}

###############################################################################
## Secrets Manager Group
##
## Creates a group for storing PowerVS ssh keys
###############################################################################
resource "ibm_sm_secret_group" "powervs_secret_group" {
  name              = var.secret_group_name
  instance_id       = ibm_resource_instance.sm_instance.guid
  region            = var.region
  description       = "group to store all PowerVS ssh keys (public keys only)"
  endpoint_type = "private"
}

###############################################################################
## Secrets Manager Group
##
## Creates a group for storing Client to Site VPN certificates
###############################################################################
resource "ibm_sm_secret_group" "vpn-certs_secret_group" {
  name              = "vpn-certificates"
  instance_id       = ibm_resource_instance.sm_instance.guid
  region            = var.region
  description       = "group to store VPN certificates"
  endpoint_type = "private"
}

###############################################################################
## IAM Access Group "administrators"
##
## Creates an access group to provide administrative account access
###############################################################################
resource "ibm_iam_access_group" "administrators" {
  name = "administrators"
  description = "Access group for IBM Cloud account administration."
}

###############################################################################
## Create base Access Group Policies
###############################################################################
###############################################################################
# Service: All Account Management services
# Resource: All
# Role(s): Administrator (Platform)
# https://cloud.ibm.com/docs/account?topic=account-account-services&interface=terraform#account-management-actions-roles-terra
###############################################################################
resource "ibm_iam_access_group_policy" "account_management_services_policy" {
    access_group_id = ibm_iam_access_group.administrators.id
    roles = ["Administrator"]
    account_management = "true"
}

###############################################################################
# Service: All Identity and Access enabled services
# Resource: All
# Role(s): Administrator (Platform)
###############################################################################
resource "ibm_iam_access_group_policy" "iam_services_policy" {
    access_group_id = ibm_iam_access_group.administrators.id
    roles   = ["Reader", "Writer", "Manager", "Viewer", "Operator", "Editor", "Administrator"]

    resources {
        resource_group_id = ibm_resource_group.resource_group.id
    }
}

###############################################################################
# Service: Catalog Management
# Resource: All
# Role(s): Editor (Platform)
###############################################################################
resource "ibm_iam_access_group_policy" "catalog_management_policy" {
    access_group_id = ibm_iam_access_group.administrators.id
    roles   = ["Editor"]

    resources {
        service = "globalcatalog-collection"
    }
}


##
## https://cloud.ibm.com/docs/ibmi-managed-powervs?topic=ibmi-managed-powervs-access
##

###############################################################################
## IAM Access Group "provisioners"
##
## Creates an access group to provide access to provision cloud resources
###############################################################################
resource "ibm_iam_access_group" "provisioners" {
  name = "provisioners"
  description = "Access group for provisionining cloud resources."
}
###############################################################################
# Service: Workspace for Power Virtual Server
# Resource: All
# Role(s): Manager (Service), Editor (Platform)
###############################################################################
resource "ibm_iam_access_group_policy" "powervs_workspace_policy" {
    access_group_id = ibm_iam_access_group.provisioners.id
    roles   = ["Editor", "Manager"]

    resources {
        service = "power-iaas"
    }
}
###############################################################################
# Service: VPC Infrastructure Services
# Resource: All
# Role(s): VirtualServerConsoleAdmin (Service), Reader (Service),
# Editor (Platform), Service Configuration Reader (Platform), Key Manager (Platform)
###############################################################################
resource "ibm_iam_access_group_policy" "vpc_infrastructure_policy" {
    access_group_id = ibm_iam_access_group.provisioners.id
    roles   = ["Reader", "Editor", "Service Configuration Reader", "Key Manager"]

    resources {
        service = "is"
    }
}
###############################################################################
# Service: Transit Gateway
# Resource: All
# Role(s): Manager (Service), Editor (Platform), KeyManager (Platform)
###############################################################################
resource "ibm_iam_access_group_policy" "transit_gateway_policy" {
    access_group_id = ibm_iam_access_group.provisioners.id
    roles   = ["Manager", "Editor", "Key Manager"]

    resources {
        service = "transit"
    }
}
###############################################################################
# Service: Schematics
# Resource: All
# Role(s): Manager (Service), Editor (Platform)
###############################################################################
resource "ibm_iam_access_group_policy" "schematics_policy" {
    access_group_id = ibm_iam_access_group.provisioners.id
    roles   = ["Manager", "Editor"]

    resources {
        service = "schematics"
    }
}
###############################################################################
# Service: Direct Link
# Resource: All
# Role(s): Editor (Platform)
###############################################################################
resource "ibm_iam_access_group_policy" "direct_link_policy" {
    access_group_id = ibm_iam_access_group.provisioners.id
    roles   = ["Editor"]

    resources {
        service = "directlink"
    }
}
###############################################################################
# Service: Key Protect
# Resource: All
# Role(s): Manager (Service), Editor (Platform)
###############################################################################
resource "ibm_iam_access_group_policy" "key_protect_policy" {
    access_group_id = ibm_iam_access_group.provisioners.id
    roles   = ["Manager", "Editor"]

    resources {
        service = "kms"
    }
}
###############################################################################
# Service: Secrets Manager
# Resource: All
# Role(s): Manager (Service), Editor (Platform), Key Manager (Platform)
###############################################################################
resource "ibm_iam_access_group_policy" "secrets_manager_policy" {
    access_group_id = ibm_iam_access_group.provisioners.id
    roles   = ["Manager", "Editor", "Key Manager"]

    resources {
        service = "secrets-manager"
    }
}
###############################################################################
# Service: Secrets Manager
# Resource: All
# Role(s): Manager (Service), Editor (Platform), Key Manager (Platform)
###############################################################################
resource "ibm_iam_access_group_policy" "backup_compass_policy" {
    access_group_id = ibm_iam_access_group.provisioners.id
    roles   = ["Manager", "Editor", "Key Manager"]

    resources {
        service = "compass"
    }
}

###############################################################################
## IAM Access Group
##
## Creates an access group to provide access to view cloud resources
###############################################################################
resource "ibm_iam_access_group" "viewers" {
  name = "viewers"
  description = "Access group for viewing cloud resources only."
}

###############################################################################
## IAM Access Group
##
## Creates an access group to provide access to connect via VPN
###############################################################################
resource "ibm_iam_access_group" "vpn_users" {
  name = "vpn_users"
  description = "Access group for allowing access to cloud resource with VPN."
}
###############################################################################
# Service: VPN Server for VPC
# Resource: All
# Role(s): VPN Client (Service)
###############################################################################
resource "ibm_iam_access_group_policy" "vpn_client_policy" {
    access_group_id = ibm_iam_access_group.vpn_users.id
    roles           = ["VPN Client"]

    resources {
        service = "is.vpn-server"
    }
}
