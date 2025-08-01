# immich-setup

# Setup

This is the setup guide to install and configure the homelab server.

## OS installation and manual setup

- Install AlpineLinux to the drive.
  - Download latest basic AlpineLinux iso from the official [website](https://alpinelinux.org/downloads/) and verify its integrity and authenticity.
  - Setup AlpineLinux according to documentation in "System Disk Mode (sys)".
    - Create a none-root user here or later on, with which the Ansible script is run later on.
    - Choose "OpenSSH" when prompted for the ssh server.
    - Choose "sys" when prompted for the Disk Mode.
  - Reboot and login as root.
- Prepare data
  - Create data usb drive with the documents found in the "manual-setup-data" folder.
  - Create new ssh key file for each device that needs to connect to the homelab machine via ssh using `ssh-keygen`.
  - Add ssh configuration on the devices to more easily connect to the homelab machine.
  - Copy public key of the newly created ssh keys to the data usb drive
  - Install mount on the AlpineLinux homelab node `apk add mount`.
  - Mount the data usb drive using `mount /dev/sdXY /media/usb`.
- Setup SSH daemon
  - Copy sshd configuration files to the sshd config folder using `cp /media/usb/sshd_config/*.conf /etc/ssh/sshd_config.d/`.
  - Restart sshd service `rc-service sshd restart`.
- Setup Ansible user
  - Create none-root user, with which the Ansible script will be run later on using `setup-user`.
  - Navigate to new users home directory.
  - Create an .ssh folder in the home directory of this new user and change its owner and mode `mkdir .ssh && chown <username> .ssh && chmod 755 .ssh`.
  - Navigate to this new .ssh folder.
  - Create an authorized_keys file in the .ssh directory its owner and mode `touch authorized_keys && chown <username> authorized_keys && chmod 600 authorized_keys`.
  - Populate authorized_keys file with ssh public keys found on the mounted usb drive `cat /media/usb/<pulic-key.pub> >> authorized_keys`.
- Elevate Ansible user privileges
  - Install doas (AlpineLinux sudo equivalent) `apk add doas`.
  - Give new user superuser privileges `echo "permit persist keepenv <username>" >> /etc/doas.conf`.
- Prepare system to be Ansible target
  - Install Python on the system `apk add python3`.

## Run Ansible script against system

TODO
