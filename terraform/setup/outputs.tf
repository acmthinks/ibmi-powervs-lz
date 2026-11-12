output "resource_group" {
    value = ibm_resource_group.resource_group.name
}

output "secrets_manager_instance_crn" {
    description = "Use as secrets_manager_instance_crn in /terraform"
    value       = ibm_resource_instance.sm_instance.crn
}

output "ssh_keys_secret_group_id" {
    description = "Use as secrets_group_id in /terraform"
    value       = ibm_sm_secret_group.powervs_secret_group.secret_group_id
}

output "post_run_instructions" {
    value = <<EOM
    POST-RUN CONFIGURATION

    Before running /terraform, add the following secrets to the Secrets Manager instance
    created by this run. Terraform reads these secrets but does not create them.

    Secrets Manager instance : ${ibm_resource_instance.sm_instance.name} (region us-south, private endpoint only)
    Instance CRN             : ${ibm_resource_instance.sm_instance.crn}

    Secrets Manager is reachable only over the IBM Cloud private network. Add the secrets from the
    IBM Cloud console (Resource list > Security > ${ibm_resource_instance.sm_instance.name} > Secrets > Add)
    or from a host with private network access.

    1. SSH public key for the IBM i VSI (power-vsi) -- PowerVS supports RSA, ECDSA, and ed255519 keys
       - Secret type  : Other secret type (arbitrary)
       - Secrets group: ${var.secret_group_name} (ID: ${ibm_sm_secret_group.powervs_secret_group.secret_group_id})
       - Name         : any name, for example "my-ssh-key". Set this name as ssh_key_powervs_secret_name in /terraform.
       - Payload      : contents of the PUBLIC key file (for example ~/.ssh/id_rsa.pub). Never the private key.
       - To create an RSA key: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
       - To create an ECDSA key: ssh-keygen -t rsa -b 521 -f ~/.ssh/id_ecdsa
       - To create an ed255219 key: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

    2. SSL certificate for the VPN server
       - Secret type  : Imported certificate
       - Secrets group: vpn-certificates
       - Name         : any name, for example "${var.prefix}-vpnserver-server-certificate". Set this name as vpn_certificate_name in /terraform.
       - Contents     : the server certificate (PEM), its private key and the CA/intermediate certificate chain.
                        The same certificate is also used to authenticate VPN clients (client_ca_crn).

    3. Set these variables in /terraform:
       - secrets_manager_instance_crn : ${ibm_resource_instance.sm_instance.crn}
       - secrets_group_id             : ${ibm_sm_secret_group.powervs_secret_group.secret_group_id}
       - ssh_key_powervs_secret_name, vpn_certificate_name : the secret names chosen above
       - resource_group               : ${ibm_resource_group.resource_group.name}

    EOM
}
