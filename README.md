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

Instructions: [README-vagrant.md](README-vagrant.md)

## Using an RSpec or ESpec to test on the virtual wall (with jFed Experiment GUI)

Upsides:
- Real bare metal
- DNS, so working https
- GUI: Easy to use

Downsides:
- Slow
- GUI: Multiple steps
- GUI: Not scriptable

**Instructions: [README-jFed-gui-rspec.md](README-jFed-gui-rspec.md)** (or [README-jFed-gui-espec.md](README-jFed-gui-espec.md) for the non-recommended ESpec version)

## Using an RSpec or ESpec to test on the virtual wall (with jFed CLI2)

Upsides:
- Real bare metal
- DNS, so working https
- CLI: Can be used from scripts

Downsides:
- Slow
- CLI: Slightly more complex setup

**Instructions: [README-jFed-cli-rspec.md](README-jFed-cli-rspec.md)** (or [README-jFed-cli-espec.md](README-jFed-cli-espec.md) for the non-recommended ESpec version)

## Install on existing servers

Upsides:
- Real bare metal or VMs
- DNS, so working https

Downsides:
- Slow
- Multiple steps

**Instructions: [README-existing.md](README-existing.md)**

# License

This code is copyrighted by [Ghent University – imec](http://idlab.ugent.be/) and released under the [EUPLv1.2 license](https://opensource.org/license/eupl-1-2/).
