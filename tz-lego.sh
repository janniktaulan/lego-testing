#!/bin/bash

if [ ! -x "$(which lego)" ]; then
   echo "Please install lego using this command: sudo snap install lego"
   exit 1
fi
mkdir -p /etc/lego/scripts/
mkdir -p /etc/lego/certs/

if ! [ -e "/etc/lego/scripts/renewal.sh" ] ; then
    echo "#!/bin/bash" > /etc/lego/scripts/renewal.sh
fi

function copy_certs() {
        echo "Copying certificates to custom path: $custom_path"
        if sudo cp /var/snap/lego/common/.lego/certificates/* "$custom_path"; then
        echo "Certificates moved to: $custom_path"
        else
        echo "Failed to copy certificates."
        fi
        exit
}

function read_credentials() {
    if test -f /etc/lego/scripts/user_credentials; then
    read -n 1 -p "Do you want to reuse saved EAB credentials? (y/n): " reuse_eab
    echo
        if [[ "$reuse_eab" == "y" ]]; then
            read -p "Please enter your domain: " domain
            echo
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
function start_prompt() {
    echo "Options:"
    echo "1. Order a new certificate"
    echo "2. List renewals"
    echo "3. Exit"
    read -n 1 -p "Enter choice [1-2]: " initial_choice
    echo
    case $initial_choice in
        1)
            echo "You selected to order a new certificate."
            new_cert
            echo
            ;;
        2)
            echo "Current cronjob renewals:"
            grep -oP '(?<=--domains ).*(?= --key-type)' /etc/lego/scripts/renewal.sh
            echo
            start_prompt
            ;;
        3)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}
# Initial promp
echo "Welcome to TZ-Bot."
start_prompt

function new_cert() {
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
    read -n 1 -p "Enter choice [1-2]: " validation_choice
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
    domain_var="--domains "${domain:?}" --key-type rsa2048 run"
    domain_renew_var="--domains "${domain:?}" --key-type rsa2048 renew"

    read -n 1 -p "Do you want to create a cronjob for automatic renewal? (y/n): " cronjob_choice
    echo
    if [[ "$cronjob_choice" == "y" ]]; then
        renewal="yes"
        echo "Selecting automatic renewal"
        job='0 8 * * * /etc/lego/scripts/renewal.sh 2> /dev/null' 
        (crontab -l 2>/dev/null | grep -Fxq -- "$job") || (crontab -l 2>/dev/null; printf '%s\n' "$job") | crontab - 
        echo
    else 
        echo "Selecting manual renewal"
        renewal="no"
        echo
    fi

    echo "Do you want to specify the path to save the certificates?"
    echo "The path must exist, since this script will not create it."
    echo "This will move ALL certificates to the specified path, including those from other domains."
    read -n 1 -p "Please select a choice. (y/n): " custom_path_choice
    echo
    if [[ "$custom_path_choice" == "y" ]]; then
        read -p "Please enter the full path to save the certificates (e.g., /etc/lego/certs): " custom_path
        echo "Custom path selected: $custom_path"
        echo
        path="true"
    fi


    case $validation in
        manual)
            echo "LEGO command: sudo lego $registration $val_manual $eab $domain_var" 
            sudo lego $registration $val_manual $eab $domain_var
            echo "Attempting to restart web server: $server"
            sudo systemctl restart $server
            if [[ $renewal = yes ]]; then
                echo "Creating cronjob for automatic renewal at: /etc/lego/scripts/renewal.sh"
                echo "sudo lego $registration $val_manual $eab $domain_renew_var" >> /etc/lego/scripts/renewal.sh
                if [[ $path = true ]]; then
                    echo "sudo cp /var/snap/lego/common/.lego/certificates/* "$custom_path"" >> /etc/lego/scripts/renewal.sh
                fi
                echo "sudo systemctl restart $server" >> /etc/lego/scripts/renewal.sh
                echo "" >> /etc/lego/scripts/renewal.sh
            fi
            if [[ $path = true ]]; then
                copy_certs
            else
                echo "If you installed LEGO through snap, your certificate is here: /var/snap/lego/common/.lego/certificates"
            fi
            exit
            ;;
        azure)
            . /etc/lego/scripts/azure_credentials
            echo "LEGO command: sudo lego $registration $val_azure $eab $domain_var"
            sudo -E lego $registration $val_azure $eab $domain_var
            echo "Attempting to restart web server: $server"
            sudo systemctl restart $server
            if [[ $renewal = yes ]]; then
                echo "Creating cronjob for automatic renewal at: /etc/lego/scripts/renewal.sh"
                echo ". /etc/lego/scripts/azure_credentials" >> /etc/lego/scripts/renewal.sh
                echo "sudo lego $registration $val_azure $eab $domain_renew_var" >> /etc/lego/scripts/renewal.sh
                if [[ $path = true ]]; then
                    echo "sudo cp /var/snap/lego/common/.lego/certificates/* "$custom_path"" >> /etc/lego/scripts/renewal.sh
                fi
                echo "sudo systemctl restart $server" >> /etc/lego/scripts/renewal.sh
                echo "" >> /etc/lego/scripts/renewal.sh
            fi
            if [[ $path = true ]]; then
                copy_certs
            else
                echo "If you installed LEGO through snap, your certificate is here: /var/snap/lego/common/.lego/certificates"
            fi
            exit
            ;;
        *)
            echo "internal error"
            exit 1
            ;;
    esac

# To do list:
# add support for managing renewals
# we overwrite old certificates when we specify a path, no backup is made. However the certificates in the snap folder remain and are maintained by lego as usual.

# test wildcard implementering

# Flere DNS udbydere end Azure?
# PT virker det kun med et set credentials. Kan vi implementere en måde at råde over flere credentials på?

# Cronjob supports 1 renewal right now, and also does not delete existing, it just fills into the renewal.sh, possibly breaking it.
# HTTP is not supported when installed using snap - snap gives no rights to anywhere other than the snap folder.
# Can only place certificates in the snap folder