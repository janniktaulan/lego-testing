#!/bin/bash
function upkeep() {
    if ! command -v lego >/dev/null 2>&1; then
        echo "Lego is not installed."
        read -n 1 -p "Do you want TZ-bot to try installing Lego? (y/n): " install_choice
        if [[ "$install_choice" == "y" ]]; then
            echo "Installing Lego using Snap: "sudo snap install lego""
            sudo snap install lego
                if ! command -v lego >/dev/null 2>&1; then
                echo "Lego installation failed. Please install Lego manually, using this command: sudo snap install lego"
                exit 1
                fi
        else
            echo "Lego is required to use TZ-bot. Please install Lego manually, using this command: sudo snap install lego"
            exit 1
        fi
    fi
    mkdir -p /etc/lego/scripts/
    mkdir -p /etc/lego/certs/

    if ! [ -e "/etc/lego/scripts/storage" ] ; then
        touch /etc/lego/scripts/storage
    fi

    if ! [ -e "/etc/lego/scripts/renewal.sh" ] ; then
        echo "#!/bin/bash" > /etc/lego/scripts/renewal.sh
        echo ". /etc/lego/scripts/azure_credentials" >> /etc/lego/scripts/renewal.sh
        chmod 600 /etc/lego/scripts/renewal.sh
    fi
}
function renewal_management() {
    echo ""
    echo "Renewal management:"
    echo "1. List renewals"
    echo "2. Remove a cronjob renewal"
    echo "3. Back to main menu"
    read -n 1 -p "Enter choice [1-2]: " renewal_choice
    echo
    case $renewal_choice in
        1)
            echo ""
            echo "Current cronjob renewals:"
            #grep -noP '(?<=--domains ).*(?= --key-type)' /etc/lego/scripts/renewal.sh
            awk '{domain=""; wildcard=""; for(i=1;i<=NF;i++){if($i=="--domains"){d=$(i+1); if(d~/^\*\./){wildcard=d} else if(domain==""){domain=d}}} if(wildcard!=""){print NR ": " wildcard} else if(domain!=""){print NR ": " domain}}' /etc/lego/scripts/renewal.sh
            echo
            renewal_management
            ;;
        2)
            read -p "Please enter the number of the renewal you want to remove: " remove_domain
            echo "You selected to remove renewal for domain: $remove_domain"
            read -n 1 -p "Are you sure you want to proceed with the removal? (y/n): " confirm_removal
            echo
            if [[ "$confirm_removal" == "y" ]]; then
                echo "Removing renewal for domain: $remove_domain"
                if sudo sed -i.bak "${remove_domain}d" /etc/lego/scripts/renewal.sh; then
                    echo "Renewal removed from renewal script."
                else
                    echo "Failed to remove renewal from script."
                fi
                renewal_management
            else
                echo "Removal cancelled."
                renewal_management
            fi
            ;;
        3)
            start_prompt
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}
function storage() {
    echo ""
    if grep -q "path=" "/etc/lego/scripts/storage"; then
        . /etc/lego/scripts/storage
        echo "Current custom path for certificate storage: $path"
    else
        echo "No custom path set for certificate storage. Certificates are stored in the default lego directory."
    fi
    echo ""
    echo "Storage Settings:"
    echo "1. Set custom path for certificate storage"
    echo "2. Disable custom path"
    echo "3. Force copy certificates to path in settings"
    echo "4. Force copy certificates to custom path"
    echo "5. Back to main menu"
    read -n 1 -p "Enter choice [1-3]: " storage_choice
    echo
    case $storage_choice in
        1)
            read -p "Please enter the full path to save the certificates (e.g., /etc/lego/certs): " path
            echo ""
            echo "Custom path selected: $path"
            echo ""
            echo "path=$path" > /etc/lego/scripts/storage
            sudo sed -i.bak "/sudo cp \/var\/snap\/lego\/common\/.lego\/certificates\/*/d" /etc/lego/scripts/renewal.sh
            echo "sudo cp /var/snap/lego/common/.lego/certificates/* "$path"" >> /etc/lego/scripts/renewal.sh
            storage
            ;;
        2)
            echo ""
            echo "Disabling custom path. Certificates will remain in the default lego directory."
            if grep -q "sudo cp /var/snap/lego/common/.lego/certificates/*" "/etc/lego/scripts/renewal.sh"; then
                sudo sed -i.bak "/sudo cp \/var\/snap\/lego\/common\/.lego\/certificates\/*/d" /etc/lego/scripts/renewal.sh
                echo "" > /etc/lego/scripts/storage
                echo "Custom path disabled."
            else
                echo "Error: No custom path found in renewal script."
            fi
            storage
            ;;
        3)
            copy_certs
            storage
            ;;
        4)
            read -p "Please enter the full path to save the certificates (e.g., /etc/lego/certs): " custom_path
            echo "Custom path selected: $custom_path"
            if sudo cp /var/snap/lego/common/.lego/certificates/* "$custom_path"; then
                echo "Certificates copied to: $custom_path"
            else
                echo "Failed to copy certificates."
            fi
            storage
            ;;
        5)
            start_prompt
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}
function copy_certs() {
        echo ""
        if grep -q "path=" "/etc/lego/scripts/storage"; then
            . /etc/lego/scripts/storage
            echo "Copying certificates to path: $path"
            if sudo cp /var/snap/lego/common/.lego/certificates/* "$path"; then
                echo "Certificates copied to: $path"
            else
                echo "Failed to copy certificates."
            exit 1
            fi
        fi
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
    if grep -q "export AZURE" "/etc/lego/scripts/azure_credentials"; then
    read -n 1 -p "Do you want to reuse saved Azure credentials? (y/n): " reuse_azure
    echo
        if [[ "$reuse_azure" == "y" ]]; then
            return
        fi
    fi
    read -p "Please enter your Azure Client ID: " azure_client_id
    read -p "Please enter your Azure Client Secret: " azure_client_secret
    read -p "Please enter your Azure Tenant ID: " azure_tenant_id
    read -p "Please enter your Azure Subscription ID: " azure_subscription_id
    sudo rm /etc/lego/scripts/azure_credentials
    echo "export AZURE_CLIENT_ID=\"$azure_client_id\"" >> /etc/lego/scripts/azure_credentials
    echo "export AZURE_CLIENT_SECRET=\"$azure_client_secret\"" >> /etc/lego/scripts/azure_credentials
    echo "export AZURE_TENANT_ID=\"$azure_tenant_id\"" >> /etc/lego/scripts/azure_credentials
    echo "export AZURE_SUBSCRIPTION_ID=\"$azure_subscription_id\"" >> /etc/lego/scripts/azure_credentials
    echo "export AZURE_ENVIRONMENT=\"public\"" >> /etc/lego/scripts/azure_credentials
    chmod 600 /etc/lego/scripts/azure_credentials
}
function start_prompt() {
    echo
    echo "Options:"
    echo "1. Order a new certificate"
    echo "2. Renewal Management"
    echo "3. Storage Settings"
    echo "4. Exit"
    read -n 1 -p "Enter choice [1-3]: " initial_choice
    echo
    case $initial_choice in
        1)
            echo ""
            echo "You selected to order a new certificate."
            new_cert
            echo
            ;;
        2)
            renewal_management
            ;;
        3)
            storage
            ;;
        4)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}
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
    if [[ "$domain" == "*."* ]]; then
        domain_non_wc="${domain#*.}"
        domain_var="--domains "${domain:?}" --domains "${domain_non_wc:?}" --key-type rsa2048 run"
        domain_renew_var="--domains "${domain:?}" --domains "${domain_non_wc:?}" --key-type rsa2048 renew"
    else
        domain_var="--domains "${domain:?}" --key-type rsa2048 run"
        domain_renew_var="--domains "${domain:?}" --key-type rsa2048 renew"
    fi

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

    case $validation in
        manual)
            if [[ $renewal = no ]]; then
                echo "LEGO command: sudo lego $registration $val_manual $eab $domain_var" 
                sudo lego $registration $val_manual $eab $domain_var
                if grep -q "path=" "/etc/lego/scripts/storage"; then
                    . /etc/lego/scripts/storage
                    sudo sed -i.bak "/sudo cp \/var\/snap\/lego\/common\/.lego\/certificates\/*/d" /etc/lego/scripts/renewal.sh
                    echo "sudo cp /var/snap/lego/common/.lego/certificates/* "$path"" >> /etc/lego/scripts/renewal.sh
                    if sudo cp /var/snap/lego/common/.lego/certificates/* $path >> /etc/lego/scripts/renewal.sh; then
                        echo "Certificates copied to: $path"
                    else
                        echo "Failed to copy certificates."
                    fi
                fi
                echo "Attempting to restart web server: $server"
                sudo systemctl restart $server
            fi
            if [[ $renewal = yes ]]; then
                echo "LEGO command: sudo lego $registration $val_manual $eab $domain_var"
                sudo lego $registration $val_manual $eab $domain_var
                echo "Creating cronjob for automatic renewal at: /etc/lego/scripts/renewal.sh"
                echo "sudo lego $registration $val_manual $eab $domain_renew_var" >> /etc/lego/scripts/renewal.sh
                echo "sudo systemctl restart $server" >> /etc/lego/scripts/renewal.sh
                if grep -q nginx "/etc/lego/scripts/renewal.sh"; then
                    sudo sed -i.bak "/sudo systemctl restart nginx/d" /etc/lego/scripts/renewal.sh
                    echo "sudo systemctl restart nginx" >> /etc/lego/scripts/renewal.sh
                fi
                if grep -q apache2 "/etc/lego/scripts/renewal.sh"; then
                    sudo sed -i.bak "/sudo systemctl restart apache2/d" /etc/lego/scripts/renewal.sh
                    echo "sudo systemctl restart apache2" >> /etc/lego/scripts/renewal.sh
                fi
                if grep -q "path=" "/etc/lego/scripts/storage"; then
                    . /etc/lego/scripts/storage
                    sudo sed -i.bak "/sudo cp \/var\/snap\/lego\/common\/.lego\/certificates\/*/d" /etc/lego/scripts/renewal.sh
                    echo "sudo cp /var/snap/lego/common/.lego/certificates/* "$path"" >> /etc/lego/scripts/renewal.sh
                    if sudo cp /var/snap/lego/common/.lego/certificates/* $path >> /etc/lego/scripts/renewal.sh; then
                        echo "Certificates copied to: $path"
                    else
                        echo "Failed to copy certificates."
                    fi
                else
                echo "If you installed LEGO through snap, your certificate is here: /var/snap/lego/common/.lego/certificates"
                fi
                echo "Attempting to restart web server: $server"
                sudo systemctl restart $server
            fi
            exit
            ;;
        azure)
            . /etc/lego/scripts/azure_credentials
            echo "LEGO command: sudo -E lego $registration $val_azure $eab $domain_var"
            sudo -E lego $registration $val_azure $eab $domain_var
            echo "Attempting to restart web server: $server"
            sudo systemctl restart $server
            if [[ $renewal = yes ]]; then
                echo "Creating cronjob for automatic renewal at: /etc/lego/scripts/renewal.sh"
                echo ". /etc/lego/scripts/azure_credentials" >> /etc/lego/scripts/renewal.sh
                echo "sudo -E lego $registration $val_azure $eab $domain_renew_var" >> /etc/lego/scripts/renewal.sh
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
}

# Start
echo "Welcome to TZ-Bot."
upkeep
start_prompt

# To do list:
# check if first letter of $domain is a "*". If it is, we need to add a second --domains, so that we get both "*.example.com" and "example.com".
# ${full_domain#*.}

# Notes:

# Only works with 1 set of credentials, both for EAB and DNS.
# Renewal management is implemented, however it works kind of quirky.
# HTTP is not supported when installed using snap - snap gives no rights to anywhere other than the snap folder.
# Can only place certificates in the snap folder, meaning that the --path option cannot be used. However we have a function in place that simply copies the entire folder, to another place.
# Should we have an option to only copy the specific cert? Also no old certs are kept, lego overwrites existing certs when ordering new ones.
# Wilcard seems to be working just fine. I have not tested a deployment of one, only issuing it.