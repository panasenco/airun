# nix-build '<nixpkgs/nixos>' -A config.system.build.image --arg configuration "{ imports = [ ./nix/build.nix ]; }"

{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    <nixpkgs/nixos/modules/image/file-options.nix>
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
    ./configuration.nix
  ];

  documentation.enable = true;

  image.extension = "qcow2";
  system.nixos.tags = [ "openstack" ];
  system.build.image = import <nixpkgs/nixos/lib/make-disk-image.nix> {
    inherit lib config;
    inherit (config.image) baseName;
    format = "qcow2";
    additionalSpace = "128M";
    pkgs = import <nixpkgs> { inherit (pkgs) system; }; # ensure we use the regular qemu-kvm package
    configFile = pkgs.writeText "configuration.nix" (builtins.readFile ./configuration.nix);
    contents = [
      {
        source = ./id_airun_server.key;
        target = "/root/.ssh/id_airun_server.key";
        mode = "600";
        user = "root";
        group = "root";
      }
      {
        source = ./id_airun_client.key.pub;
        target = "/etc/nixos/id_airun_client.key.pub";
      }
    ];
  };
}

