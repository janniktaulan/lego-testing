#!/bin/bash
function upkeep() {
    if ! command -v lego >/dev/null 2>&1; then
        echo "Lego is not installed."
        read -n 1 -p "Do you want TZ-bot to try installing Lego? (y/n): " install_choice
        if [[ "$install_choice" == "y" ]]; then
            echo ""
            echo "Installing Lego..."
            sudo curl -L https://github.com/go-acme/lego/releases/download/v4.27.0/lego_v4.27.0_linux_386.tar.gz > /tmp/lego.tar.gz
            sudo tar -xvzf /tmp/lego.tar.gz -C /tmp/
            sudo mkdir -p /usr/local/bin
            sudo mv /tmp/lego /usr/local/bin/lego
            sudo chmod +x /usr/local/bin/lego
                if ! command -v lego >/dev/null 2>&1; then
                echo "Lego installation failed. Please install Lego manually."
                exit 1
                fi
        else
            echo "Lego is required to use TZ-bot. If you need help installing lego, please contact TRUSTZONE support at support@trustzone.com"
            exit 1
        fi
    fi
    cron="true"
    if ! command -v crontab >/dev/null 2>&1; then
        echo "---------WARNING---------"
        echo "Crontab is NOT installed."
        echo "Automatic renewal via cronjobs will not be available."
        read -n 1 -p "Do you want TZ-bot to try installing cron/crontab? (y/n): " install_cron
        if [[ "$install_cron" == "y" ]]; then
            echo ""
            echo "Installing cron..."
            sudo apt-get update
            sudo apt-get install cron -y
                if ! command -v crontab >/dev/null 2>&1; then
                echo "Crontab installation failed. Please install cron/crontab manually."
                exit 1
                fi
        else
            echo "Entering manual renewal mode."
            cron="false"
        fi
    fi
    mkdir -p /etc/tz-bot/scripts/
    mkdir -p /etc/tz-bot/certs/

    if ! [ -e "/etc/tz-bot/scripts/storage" ] ; then
        touch /etc/tz-bot/scripts/storage
    fi
        if ! [ -e "/etc/tz-bot/scripts/azure_credentials" ] ; then
        touch /etc/tz-bot/scripts/azure_credentials
    fi

    if ! [ -e "/etc/tz-bot/scripts/renewal_list" ] ; then
        touch /etc/tz-bot/scripts/renewal_list
        chmod 600 /etc/tz-bot/scripts/renewal_list
    fi
    if ! [ -e "/etc/tz-bot/scripts/renewal.sh" ] ; then
        sudo echo "sudo echo "#!/bin/bash" > renew_temp.sh" > /etc/tz-bot/scripts/renewal.sh
        sudo echo "sudo echo ". /etc/lego/scripts/azure_credentials" >> renew_temp.sh" >> /etc/tz-bot/scripts/renewal.sh
        sudo echo "sudo cat renewal_list.sh >> renew_temp.sh" >> /etc/tz-bot/scripts/renewal.sh
        sudo echo "chmod +x renew_temp.sh" >> /etc/tz-bot/scripts/renewal.sh
        sudo chmod +x /etc/tz-bot/scripts/renewal.sh
        sudo echo "bash renew_temp.sh" >> /etc/tz-bot/scripts/renewal.sh
        sudo echo "rm -rf renew_temp.sh" >> /etc/tz-bot/scripts/renewal.sh
        sudo chmod +x /etc/tz-bot/scripts/renewal.sh
        chmod 600 /etc/tz-bot/scripts/renewal.sh
    fi
}
function renewal_management() {
    echo ""
    echo "Renewal management:"
    echo "1. List renewals"
    echo "2. Remove a cronjob renewal"
    echo "3. Remove all cronjob renewals"
    echo "4. Back to main menu"
    read -n 1 -p "Enter choice [1-4]: " renewal_choice
    echo
    case $renewal_choice in
        1)
            if ! grep -q "sudo lego" "/etc/tz-bot/scripts/renewal_list"; then
                echo ""
                echo "No renewals found."
            else
                echo ""
                echo "Current cronjob renewals:"
                awk '{domain=""; wildcard=""; for(i=1;i<=NF;i++){if($i=="--domains"){d=$(i+1); if(d~/^\*\./){wildcard=d} else if(domain==""){domain=d}}} if(wildcard!=""){print NR ": " wildcard} else if(domain!=""){print NR ": " domain}}' /etc/tz-bot/scripts/renewal_list
                echo
            fi
            renewal_management
            ;;
        2)
            if ! grep -q "sudo lego" "/etc/tz-bot/scripts/renewal_list"; then
                echo ""
                echo "No renewals found."
                renewal_management
            else
                read -p "Please enter the NUMBER of the renewal you want to remove: " remove_domain
                if ! [[ "$remove_domain" =~ ^[0-9]+$ ]]; then
                    echo "Only input whole numbers, e.g., '5'"
                    renewal_management
                fi
                echo "You selected to remove renewal for domain: $remove_domain"
                read -n 1 -p "Are you sure you want to proceed with the removal? (y/n): " confirm_removal
                echo
                if [[ "$confirm_removal" == "y" ]]; then
                    echo "Removing renewal for domain: $remove_domain"
                    if sudo sed -i.bak "${remove_domain}d" /etc/tz-bot/scripts/renewal_list; then
                        echo "Renewal removed from renewal script."
                        if sudo grep -q 'sudo lego' /etc/tz-bot/scripts/renewal_list; then
                            echo "Keeping crontab entry, since there are still renewals left in the script."
                        else
                            sudo crontab -l | grep -v '/etc/tz-bot/scripts/renewal_list' | sudo crontab -
                            echo "Crontab entry removed, since no renewals are left in the script."
                        fi
                    else
                        echo "Failed to remove renewal from script."
                fi
                renewal_management
                else
                    echo "Removal cancelled."
                    renewal_management
                fi
            fi
            ;;
        3)
            echo "Are you sure you want to remove ALL cronjob renewals? This action cannot be undone."
            read -n 1 -p "Type 'y' to confirm, or 'n' to cancel: " confirm_all_removal
            echo
            if [[ "$confirm_all_removal" = "y" ]]; then
                sudo rm /etc/tz-bot/scripts/renewal_list
                sudo touch /etc/tz-bot/scripts/renewal_list
                chmod 600 /etc/tz-bot/scripts/renewal_list
                sudo crontab -l | grep -v '/etc/tz-bot/scripts/renewal.sh' | sudo crontab -
                echo "All renewals have been removed."
                renewal_management
            else
                echo "Removal cancelled."
                renewal_management
            fi
            ;;
        4)
            start_prompt
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}
function read_credentials() {
    if test -f /etc/lego/scripts/user_credentials; then
    read -n 1 -p "Do you want to reuse saved EAB credentials? (y/n): " reuse_eab
    echo
        if [[ "$reuse_eab" == "y" ]]; then
            read -p "Please enter your domain: " domain
            echo
            return
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
    #sudo rm /etc/lego/scripts/azure_credentials
    echo "export AZURE_CLIENT_ID=\"$azure_client_id\"" > /etc/lego/scripts/azure_credentials
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
    echo "3. Uninstall TZ-Bot and Lego"
    echo "4. Exit"
    read -n 1 -p "Enter choice [1-4]: " initial_choice
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
            echo "You selected to uninstall TZ-Bot and Lego."
            read -n 1 -p "Are you sure you want to proceed? (This will open another script and leave tz-bot) (y/n): " confirm_uninstall
            echo ""
            if [[ "$confirm_uninstall" == "y" ]]; then
                echo "Proceeding to uninstall..."
                echo ""
                /etc/lego/tz-bot-remover.sh
            else
                echo "Uninstallation cancelled."
                start_prompt
            fi
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
function cronjob() {
        if cron="true"; then
        read -n 1 -p "Do you want to create a cronjob for automatic renewal? (y/n): " cronjob_choice
        echo
        if [[ "$cronjob_choice" == "y" ]]; then
            renewal="yes"
            echo "Selecting automatic renewal"
            job='0 0 1 * * /etc/tz-bot/scripts/renewal.sh 2> /dev/null' 
            (crontab -l 2>/dev/null | grep -Fxq -- "$job") || (crontab -l 2>/dev/null; printf '%s\n' "$job") | crontab - 
            echo
        else 
            echo "Selecting manual renewal"
            echo
        fi
    fi
}
function new_cert() {
    # Prompt for web server type
    echo "Which web server are you ordering a certificate for?"
    echo "1: Nginx"
    echo "2: Apache"
    echo "3: Other (No automatic restart)"
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
        3)
            server="other"
            echo "Server: Other (No automatic restart)"
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
    echo "3: HTTP Validation (Places files for validation in /var/www/html/)"
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
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac

    #reg var
    # Always source user credentials before using eab_kid and eab_hmac
    if [ -f /etc/tz-bot/scripts/user_credentials ]; then
        . /etc/tz-bot/scripts/user_credentials
    fi
    registration="--server https://emea.acme.atlas.globalsign.com/directory --email test123@test.com -a"

    #eab var
    eab="--eab --kid "${eab_kid:?}" --hmac "${eab_hmac:?}""

    #dns vars
    val_manual="--dns manual"
    val_azure="--dns azuredns"
    val_http="--http --http.webroot /var/www/html/"

    #domains
    if [[ "$domain" == "*."* ]]; then
        domain_non_wc="${domain#*.}"
        domain_var="--domains "${domain:?}" --domains "${domain_non_wc:?}" --key-type rsa2048 run"
        domain_renew_var="--domains "${domain:?}" --domains "${domain_non_wc:?}" --key-type rsa2048 renew"
    else
        domain_var="--domains "${domain:?}" --key-type rsa2048 run"
        domain_renew_var="--domains "${domain:?}" --key-type rsa2048 renew"
    fi
    renewal="no"

    read -n 1 -p "Do you want to specify where the certificate is saved? (y/n): " custom_path_choice
    echo
    if [[ "$custom_path_choice" == "y" ]]; then
        read -p "Please enter the full path to save the certificates (e.g., /etc/tz-bot/certs): " custom_path
        echo ""
        echo "Custom path selected: $custom_path"
        echo "path=$custom_path" > /etc/tz-bot/scripts/storage
        . /etc/tz-bot/scripts/storage
        path_var="--path $path"
        else
        echo "Using default path for certificate storage: /etc/tz-bot/certs/"
        echo "path=/etc/tz-bot/certs" > /etc/tz-bot/scripts/storage
        . /etc/tz-bot/scripts/storage
        path_var="--path $path"

    fi

    case $validation in
        manual)
            echo "LEGO command: sudo lego $registration $val_manual $path_var $eab $domain_var"
            if sudo lego $registration $val_manual $path_var $eab $domain_var; then
                cronjob
            else
                echo "There was a problem with the certificate request. Please check your credentials and domain validation."
                echo "You can also contact TRUSTZONE support at support@trustzone.com"
                exit
            fi
            if [[ $renewal = yes ]]; then
                echo "Updating renewal list at: /etc/tz-bot/scripts/renewal_list"
                echo "sudo lego $registration $val_manual $path_var $eab $domain_renew_var" >> /etc/tz-bot/scripts/renewal_list
                if [[ $server != "other" ]]; then
                    echo "sudo systemctl restart $server" >> /etc/tz-bot/scripts/renewal_list
                fi
                if grep -q nginx "/etc/tz-bot/scripts/renewal_list"; then
                    sudo sed -i.bak "/sudo systemctl restart nginx/d" /etc/tz-bot/scripts/renewal_list
                    echo "sudo systemctl restart nginx" >> /etc/tz-bot/scripts/renewal_list
                fi
                if grep -q apache2 "/etc/tz-bot/scripts/renewal_list"; then
                    sudo sed -i.bak "/sudo systemctl restart apache2/d" /etc/tz-bot/scripts/renewal_list
                    echo "sudo systemctl restart apache2" >> /etc/tz-bot/scripts/renewal_list
                fi
            fi
            if [[ $server != "other" ]]; then
                echo "Attempting to restart web server: $server"
                sudo systemctl restart $server
            fi
            echo "Your certificate is here: $path"
            start_prompt
            ;;
        azure)
            . /etc/tz-bot/scripts/azure_credentials
            echo "LEGO command: sudo -E lego $registration $val_azure $path_var $eab $domain_var"
            if sudo -E lego $registration $val_azure $path_var $eab $domain_var; then
                cronjob
            else
                echo "There was a problem with the certificate request. Please check your credentials and domain validation."
                echo "You can also contact TRUSTZONE support at support@trustzone.com"
                exit
            fi
            if [[ $renewal = yes ]]; then
                echo "Updating renewal list at: /etc/tz-bot/scripts/renewal_list"
                echo "sudo -E lego $registration $val_azure $path_var $eab $domain_renew_var" >> /etc/tz-bot/scripts/renewal_list
                if [[ $server != "other" ]]; then
                    echo "sudo systemctl restart $server" >> /etc/tz-bot/scripts/renewal_list
                fi
                if grep -q nginx "/etc/tz-bot/scripts/renewal_list"; then
                    sudo sed -i.bak "/sudo systemctl restart nginx/d" /etc/tz-bot/scripts/renewal_list
                    echo "sudo systemctl restart nginx" >> /etc/tz-bot/scripts/renewal_list
                fi
                if grep -q apache2 "/etc/tz-bot/scripts/renewal_list"; then
                    sudo sed -i.bak "/sudo systemctl restart apache2/d" /etc/tz-bot/scripts/renewal_list
                    echo "sudo systemctl restart apache2" >> /etc/tz-bot/scripts/renewal_list
                fi
            fi
            if [[ $server != "other" ]]; then
                echo "Attempting to restart web server: $server"
                sudo systemctl restart $server
            fi
            echo "Your certificate is here: $path"
            start_prompt
            ;;
        http)
            echo "LEGO command: sudo lego $registration $val_http $path_var $eab $domain_var"
            if sudo lego $registration $val_http $path_var $eab $domain_var; then
                cronjob
            else
                echo "There was a problem with the certificate request. Please check your credentials and domain validation."
                echo "You can also contact TRUSTZONE support at support@trustzone.com"
                exit
            fi
            if [[ $renewal = yes ]]; then
                echo "Updating renewal list at: /etc/tz-bot/scripts/renewal_list"
                echo "sudo lego $registration $val_http $path_var $eab $domain_renew_var" >> /etc/tz-bot/scripts/renewal_list
                if [[ $server != "other" ]]; then
                    echo "sudo systemctl restart $server" >> /etc/tz-bot/scripts/renewal_list
                fi
                if grep -q nginx "/etc/tz-bot/scripts/renewal_list"; then
                    sudo sed -i.bak "/sudo systemctl restart nginx/d" /etc/tz-bot/scripts/renewal_list
                    echo "sudo systemctl restart nginx" >> /etc/tz-bot/scripts/renewal_list
                fi
                if grep -q apache2 "/etc/tz-bot/scripts/renewal_list"; then
                    sudo sed -i.bak "/sudo systemctl restart apache2/d" /etc/tz-bot/scripts/renewal_list
                    echo "sudo systemctl restart apache2" >> /etc/tz-bot/scripts/renewal_list
                fi
            fi
            if [[ $server != "other" ]]; then
                echo "Attempting to restart web server: $server"
                sudo systemctl restart $server
            fi
            echo "Your certificate is here: $path"
            start_prompt
            ;;
        *)
            echo "internal error in "new_cert" function"
            exit 1
            ;;
    esac
}

# Start
echo "Welcome to TZ-Bot."
upkeep
start_prompt