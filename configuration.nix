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
    "d /var/lib/private/polkadot-validator/* 0777 - - -"
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
        mkdir --context --mode=0700 --verbose /var/lib/private/polkadot-validator/*
        mkdir --context --mode=0700 --verbose /var/lib/private/polkadot/*
        # Todo how do i find the rest
        chown nobody:nogroup /var/lib/private/polkadot-validator/*
        chown polkadot:polkadot /var/lib/private/polkadot-validator/*
      '';
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  system.stateVersion = "24.11";
}

