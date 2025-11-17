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
    ssh-keygen -f ~/.ssh/id_airun -t ed25519
    ```
2.  [Upload the public key to OpenStack](https://docs.infomaniak.cloud/compute/key_pairs/) with:
    ```sh
    openstack --os-cloud airun keypair create --public-key ~/.ssh/id_airun.pub airun_key
    ```


## Building the image

### NixOS

#### Build the image from unstable NixOS
If you're on the `unstable` NixOS channel, you'll likely not have prebuilt binary NVIDIA drivers and llama.cpp,
which could take hours to build.
You'll instead want to use the stable channel of nixpkgs:
```sh
git clone --depth 1 --branch nixos-25.05 https://github.com/NixOS/nixpkgs.git pkgs-25.05
nix-build -I nixpkgs=pkgs-25.05 '<nixpkgs/nixos>' -A config.system.build.image --arg configuration "{ imports = [ ./nix/build.nix ]; }"
```

#### Build the image from stable NixOS

If you're already on the stable channel, simply run the following command to build a generic OpenStack qcow2 image:
```sh
nix-build '<nixpkgs/nixos>' -A config.system.build.image --arg configuration "{ imports = [ ./nix/build.nix ]; }"
```

### Testing the image locally
You'll need `qemu` installed on your Linux PC to test the image locally.

Copy the qcow2 image file to be able to change its permission mode.
```sh
cp result/*.qcow2 disk.qcow2
chmod 644 disk.qcow2
```

Then, test the image with the command:
```sh
qemu-system-x86_64 -enable-kvm -cpu host -drive file=disk.qcow2,format=qcow2,if=virtio -nographic
```

When you see the message `[ OK ] Reacher target Multi-User System.`, type in `root` and hit Enter.

Press Ctrl+A and then X to kill QEMU.

### Uploading the image
```sh
openstack --os-cloud airun image create airun-image --container-format bare --disk-format qcow2 --file result/*.qcow2
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

To check the status of the stack creation:
```sh
openstack --os-cloud airun stack show airun-stack
```

### Accessing the instance
To SSH into the instance:
```sh
ssh -i ~/.ssh/id_airun root@$(openstack --os-cloud airun stack output show --format value --column output_value airun-stack airun_instance_ip)
```

