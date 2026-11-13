output "message" {
    value = <<EOM
    1. Connect with OpenVPN. Be sure to download the client profile template (locally) and specify your certificate and private key.
    2. Manual IBM i configuration after provisioning (one time, from the IBM Cloud console).

       The commands below reset the QSECOFR password, accept the software license agreements, and set the
       system values so that an ACS 5250 (telnet) session can sign on.

       2a. Open the IBM i console:
           IBM Cloud console > Resources list > Power Virtual Server workspace > Virtual server instances
           > ${ibm_pi_instance.powervs_instance.pi_instance_name} > Actions > Open console.
           Sign on as QSECOFR at the console sign-on screen. If the system prompts you to change an
           expired password, enter a new one when asked and continue.

       2b. Reset the QSECOFR password (CL command line):

           CHGUSRPRF USRPRF(QSECOFR) PASSWORD(<new_password>) PWDEXP(*NO) STATUS(*ENABLED)

       2c. Accept the software license agreements, if they have not been accepted already (CL command line):

           WRKSFWAGR

           Review the terms with the Display option, then accept every agreement that is not yet accepted
           using the accept option shown on the screen. Agreements already accepted need no action.

       2d. Set the system values that affect ACS 5250 sign-on (CL command line, signed on as QSECOFR):

           QAUTOVRT (required). The default is 0, which stops IBM i from creating virtual devices, so the
           Telnet session fails with ACS response code 8917 "Not authorized to object" before the sign-on
           screen appears. Allow virtual devices:

           CHGSYSVAL SYSVAL(QAUTOVRT) VALUE(100)

           QLMTSECOFR (optional). The default is 1, so QSECOFR, and any profile with *ALLOBJ or *SERVICE,
           can sign on only at devices it has been explicitly authorized to. Setting it to 0 allows sign-on
           from any device. This loosens security; it is acceptable for a PoC behind the VPN. This is a
           security-related system value and may be locked (message CPF18C0 "cannot be changed"). Unlock it,
           change it, then lock it again:

           CHGSSTSECA SECSYSVAL(*YES)
           CHGSYSVAL SYSVAL(QLMTSECOFR) VALUE('0')
           CHGSSTSECA SECSYSVAL(*NO)

           Verify with: DSPSYSVAL SYSVAL(QAUTOVRT) and DSPSYSVAL SYSVAL(QLMTSECOFR)

           These values are set on the IBM i LPAR itself, not by Terraform, so repeat them after
           rebuilding an LPAR.

       2e. Connect with ACS 5250 (while connected to OpenVPN):
           Host: ${ibm_pi_instance.powervs_instance.pi_network[0].ip_address}, Port: 23
           Leave the Workstation ID blank so IBM i creates a virtual device (QPADEV*) for the session.
           If the connection is refused, make sure the Telnet server is started (CL command line using the IBM i console in step 2a):

           STRTCPSVR SERVER(*TELNET)

           To restart the Telnet service after IPL:

           CHGTELNA AUTOSTART(*YES)

    EOM
}
