{
  config,
  pkgs,
  lib,
  ...
}:

{
  # GENERIC CONFIGURATION
  imports = [
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
    <nixpkgs/nixos/modules/profiles/headless.nix>
  ];

  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
    autoResize = true;
  };

  fileSystems."/mnt/shared" = {
    device = "/dev/vdb";
    fsType = "ext4";
    autoFormat = true;
    options = [ "x-systemd.automount" "nofail" ];
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

  # Enable the serial console on ttyS0
  systemd.services."serial-getty@ttyS0".enable = true;

  # Networking
  networking.useNetworkd = true;
  networking.useDHCP = true;

  # Create ollama_user
  users.users.ollama_user = {
    isNormalUser = true;
    shell = "/run/current-system/sw/bin/nologin";
    openssh.authorizedKeys.keys = [
      (builtins.readFile ./id_airun_client.key.pub)
    ];
  };

  # Uncomment for debugging
#  users.users.root = {
#    # Empty password for local QEMU run
#    initialHashedPassword = "";
#    # Hardcode SSH public key
#    openssh.authorizedKeys.keys = [
#      (builtins.readFile ./id_airun_client.key.pub)
#    ];
#  };

  # Allow only public key logins from ollama_user
  services.openssh = {
    enable = true;
    # Comment the settings section out for debugging
    settings = {
      # Lock most things down
      AllowAgentForwarding = false;
      AllowStreamLocalForwarding = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      PermitTTY = false;
      PermitTunnel = "no";
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      # Allow only TCP forwarding (ssh tunnel) for ollama_user
      AllowUsers = [
        "ollama_user"
      ];
      AllowTcpForwarding = "yes";
    };
    hostKeys = [
      {
        path = "/root/.ssh/id_airun_server.key";
        type = "ed25519";
      }
    ];
  };

  # Set system version
  system.stateVersion = "25.05";

  # AI CONFIGURATION
  # Enable unfree packages
  nixpkgs.config.allowUnfree = true;

  # Install packages
  environment.systemPackages = with pkgs; [
    ollama-cuda
    pciutils
    vim
    wget
  ];

  # Enable NVIDIA kernel module
  services.xserver.videoDrivers = [ "nvidia" ];

  # Enable OpenGL
  hardware.graphics.enable = true;

  # NVIDIA-specific headless CUDA/OpenCL stubs
  hardware.nvidia = {
    modesetting.enable = false;
    powerManagement.enable = false;
    open = false; # use proprietary CUDA-supporting driver
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Start the ollama server
  systemd.services.ollama = {
    description = "Ollama server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStartPre = "+${pkgs.bash}/bin/bash -c 'mkdir -p /mnt/shared/ollama-home && chown ollama_user:users /mnt/shared/ollama-home'";
      ExecStart = "/run/current-system/sw/bin/ollama serve";
      Restart = "on-failure";
      User = "ollama_user";
      Group = "users";
    };
    environment = {
      HOME = "/mnt/shared/ollama-home";
      OLLAMA_KEEP_ALIVE = "-1"; # Never unload any model from RAM
    };
  };
}
