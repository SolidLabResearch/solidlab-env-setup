# SolidLab Env Setup

The tools in this repository allow you to set up multiple solid servers easily.
These servers are ready for "css-populate": they accept new account registrations. 

There are a few methods to use this. See below.

## Using vagrant to test locally

With vagrant, you can easily start VM(s) on your local machine to run solid server(s) and use them locally.

Upsides:
- Quick
- Easy: all in one step

Downsides:
- No DNS name, so no https

Prerequisites: 
- Install [ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) 
- Install [vagrant](https://developer.hashicorp.com/vagrant/docs/installation)

Instructions: [README-vagrant.md](README-vagrant.md)

## Using an ESpec to test on the virtual wall (with jFed Experiment GUI)

**You need the latest jFed version to run this! Use the version at the top of [this page](https://jfed.ilabt.imec.be/releases/develop/?C=N;O=D)**  

Upsides:
- Real bare metal
- DNS, so working https

Downsides:
- Slow
- Multiple steps

Prerequisites:
- Install [cookiecutter](https://github.com/cookiecutter/cookiecutter#installation)
- Install [jFed GUI](https://jfed.ilabt.imec.be/downloads/) 

**Instructions: [README-jFed-gui.md](README-jFed-gui.md)**

## Using an ESpec to test on the virtual wall (with jFed CLI2)

**You need the latest jFed version to run this! Use the version at the top of [this page](https://jfed.ilabt.imec.be/releases/develop/?C=N;O=D)**  

Upsides:
- Real bare metal
- DNS, so working https

Downsides:
- Slow
- Slightly more complex setup

Prerequisites: 
- Install [cookiecutter](https://github.com/cookiecutter/cookiecutter#installation)
- Install [jFed CLI2](https://jfed.ilabt.imec.be/downloads/) (scroll down for CLI download!)

**Instructions: [README-jFed-cli.md](README-jFed-cli.md)**

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
- Install [cookiecutter](https://github.com/cookiecutter/cookiecutter#installation)
- Install [jFed GUI/CLI2](https://jfed.ilabt.imec.be/downloads/)

**Instructions: [README-existing.md](README-existing.md)**

# License

This code is copyrighted by [Ghent University – imec](http://idlab.ugent.be/) and released under the [EUPLv1.2 license](https://opensource.org/license/eupl-1-2/).
