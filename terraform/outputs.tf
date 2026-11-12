output "message" {
    value = <<EOM
    1. Connect with OpenVPN. Be sure to download the client profile template (locally) and specify your certificate and private key.
    2. Manual IBM i configuration after provisioning (one time, from the IBM Cloud console).

       The commands below achieve the same outcome as ibmi/CRTACSDEV.clle: reset the QSECOFR password,
       accept the software license agreements, and create/vary on a virtual display device so that an
       ACS 5250 (telnet) session can sign on.

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

       2d. Create and vary on a virtual display device for ACS 5250 (what CRTACSDEV.clle does with its defaults
           ACSDEV01 / QPACTL01):

           i.   Confirm the controller exists (it must be listed):
                WRKCFGSTS CFGTYPE(*CTL) CFGD(QPACTL*)

           ii.  Check whether the device already exists (skip step iii if it does):
                WRKCFGSTS CFGTYPE(*DEV) CFGD(ACSDEV01)

           iii. Create the device (AUT(*EXCLUDE): QSECOFR has *ALLOBJ so it can still sign on;
                other profiles need explicit authority):
                CRTDEVDSP DEVD(ACSDEV01) DEVCLS(*VRT) TYPE(3179) MODEL(2) ONLINE(*YES) CTL(QPACTL01) +
                          TEXT('Virtual device for ACS 5250 session') AUT(*EXCLUDE)

           iv.  Vary it on only if its status is VARIED OFF:
                VRYCFG CFGOBJ(ACSDEV01) CFGTYPE(*DEV) STATUS(*ON)

           v.   (Optional) Allow QSECOFR more than one device session. This loosens a security
                setting; use it only when needed. To restore it later, use LMTDEVSSN(*SYSVAL):
                CHGUSRPRF USRPRF(QSECOFR) LMTDEVSSN(*NO)

       2e. Alternative to 2d: run the CRTACSDEV.clle program instead of typing the commands.
           Copy ibmi/CRTACSDEV.clle to the IFS (for example with the IFS file transfer in ACS) and
           compile and call it from the CL command line:

           CRTBNDCL PGM(QGPL/CRTACSDEV) SRCSTMF('/tmp/CRTACSDEV.clle') DFTACTGRP(*NO) ACTGRP(*CALLER) AUT(*EXCLUDE)
           CALL PGM(QGPL/CRTACSDEV)

           Parameters (all optional): device name, controller name, and SETLMT ('Y' sets QSECOFR LMTDEVSSN(*NO),
           default 'N'), e.g. CALL PGM(QGPL/CRTACSDEV) PARM('ACSDEV01' 'QPACTL01' 'N')

       2f. Connect with ACS 5250 (while connected to OpenVPN):
           Host: ${ibm_pi_instance.powervs_instance.pi_network[0].ip_address}, Port: 23, Workstation ID: ACSDEV01
           If the connection is refused, make sure the Telnet server is started (CL command line using the IBM i console in step 2a):

           STRTCPSVR SERVER(*TELNET)

    EOM
}
