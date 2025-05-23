#!/bin/bash

set -e
set -u
set -o pipefail

# Prompt for user input
read -p 'Container ID Number: ' number
if ! [[ "$number" =~ ^[0-9]+$ ]]; then
    echo "Error: Container ID must be a number." >&2
    exit 1
fi
read -p 'Container Name: ' name
read -p 'CPU Cores: ' cpu
if ! [[ "$cpu" =~ ^[0-9]+$ && "$cpu" -gt 0 ]]; then
    echo "Error: CPU Cores must be a positive integer." >&2
    exit 1
fi
read -p 'Static IP Address Of container(/CIDR) eg 192.168.1.20/24: ' ip
if ! [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    echo "Error: Invalid Static IP Address format. Expected format: xxx.xxx.xxx.xxx/xx" >&2
    exit 1
fi
read -p 'Default Gateway eg 192.168.1.1: ' gw
if ! [[ "$gw" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Error: Invalid Default Gateway format. Expected format: xxx.xxx.xxx.xxx" >&2
    exit 1
fi

# Check for brctl command
if ! command -v brctl >/dev/null; then
    echo "Error: brctl command not found. Please install bridge-utils on your Proxmox host (e.g., apt install bridge-utils) and try again." >&2
    exit 1
fi

bridge_output=$(brctl show)
echo "$bridge_output"
read -p 'From the above list, please specify bridge name for the container network (e.g., vmbr0): ' bridge

if ! echo "$bridge_output" | awk 'NR>1 {print $1}' | grep -qw "$bridge"; then
    echo "Error: Bridge '$bridge' not found in the output of brctl show." >&2
    exit 1
fi

# Update Proxmox VE templates
echo "Updating Proxmox VE template list..."
pveam update
echo "Template list updated."

# Find the latest Alpine template available online
# This logic attempts to find the newest version of the Alpine Linux template from the Proxmox VE repository.
# It filters for 'alpine-', sorts them by version, and takes the last one.
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
    echo "Downloading Alpine template: $latest_alpine_template..."
    pveam download local $latest_alpine_template
    if [ $? -eq 0 ]; then
        echo "Template $latest_alpine_template downloaded successfully."
    else
        echo "Failed to download template $latest_alpine_template. Please check pveam output for errors." >&2
        # set -e will handle exit
    fi
fi

echo "Using Alpine template: $latest_alpine_template"

# Check if the container ID is already in use
if pct list | grep -qw "$number"; then
    echo "Container ID $number is already in use. Please choose a different ID."
    exit 1
fi

# Create and start the container on local-lvm storage
echo "Creating container $name (ID: $number)..."
pct create $number --storage local-lvm --ostype alpine --hostname "$name" --net0 name=eth0,ip="$ip",gw="$gw",bridge="$bridge" --memory 512 --cores $cpu --unprivileged 1 --cmode shell --onboot 1 local:vztmpl/$latest_alpine_template
if [ $? -eq 0 ]; then
    echo "Container $name (ID: $number) created successfully."
else
    echo "Failed to create container $name (ID: $number). Please check pct output for errors." >&2
    # set -e will handle exit
fi

pct start $number
echo "Container $name (ID: $number) started."

# Basic container setup
echo "Performing basic container setup (updates, upgrades, essential packages)..."
pct exec $number -- apk update
pct exec $number -- apk upgrade
pct exec $number -- apk add curl sudo bash openrc
echo "Basic container setup complete."

# Install AdGuardHome using the official AdGuard script
# The following command downloads and executes the official AdGuard Home installation script.
# Source: https://github.com/AdguardTeam/AdGuardHome/blob/master/scripts/install.sh
echo "Installing AdGuard Home..."
pct exec $number -- bash -c 'curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v'
if [ $? -eq 0 ]; then
    echo "AdGuard Home installation script executed."
else
    echo "AdGuard Home installation script failed. Please check the output above for errors." >&2
    # set -e and set -o pipefail will handle exit if curl or sh fail
fi


# Reboot the container
pct exec $number -- reboot

# Covert CIRD to plain IP
plain_ip="${ip%%/*}"

# Final message
echo "You can now browse to http://$plain_ip:3000 to resume the rest of the configuration."
echo "Installation of AdGuard Home container $name (ID: $number) completed successfully!"
