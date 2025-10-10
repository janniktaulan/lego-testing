#!/bin/bash

if [ ! -x "$(which lego)" ]; then
   echo "Please install lego using this command: sudo snap install lego"
   exit 1
fi

function read_credentials() {
read -p "Please enter your EAB Key ID: " eab_kid
read -p "Please enter your EAB HMAC Key: " eab_hmac
read -p "Please enter your domain: " domain
}

read -p "Do you want to use pre-validation? (y/n): " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]] 
then
    dns="manual"
    read_credentials
else
    echo "Sorry, we currently only support pre-validation"
    exit 1
fi
#reg var
registration="--server https://emea.acme.atlas.globalsign.com/directory --email test123@test.com -a"

#eab var
eab="--eab --kid "${eab_kid:?}" --hmac "${eab_hmac:?}""

#dns vars
dns_manual="--dns manual"
dns_azure="--dns azuredns"

#domains
domain="--domains "${domain:?}" --key-type rsa2048 run"

# pre-validated
if [ $dns = manual ]; 
then

    echo "LEGO command: sudo lego $registration $dns_manual $eab $domain" 
    sudo lego $registration $dns_manual $eab $domain
    echo "If you installed LEGO through snap, your certificate is here: /var/snap/leggo/common/.lego/certificates"
    exit
fi
# cronjob implementering - evt opret en liste som scriptet kan bruge til at vedligeholde cronjobs.
# valg af pre-validated / dns / HTTP