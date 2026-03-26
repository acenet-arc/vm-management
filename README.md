#  Overview
Ansible playbooks to manage VMs.

These playbooks have been developed only testing Ubuntu based VMs. Modifications are likely required for VMs using other operating systems.

As a first step, the playbook [`playbooks/update_apt_packages.yml`](./playbooks/update_apt_packages.yml) can be used to update apt-based VMs and reboot if required.

The main funciton of this repository currently is to setup, update, backup, and restore WordPress and Omeka-S sites. This process involves creating an inventory (see: [`inventory-example.yml`](./inventory-example.yml)), running the playbook [`playbooks/manage_proxy.yml`](./playbooks/manage_proxy.yml) to setup the reverse proxy in front of your sites and finally running [`playbooks/manage_sites.yml`](./playbooks/manage_sites.yml) to setup and later manage your sites.

All of these playbooks should be run, regularly to update and backup sites.

The reverse proxy sits in front of the websites and forwards requests to them. The sites and their databases are run in docker containers. Each site in a it's own container with the associated database also running in a separate container. The reverse proxy runs the nginx web server, while the site containers run their own Apache webservers. SSL certificates are setup on the reverse proxy for the different sites using [certbot](https://certbot.eff.org/) and [lets encrypt](https://letsencrypt.org/) and self sign certificates are created for the container Apache web servers so that traffic from the reverse proxy to the containers are also encrypted. The reverse proxy can either be on the same host as the sites running in docker containers or it can be a separate host within the same private network as the hosts running docker containers.

