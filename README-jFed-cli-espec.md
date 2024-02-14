
## Using an ESpec to test on the virtual wall (with jFed CLI2)

Upsides:
- Real bare metal
- DNS, so working https

Downsides:
- Slow
- Slightly more complex setup

Prerequisites:
- Install [cookiecutter](https://github.com/cookiecutter/cookiecutter#installation) (`apt install cookiecutter`)
- Install [jFed CLI2](https://jfed.ilabt.imec.be/downloads/)  (scroll down for CLI download)  (You need at least **jFed 6.4.7**!)

(Step 0, 1, 2 are the same for jFed GUI and CLI2)

### Step 0: Configure ESpec generation parameters

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
- `ss_use_https`: set to `true` for https (recommended), `false` for http.

### Step 3: Run the ESpec

Edit `jfed-cli2-run-espec.yaml`. You'll need to replace the following:
- `<<GENERATED_DIR>>`: The absolute path of the generated dir with `jfed-cli2-run-espec.yaml` and `experiment-specification.yaml` in it.
- `<<YOUR_PORTAL_PROJECT>>`: The project you want to create an experiment in
- `<<YOUR_WANTED_EXPERIMENT_NAME>>`: A name for your new experiment
- `<<YOUR_LOGIN_PEM>>`: The login file for your portal account. You can download this at the bottom of the homepage of the account portal.

Execute this file with jFed CLI2:
```shell
COMMAND_FILE="$(readlink -f jfed-cli2-run-espec.yaml)" 
cd <jfed_cli_utils_dir>
java -jar experimenter-cli2.jar -a "${COMMAND_FILE}"
```

Now wait until the experiment is running, and the ESpec and ansible script have successfully completed.

### Step 4 (optional): Extract css root URL list (JSON) 

#### Option 1: manual `scp`

You'll notice that the jFed CLI writes a file `ssh_info.csv` when running the CLI (this is requested in the ESpec).

You can download the URL files and then use `cat` as before to summarize them:
```shell
cd <jfed_cli_utils_dir>
ls ssh_info.csv
scp "$(grep -e '^css0,' ssh_info.csv | cut -d, -f6):~/ansible/css_url_*" .
cat css_url_* | tee all_urls
```

#### Option 2: jFed CLI2 fetch

Alternatively, you can use jFed CLI2 to get a file with all URLs.

Edit `jfed-cli2-fetch-urls.yaml`. You'll again need to replace the following:
- `<<GENERATED_DIR>>`: The absolute path of the generated dir with `jfed-cli2-run-espec.yaml` and `experiment-specification.yaml` in it. Or another dir in which you want the output file `ss_url` to be written.
- `<<YOUR_PORTAL_PROJECT>>`: The project you created the experiment in
- `<<YOUR_EXPERIMENT_NAME>>`: The name of the now running experiment
- `<<YOUR_LOGIN_PEM>>`: The login file for your portal account.

Execute this file with jFed CLI2:
```shell
COMMAND_FILE="$(readlink -f jfed-cli2-fetch-urls.yaml)" 
cd <jfed_cli_utils_dir>
java -jar experimenter-cli2.jar -a "${COMMAND_FILE}"
```

You'll now find a file `ss_url` in the dir with `jfed-cli2-fetch-urls.yaml`, which contains all CSS server URLs.

### Step 5: Renew or Terminate Experiment

Inside jFed, you'll need to renew the experiment if you plan to use it for a longer time.

If you're done with the experiment, don't forget to terminate the experiment.
