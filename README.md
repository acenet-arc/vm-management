#  Overview
Ansible playbooks to manage VMs.

These playbooks have been developed only testing Ubuntu based VMs. Modifications are likely required for VMs using other operating systems.

As a first step, the playbook [`playbooks/update_apt_packages.yml`](./playbooks/update_apt_packages.yml) can be used to update apt-based VMs and reboot if required.

The main playbook used in this repository is [`playbooks/manage_sites.yml`](playbooks/manage_sites.yml). This playbook can be used to create, configure, update, and backup WordPress and Omeka sites on one or more hosts. These sites are run inside docker containers and have separate databases running in their own separate docker containers.

# Setup
## Ansible Controller setup
On the machine that you will be running these plays to manage VMs, you must:
- have Ansible installed (see: [Installing Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) )
- install Ansible requirements.<br/>
These requirements are needed primarily for the manage_sites.yml](./playbooks/manage_sites.yml) playbook, other playbooks have no requirements. For example, it is not requred for [`playbooks/update_apt_packages.yml`](./playbooks/update_apt_packages.yml).

  `$ ansible-galaxy install -r requirements.yml`

- Setup public/private key to use when accessing managed VMs
  1. start up ssh-agent  
    `$ ssh-agent`
  2. add private key used by ansible to connect to clients  
    `$ ssh-add <path-to-private-key>`

