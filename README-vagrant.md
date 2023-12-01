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

### Optional step 1: Configure number of servers in Vagrantfile

Just export the wanted numer of VMs as an env variable:

```shell
export SS_COUNT=2
```

Optionally, you can hardcode this in the `Vagrantfile`, so it doesn't depend on the environment.

### Optional step 2: Configure ansible

Set the ansible variables in `ansible-variables.yaml`.

You can mostly leave these as is, but this variable is useful:
- `ss_use_https`: set to `false` for http (recommended with vagrant), `true` for https (doesn't work with vagrant).

### step 3: Start the VMs

```shell
ansible-galaxy install -r ansible-galaxy-requirements.yaml
vagrant up
#vagrant provision
vagrant ssh
```

### Optional step 4: Get css root URL list

Ansible will write files with server URL info. 
You can use this to gather all URLs using this command:

```shell
cat css_url_* > all_urls
```

You can also just create a (the predictable) list of CSS server root URLs with something like:

```shell
for i in $(seq 0 $(( SS_COUNT - 1 )) )
do
  echo "http://localhost:$(( $i + 3000 ))/"
done
```
