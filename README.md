# SolidLab Env Setup

The tools in this repository allow you to set up multiple CSS servers easily.
These servers are ready for "css-populate": they accept new account registrations. 

## Using vagrant to test locally

Upsides:
- Quick
- Easy: all in one step

Downsides:
- No DNS name, so no https

Prerequisites: install ansible and vagrant

```shell
ansible-galaxy install -r ansible-galaxy-requirements.yaml
vagrant up
#vagrant provision
vagrant ssh
```

### Optional step 1: Configure number of servers in Vagrantfile

TODO

### Optional step 2: Configure ansible

TODO

### Optional step 3: Extract ansible inventory and or css root URL list

TODO



## Using an ESpec to test on the virtual wall

Upsides:
- Real bare metal
- DNS, so working https

Downsides:
- Slow
- Multiple steps

Prerequisites: Install ansible, cookiecutter and jFed

### Step 1: Configure ESpec generation parameters

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

### Step 1: Make the ESpec

Use cookiecutter to generate an ESpec with the number of nodes you need.

Execute this in the repository root dir:

```shell
cookiecutter --no-input --verbose --output-dir generated_espec espec
```

This will create a dir `generated_espec/<espec_name>/` containing the ESpec. (where `<espec_name>` is the `espec_name` set in step 1 in `espec/cookiecutter.json`)

### Step 2: Configure ansible variables

Set the ansible variables in `ansible-variables.yaml`.

You can mostly leave these as is, but this variable is useful:
- `css_use_https`: set to `true` for https (recommended), `false` for http.

### Step 3: Run the ESpec & Save the Inventory

Start jFed.

Click on "Open ESpec":

![Alt text](img/jfed-open-espec.png)

Select "Local Directory", and click "Choose Dir".
Choose the `generated_espec/<espec_name>/` directory, and click "Start ESpec":

![Alt text](img/jfed-start-espec.png)

Select a name for your experiment, and start it. Now wait until it is running, and the ESpec and ansible script have successfully completed.

### Step 4 (optional): Extract css root URL list (JSON) 

On the ansible node (first CSS server in experiment) ansible will write files with URL info. You can thus gather all URLs with:

```shell
head ~/ansible/css_url_*
```

To get the same list on the jFed machine, in jFed, click "Export As", then "Export Configuration Management Settings (Ansible, Fabric, ...)":

![Alt text](img/jfed-export-inventory.png)

You will be able to choose a location to save the ansible config. You'll need to extract it from the zip file after saving.
The ansible inventory is in the `ansible-hosts` file.

Open a terminal and `cd` to the directory with the `ansible-hosts` file.

Get the list of CSS servers with this command:
```shell
sed -n '/^\[css_servers\]$/,$s#.*ansible_ssh_host=\([^ \t]*\).*#https://\1#p' < ansible-hosts
```

### Step 5: Renew or Terminate Experiment

Inside jFed, you'll need to renew the experiment if you plan to use it for a longer time.

If you're done with the experiment, don't forget to terminate the experiment.
