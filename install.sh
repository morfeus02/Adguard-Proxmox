#!/bin/bash

# Prompt for user input
read -p 'Container ID Number: ' number
read -p 'Container Name: ' name
read -p 'CPU Cores: ' cpu
read -p 'Static IP Address Of container(/CIDR) eg 192.168.1.20/24: ' ip
read -p 'Default Gateway eg 192.168.1.1: ' gw
brctl show
read -p 'From the above list, please specify bridge name for the container network (e.g., vmbr0): ' bridge

# Update Proxmox VE templates
pveam update

# Find the latest Alpine template available online
latest_alpine_template=$(pveam available --section system | grep 'alpine-.' | sort -V | tail -n 1 | awk '{print $2}')

if [ -z "$latest_alpine_template" ]; then
    echo "No new Alpine template found online. Checking for local templates..."
    latest_alpine_template=$(pveam list local | grep 'alpine-.' | sort -V | tail -n 1 | awk '{print $1}')

    if [ -z "$latest_alpine_template" ]; then
        echo "No Alpine template found locally either. Exiting."
        exit 1
    fi
else
    # Download the latest Alpine template
    pveam download local $latest_alpine_template
fi

echo "Using Alpine template: $latest_alpine_template"

# Check if the container ID is already in use
if pct list | grep -qw "$number"; then
    echo "Container ID $number is already in use. Please choose a different ID."
    exit 1
fi

# Create and start the container on local-lvm storage
pct create $number --storage local-lvm --ostype alpine --hostname "$name" --net0 name=eth0,ip="$ip",gw="$gw",bridge="$bridge" --memory 512 --cores $cpu --unprivileged 1 --cmode shell --onboot 1 local:vztmpl/$latest_alpine_template
pct start $number

# Basic container setup
pct exec $number -- apk update
pct exec $number -- apk upgrade
pct exec $number -- apk add curl sudo bash openrc

# Install AdGuardHome using the official AdGuard script
pct exec $number -- bash -c 'curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v'


# Reboot the container
pct exec $number -- reboot

# Final message
echo "You can now browse to http://$ip:3000 to resume the rest of the configuration."
