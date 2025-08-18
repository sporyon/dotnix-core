{ inputs, lib, pkgs, ... }: {
  imports = [
    inputs.self.nixosModules.polkadot-validator
    inputs.self.nixosModules.selinux
    ({ config, lib, pkgs, ... }: {
      # Validator configuration.
      dotnix.polkadot-validator.enable = true;
      dotnix.polkadot-validator.name = "sporyon-dotnix-westend2";
      dotnix.polkadot-validator.chain = "westend";
      dotnix.polkadot-validator.extraArgs = [
        "--db-storage-threshold=0"
      ];

      environment.systemPackages = [
        config.dotnix.polkadot-validator.package
        pkgs.polkadot-rpc
      ];
    })
  ];

  users.groups.admin = {};
  users.users = {
    admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      password = "yolo";
      group = "admin";
    };
  };

  virtualisation.vmVariant = {
    # following configuration is added only when building VM with build-vm
    virtualisation = {
      cores = 3;
      diskSize = 32 * 1024;
      memorySize = 2048; # Use 2048MiB memory.
      graphics = false;
    };
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  security.selinux.enable = true;

  environment.systemPackages = [
    # Utilities for working with SELinux interactively
    pkgs.audit
    pkgs.libselinux
    pkgs.policycoreutils
    pkgs.selinux.coreutils
    pkgs.selinux.selinux-python
  ];

  nixpkgs.overlays = [
    inputs.self.overlays.default
  ];

  system.stateVersion = "24.11";
}
