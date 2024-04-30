#!/bin/bash

# Define the maximum amount to send
max_amount=100

# Define the recipient address
# 247
# recipient_address="penumbra1jwyf402wzm2smqa0hrgp42pkrxtcdw6f39z96jt2yrlwevace4axfecajzxvdpmznlzwp8auwvtz7rqea836pr700gz7at5tx32zqx5va6pg7xqq5y6gttp2jcd8zdfd3q2fzf"

# nodesphere
recipient_address="penumbra1ydgq3zy2p5f93yu9rpr7msm2auz8pdqugzed6cdhds8ka7y4uzw8vvd27dgm3utee0tmu92xsw90rrh9jzvj6w2txcsc0tmalrsljsqsgvedqy8cq7p2mflut8yar6rjsgzck0"

# Run the command to get the balance and capture the output
output=$(pcli view balance)

# Loop through wallet numbers from 0 to 30
for wallet_id in {1..30}
do
    echo "Processing wallet #$wallet_id:"
    # Extract lines for the current wallet that include 'penumbra'
    line=$(echo "$output" | grep "# $wallet_id " | grep -P '\d+(\.\d+)?penumbra')

    echo "processing line: ${line}"

    # Use awk to extract the numeric amount directly before 'penumbra'
    if [[ ! -z "$line" ]]; then
        amount=$(echo "$line" | awk '{print $3}' | sed 's/penumbra//')

        echo "Extracted amount: '$amount'"

        # Validate the amount and proceed if it's greater than 0
        if [[ ! -z "$amount" ]] && (( $(echo "$amount > 0" | bc -l) )); then
            amount_to_send=$(echo -e "$amount\n$max_amount" | sort -n | head -n1)
            echo "Sending ${amount_to_send}penumbra from wallet #${wallet_id}"
            pcli tx send ${amount_to_send}penumbra --to $recipient_address --source $wallet_id
        else
            echo "No valid amount found for wallet #${wallet_id}, or amount is 0"
        fi
    else
        echo "No penumbra entry found for wallet #${wallet_id}"
    fi
done
