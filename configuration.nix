{ inputs, pkgs, ... }: {
  imports = [
    inputs.self.nixosModules.selinux
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
    (pkgs.dotnix.makeModule "dotnix/polkadot" {
      typeEnforcement = '' 
        module polkadot 1.0;

        require {
          class dir [ open search};
          }

          type polkadot_validator_service_t;
          '';
        };
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
                /root/polkadot-validator.node_key system_u:object_r:polkadot-validator.service polkadot-validator.node_key
                /var/lib/polkadot-validator(/.*)?  system_u:object_r:var_lib_t
                /var/lib/private/polkadot-validator(/.*)? system_u:object_r:var_lib_t

                /root/polkadot-validator.node_key system_u:object_r:polkadot-validator-orchestrator.service
                /var/lib/private/polkadot-validator(/.*)? system_u:object_r:polkadot-validator-orchestrator.service
                /var/lib/polkadot-validator(/.*)? system_u:object_r:polkadot-validator-orchestrator.service
 
                /root/polkadot-validator.node_key system_u:object_r:polkadot-validator-orchestrator-starter.service
                /var/lib/private/polkadot-validator(/.*)? system_u:object_r:polkadot-validator-orchestrator-starter.service
                /var/lib/polkadot-validator(/.*)? system_u:object_r:polkadot-validator-orchestrator-starter.service
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
    "d /var/lib/private/polkadot-validator/ 0700 polkadot polkadot"
    " /root/polkadot-validator.node_key 0700 polkadot polkadot"
    "d /var/lib/polkadot-validator/ 0700 polkadot polkadot"
    "d /run/current-system/sw/bin/polkadot 0700 polkadot polkadot"
    "d /run/current-system/sw/bin/polkadot-validator 0700 polkadot polkadot"
    "d /run/current-system/sw/bin/polkadot-prepare-worker 0700 polkadot polkadot"
    "d /run/current-system/sw/bin/polkadot-execute-worker 0700 polkadot polkadot"
    # Todo search for more "d /var/lib/private/Todo 0777 - - -"
  ];

#  systemd.services.dotnix-selinux-setup = {
#    description = "Dotnix SELinux Setup";
#    wantedBy = [ "multi-user.target" ];
#    serviceConfig = {
#      ExecStart = pkgs.writers.writeDash "dotnix-selinux-setup" ''
#        echo this is an examplesecret > /examplesecret/examplesecret.txt
#      '';
#      Type = "oneshot";
#      RemainAfterExit = true;
#    };
#  };

  systemd.services.dotnix-selinux-setup = {
    description = "Dotnix SELinux Setup";
    wantedBy = [ "multi-user.target" ];
    requiredBy = [ "pokadot-validator.service" ];
    before = [ "polkadot-validator.service"];
    serviceConfig = {
      ExecStart = pkgs.writers.writeDash "dotnix-selinux-setup" ''
        echo this is an examplesecret > /examplesecret/examplesecret.txt
        mkdir --context --mode=0700 --verbose /var/lib/private/polkadot-validator/
        mkdir --context --mode=0700 --verbose /var/lib/private/polkadot-validator/
        mkdir --context --mode=0700 --verbose /root/polkadot-validator.node_key
        mkdir --context --mode=0700 --verbose /var/lib/polkadot-validator/
        mkdir --context --mode=0700 --verbose /run/current-system/sw/bin/polkadot/
      
        chown nobody:nogroup /var/lib/private/polkadot-validator/
        chown nobody:nogroup /var/lib/private/polkadot-validator/
        chown polkadot:polkadot /root/polkadot-validator.node_key
        chown polkadot:polkadot /var/lib/polkadot-validator/
        chown polkadot:polkadot /run/current-system/sw/bin/polkadot/
      '';
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  system.stateVersion = "24.11";
}

