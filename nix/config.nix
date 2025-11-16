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
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };

    boot.growPartition = true;
    boot.kernelParams = [ "console=tty1" ];
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

    # Enable the serial console on tty1
    systemd.services."serial-getty@tty1".enable = true;
  };
}
