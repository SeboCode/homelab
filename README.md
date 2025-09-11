# Homelab

This is the setup script to configure my private homelab server. It builds on Ansible to configure the homelab server
and provision the services using Podman. The Ansible playbook is built such that it configures an Alpine Linux machine.
For local development, the Ansible playbook is run on an Alpine Linux VM, provisioned using Vagrant.

# Installation guide

This is the installation guide describes how to set up ACME Let's Encrypt certificate configuration, how to prepare the
local and remote DNS entries and how to install the os and perform manual setup steps.

## OS installation and manual Ansible preparation

1. Install Alpine Linux on the server.
   1. Download the latest basic Alpine Linux iso from the official [website](https://alpinelinux.org/downloads/) and verify its integrity and authenticity.
   2. Setup Alpine Linux according to the documentation in "System Disk Mode (sys)".
      1. Create a none-root user during this step (or later on). This user should be used by Ansible to configure the server. It is advised to create this user, to avoid running Ansible with the root user.
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

## (Optional) Setup Tailscale

To access the services from anywhere in the world, without the need to expose the server into the internet, a VPN
solution, such as Tailscale, can be used.

1.  Install Tailscale using `apk add tailscale`.
2.  Add Tailscale to autostart list `doas rc-update add tailscale`.
3.  Start Tailscale service `doas rc-service tailscale start`. See the status using `rc-service tailscale status`.
4.  Connect to Tailnet `doas tailscale up`.
5.  Disable key expiry in the Tailscale admin panel for the server, to avoid need for reauthentication of the node
    after token is expired. If this step is not performed, the service might no longer be accessible at some point,
    until it is reauthenticated using `doas tailscale up`.

## ACME Let's Encrypt setup

The current setup uses Traefik's built in ACME client configured for Infomaniak's NameServer to perform a DNS challenge
to get a valid Let's Encrypt certificate. To perform this challenge, Traefik, the reverse proxy used in this setup,
needs an appropriate access token with write privileges to the NameServer. If a different NameServer is supposed to be used,
the environment variable passed to the Traefik-Container has to be modified. Furthermore, the
`certificatesResolvers.[resolver-name].acme.dnsChallenge.provider` value has to be updated, to contain the
specific value required by the used NameServer. In addition (not necessary, but results in a cleaner
configuration), name of the `certresolver` in the `service.yaml.j2` and `traefik.yaml.j2` files have to be
updated.

## Prepare the DNS entries for both local and remote access

1. To improve network speed and avoid unnecessary routing, it is advised to setup a DNS entry in the local gateway. This
   can be done in the appropriate admin panel of the home router.
2. To setup remote access over Tailscale, additional DNS entries have to be manually added to the NameServer of the
   domain to be used. An A and AAAA record should be added with the IPv4 and IPv6 of the server node in the Tailnet,
   respectively.

## Automatic setup using Ansible and manual configurations

1. Check that all secrets and variable values for all services are set correctly in the `ansible/vars/prod.yaml` file.
   Take inspiration from the `ansible/vars/dev.yaml` file to get a list of all necessary variables that have to be set.
   In addition to the ones found in the development variable file, the following secret variables have to be set:
   | Variablename | Description |
   | :----------- | :---------- |
   | infomaniak_dns_api_token | Token used to edit the DNS entries of the NameServer for the ACME challenge performed by Traefik. |
2. Check that the `ansible/inventory/prod.ini` file is configured correctly.
3. Execute the bash script `prod.sh`.

# Services

The following services are available on the machine:
| Service | Reserved Portrange | Exposed Service | Port of exposed Service | Directly accessible | Url Accessibility |
| :------ | -----------------: | :-------------- | ----------------------: | :-----------------: | :---------------- |
| Traefik | 10000 - 19999 | | | | |
| | | Traefik API/Dashboard | 8080 | :x: | `traefik(.dev).homelab.*` |
| | | Traefik Web | 10080 | :heavy_check_mark: | |
| | | Traefik Websecure | 10443 | :heavy_check_mark: | |
| Immich | 20000 - 20099 | | | | |
| | | Immich Server | 20000 | :x: | `immich(.dev).homelab.*` |
| Filebrowser | 20100 - 20199 | | | | |
| | | Filebrowser Server | 20100 | :x: | `filebrowser(.dev).homelab.*` |
| NextCloud | 20100 - 20199 | | | | |
| | | NextCloud Server | 20100 | :x: | `nextcloud(.dev).homelab.*` |
| PhotoPrism | 20200 - 20299 | | | | |
| | | PhotoPrism Server | 20200 | :x: | `photoprism(.dev).homelab.*` |
| Gitea | 20300 - 20399 | | | | |
| | | Gitea Server | 20300 | :x: | `gitea(.dev).homelab.*` |
| | | Gitea Server SSH | 20322 | :x: | This is currently not working due to firewall and traefik configurations. Repositories can only be cloned via https. |

## Introduce new service

To introduce a new service, follow these steps:

1. Create a new role in the `services` directory with the name of the service.
   1. Implement new role in accordance with the other roles.
   2. Every service has its own user to increase security and have a clearer separation of the independent services.
2. Add all relevant configuration for the new service to the `ansible/group_vars/all.yaml` file.
   1. Secrets and other variables that are environment dependent have to be added to the `ansible/vars/<environment>.yaml` file.
3. Add the service to the `active_services` variable in `ansible/group_vars/all.yaml`.
4. Add the port to the vagrant configuration to be forwarded to the host machine for accessing the service locally
   without the need to go through Traefik (nice for debugging).
5. Update router DNS entries to easily access the service in the home network.

# Post installation

1. Setup Immich admin account and user accounts using the web overview.
2. Setup Gitea admin account and user accounts using the web overview. In addition, set configuration flags during first
   setup as follows:
   1. Check correct port of server domain.
   2. Disable `Enable Local Mode`.
   3. Disable `Enable OpenID Sign-In`.
   4. Enable `Disable Self-Registration`.
   5. Enable `Require Sign-In to View Pages`.
   6. Enable `Allow Creation of Organizations by Default`.
   7. Enable `Enable Time Tracking by Default`.
   8. Set password hash algorithm to `argon2`, if memory is not a limiting factor. Otherwise, choose based on your
      system configuration.
   9. Set correct administrator credentials.