Also a good idea:
- If making changes to playbooks, to install ansible-lint to check changes to the playbooks (see: [Installing Ansible Lint](https://ansible.readthedocs.io/projects/lint/installing/) )
Also see: yamllint, ansible-playbook --syntax-check, (molecule test (integration tests)), ansible-playbook --check (see what would change if run).

## Managed VM setup
To manage a VM with ansible, ansible requires ssh access, usually as a user with `sudo` permissions. There is an example cloud-init script, [`ansible-client-cloud-init-example.yml`](./ansible-client-cloud-init-example.yml) that can be used when creating a new VM after filling in the missing `< >` fields with suitable values. The new VM created with this cloud-init script will be setup to be managed with ansible. The `ssh_authorized_keys` list should contain a public key matching the private key added during the "Setup key" step under the [Usage](#usage) section.

If the `authorized_keys` file on the managed VMs needs to be changed, the [`playbooks/files/authorized_keys.yml`](./playbooks/files/authorized_keys) can be updated to what is desired on the remote VMs and the [`playbooks/set-authorized-keys-file.yml`](./playbooks/set-authorized-keys-file.yml) playbook can be used to update that file on managed VMs, provided you currently have ssh access on the managed VMs.  
**CAUTION**: running the [`playbooks/set_authorized_keys_file.yml`](./playbooks/set_authorized_keys_file.yml) playbook with a miss-configured [`playbooks/files/authorized_keys`](./playbooks/files/authorized_keys) can cause you to loose access to your VMs.

## Object store setup

Backups are saved to a container in Object store using the backup tool [restic](https://restic.readthedocs.io/en/latest/manual_rest.html). Restic encrypts backups using AES-256 in counter mode and authenticated using Poly1305-AES, see [https://restic.readthedocs.io/en/latest/design.html#keys-encryption-and-mac](Keys, Encryption and MAC). To set it up:

  1. Create storage access ID and secrete key: (see: [Establishing access to your Arbutus Object Store](https://docs.alliancecan.ca/wiki/Arbutus_object_storage#Establishing_access_to_your_Arbutus_Object_Store) )
  2. Create a new container to store restic backups using the "Containers" pane under "Object Store" left hand menu item.
  3. Initialize a new restic repository using the access credentials created in step 1 and the Arbutus HTTPS endpoint url (something like `https://object-arbutus.cloud.computecanada.ca:443/CONTAINER_NAME` ) using the "s3" protocol so that `s3:` should be appended to that URL to be used with the `RESTIC_BACKUP_URL` mentioned below under the "Managing bakups" section. The `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are the ID and Key created in step 1 above. The commands to do this will look like:
  
  `$ export RESTIC_PASSWORD="<restic-backup-repository-password>"`  
  `$ export RESTIC_BACKUP_URL="s3:https://object-arbutus.cloud.computecanada.ca:443/CONTAINER_NAME"`  
  `$ export AWS_ACCESS_KEY_ID="ID-from-step-1"`  
  `$ export AWS_SECRET_ACCESS_KEY="key-from-step-1"`  
  `$ restic -r $RESTIC_BACKUP_URL init`  

## Inventory setup

Wordpress and Omeka default variable values are set in [`playbooks/group_vars/website_hosts/defaults.yml`](./playbooks/group_vars/website_hosts/defaults.yml) which can be overridden per site in your `inventory.yml` file. The majority of variables describing how sites are configured are set in your inventory.yml file. Use [`inventory-example.yml`](inventory-example.yml) as a template for creating your own `inventory.yml` file.

# Usage

* Run a playbook  
  `$ ansible-playbook -i ./inventory.yml playbooks/<playbook-file-name>`
* Update and upgrade apt repo and packages all hosts, rebooting if needed  
  `$ ansible-playbook -i ./inventory.yml ./playbooks/update_apt_packages.yml`
* Limiting a play to a specific group of hosts (e.g. `dockerhosts_dev`)  
  `$ ansible-playbook -i ./inventory.yml -l dockerhosts_dev ./playbooks/update_apt_packages.yml`  
  Where `dockerhosts_dev` are a host group defined in your `./inventory.yml` file.
 * Creating, configurating, updating, and backing up sites on hosts defined in `./inventory.yml`  
  `$ ansible-playbook -i ./inventory.yml -l dockerhosts_dev ./playbooks/manage_sites.yml`

# Managing backups

This section describes how to manage restic backups to an openstack object store from the command line. This setup is not needed if you are interacting with backups using ansible playbooks, instead those use the variables defined in your `./inventory.yml` file.

## Set restic environment variables

Set restic environment variables to those in your `./inventory.yml` file for a particular host:

  `$ export RESTIC_BACKUP_URL="{{ restic_backup_url }}"`  
  `$ export RESTIC_PASSWORD="{{ restic.password }}"`  
  `$ export AWS_ACCESS_KEY_ID="{{ object_store.key_id }}"`  
  `$ export AWS_SECRET_ACCESS_KEY="{{ object_store.key }"`

## List snapshots

  `$ restic -r $RESTIC_BACKUP_URL snapshots`

## Delete all snapshost with a given tag
  
  `$ restic -r $RESTIC_BACKUP_URL forget --group-by tags --tag <tag-name> --keep-last 1`  
  `$ restic -r $RESTIC_BACKUP_URL forget --group-by tags latest --prune --tag <tag-name>`

Restic by default groups snapshots by host, which means that if snapshots come from different hosts the `--keep-last 1` will keep the last snapshot on each host. The `--group-by tags` instead groups snapshots by tags so that the `--keep-last 1` keeps only one snapshot with that `<tag-name>` instead of one for each host.

# Specific plays

## manage_sites.yml

### setup/updating

The same [`playbooks/manage_sites.yml`](playbooks/manage_sites.yml) playbook both updates and sets up sites as needed based on the settings in your inventory file. See [`inventory-example.yml`](inventory-example.yml) for details on what should be in your inventory file. This playbook can also restore sites from existing backups on different hosts. Port numbers and urls need to be considered when restoring sites on different hosts as Port numbers need to be unique within a host and URLs will necessarily need to be different from the original site.

  `$ ansible-playbook -i ./inventory.yml -l website_hosts ./playbooks/manage_sites.yml`

NOTE: to update the version of php used on Omeka-S sites, `base_docker_image` in `group_vars/website_hosts/defaults.yml` should be updated to the most recent php docker image available.

### Adding a new site to a host
The `port` number must be unique from other site `port` values on that host VM.

A new site must also have a unique `id` across all hosts otherwise it's backups will be associated with previous sites. This implies that the site backups would be lumped together. Since the `id` is used to reference backups during creation and restoring from.

It must also be unique within a host or there will be issues with the same directory/docker volumes trying to be used by two docker-compose setups.

### Hardware requirements

#### RAM
The below table shows how much RAM is used on a VM with a given number of WordPress sites. In this test a VM with 4 cores and 7.5G of RAM was used. These sites were basic no-frills sites with only one theme (tutorstarter) and two plugins installed (filebird-document-library,filebird ) there was also little to no content on these sites.

|Sites | RAM(GB)|
|------|--------|
| 2    | 1.2    |
| 4    | 2.1    |
| 8    | 3.8    |

This produced a very good linear relationship of about 0.43 GB per site with an initial amount of RAM used of 0.33 GB if we fit a line and calculate the y-axis crossing (with RAM on the y-axis and site count on the x-axis).
