# THIS CONFIGURATION IS JUST FOR TESTING PURPOSES NOT FOR PRODUCTION USE
{
  imports = [
    # Base configuration
    ({ config, inputs, lib, pkgs, ... }: {
      imports = [
        inputs.self.nixosModules.polkadot-validator
        inputs.self.nixosModules.selinux
      ];
      nixpkgs.overlays = [
        inputs.self.overlays.default
      ];

      boot.kernelParams = [ "hidepid=2" ];

      environment.variables = {
        NIX_REMOTE = "daemon";
      };

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

      # Enable nixos-rebuild
      system.activationScripts.nixos-config = let
        flake = pkgs.writeText "nixos-config" /* nix */ ''
          {
            inputs.dotnix-core.url = ${builtins.toJSON inputs.self};
            outputs = inputs: {
              nixosConfigurations.${builtins.toJSON config.networking.hostName} =
                inputs.dotnix-core.nixosConfigurations.${builtins.toJSON "example-${config.nixpkgs.system}"};
            };
          }
        '';
      in /* sh */ ''
        cp --update=none -L ${flake} /etc/nixos/flake.nix
      '';

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
      system.build.diskImage =
        if !config.dotnix.secure-boot.enable then
          throw "Secure Boot must be enabled to build images."
        else
          import (inputs.nixpkgs + "/nixos/lib/make-disk-image.nix") {
            inherit config lib pkgs;
            partitionTableType = "hybrid";
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
    ({ config, inputs, lib, pkgs, ... }: {
      # following configuration is used only by nixos-rebuild build-vm
      virtualisation.vmVariant = {
        boot.kernelParams = [ "console=ttyS0" ];
        virtualisation = {
          cores = 3;
          diskSize = 32 * 1024;
          graphics = false;
          memorySize = 4 * 1024;
        };

        # Enable nixos-rebuild within a VM
        system.activationScripts.nixos-config = lib.mkForce (let
          flake = pkgs.writeText "nixos-config" /* nix */ ''
            {
              inputs.dotnix-core.url = ${builtins.toJSON inputs.self};
              outputs = inputs: {
                nixosConfigurations.${builtins.toJSON config.networking.hostName} = let
                  base = inputs.dotnix-core.nixosConfigurations.${builtins.toJSON "example-${config.nixpkgs.system}"};
                in base.extendModules {
                  modules = [
                    # Ensure that rebuilds stay fit for the VM.
                    {
                      boot.kernelParams = [ "console=ttyS0" ];
                    }
                  ];
                };
              };
            }
          '';
        in /* sh */ ''
          cp --update=none -L ${flake} /etc/nixos/flake.nix
        '');
      };
    })

    # Docker configuration
    ({ config, inputs, lib, options, pkgs, ... }: {
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
              ${lib.optionalString (options.dotnix?secure-boot && config.dotnix.secure-boot.enable) /* sh */ ''
                if test -d /shared; then
                  export NIX_DISK_IMAGE=''${NIX_DISK_IMAGE-/shared/nixos.qcow2}
                  export NIX_EFI_VARS=''${NIX_EFI_VARS-/shared/OVMF_VARS.fd}
                fi
              ''}
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
    ({ inputs, ... }: {
      imports = [
        inputs.self.nixosModules.secure-boot
      ];

      dotnix.secure-boot.enable = true;
    })

    # VM-related Secure Boot configuration
    ({ pkgs, ... }: {
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
