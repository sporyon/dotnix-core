# THIS CONFIGURATION IS JUST FOR TESTING PURPOSES NOT FOR PRODUCTION USE
{
  imports = [
    # Base configuration
    ({ inputs, ... }: {
      imports = [
        inputs.self.nixosModules.polkadot-validator
        inputs.self.nixosModules.selinux
      ];
      nixpkgs.overlays = [
        inputs.self.overlays.default
      ];

      boot.kernelParams = [ "hidepid=2" ];

      # On a real system root would either not get a password at all or it
      # would be configured using hashedPassword.
      # For the Docker image this is good enough :)
      users.users.root.password = "yolo";
      services.getty.autologinUser = "root";

      nix.nixPath = [
        "nixpkgs=${inputs.nixpkgs}"
      ];

      # Enable flakes
      nix.settings.experimental-features = [ "flakes" "nix-command" ];

      i18n.defaultLocale = "C.UTF-8";

      services.openssh = {
        enable = true;
        settings.PasswordAuthentication = true;
      };

      networking.firewall.allowedTCPPorts = [ 22 ];

      system.stateVersion = "24.11";
    })

    # Disk configuration (used by all images)
    {
      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
      fileSystems."/boot" = {
        device = "/dev/disk/by-label/ESP";
        fsType = "vfat";
      };
      boot.growPartition = true;
      systemd.services.systemd-growfs-root.wantedBy = [ "multi-user.target" ];
    }

    # VM configuration
    {
      # following configuration is used only by nixos-rebuild build-vm
      virtualisation.vmVariant = {
        virtualisation = {
          cores = 3;
          diskSize = 32 * 1024;
          graphics = false;
          memorySize = 4 * 1024;
        };
      };
    }

    # Docker configuration
    ({ config, inputs, lib, pkgs, ... }: {
      imports = [
        (inputs.nixpkgs + "/nixos/modules/profiles/qemu-guest.nix")
        (inputs.nixpkgs + "/nixos/modules/installer/cd-dvd/channel.nix")
      ];
      boot.kernelParams = [ "console=ttyS0" ];
      boot.loader.timeout = lib.mkDefault 0;
      system.build.docker = pkgs.dockerTools.buildImage {
        name = "dotnix-docker";
        tag = "latest";
        copyToRoot = pkgs.buildEnv {
          name = "dotnix-docker-image-root";
          paths = [
            (pkgs.writers.writeDashBin "run-nixos-vm" ''
              set -efu
              ${pkgs.coreutils}/bin/install -d -m 1777 /tmp
              exec ${config.system.build.vm}/bin/run-nixos-vm
            '')
          ];
          pathsToLink = [
            "/bin"
          ];
        };
        config = {
          os = "linux";
          Cmd = "run-nixos-vm";
        };
      };
    })

    # Validator configuration
    ({ config, pkgs, ... }: {
      dotnix.polkadot-validator.enable = true;
      dotnix.polkadot-validator.name = "sporyon-dotnix-westend2";
      dotnix.polkadot-validator.chain = "westend";
      dotnix.polkadot-validator.extraArgs = [
        "--db-storage-threshold=0"
      ];

      environment.systemPackages = [
        config.dotnix.polkadot-validator.package
        pkgs.list-dependencies
        pkgs.polkadot-rpc
      ];
    })

    # SELinux configuration
    ({ pkgs, ... }: {
      security.selinux.enable = true;

      environment.systemPackages = [
        # Utilities for working with SELinux interactively
        pkgs.audit
        pkgs.libselinux
        pkgs.policycoreutils
        pkgs.selinux.coreutils
        pkgs.selinux.selinux-python
      ];

      boot.kernelParams = [ "enforcing=1" ];
    })
  ];
}
