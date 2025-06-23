{ inputs, pkgs, ... }: {
  imports = [
    inputs.self.nixosModules.selinux
    inputs.self.nixosModules.polkadot-validator
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

      systemd.tmpfiles.rules = [
        "d /var/lib/private/polkadot-validator 0700 - -"
      ];

      systemd.services.polkadot-validator.serviceConfig = {
        SELinuxContext = "system_u:system_r:polkadot_validator_service_t";
        ExecStart = lib.mkForce (pkgs.writers.writeDash "test" ''
          ${lib.getExe' pkgs.selinux.coreutils "id"}
          ${lib.getExe' pkgs.selinux.coreutils "ls"} -laZ "$STATE_DIRECTORY"
          ${lib.getExe' pkgs.selinux.coreutils "sleep"} infinity
        '');
      };
      security.selinux.packages = [
        (pkgs.selinux.makeModule "dotnix/polkadot" {
          fileContexts = ''
            /var/lib/private/polkadot-validator(/.*)? system_u:object_r:polkadot_validator_state_t
          '';
          typeEnforcement = ''
            module polkadot 1.0;

            require {
              attribute domain;
              role system_r;
            }

            type polkadot_validator_service_t;
            typeattribute polkadot_validator_service_t domain;
            role system_r types polkadot_validator_service_t;

            type polkadot_validator_state_t;
          '';
        })
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
      memorySize = 2048; # Use 2048MiB memory.
      cores = 3;
      graphics = false;
    };
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  security.auditd.enable = true;

  security.selinux.enable = true;
  security.selinux.packages = [
    pkgs.dotnix-selinux-policy
  ];

  environment.systemPackages = [
    pkgs.htop

    # Utilities for working with SELinux interactively
    pkgs.audit
    pkgs.libselinux
    pkgs.policycoreutils
    pkgs.selinux.coreutils
    pkgs.selinux.selinux-python
  ];

  nixpkgs.overlays = [
    inputs.self.overlays.default
    (self: super: {
      dotnix-selinux-policy =
        pkgs.symlinkJoin {
          name = "dotnix-selinux-policy";
          paths = [
            (pkgs.selinux.makeModule "dotnix/examplesecret" {
              fileContexts = ''
                /examplesecret(/.*)? system_u:object_r:examplesecret_t
              '';
              typeEnforcement = ''
                module examplesecret 1.0;

                require {
                  class dir { getattr open read search };
                  class file { getattr open read relabelto };
                  class filesystem { associate };
                  type fs_t;
                  type unconfined_t;
                }

                type examplesecret_t;

                allow examplesecret_t fs_t:filesystem associate;
                allow unconfined_t examplesecret_t:dir { getattr open read search };
                allow unconfined_t examplesecret_t:file { getattr open read relabelto };
              '';
            })
          ];
        };
    })
  ];

  systemd.tmpfiles.rules = [
    "d /examplesecret 0777 - - -"
  ];

  systemd.services.dotnix-selinux-setup = {
    description = "Dotnix SELinux Setup";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = pkgs.writers.writeDash "dotnix-selinux-setup" ''
        echo this is an examplesecret > /examplesecret/examplesecret.txt
      '';
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  system.stateVersion = "24.11";
}

