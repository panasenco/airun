# airun
Run a custom LLM on demand in an OpenStack VM and start a dependent process. The VM powers off as soon as the process exits to save $$.

## Prerequisites
- A laptop with [python3-openstackclient installed](https://docs.infomaniak.cloud/getting_started/first_project/connect_project/#installation).
  - On NixOS, add `pkgs.openstackclient-full` to either `environment.systemPackages` or `home.packages`.

## Setup

### Infomaniak

1.  Follow [these instructions](https://docs.infomaniak.cloud/getting_started/first_project/create_a_project/) to create your project.
    Make sure to set an OpenStack password.
2.  Once the project is created, you'll have to contact Infomaniak support to enable GPU instances in your project.
    In my case, I had to deposit 100 CHF (around $125 USD) into my Infomaniak prepaid account and go through and identity verification process.
3.  Download the file clouds.yaml and place it in `~/.config/openstack/clouds.yaml`.
    Keep only one of the clouds (doesn't matter which, dc3 or dc4) in the file and rename it to `airun`.
    Paste in the password you created earlier.
4.  You should now be able to run `openstack --os-cloud airun project list` and have your project ID and name returned.
    When you've successfully gone through the process to enable GPU instance flavors, you should be able to see them when running the command:
    ```
    openstack --os-cloud airun flavor list
    ```
    On Infomaniak, GPU flavors begin with `nv`.
