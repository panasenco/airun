{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
    <nixpkgs/nixos/modules/profiles/headless.nix>
  ];

  config = {
    fileSystems."/" = {
      device = "/dev/vda1";
      fsType = "ext4";
      autoResize = true;
    };

    boot.growPartition = true;
    boot.kernelParams = [ "console=ttyS0,115200n8" ];
    boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/vda";
    boot.loader.timeout = 1;
    boot.loader.grub.extraConfig = ''
      serial --unit=1 --speed=115200 --word=8 --parity=no --stop=1
      terminal_output console serial
      terminal_input console serial
    '';

    # Allow root logins
    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "prohibit-password";
      settings.PasswordAuthentication = false;
    };

    # Enable cloud-init
    services.cloud-init = {
      enable = true;
      network.enable = true;
    };

    # Enable the serial console on ttyS0
    systemd.services."serial-getty@ttyS0".enable = true;

    users.users.root.initialHashedPassword = "";
  };
}
