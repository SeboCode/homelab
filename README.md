# Homelab

This is the setup script to configure my private homelab server. It builds on Ansible to configure the homelab server
and provision the services using Podman. The Ansible playbook is built such that it configures an Alpine Linux machine.
For local development, the Ansible playbook is run on an Alpine Linux VM, provisioned using Vagrant.

# Installation guide

This is the installation guide to install the os and configure the homelab server.

## OS installation and manual setup

1. Install Alpine Linux to the drive.
   1. Download latest basic Alpine Linux iso from the official [website](https://alpinelinux.org/downloads/) and verify its integrity and authenticity.
   2. Setup Alpine Linux according to documentation in "System Disk Mode (sys)".
      1. Create a none-root user here or later on, with which the Ansible script is run later on.
      2. Choose "OpenSSH" when prompted for the ssh server.
      3. Choose "sys" when prompted for the Disk Mode.
   3. Reboot and login as root.
2. Prepare data
   1. Create data usb drive with the documents found in the "manual-setup-data" folder.
   2. Create new ssh key file for each device that needs to connect to the homelab machine via ssh using `ssh-keygen`.
   3. Add ssh configuration on the devices to more easily connect to the homelab machine.
   4. Copy public key of the newly created ssh keys to the data usb drive
   5. Install mount on the Alpine Linux homelab node `apk add mount`.
   6. Mount the data usb drive using `mount /dev/sdXY /media/usb`.
3. Setup SSH daemon
   1. Copy sshd configuration files to the sshd config folder using `cp /media/usb/sshd_config/*.conf /etc/ssh/sshd_config.d/`.
   2. Restart sshd service `rc-service sshd restart`.
4. Setup Ansible user
   1. Create none-root user, with which the Ansible script will be run later on using `setup-user`.
   2. Navigate to new users home directory.
   3. Create an .ssh folder in the home directory of this new user and change its owner and mode `mkdir .ssh && chown <username> .ssh && chmod 755 .ssh`.
   4. Navigate to this new .ssh folder.
   5. Create an authorized_keys file in the .ssh directory its owner and mode `touch authorized_keys && chown <username> authorized_keys && chmod 600 authorized_keys`.
   6. Populate authorized_keys file with ssh public keys found on the mounted usb drive `cat /media/usb/<pulic-key.pub> >> authorized_keys`.
5. Elevate Ansible user privileges
   1. Install doas (Alpine Linux sudo equivalent) `apk add doas`.
   2. Give new user superuser privileges `echo "permit persist keepenv <username>" >> /etc/doas.conf`.
6. Prepare system to be Ansible target
   1. Install Python on the system `apk add python3`.

## Run Ansible script against system

1. Check that all secrets and variable values for all services are set correctly in the `vars/prod.yaml` file.
2. Check that the `inventory/prod.ini` file is configured correctly.
3. Execute the bash script `prod.sh`.

# Services

The following services are available on the machine:
| Service | Reserved Portrange | Exposed Service | Port of exposed Service |
| :------ | -----------------: | :-------------- | ----------------------: |
| Immich | 20000 - 20099 | | |
| | | Immich Server | 20000 |
| NextCloud | 20100 - 20199 | | |
| | | NextCloud Server | 20100 |
| PhotoPrism | 20200 - 20299 | | |
| | | PhotoPrism Server | 20200 |

## Introduce new service

To introduce a new service, follow these steps:

1. Create a new role in the `services` directory with the name of the service.
   1. Implement new role in accordance with the other roles.
   2. Every service has its own user to increase security and have a clearer separation of the independent services.
2. Add all relevant configuration for the new service to the `group_vars/all.yaml` file.
   1. Secrets and other variables that are environment dependent have to be added to the `vars/<environment>.yaml` file.
3. Add the new service to the firewall by updating the `firewall` role.
4. Add the new service to the `deployment.yaml` playbook.
5. Add the port to the vagrant configuration to be forwarded to the host machine for accessing the service locally.
