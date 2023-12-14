## Install on existing servers

Upsides:
- Real bare metal or VMs
- DNS, so working https

Downsides:
- Slow
- Multiple steps

Prerequisites:
- Install [ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html)

Optional instructions are included to get the needed bare metal servers using jFed (Using an RSpec instead of an ESpec). This requires extra prerequisites:
- Install [cookiecutter](https://github.com/cookiecutter/cookiecutter#installation) (`apt install cookiecutter`)
- Install [jFed GUI/CLI2](https://jfed.ilabt.imec.be/downloads/)   (You need at least **jFed 6.4.7**!)

### Optional Step 0: Get bare metal resources using jFed.

Edit `espec/cookiecutter.json` to customize some parameters. 
The most obvious one to change is `server_count`, to select the number of servers needed. 

Things to edit:
- `espec_name`: The nickname of the generated espec. This will be used as a dir name, so best use only the chars `A-Za-z0-9_`.
- `server_count`: How many CSS servers do you want?
- `client_count`: How many machines do you want as clients? (leave as 0 if all you need are CSS servers)
- `component_manager_urn`: This selects which testbed is used. Each testbed has a "component manager URN" that identifies it.
- `disk_image_name`: If you change the testbed, you'll need to change the diskimage to an appropriate disk image.
- `server_hardware_type_name`: If not set to `"none"`, this is the name of the "hardware type" of the testbed to use for server nodes. 
- `client_hardware_type_name`: If not set to `"none"`, this is the name of the "hardware type" of the testbed to use for client nodes. 

Use cookiecutter to generate an ESpec with the number of nodes you need.

Execute this in the repository root dir:

```shell
cookiecutter --no-input --verbose --output-dir generated_espec espec
```

This will create a dir `generated_espec/<espec_name>/` containing the ESpec. (where `<espec_name>` is the `espec_name` set in step 1 in `espec/cookiecutter.json`)

We won't use the ESpec, we will only use the RSpec: `generated_espec/<espec_name>/solidlab-env.rspec`

Open the RSpec in the jFed GUI, and start an experiment. When it's ready, use the button in jFed to store the ansible inventory file.

### Step 1: Get the ansible inventory file

To let ansible install the machines, you need an ansible inventory file.

If you used jFed to set up the resources, you can use the button in jFed to store the ansible inventory file.

Otherwise, you'll need to [create the inventory file](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html). An example:
```ini
[nodes]
ss0      ansible_ssh_host=node1.example.com	ansible_ssh_port=22	ansible_ssh_user=solid 
ss1      ansible_ssh_host=node2.example.com	ansible_ssh_port=22	ansible_ssh_user=solid 
client0  ansible_ssh_host=node3.example.com	ansible_ssh_port=22	ansible_ssh_user=solid 

[clients]
client0  ansible_ssh_host=node3.example.com ansible_ssh_port=22	ansible_ssh_user=solid 

[ss_servers]
ss0      ansible_ssh_host=node1.example.com	ansible_ssh_port=22	ansible_ssh_user=solid 
ss1      ansible_ssh_host=node2.example.com	ansible_ssh_port=22	ansible_ssh_user=solid 
```

### Step 2: Configure ansible variables

Set the ansible variables in `ansible-variables.yaml`.

You can mostly leave these as is, but this variable is useful:
- `ss_use_https`: set to `true` for https (recommended), `false` for http.

Run ansible from this repo's root dir, like this:

```shell
ansible-galaxy install -r ansible-galaxy-requirements.yaml

export ANSIBLE_SSH_ARGS='-o ForwardAgent=yes -o ControlMaster=auto -o ControlPersist=60s'
export ANSIBLE_CONNECTION='ssh'
ansible-playbook --inventory your_ansible_inventory_file playbook.yaml
```

If you need to rerun the playbook, you'll only need the last line.

### Step 4 (optional): Extract css root URL list (JSON) 

Ansible will write files with server URL info. 
You can use this to gather all URLs using this command:

```shell
cat ~/ansible/ss_url_* > all_urls
```
