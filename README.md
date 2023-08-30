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

### Step 0: Configure ansible variables

Set the ansible variables in `ansible-variables.yaml`.

Change these variables:
- `css_use_https`: set to `true` for https (recommended), `false` for http.

### Step 1: Make the ESpec

Use cookiecutter to generate an ESpec with the number of nodes you need.

```shell
cookiecutter --no-input --verbose --output-dir generated_espec espec
```

### Step 2: Run the ESpec & Save the Inventory

Start jFed.

Click on "Open ESpec":

![Alt text](img/jfed-open-espec.png)

Select "Local Directory", and click "Choose Dir".
Choose the `generated_espec` directory, and click "Start ESpec":

![Alt text](img/jfed-start-espec.png)

Select a name for your experiment, and start it. Now wait until it is running.

### Step 3 (optional): Extract css root URL list (JSON) 

Finally, click "Export As", then "Export Configuration Management Settings (Ansible, Fabric, ...)":

![Alt text](img/jfed-export-inventory.png)

You will be able to choose a location to save the ansible config. You'll need to extract it from the zip file after saving.
The ansible inventory is in the `ansible-hosts` file.

Get the list of CSS servers with:
```shell
sed -n '/^\[css_servers\]$/,$s#.*ansible_ssh_host=\([^ \t]*\).*#https://\1#p' < ansible-hosts
```

### Step 5: Renew or Terminate Experiment

Inside jFed, you'll need to renew the experiment if you plan to use it for a longer time.

If you're done with the experiment, you need to terminate the experiment.
