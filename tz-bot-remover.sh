# UNDER CONSTRUCTION
echo "Welcome to the TZ-Bot and Lego uninstaller."
echo "This script will uninstall TZ-Bot and Lego from your system."
echo "It will also remove all certificates from /etc/tz-bot/certs/ and all scripts from /etc/tz-bot/scripts/."
read -n 1 -p "Are you sure you want to proceed? (y/n): " confirm_uninstall
echo
if [[ "$confirm_uninstall" == "y" ]]; then
    echo "Uninstalling TZ-Bot and Lego..."
    sudo rm -rf /etc/tz-bot/
    sudo rm -rf /usr/local/bin/tz-bot
    sudo rm -rf /usr/local/bin/lego
    sudo crontab -l | grep -v '/etc/tz-bot/scripts/renewal.sh' | sudo crontab -
    if command -v lego >/dev/null 2>&1; then
        echo "Uninstallation failed. Please remove manually."
        exit
    else
        echo "TZ-Bot and Lego have been uninstalled successfully."
        exit
    fi
else
    echo "Uninstallation cancelled."
    exit
fi