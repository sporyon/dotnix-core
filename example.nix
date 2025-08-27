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

    # VM configuration
    {
      virtualisation.diskSize = 32 * 1024;

      # following configuration is used only by nixos-rebuild build-vm
      virtualisation.vmVariant = {
        boot.growPartition = false;
        virtualisation = {
          cores = 3;
          graphics = false;
          memorySize = 2 * 1024;
        };
      };
    }

    # Docker configuration
    ({ inputs, config, pkgs, ... }: {
      imports = [
        (inputs.nixpkgs + "/nixos/modules/profiles/qemu-guest.nix")
        (inputs.nixpkgs + "/nixos/modules/installer/cd-dvd/channel.nix")
        (inputs.nixpkgs + "/nixos/modules/virtualisation/disk-image.nix")
      ];
      boot.kernelParams = [ "console=ttyS0" ];
      boot.loader.timeout = 0;
      image = {
        baseName = "nixos";
        efiSupport = false;
      };
      system.build.docker = pkgs.dockerTools.buildImage {
        name = "dotnix-docker";
        tag = "latest";
        copyToRoot = pkgs.buildEnv {
          name = "dotnix-docker-image-root";
          paths = [
            pkgs.qemu
          ];
          pathsToLink = [
            "/bin"
          ];
        };
        config = {
          os = "linux";
          Cmd = [
            "qemu-system-x86_64"
            "-enable-kvm"
            "-drive" "file=${config.system.build.image}/nixos.qcow2,format=qcow2,if=virtio"
            "-nographic"
            "-m" (toString config.virtualisation.vmVariant.virtualisation.memorySize)
          ];
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
    })
  ];
}
