# airun
Run a custom LLM on demand in an OpenStack VM and start a dependent process. The VM powers off as soon as the process exits to save $$.

## Prerequisites
- A laptop with [python3-openstackclient installed](https://docs.infomaniak.cloud/getting_started/first_project/connect_project/#installation).
  - On NixOS, add `pkgs.openstackclient-full` to either `environment.systemPackages` or `home.packages`.

## Cloud-specific Setup

### Infomaniak

Note that activating GPU instances on Infomaniak can take about a week.

1.  Follow [these instructions](https://docs.infomaniak.cloud/getting_started/first_project/create_a_project/) to create your project.
    Make sure to set an OpenStack password.
2.  Once the project is created, you'll have to contact Infomaniak support to enable GPU instances in your project.
    In my case, I had to deposit 100 CHF (around $125 USD) into my Infomaniak prepaid account.
    Then, I had to go through an identity verification process, which took a week of back-and-forth.
3.  Download the file clouds.yaml and place it in `~/.config/openstack/clouds.yaml`.
    Keep only one of the clouds (doesn't matter which, dc3 or dc4) in the file and rename it to `airun`.
    Paste in the password you created earlier.
4.  You should now be able to run `openstack --os-cloud airun project list` and have your project ID and name returned.
    When you've successfully gone through the process to enable GPU instance flavors, you should be able to see them when running the command:
    ```sh
    openstack --os-cloud airun flavor list
    ```
    On Infomaniak, GPU flavors begin with `nv`.


## Manual setup
1.  Generate an SSH keypair for access to your AI server instances.
    I recommend generating a new one so you can share it across devices.
    ```sh
    ssh-keygen -f nix/id_airun_client.key -t ed25519 -N '' -C ''
    ```
2.  Additionally, generate an SSH key for your server's fingerprint
    ```sh
    ssh-keygen -f nix/id_airun_server.key -t ed25519 -N '' -C ''
    echo "* $(cat nix/id_airun_server.key.pub)" > airun.hosts
    ```


## Building the image

### NixOS

Note that the first image build will take a very long time, but subsequent ones will use the Nix cache and will be a lot faster.
Run the following command to build an OpenStack qcow2 image:
```sh
nix-build '<nixpkgs/nixos>' -A config.system.build.image --arg configuration "{ imports = [ ./nix/build.nix ]; }"
```

### Testing the image locally
You'll need to uncomment the `users.users.root` section in `nix/configuration.nix` to be able to test the image locally.

#### On Linux
On a Linux machine, have `qemu` installed first.

Copy the qcow2 image file to be able to change its permission mode.
```sh
cp result/*.qcow2 disk.qcow2
chmod 644 disk.qcow2
```

Then, test the image with the command:
```sh
qemu-system-x86_64 -m 4G -enable-kvm -cpu host -drive file=disk.qcow2,format=qcow2,if=virtio -nographic
```

When you see the prompt `nixos login:`, type in `root` and hit Enter.

When finished testing, press Ctrl+A and then X to kill QEMU.

### Uploading the image
```sh
openstack --os-cloud airun image create --private airun-image --container-format bare --disk-format qcow2 --file result/*.qcow2
```
Confirm the image's creation with `openstack --os-cloud airun image list --name airun-image`.

### Reuploading the image
To upload the image again, you first have to delete the existing one with
```sh
openstack --os-cloud airun image delete airun-image
```


## Deployment

### Creating the stack
Run the following command:
```sh
openstack --os-cloud airun stack create -t heat/stack.yml --parameter instance_exists=true airun-stack
```

See the file heat/stack.yml for input parameters.
For example, you can use a different instance flavor with:
```sh
openstack --os-cloud airun stack update -t heat/stack.yml --parameter instance_exists=true --parameter instance_flavor=a1-ram2-disk20-perf1 airun-stack
```

To check the status of the stack creation:
```sh
openstack --os-cloud airun stack show airun-stack
openstack --os-cloud airun stack resource list airun-stack
```

### Accessing the instance
For security reasons, SSH access to the instance is disabled by default.
However, you can enable it by making some manual changes to `nix/configuration.nix`:
1. Uncomment the `users.users.root` section.
2. Comment out the `settings` section in `services.openssh`.
Then you'll be able to SSH into the instance with:
```sh
ssh -i nix/id_airun_client.key -o StrictHostKeyChecking=yes -o UserKnownHostsFile=airun.hosts root@$(openstack --os-cloud airun stack output show --format value --column output_value airun-stack airun_instance_ip)
```

## Accessing ollama on the local machine

### SSH Tunnel
Create an SSH tunnel to expose the instance's Ollama API server on your local machine:
```sh
ssh -i nix/id_airun_client.key -o StrictHostKeyChecking=yes -o UserKnownHostsFile=airun.hosts -N -L 11434:localhost:11434 ollama_user@$(openstack --os-cloud airun stack output show --format value --column output_value airun-stack airun_instance_ip)
```

### Pulling a model
Use the ollama API to pull a model without having to SSH into the server:
```sh
curl http://localhost:11434/api/pull -d '{"model": "gpt-oss"}'
```

### Configure aichat
Add the following section into your ~/.config/aichat/config.yaml:
```yaml
clients:
- api_base: http://localhost:11434/v1
  api_key: ignored
  models:
  - name: gpt-oss
  name: ollama
  type: openai-compatible
```

Then run `aichat --model ollama:gpt-oss`

## Teardown

Ctrl+C out of the SSH tunnel.

Run the following command to make sure the instance isn't using up your $$ when you aren't using it.
```sh
openstack --os-cloud airun stack update -t heat/stack.yml --parameter instance_exists=false airun-stack
```