# Setup
## Ansible controller setup
On the machine that you will be running these plays to manage VMs, you must:
- have Ansible installed (see: [Installing Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) )
- install Ansible requirements.<br/>
These requirements are needed primarily for the [`playbooks/manage_sites.yml`](./playbooks/manage_sites.yml) and [`playbooks/manage_proxy.yml`](./playbooks/manage_proxy.yml) playbooks, other playbooks have no requirements. For example, it is not required for [`playbooks/update_apt_packages.yml`](./playbooks/update_apt_packages.yml).

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
To manage a virtual machine (VM) with ansible, ansible requires ssh access, usually as a user with `sudo` permissions. There is an example cloud-init script, [`ansible-client-cloud-init-example.yml`](./ansible-client-cloud-init-example.yml) that can be used when creating a new VM after filling in the missing `< >` fields with suitable values. The new VM created with this cloud-init script will be setup to be managed with ansible. The `ssh_authorized_keys` list should contain a public key matching the private key added during the "Setup public/private key" step under the [Ansible controller setup](#ansible-controller-setup) section.

If the `authorized_keys` file on the managed VMs needs to be changed, the [`playbooks/files/authorized_keys.yml`](./playbooks/files/authorized_keys) can be updated to what is desired on the remote VMs and the [`playbooks/set_authorized_keys_file.yml`](./playbooks/set_authorized_keys_file.yml) playbook can be used to update that file on managed VMs, provided you currently have ssh access on the managed VMs.  
**CAUTION**: running the [`playbooks/set_authorized_keys_file.yml`](./playbooks/set_authorized_keys_file.yml) playbook with a miss-configured [`playbooks/files/authorized_keys`](./playbooks/files/authorized_keys) file can cause you to loose access to your VMs.

## Object store setup

Backups are saved to a container in object store using the backup tool [restic](https://restic.readthedocs.io/en/latest/manual_rest.html). Restic encrypts backups using AES-256 in counter mode and authenticated using Poly1305-AES, see [Keys, Encryption and MAC](https://restic.readthedocs.io/en/latest/design.html#keys-encryption-and-mac).

To set it up:

  1. Create storage access ID and secrete key: see: [Establishing access to your Arbutus Object Store](https://docs.alliancecan.ca/wiki/Arbutus_object_storage#Establishing_access_to_your_Arbutus_Object_Store)
  2. Create a new container to store restic backups using the "Containers" pane under "Object Store" left hand menu item.
  3. Initialize a new restic repository using the access credentials created in step 1 and the Arbutus HTTPS endpoint url (something like `https://object-arbutus.cloud.computecanada.ca:443/CONTAINER_NAME` ) using the "s3" protocol so that `s3:` should be appended to that URL to be used with the `RESTIC_BACKUP_URL` mentioned below under the "Managing bakups" section. The `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are the ID and Key created in step 1 above. The commands to do this will look like:
  
  `$ export RESTIC_PASSWORD="<restic-backup-repository-password>"`  
  `$ export RESTIC_BACKUP_URL="s3:https://object-arbutus.cloud.computecanada.ca:443/CONTAINER_NAME"`  
  `$ export AWS_ACCESS_KEY_ID="ID-from-step-1"`  
  `$ export AWS_SECRET_ACCESS_KEY="key-from-step-1"`  
  `$ restic -r $RESTIC_BACKUP_URL init`  
  when initializing the repository, a strong password should be specified to use while encrypting/decrypting the backups.

## Inventory setup

Your inventory describes how you want to configure your hosts. The variables needed in your inventory depend on the playbooks you will run on your inventory.

These variables describe how to configure your reverse proxy with the [`playbooks/manage_proxy.yml`](./playbooks/manage_proxy.yml) playbook and also how to configure your WordPress and or Omeka-S sites with [`playbooks/manage_sites.yml`](./playbooks/manage_sites.yml) playbook. See [`inventory-example.yml`](inventory-example.yml) for examples and descriptions of these variables. This example file can be used as a template to create your own inventory to use with these playbooks.

# Usage

* Run a playbook  
  `$ ansible-playbook -i ./inventory.yml playbooks/<playbook-file-name>`
* Update and upgrade apt repo and packages all hosts, rebooting if needed  
  `$ ansible-playbook -i ./inventory.yml ./playbooks/update_apt_packages.yml`
* Limiting a play to a specific group of hosts (e.g. `dockerhosts_dev`)  
  `$ ansible-playbook -i ./inventory.yml -l dockerhosts_dev ./playbooks/update_apt_packages.yml`  
  Where `dockerhosts_dev` are a host group defined in your `./inventory.yml` file.
 * Creating, configuring, updating, and backing up sites on hosts defined in `./inventory.yml`  
  `$ ansible-playbook -i ./inventory.yml -l dockerhosts_dev ./playbooks/manage_sites.yml`

# Managing backups

This section describes how to manage Restic backups to an OpenStack object store from the command line. This setup is not needed if you are interacting with backups using Ansible playbooks, instead those use the variables defined in your `./inventory.yml` file. However, you will still need to do the setup described in [Object store setup](#object-store-setup) section, including initializing the restic repository as the playbooks don't do that for you. You may however, still want to interact with the restic backup repositories manually to do things like list available snapshots to restore from, or to delete older backups. Note, currently older backups are not removed from restic automatically by the [`playbooks/manage_sites.yml`](./playbooks/manage_sites.yml) playbook.

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

## update_apt_packages.yml

The [`playbooks/update_apt_packages.yml`](./playbooks/update_apt_packages.yml) will update all packages on a host that are managed with the apt package manger. It will also reboot the host if needed.

## manage_proxy.yml

The [`playbooks/manage_proxy.yml`](./playbooks/manage_proxy.yml) playbook is used to setup the reverse proxy that will sit in front of your sites in docker containers and forward requests to them. This reverse proxy can either be on the same host as your site's docker containers are run, or it can be on a separate host. This play uses the `proxy_for_hosts` variable which contains a list of host names as strings to use to construct a virtual host configuration based on the sites described on these hosts. Settings can also be configured manually using the `server_ssl_settings`, and `nginx_vhosts` variables. See [`inventory-example.yml`](inventory-example.yml) for examples of how to do this.

An example of a command to run this playbook:

  `$ ansible-playbook -i ./inventory.yml ./playbooks/manage_proxy.yml`

## manage_sites.yml

The [`playbooks/manage_sites.yml`](playbooks/manage_sites.yml) playbook is used to perform initial setup, updates, and backups of sites described in your inventory file. See [`inventory-example.yml`](inventory-example.yml) for and example of what variables should be in your inventory and a description of what they do.

This playbook can also restore sites from existing backups on different hosts. Port numbers and urls need to be considered when restoring sites on different hosts as Port numbers need to be unique within a host and URLs will necessarily need to be different from the original site.

An example of a command to run this playbook:

  `$ ansible-playbook -i ./inventory.yml ./playbooks/manage_sites.yml`

NOTE: to update the version of php used on Omeka-S sites, `base_docker_image` in `group_vars/website_hosts/defaults.yml` should be updated to the most recent php docker image available.

### Adding a new site to a host
The `port` number must be unique from other site `port` values on that host VM.

A new site must also have a unique `id` across all hosts otherwise it's backups will be associated with previous sites if the same backup repository is used for both. Since the `id` is used to reference backups during creation and restoration. It must also be unique within a host or there will be issues with the same directory/docker volumes trying to be used by two docker-compose setups.

### Hardware requirements

#### RAM
The below table shows how much RAM is used on a VM with a given number of WordPress sites. In this test a VM with 4 cores and 7.5G of RAM was used. These sites were basic no-frills sites with only one theme (tutorstarter) and two plugins installed (filebird-document-library,filebird ) there was also little to no content on these sites.

|Sites | RAM(GB)|
|------|--------|
| 2    | 1.2    |
| 4    | 2.1    |
| 8    | 3.8    |

This produced a very good linear relationship of about 0.43 GB per site with an initial amount of RAM used of 0.33 GB if we fit a line and calculate the y-axis crossing (with RAM on the y-axis and site count on the x-axis). This represents a minimum amount of RAM required on a host VM to host a given number of WordPress sites. Larger amounts of RAM will be required depending on the details of the sites and the amount of traffic they get.

# Importing an existing site

If there is a WordPress or Omeka-S site that already exists these steps can be used as guidelines to importing that site into this management framework.

1. Setup your inventory as you would for a new site
2. Run the `update_apt_packages.yml`, `manage_proxy.yml`, and `manage_sites.yml` playbooks on your inventory to create your new sites.
3. On the host that runs the containers for your new site stop the web container with something like `docker container stop <site-id>-web-1`.
4. Merge the web root of the existing site with the web root of the `<site-id>-web-1` container. The path should be something like `{{ container_base }}/{{ site.id }}/volumes/web`.
4. Merge the web root of the existing site with the web root of the `<site-id>-web-1` container. The path should be something like `{{ container_base }}/{{ site.id }}/volumes/web`. In the case of WordPress sites, often the only content that needs to be merged in is under the `wp-content` folder. Note that there are configuration differences in some WordPress files from a plain WordPress install to allow it to function well inside the container. For example many settings are set via environment variables passed into the container when it is run.
5. Import the database dump from the existing site into the database container with a command something like `run docker exec -e MYSQL_ROOT_PASSWORD -i {{ site.id }}-db-1 sh -c 'exec mysql -uroot -p$MYSQL_ROOT_PASSWORD' < {{ container_base }}/{{ site.id }}/all-databases.sq`. it may need to be different if the database dump is for a specific database rather than all the databases. In that case I believe you can simply name the database you want the dump to apply to and it will overwrite or create a new database as needed.
6. Run the ansible playbooks again to start up the containers with the correct environment variables set.
