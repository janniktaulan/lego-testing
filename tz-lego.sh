#!/bin/bash

if [ ! -x "$(which lego)" ]; then
   echo "Please install lego using this command: sudo snap install lego"
   exit 1
fi
mkdir -p /etc/lego/scripts/

if ! [ -e "/etc/lego/scripts/renewal.sh" ] ; then
    touch "/etc/lego/scripts/renewal.sh"
fi

function read_credentials() {
    if test -f /etc/lego/scripts/user_credentials; then
    read -n 1 -p "Do you want to reuse saved EAB credentials? (y/n): " reuse_eab
    echo
        if [[ "$reuse_eab" == "y" ]]; then
            read -p "Please enter your domain: " domain
            return
        else 
            sudo rm /etc/lego/scripts/user_credentials
        fi
    fi
    read -p "Please enter your EAB Key ID: " eab_kid
    read -p "Please enter your EAB HMAC Key: " eab_hmac
    read -p "Please enter your domain: " domain
    echo "export eab_kid=\"$eab_kid\"" > /etc/lego/scripts/user_credentials
    echo "export eab_hmac=\"$eab_hmac\"" >> /etc/lego/scripts/user_credentials
    chmod 600 /etc/lego/scripts/user_credentials
}

function dns_full() {
    if test -f /etc/lego/scripts/azure_credentials; then
    read -n 1 -p "Do you want to reuse saved Azure credentials? (y/n): " reuse_azure
    echo
        if [[ "$reuse_azure" == "y" ]]; then
            return
        else
            sudo rm /etc/lego/scripts/azure_credentials
        fi
    fi
    read -p "Please enter your Azure Client ID: " azure_client_id
    read -p "Please enter your Azure Client Secret: " azure_client_secret
    read -p "Please enter your Azure Tenant ID: " azure_tenant_id
    read -p "Please enter your Azure Subscription ID: " azure_subscription_id
    echo "export AZURE_CLIENT_ID=\"$azure_client_id\"" >> /etc/lego/scripts/azure_credentials
    echo "export AZURE_CLIENT_SECRET=\"$azure_client_secret\"" >> /etc/lego/scripts/azure_credentials
    echo "export AZURE_TENANT_ID=\"$azure_tenant_id\"" >> /etc/lego/scripts/azure_credentials
    echo "export AZURE_SUBSCRIPTION_ID=\"$azure_subscription_id\"" >> /etc/lego/scripts/azure_credentials
    echo "export AZURE_ENVIRONMENT=\"public\"" >> /etc/lego/scripts/azure_credentials
    chmod 600 /etc/lego/scripts/azure_credentials
}

# Prompt for web server type
echo "Which web server are you ordering a certificate for?"
echo "1: Nginx"
echo "2: Apache"
read -n 1 -p "Enter choice [1-2]: " server_choice
echo

case $server_choice in
    1)
        server="nginx"
        echo "Server: Nginx"
        echo
        ;;
    2)
        server="apache2"
        echo "Server: Apache"
        echo
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Prompt for validation method
echo "How do you want to validate?"
echo "1: Pre-validated domain"
echo "2: Azure DNS"
echo "3: HTTP Validation (NOT SUPPORTED YET)"
read -n 1 -p "Enter choice [1-3]: " validation_choice
echo

case $validation_choice in
    1)
        validation="manual"
        echo "MODE: Pre-validated DNS"
        echo
        read_credentials
        ;;
    2)
        validation="azure"
        echo "MODE: Azure DNS"
        echo
        read_credentials
        dns_full
        ;;
    3)
        validation="http"
        echo "MODE: HTTP Validation"
        echo
        read_credentials
        http_validation  # You may need to implement this function if not present
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

#reg var
# Always source user credentials before using eab_kid and eab_hmac
if [ -f /etc/lego/scripts/user_credentials ]; then
    . /etc/lego/scripts/user_credentials
fi
registration="--server https://emea.acme.atlas.globalsign.com/directory --email test123@test.com -a"

#eab var
eab="--eab --kid "${eab_kid:?}" --hmac "${eab_hmac:?}""

#dns vars
val_manual="--dns manual"
val_azure="--dns azuredns"

#domains
domain="--domains "${domain:?}" --key-type rsa2048 run"
domain_renew="--domains "${domain:?}" --key-type rsa2048 renew"

read -n 1 -p "Do you want to create a cronjob for automatic renewal? (y/n): " cronjob_choice
echo
if [[ "$cronjob_choice" == "y" ]]; then
    renewal="yes"
    echo "Selecting automatic renewal"
    job='0 8 * * * /etc/lego/scripts/renewal.sh' 
    (crontab -l 2>/dev/null | grep -Fxq -- "$job") || (crontab -l 2>/dev/null; printf '%s\n' "$job") | crontab - 
    echo
else 
    echo "Selecting manual renewal"
    renewal="no"
    echo
fi


# pre-validated
if [ $validation = manual ]; 
then
    echo "LEGO command: sudo lego $registration $val_manual $eab $domain" 
    sudo lego $registration $val_manual $eab $domain
    echo "Attempting to restart web server: $server"
    sudo systemctl restart $server
    if [ $renewal = yes ]; then
        echo "Creating cronjob for automatic renewal at: /etc/lego/scripts/renewal.sh"
        echo "# Renewal job for: $domain" >> /etc/lego/scripts/renewal.sh
        echo ". /home/jn/.lego/scripts/lego-env" >> /etc/lego/scripts/renewal.sh
        echo "sudo lego $registration $val_manual $eab $domain_renew" >> /etc/lego/scripts/renewal.sh
        # sudo lego --server https://emea.acme.atlas.globalsign.com/directory --email test123@test.com -a --dns manual --eab --kid d87cde73ba31fa59 --hmac gJ2GEaeH-cEdyIk_om97z8OYZ-C5SJw_aLcRtPuRrJOM8v69k4Ac0c12eksZqnlVuDgagnMZZm-RtFjIA4uioFXmX588Unk2WDRjlSYXwETC1HRGDiqEfYOaz9tkMmcN5WO-_usK53gZXgk4wqpcL9XZtc7nITTowMLl9S9c1pc --domains learning.alfassl.com --key-type rsa2048 renew --days 397

        echo "sudo systemctl restart $server" >> /etc/lego/scripts/renewal.sh
        echo "" >> /etc/lego/scripts/renewal.sh
    fi
    echo "If you installed LEGO through snap, your certificate is here: /var/snap/lego/common/.lego/certificates"
    exit
fi

if [ $validation = azure ]; 
then
    . /etc/lego/scripts/azure_credentials
    echo "LEGO command: sudo lego $registration $val_azure $eab $domain"
    sudo -E lego $registration $val_azure $eab $domain
    echo "Attempting to restart web server: $server"
    sudo systemctl restart $server
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

# vil du specificere hvor certifikaterne skal ligge?
# test wildcard implementering
# cronjob implementering - opret cronjob HVIS DET IKKE FINDES ALLEREDE
# cronjob script - hvordan kan vi styre hvilke domains der skal slettes, hvis man har flere?
# HTTP implementering
# Flere DNS udbydere end Azure?
# PT virker det kun med et set credentials. Kan vi implementere en måde at råde over flere credentials på?