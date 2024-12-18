#!/bin/bash

AUT_VERSION="1.0.2-alpha"
ORACLE_VERSION="0.2.3"

NETWORK_NAME="piccadilly"
KEYSTORE_DIR="$HOME/piccadilly-keystore"

install_expect() {
    sudo apt install -y expect
}

read -r -p "Enter new wallet password: " WALLET_PASSWORD

# Check if expect is installed, if not, install it
if ! command -v expect &>/dev/null; then
    echo "Expect is not installed. Installing..."
    install_expect
fi

echo -e "=============== Install Oracle ==================="

cd $HOME
sudo wget https://github.com/autonity/autonity-oracle/releases/download/v$ORACLE_VERSION/oracle-server.tgz
sudo tar -xzf oracle-server.tgz
sudo rm -rf oracle-server.tgz

cd oracle-server && sudo cp -r autoracle /usr/local/bin/autoracle && cd $HOME
autoracle version

sudo tee /etc/systemd/system/autoracled.service > /dev/null << EOF
[Unit]
Description=Autoracled Node
After=network-online.target
StartLimitIntervalSec=0
[Service]
User=$USER
Restart=always
RestartSec=3
LimitNOFILE=65535
ExecStart=autoracle \
    -key.file="${KEYSTORE_DIR}/wallet.key" \
    -key.password="${WALLET_PASSWORD}" \
    -ws="ws://127.0.0.1:8546" \
    -plugin.conf="${HOME}/oracle-server/plugins-conf.yml" \
    -plugin.dir="${HOME}/oracle-server/plugins/" \
  
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload 
sudo systemctl enable autoracled

echo -e "=============== SETUP FINISHED ==================="
echo -e "Check logs:            ${CYAN}sudo journalctl -u $BINARY_NAME -f -o cat ${NC}"
