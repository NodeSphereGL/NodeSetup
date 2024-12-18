#!/bin/bash

# Function to get the address from the command output
get_address() {
    address=$(pcli view address $1 | grep -oP 'penumbra[0-9a-z]+')
    echo $address
}

# Main loop to run the command and write addresses to file
for i in {1..30}; do
    address=$(get_address $i)
    echo $address >> penum.txt
done
