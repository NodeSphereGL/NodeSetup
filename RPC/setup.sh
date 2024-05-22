#!/bin/bash

# Function to install nginx if not already installed
install_nginx() {
    if ! command -v nginx &> /dev/null; then
        sudo apt update
        sudo apt install -y nginx
    fi
}

# Function to install jq if not already installed
install_jq() {
    if ! command -v jq &> /dev/null; then
        sudo apt update
        sudo apt install -y jq
    fi
}

# Function to change settings in app.toml
change_app_toml() {
    local project_name=$1
    local project_home_dir=$2

    # Modify app.toml
    sed -i '/^\[api\]/,/^\[/ { s/^enable *=.*$/enable = true/; s/^swagger *=.*$/swagger = true/; s/^address *=.*$/address = "tcp:\/\/127.0.0.1:1317"/ }' "$project_home_dir/config/app.toml"
}

# Function to change settings in config.toml
change_config_toml() {
    local project_home_dir=$1

    # Modify config.toml
    sed -i '/^\[rpc\]/,/^\[/ { s/^laddr *=.*$/laddr = "tcp:\/\/127.0.0.1:26657"/; s/^cors_allowed_origins *=.*$/cors_allowed_origins = '"'"'["*"]'"'"'/ }' "$project_home_dir/config/config.toml"
    sed -i '/^\[tx_index\]/,/^\[/ { s/^indexer *=.*$/indexer = "kv"/ }' "$project_home_dir/config/config.toml"
}

# Function to add nginx config
add_nginx_config() {
    local project_name=$1
    local domain=$2

    # Nginx config file path
    nginx_config="/etc/nginx/sites-enabled/$project_name.conf"

    # Nginx config content
    nginx_content=$(cat <<EOF
server {
    listen 80;
    server_name ${project_name}-testnet-api.${domain};

    location / {
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Max-Age 3600;
        add_header Access-Control-Expose-Headers Content-Length;

        proxy_pass http://127.0.0.1:1317;

    }
}

server {
    listen 80;
    server_name ${project_name}-testnet-rpc.${domain};

    location / {
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Max-Age 3600;
        add_header Access-Control-Expose-Headers Content-Length;

        proxy_pass http://127.0.0.1:26657;

    }
}
EOF
)

    # Write Nginx config content to the config file
    echo "$nginx_content" | sudo tee "$nginx_config" > /dev/null
}

# Restart Nginx
restart_nginx() {
    sudo systemctl restart nginx
}

# Function to print RPC and API URLs
print_urls() {
    local project_name=$1
    local domain=$2

    echo -e "Your RPC URL: https://${project_name}-testnet-rpc.${domain}"
    echo -e "Your API URL: https://${project_name}-testnet-api.${domain}"
}

# Main function
main() {
    install_nginx
    install_jq

    # Input project details
    read -p "Please enter project name: " project_name
    read -p "Please enter project home dir (e.g., /root/.junction): " project_home_dir
    read -p "Please enter your domain (e.g., example.com): " domain

    # Change settings in app.toml
    change_app_toml "$project_name" "$project_home_dir"

    # Change settings in config.toml
    change_config_toml "$project_home_dir"

    # Add Nginx config
    add_nginx_config "$project_name" "$domain"

    # Restart Nginx
    restart_nginx

    echo -e "Setup completed. Restart node and enjoy !"
    
    # Print RPC and API URLs
    print_urls "$project_name" "$domain"
}

# Run the main function
main
