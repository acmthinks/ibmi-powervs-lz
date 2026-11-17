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

       2b. Follow the prompts to change the password (USERID: QSECOFR). Passwords must be a minimum of 15
           characters in length. Be sure to include single quotes (') around the PASSWORD parameter.

           CHGUSRPRF USRPRF(QSECOFR) PASSWORD(<new_password>) PWDEXP(*NO) STATUS(*ENABLED)

       2c. Accept the software license agreements, if they have not been accepted already (CL command line):

           WRKSFWAGR

           Review the terms with the Display option, then accept every agreement that is not yet accepted
           using the accept option shown on the screen. Agreements already accepted need no action.

       2d. Set the system values that affect ACS 5250 sign-on (CL command line, signed on as QSECOFR):

           QAUTOVRT (required). The default is 0, which stops IBM i from creating virtual devices, so the
           Telnet session fails with ACS response code 8917 "Not authorized to object" before the sign-on
           screen appears. Allow virtual devices.

           QLMTSECOFR (optional). The default is 1, so QSECOFR, and any profile with *ALLOBJ or *SERVICE,
           can sign on only at devices it has been explicitly authorized to. Setting it to 0 allows sign-on
           from any device. This loosens security; it is acceptable for a PoC behind the VPN.

           QLMTDEVSSN (optional). The default is 1, QSECOFR only allows 1 device per session (default).
           To allow more than 1 concurrent session with the QSECOFR user, change the number of concurrent
           devices. Setting the value to 0 will allow unlimited devices. Or set a value greater than 1 to
           allow more than one device per session.

           These are security-related system values and may be locked (message CPF18C0 "cannot be changed").
           Unlock it, change it, then lock it again:

           CHGSSTSECA SECSYSVAL(*YES)
           CHGSYSVAL SYSVAL(QAUTOVRT) VALUE(100)
           CHGSYSVAL SYSVAL(QLMTSECOFR) VALUE('0')
           CHGSYSVAL SYSVAL(QLMTDEVSSN) VALUE('0')
           CHGSSTSECA SECSYSVAL(*NO)

           Verify with: DSPSYSVAL SYSVAL(QAUTOVRT) and DSPSYSVAL SYSVAL(QLMTSECOFR)

           These values are set on the IBM i LPAR itself, not by Terraform, so repeat them after
           rebuilding an LPAR.

       2e. Start the Telnet server:

           STRTCPSVR SERVER(*TELNET)

           To restart the Telnet service after IPL:

           CHGTELNA AUTOSTART(*YES)

       2f. Connect with ACS 5250 (while connected to OpenVPN):
           Host: ${ibm_pi_instance.powervs_instance.pi_network[0].ip_address}, Port: 23
           Leave the Workstation ID blank so IBM i creates a virtual device (QPADEV*) for the session.
           Logon with QSECOFR and the newly reset password.

    3. Enable SSH to support connection with IBM Bob.

       3a. Update the sshd_config file to permit root login with QSECOFR:

           CALL QP2TERM
           sed 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /QOpenSys/QIBM/ProdData/SC1/OpenSSH/etc/sshd_config > /tmp/sshd_config.new
           cp /QOpenSys/QIBM/ProdData/SC1/OpenSSH/etc/sshd_config /tmp/sshd_config.bak
           cp /tmp/sshd_config.new /QOpenSys/QIBM/ProdData/SC1/OpenSSH/etc/sshd_config
           grep -n PermitRootLogin /QOpenSys/QIBM/ProdData/SC1/OpenSSH/etc/sshd_config

           sed 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /QOpenSys/QIBM/ProdData/SC1/OpenSSH/etc/sshd_config > /tmp/sshd_config.new
           cp /QOpenSys/QIBM/ProdData/SC1/OpenSSH/etc/sshd_config /tmp/sshd_config.bak
           cp /tmp/sshd_config.new /QOpenSys/QIBM/ProdData/SC1/OpenSSH/etc/sshd_config
           grep -n PubkeyAuthentication /QOpenSys/QIBM/ProdData/SC1/OpenSSH/etc/sshd_config

           sed 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /QOpenSys/QIBM/ProdData/SC1/OpenSSH/etc/sshd_config > /tmp/sshd_config.new
           cp /QOpenSys/QIBM/ProdData/SC1/OpenSSH/etc/sshd_config /tmp/sshd_config.bak
           cp /tmp/sshd_config.new /QOpenSys/QIBM/ProdData/SC1/OpenSSH/etc/sshd_config
           grep -n PasswordAuthentication /QOpenSys/QIBM/ProdData/SC1/OpenSSH/etc/sshd_config

           /QOpenSys/QIBM/ProdData/SC1/OpenSSH/sbin/sshd -T | grep -i PermitRootLogin
           /QOpenSys/QIBM/ProdData/SC1/OpenSSH/sbin/sshd -T | grep -i PubkeyAuthentication
           /QOpenSys/QIBM/ProdData/SC1/OpenSSH/sbin/sshd -T | grep -i PasswordAuthentication

       3b. Start the SSH server. If SSHD is already running, restart it so that it reads the
           updated sshd_config (a running sshd keeps the old settings until it is restarted):

           ENDTCPSVR SERVER(*SSHD)
           STRTCPSVR SERVER(*SSHD)

           To restart the SSHD service after IPL:

           CHGSSHA AUTOSTART(*YES)

       3c. Authorize your public key for QSECOFR. The key registered with PowerVS is NOT installed for
           QSECOFR, so sshd rejects public key logon until it is added to authorized_keys. sshd also
           refuses keys if the home directory or .ssh are group/world writable (StrictModes):

           CALL QP2TERM
           mkdir -p /home/QSECOFR/.ssh
           chmod 755 /home/QSECOFR
           chmod 700 /home/QSECOFR/.ssh
           echo '<contents of your ~/.ssh/id_ed25519.pub>' >> /home/QSECOFR/.ssh/authorized_keys
           chmod 600 /home/QSECOFR/.ssh/authorized_keys
           ssh-keygen -lf /home/QSECOFR/.ssh/authorized_keys

           A 5250 session wraps long lines and can corrupt the pasted key. If the fingerprint printed by
           ssh-keygen does not match "ssh-keygen -lf ~/.ssh/id_ed25519.pub" on your workstation, rewrite the
           key in short pieces with printf '%s' '<first part>' > file, then printf '%s\n' '<rest>' >> file.

           Then connect from your workstation (while connected to OpenVPN):

           ssh -i ~/.ssh/id_ed25519 QSECOFR@${ibm_pi_instance.powervs_instance.pi_network[0].ip_address}

       4. Launch your local IDE, IBM Bob. Connect to the PowerVS LPAR with the folowing:
           Host or IP Address: ${ibm_pi_instance.powervs_instance.pi_network[0].ip_address}
           Port (SSH): 22
           Username: QSECOFR
           Private Key: <upload the private key file, i.e. id_ed25519 from your local workstation)
           Key Passphrase (stored): <your passphrase for your private key file>

    EOM
}
