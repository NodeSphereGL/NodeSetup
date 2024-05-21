#!/bin/bash

pcli_version="0.75.0"
pd_version="0.75.0"
cometbft_version="0.37.5"

read -r -p "Enter Node Name: " NODE_NAME

echo -e "\e[1m\e[32m1. Updating packages and dependencies--> \e[0m" && sleep 1

sudo apt update && apt upgrade -y
sudo apt install git curl wget -y && git config --global core.editor "vim" && sudo apt install make clang pkg-config libssl-dev build-essential -y 
sudo apt install tar wget clang pkg-config libssl-dev libleveldb-dev jq bsdmainutils git make ncdu htop lz4 screen bc fail2ban -y

IP_ADDRESS=$(curl eth0.me)

cd $HOME

curl -sSfL -O https://github.com/penumbra-zone/penumbra/releases/download/v${pcli_version}/pcli-x86_64-unknown-linux-gnu.tar.xz
unxz pcli-x86_64-unknown-linux-gnu.tar.xz
tar -xf pcli-x86_64-unknown-linux-gnu.tar
sudo mv pcli-x86_64-unknown-linux-gnu/pcli /usr/local/bin/
sudo chmod +x /usr/local/bin/pcli

# confirm the pcli binary is installed by running:
pcli --version

curl -sSfL -O https://github.com/penumbra-zone/penumbra/releases/download/v${pd_version}/pd-x86_64-unknown-linux-gnu.tar.xz
unxz pd-x86_64-unknown-linux-gnu.tar.xz
tar -xf pd-x86_64-unknown-linux-gnu.tar
sudo mv pd-x86_64-unknown-linux-gnu/pd /usr/local/bin/
sudo chmod +x /usr/local/bin/pd

# confirm the pd binary is installed by running:
pd --version

cd $HOME
mkdir cometbft_${cometbft_version}
cd cometbft_${cometbft_version}
wget https://github.com/cometbft/cometbft/releases/download/v${cometbft_version}/cometbft_${cometbft_version}_linux_amd64.tar.gz
sudo tar -xvzf cometbft_${cometbft_version}_linux_amd64.tar.gz
sudo mv cometbft /usr/local/bin/
sudo chmod +x /usr/local/bin/cometbft

# confirm the cometbft binary is installed by running:
cometbft version

pd testnet unsafe-reset-all
pd testnet join --external-address ${IP_ADDRESS}:26656 --moniker ${NODE_NAME}

sleep 3

sudo tee /etc/systemd/system/penumbra.service > /dev/null << EOF
[Unit]
Description=Penumbra pd
Wants=cometbft.service

[Service]
# If both 1) running pd as non-root; and 2) using auto-https logic, then
# uncomment the capability declarations below to permit binding to 443/TCP for HTTPS.
# CapabilityBoundingSet=CAP_NET_BIND_SERVICE
# AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStart=/usr/local/bin/pd start
# Consider overriding the home directory, e.g.
# ExecStart=/usr/local/bin/pd start --home /var/www/.penumbra/testnet_data/node0/pd
Restart=no
User=$USER
# Raise filehandle limit for tower-abci.
LimitNOFILE=65536
# Consider configuring logrotate if using debug logs
# Environment=RUST_LOG=info,pd=debug,penumbra=debug,jmt=debug

[Install]
WantedBy=default.target
EOF

sudo tee /etc/systemd/system/cometbft.service > /dev/null << EOF
[Unit]
Description=CometBFT for Penumbra

[Service]
ExecStart=/usr/local/bin/cometbft start --home $HOME/.penumbra/testnet_data/node0/cometbft
Restart=no
User=$USER

[Install]
WantedBy=default.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable penumbra.service && sudo systemctl enable cometbft.service
sudo systemctl restart penumbra cometbft

sudo journalctl -af -u penumbra -u cometbft

echo -e "\n=============== INSTALL COMPLETED ===================\n"
