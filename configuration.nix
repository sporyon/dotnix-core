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
      };
      security.selinux.packages = [
        (pkgs.writeTextFile {
          name = "polkadot-selinux-module";
          destination = "/share/selinux/modules/polkadot.cil";
          text = ''
            (type polkadot_validator_service_t)
            (typeattributeset domain (polkadot_validator_service_t))
            (roletype system_r polkadot_validator_service_t)

            (type polkadot_validator_state_t)
            (roletype object_r polkadot_validator_state_t)

            (context polkadot_validator_context (system_u object_r polkadot_validator_state_t (systemlow systemlow)))
            (filecon "/var/lib/private/polkadot-validator(/.*)?" any polkadot_validator_context)

            (type polkadot_p2p_port_t)
            (roletype object_r polkadot_p2p_port_t)
            (portcon tcp 30333 (system_u object_r polkadot_p2p_port_t (systemlow systemlow)))

            (type polkadot_prometheus_port_t)
            (roletype object_r polkadot_prometheus_port_t)
            (portcon tcp 9615 (system_u object_r polkadot_prometheus_port_t (systemlow systemlow)))

            (type polkadot_rpc_port_t)
            (roletype object_r polkadot_rpc_port_t)
            (portcon tcp 9944 (system_u object_r polkadot_rpc_port_t (systemlow systemlow)))

            ; Allow connecting to boot nodes.
            (allow polkadot_validator_service_t port_type (tcp_socket (name_connect)))

            ; This is used for mDNS (port 5353, UDP)
            (allow polkadot_validator_service_t howl_port_t (udp_socket (name_bind)))
            ; Ideally we would like to use
            ;   (portcon udp (32768 60999) (system_u object_r ephemeral_port_t (systemlow systemlow)))
            ;   (allow polkadot_validator_service_t ephemeral_port_t (udp_socket (name_bind)))
            ; but even when defining the ephemeral port range, the ports used by mDNS unreserved_port_t.
            ; This is probably due to some quirk in refpolicy, but the exact cause hasn't been determined
            ; as its not really a security concern to allow polkadot to listen to any unreserved port.
            (allow polkadot_validator_service_t unreserved_port_t (udp_socket (name_bind)))
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

