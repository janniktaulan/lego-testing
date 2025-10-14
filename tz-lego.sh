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

function dns_full() {
    read -p "Please enter your Azure Client ID: " azure_client_id
    read -p "Please enter your Azure Client Secret: " azure_client_secret
    read -p "Please enter your Azure Tenant ID: " azure_tenant_id
    read -p "Please enter your Azure Subscription ID: " azure_subscription_id
    touch /etc/lego/scripts/azure_credentials
    echo "AZURE_CLIENT_ID=$azure_client_id" >> /etc/lego/scripts/azure_credentials
    echo "AZURE_CLIENT_SECRET=$azure_client_secret" >> /etc/lego/scripts/azure_credentials
    echo "AZURE_TENANT_ID=$azure_tenant_id" >> /etc/lego/scripts/azure_credentials
    echo "AZURE_SUBSCRIPTION_ID=$azure_subscription_id" >> /etc/lego/scripts/azure_credentials
    echo "AZURE_ENVIRONMENT=public" >> /etc/lego/scripts/azure_credentials
    chmod 600 /etc/lego/scripts/azure_credentials
    chmod +x /etc/lego/scripts/azure_credentials
}

# Prompt for validation method
echo "How do you want to validate?"
echo "1: Pre-validated"
echo "2: DNS"
echo "3: HTTP"
read -p "Enter choice [1-3]: " validation_choice

case $validation_choice in
    1)
        validation="manual"
        echo "MODE: Pre-validated DNS"
        read_credentials
        ;;
    2)
        validation="azure"
        echo "MODE: Azure DNS"
        read_credentials
        dns_full
        ;;
    3)
        validation="http"
        echo "MODE: HTTP Validation"
        read_credentials
        http_validation  # You may need to implement this function if not present
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac
#reg var
registration="--server https://emea.acme.atlas.globalsign.com/directory --email test123@test.com -a"

#eab var
eab="--eab --kid "${eab_kid:?}" --hmac "${eab_hmac:?}""

#dns vars
val_manual="--dns manual"
val_azure="--dns azuredns"

#domains
domain="--domains "${domain:?}" --key-type rsa2048 run"

# pre-validated
if [ $validation = manual ]; 
then
    echo "LEGO command: sudo lego $registration $val_manual $eab $domain" 
    sudo lego $registration $dns_manual $eab $domain
    echo "If you installed LEGO through snap, your certificate is here: /var/snap/lego/common/.lego/certificates"
    exit
fi

if [ $validation = azure ]; 
then
    echo "LEGO command: sudo lego $registration $val_azure $eab $domain"
    sudo lego $registration $val_azure $eab $domain
    echo "If you installed LEGO through snap, your certificate is here: /var/snap/lego/common/.lego/certificates"
    exit
fi

#if [ $validation = http ]; 
#then
#    echo "LEGO command: sudo lego $registration --http --http.webroot /var/www/html $eab $domain"
#    sudo lego $registration --http --http.webroot /var/www/html $eab $domain
#    echo "If you installed LEGO through snap, your certificate is here: /var/snap/lego/common/.lego/certificates"
#    exit
#fi

# cronjob implementering - evt opret en liste som scriptet kan bruge til at vedligeholde cronjobs.
# valg af pre-validated / dns / HTTP