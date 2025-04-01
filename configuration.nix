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
            (pkgs.selinux.makeModule "dotnix/examplesecret" ''
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
            '')
          ];
        };
    })
  ];

  systemd.services.dotnix-selinux-setup = {
    description = "Dotnix SELinux Setup";
    requiredBy = [ "multi-user.target" ];
    after = [ "selinux-modular-setup.service" ];
    serviceConfig = {
      ExecStart = pkgs.writers.writeDash "dotnix-selinux-setup" ''
        if ! test -e /examplesecret; then
          mkdir -m 0777 /examplesecret
          echo this is an examplesecret > /examplesecret/examplesecret.txt
          ${pkgs.selinux.coreutils}/bin/chcon -t examplesecret_t /examplesecret
          ${pkgs.selinux.coreutils}/bin/chcon -t examplesecret_t /examplesecret/examplesecret.txt
        fi
      '';
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  system.stateVersion = "24.11";
}

