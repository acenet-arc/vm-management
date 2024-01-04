#  Overview
Ansible playbooks to management VMs.

These playbooks have been developed only testing Ubuntu based VMs. Modifications are likely required for VMs using other operating systems.

As a first step, the playbook [playbooks/update_apt_packages.yml](./playbooks/update_apt_packages.yml) can be used to update apt-based VMs and reboot if required.

# Setup
## Requirements
On the machine that you will be running these plays, you must:
- have Ansible installed (see: [Installing Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) )
- install Ansible requirements.<br/>
This is needed primarily for the [setup-dockerhost.yml](./playbooks/setup-dockerhost.yml) playbook, most other playbooks have no requirements. For example, it is not requred for [playbooks/update_apt_packages.yml](./playbooks/update_apt_packages.yml).

  `$ ansible-galaxy install -r requirements.yml`

Also a good idea:
- if making changes to install ansible-lint to check changes (see: [Installing Ansible Lint](https://ansible.readthedocs.io/projects/lint/installing/) )

## Managed VM setup
To manage a VM with ansible it requires ssh access, usually as a user with `sudo` permissions. There is a cloud-init script, [ansible-client-cloud-init.yml](./ansible-client-cloud-init.yml) which can be used when creating a new VM to create a user and inject a public key.

To use a different key, change the `ssh_authorized_keys` to list a different public key or set of public keys. A matching private key should be added during the "Setup key" step under the [Usage](#usage) section.

If you change the `name` under the `users` section of the "ansible-client-cloud-init.yml" file, the `ansible_user` listed under `hosts` in the [inventory.yml](./inventory.yml) should match.

If the `authorized_keys` file on the managed VMs need to be changed, the [./files/authorized_keys](./files/authorized_keys) can be updated to what is desired on the remote VMs and the [set-authorized-keys-file.yml](./playbooks/set-authorized-keys-file.yml) playbook can be used to update that file on managed VMs, provided you currently have ssh access on the managed VMs.  
**CAUTION**: running the [set-authorized-keys-file.yml](./playbooks/set-authorized-keys-file.yml) playbook with a miss-configured [./files/authorized_keys](./files/authorized_keys) can cause you to loose access to your VMs.

## Object store setup

Backups are saved to a container in Object store on Arbutus. To set it up:

  1. Create storage access ID and secrete key: (see: [Establishing access to your Arbutus Object Store](https://docs.alliancecan.ca/wiki/Arbutus_object_storage#Establishing_access_to_your_Arbutus_Object_Store) )
  2. Create a new container to store restic backups using the "Containers" pane under "Object Store" left hand menu item.
  3. Initialize a new restic repository using the access credentials created in 1 and the Arbutus HTTPS endpoint url (something like `https://object-arbutus.cloud.computecanada.ca:443/CONTAINER_NAME` ) using the "s3" protocol so that `s3:` should be appended to that URL to be used with the `RESTIC_BACKUP_URL` mentioned below under the "Managing bakups" section. The `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are the ID and Key created in step 1 above. The commands to do this will look like:
  
  `$ export RESTIC_BACKUP_URL="s3:https://object-arbutus.cloud.computecanada.ca:443/CONTAINER_NAME"`  
  `$ export AWS_ACCESS_KEY_ID="ID-from-step-1"`  
  `$ export AWS_SECRET_ACCESS_KEY="key-from-step-1"`
  `$ restic -r $RESTIC_BACKUP_URL init`  

  During the `init` restic command you will create a new password for the repository which will be the `RESTIC_PASSWORD` used below.

## Secrets
Some secret variables are stored in `secrets.yml` files in both `group_vars/all` and `group_vars/wp_hosts`. These files are not committed to version control, but `secrets-example.yml` files are, which document what variables should be set in these files and to serve as a template for the `secrets.yml` files. Any files named `secrets.yml` are ignored by git.

# Usage

* Setup key
  1. start up ssh-agent  
    `$ ssh-agent`
  2. add private key used by ansible to connect to clients  
    `$ ssh-add <path-to-private-key>`
* Run a playbook  
  `$ ansible-playbook -i ./inventory.yml playbooks/<playbook-file-name>`
* Update and upgrade all hosts, rebooting if needed  
  `$ ansible-playbook -i ./inventory.yml ./playbooks/update_apt_packages.yml`
* To add a new host, put it in `./inventory.yml`
* limiting a play to a specific group of hosts (e.g. `dockerhosts_dev`)  
  `$ ansible-playbook -i ./inventory.yml -l dockerhosts_dev ./playbooks/update_apt_packages.yml`

* Creating a new VM
  To create a new VM to be managed by ansible use the `ansible-client-cloud-init.yml` when creating the VM and then add it to the `inventory.yml`

# Managing backups

## Set restic environment variables to those in your `group_vars/wp_hosts/scecrets.yml` file:

  `$ export RESTIC_BACKUP_URL="{{ restic_backup_url }}"`  
  `$ export RESTIC_PASSWORD="{{ restic_backup_repo_password }}"`  
  `$ export AWS_ACCESS_KEY_ID="{{ object_store_access_key_id }}"`  
  `$ export AWS_SECRET_ACCESS_KEY="{{ object_store_access_key }"`

## View snapshots

  $ restic -r $RESTIC_BACKUP_URL snapshots

## Delete all snapshost with a given tag
  
  `$ restic -r $RESTIC_BACKUP_URL forget --group-by tags --tag <tag-name> --keep-last 1`  
  `$ restic -r $RESTIC_BACKUP_URL forget --group-by tags latest --prune --tag <tag-name>`

restic by default, groups snapshots by host, which means that if snapshots come from different hosts the `--keep-last 1` will keep the last snapshot on each host. The `--group-by tags` instead groups snapshots by tags so that the `--keep-last 1` keeps only one snapshot with that `<tag-name>` instead of one for each host.

# Specific plays

## `wp_setup.yml`
### Adding a new site to a host
The `port` number must be unique from other site `port` values.

A new site must also have a unique `id` across all hosts otherwise it's backups will be associated with previous sites. This implies that the site backups would be lumped together. Since the `id` is used to reference backups during creation and restoring from.

It must also be unique within a host or there will be issues with the same directory/docker volumes trying to be used by two docker-compose setups.

### Hardware requirements

#### RAM
The below table shows how much RAM is used on a VM with a given number of sites. In this test a VM with 4 cores and 7.5G of RAM was used. These sites were basic no-frills sites with only one theme (tutorstarter) and two plugins installed (filebird-document-library,filebird ) there was also little to no content on these sites.

+------+--------+
|Sites | RAM(GB)|
+------+--------+
| 2    | 1.2    |
| 4    | 2.1    |
| 8    | 3.8    |
+------+--------+

This produced a very good linear relationship of about 0.43 GB per site with an initial amount of RAM used of 0.33 GB if we fit a line and calculate the y-axis crossing (with RAM on the y-axis and site count on the x-axis).

### Variables

Important variables are set in 
  * `group_vars/all/secerets.yml` : set the default email and what user ansible should connect with
  * `group_vars/wp_hosts/secrets.yml`: sets Wordpress related secrets, e.g. database password
  * `group_vars/wp_hosts/defaults.yml` : sets WordPress related default settings which can be overridden per site in the `inventory.yml` file.

