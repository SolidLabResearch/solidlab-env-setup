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

### Step 1: Make the ESpec

Use cookiecutter to generate an ESpec with the number of nodes you need.

```shell
cookiecutter --no-input --verbose --output-dir generated_espec espec
```

### Step 2: Run the ESpec & Save the Inventory

TODO

### Step 3: Configure & run ansible

Set the ansible variables, and run ansible. Provide ansible the inventory file.

TODO

### Step 4 (optional): Extract css root URL list (JSON) 

TODO

### Step 5: Renew or Terminate Experiment

Inside jFed, you'll need to renew the experiment if you plan to use it for a longer time.

If you're done with the experiment, you need to terminate the experiment.
