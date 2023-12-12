# Proxmox Alpine LXC with AdGuard Home

This repository contains a script for setting up a lightweight and efficient AdGuard Home instance inside an LXC container on Proxmox VE, using the latest Alpine Linux template available. AdGuard Home is a network-wide software for blocking ads & tracking.

## Features

- **Lightweight Setup**: Uses Alpine Linux, known for its minimalism and efficiency.
- **Automated Container Creation**: The script automates the process of creating an LXC container in Proxmox.
- **Dynamic Template Retrieval**: Automatically finds and uses the latest Alpine Linux LXC template available on Proxmox.
- **AdGuard Home Installation**: Installs and configures AdGuard Home for immediate use.

## Prerequisites

- A Proxmox VE installation (version 6.0 or later recommended).
- SSH access to your Proxmox server.
- User privileges sufficient to create LXC containers and download templates.

## Installation

To install, run the following command in your Proxmox server's terminal:

curl -LJO https://raw.githubusercontent.com/morfeus02/Adguardd-Proxomx/MainBranch/install.sh && chmod +x install.sh && ./install.sh && rm install.sh

## Usage

After the container is set up and AdGuard Home is installed, you can access the AdGuard Home web interface by navigating to:
http://[Container-IP]:3000


Complete the initial setup through the web interface to start using AdGuard Home.

## Customization

You can modify the script to customize various aspects like the default memory allocation, storage location, and more.

## Contributing

Contributions to this project are welcome. Please fork the repository and submit a pull request with your changes.

## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgments

- [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) for the excellent ad-blocking software.
- The Proxmox community for the great virtualization platform.
- Project based on haris2887/Adguardd-Proxomx but completely rewritten code
