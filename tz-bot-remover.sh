# UNDER CONSTRUCTION
echo "This will uninstall TZ-Bot and Lego from your system."
echo "It will also remove all certificates from /etc/lego/certs/ and all scripts from /etc/lego/scripts/."
read -n 1 -p "Are you sure you want to proceed? (y/n): " confirm_uninstall
echo
if [[ "$confirm_uninstall" == "y" ]]; then
    echo "Uninstalling TZ-Bot and Lego..."
    sudo rm -rf /etc/lego/
    sudo rm -rf /usr/local/bin/lego
    sudo rm -rf /usr/local/bin/tz-bot
    if command -v lego >/dev/null 2>&1; then
        echo "Uninstallation failed. Please remove manually."
        exit 1
    else
        echo "TZ-Bot and Lego have been uninstalled successfully."
        exit 0
    fi
fi