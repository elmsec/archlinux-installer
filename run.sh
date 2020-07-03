#!/bin/bash

. ./installer/files/install.config

PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

# make yourself a well-known friend
ssh -tt -p "$PORT" "$HOST" "mkdir -m 700 ~/.ssh; echo $PUBLIC_KEY > ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys"

# copy files
scp -rp -P "$PORT" ./installer/ "$HOST:/root"

# run the install script remotely
ssh -tt -p "$PORT" "$HOST" "./installer/install.sh"
