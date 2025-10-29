Installation guide:
Run the following commands in your linux terminal:
1. sudo wget https://github.com/janniktaulan/lego-testing/releases/download/beta/tz-bot-installer
2. source tz-bot-installer

Uninstallation:
Can be done from TZ-bot main menu.

Manual uninstall:
Run the following commands to uninstall:
sudo rm -rf /etc/lego/
sudo rm -rf /usr/local/bin/lego
sudo rm -rf /usr/local/bin/tz-bot

This SHOULD uninstall everything TZ-bot created/installed. Certs created on a custom path will remain. Any certs using default path will be removed.
