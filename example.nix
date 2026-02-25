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

      # Enable rebuild within a VM
      # usage: nixos-rebuild switch --flake /etc/nixos#example-$(uname -m)-linux
      environment.etc.nixos.source = inputs.self;

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

    # Disk image configuration
    ({ config, inputs, lib, pkgs, ... }: {
      # Allow booting from USB storage.
      boot.initrd.availableKernelModules = [
        "usb_storage"
        "uas"
        "scsi_mod"
      ];
      system.build.diskImage = import (inputs.nixpkgs + "/nixos/lib/make-disk-image.nix") {
        inherit config lib pkgs;
        #label = "nixos";
        partitionTableType = "hybrid";
        #format = "raw";
        #bootSize = "128M";
        additionalSpace = "0M";
        copyChannel = true;
      };
      system.build.diskImageCompressed =
        pkgs.runCommand "nixos-disk-image.zst" {} ''
          ${pkgs.coreutils}/bin/mkdir "$out"
          ${pkgs.zstd}/bin/zstd --compress --ultra \
              ${config.system.build.diskImage}/nixos.img \
              -o $out/nixos.img.zst
        '';
    })

    # VM configuration
    {
      # following configuration is used only by nixos-rebuild build-vm
      virtualisation.vmVariant = {
        boot.kernelParams = [ "console=ttyS0" ];
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
      dotnix.polkadot-validator.canonicalInstanceName = "default";
      dotnix.polkadot-validator.instances.default.enable = true;
      dotnix.polkadot-validator.instances.default.name = "sporyon-dotnix-westend2";
      dotnix.polkadot-validator.instances.default.chain = "westend";
      dotnix.polkadot-validator.instances.default.extraArgs = [
        "--db-storage-threshold=0"
      ];

      environment.systemPackages = [
        config.dotnix.polkadot-validator.instances.default.package
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

    # Secure Boot configuration
    ({ inputs, pkgs, ... }: {
      imports = [
        inputs.self.nixosModules.secure-boot
      ];

      dotnix.secure-boot.enable = true;

      # TODO move this, or parts of it, to ./nixosModules/secure-boot.nix or to "VM configuration" below
      virtualisation.vmVariant = {
        virtualisation = {
          useBootLoader = true;
          useEFIBoot = true;
          useSecureBoot = true;
          efi.OVMF = let
            OVMF = (pkgs.OVMF.override { secureBoot = true; }).fd;
          in
            OVMF // {
              variables = pkgs.runCommand "OVMF_VARS.SecureBoot.fd" {} ''
                ${pkgs.python3Packages.virt-firmware}/bin/virt-fw-vars \
                    -i ${OVMF.variables} \
                    -o $out \
                    --set-true SecureBoot
              '';
            };
        };
      };
    })
  ];
}
