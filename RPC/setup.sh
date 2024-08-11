#!/bin/bash

API_PORT="12317"
RPC_PORT="12657"

# Cloudflare configuration
CLOUDFLARE_ZONE_ID="<zone id>"
CLOUDFLARE_API_TOKEN="<token key>"

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
    sed -i "/^\[api\]/,/^\[/ { s/^enable *=.*$/enable = true/; s/^swagger *=.*$/swagger = true/; s/^address *=.*$/address = \"tcp:\/\/127.0.0.1:${API_PORT}\"/ }" "$project_home_dir/config/app.toml"
}

# Function to change settings in config.toml
change_config_toml() {
    local project_home_dir=$1

    # Modify config.toml
    sed -i "/^\[rpc\]/,/^\[/ { s/^laddr *=.*$/laddr = \"tcp:\/\/127.0.0.1:${RPC_PORT}\"/; s/^cors_allowed_origins *=.*$/cors_allowed_origins = '\"[*]\"'/ }" "$project_home_dir/config/config.toml"
    sed -i '/^\[tx_index\]/,/^\[/ { s/^indexer *=.*$/indexer = "null"/ }' "$project_home_dir/config/config.toml"
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

        proxy_pass http://127.0.0.1:${API_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}

server {
    listen 80;
    server_name ${project_name}-testnet-rpc.${domain};

    location / {
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Max-Age 3600;
        add_header Access-Control-Expose-Headers Content-Length;

        proxy_pass http://127.0.0.1:${RPC_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
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

# Function to create or update A records on Cloudflare
create_or_update_cloudflare_record() {
    local project_name=$1
    local domain=$2
    local public_ip=$3

    local subdomain_api="${project_name}-testnet-api.${domain}"
    local subdomain_rpc="${project_name}-testnet-rpc.${domain}"

    # Check if API A record exists
    api_record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=A&name=${subdomain_api}" \
                        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
                        -H "Content-Type: application/json" | jq -r '.result[0].id')

    if [ "$api_record_id" != "null" ]; then
        # Update API A record
        curl -X PUT "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${api_record_id}" \
             -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
             -H "Content-Type: application/json" \
             --data '{"type":"A","name":"'${subdomain_api}'","content":"'${public_ip}'","ttl":120,"proxied":true}'
    else
        # Create API A record
        curl -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
             -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
             -H "Content-Type: application/json" \
             --data '{"type":"A","name":"'${subdomain_api}'","content":"'${public_ip}'","ttl":120,"proxied":true}'
    fi

    # Check if RPC A record exists
    rpc_record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=A&name=${subdomain_rpc}" \
                        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
                        -H "Content-Type: application/json" | jq -r '.result[0].id')

    if [ "$rpc_record_id" != "null" ]; then
        # Update RPC A record
        curl -X PUT "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${rpc_record_id}" \
             -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
             -H "Content-Type: application/json" \
             --data '{"type":"A","name":"'${subdomain_rpc}'","content":"'${public_ip}'","ttl":120,"proxied":true}'
    else
        # Create RPC A record
        curl -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
             -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
             -H "Content-Type: application/json" \
             --data '{"type":"A","name":"'${subdomain_rpc}'","content":"'${public_ip}'","ttl":120,"proxied":true}'
    fi
}

# Main function
main() {
    install_nginx
    install_jq

    # Input project details
    read -p "Please enter project name: " project_name
    read -p "Please enter project home dir (e.g., /root/.junction): " project_home_dir
    read -p "Please enter your domain (e.g., example.com): " domain

    # Get public IP
    public_ip=$(curl -s eth0.me)

    # Change settings in app.toml
    change_app_toml "$project_name" "$project_home_dir"

    # Change settings in config.toml
    change_config_toml "$project_home_dir"

    # Create or update Cloudflare A records
    create_or_update_cloudflare_record "$project_name" "$domain" "$public_ip"

    # Add Nginx config
    add_nginx_config "$project_name" "$domain"

    # Restart Nginx
    restart_nginx

    echo -e "\n=========================================\n"

    echo -e "\nSetup completed. Restart node and enjoy !\n"
    
    # Print RPC and API URLs
    print_urls "$project_name" "$domain"
}

# Run the main function
main
