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

## Using an ESpec to test on the virtual wall (with jFed Experiment GUI)

Upsides:
- Real bare metal
- DNS, so working https

Downsides:
- Slow
- Multiple steps

**Instructions: [README-jFed-gui.md](README-jFed-gui.md)**

## Using an ESpec to test on the virtual wall (with jFed CLI2)

Upsides:
- Real bare metal
- DNS, so working https

Downsides:
- Slow
- Slightly more complex setup

**Instructions: [README-jFed-cli.md](README-jFed-cli.md)**

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
