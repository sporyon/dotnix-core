{ config, lib, pkgs, ... }: {
  options.dotnix.polkadot-validator = {
    enable = lib.mkEnableOption "Polkadot validator";
  };
  config = lib.mkIf config.dotnix.polkadot-validator.enable {
    systemd.services.polkadot-validator = {
      wantedBy = [
        "multi-user.target"
      ];
      after = [
        "network.target"
      ];
      serviceConfig = {
        ExecStartPre = "${pkgs.polkadot}/bin/polkadot --version";
        ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
        DynamicUser = true;
        User = "polkadot";
        Group = "polkadot";
        Restart = "always";
        RestartSec = 120;
        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictAddressFamilies = "AF_INET AF_INET6 AF_NETLINK AF_UNIX";
        RestrictNamespaces = "false";
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "landlock_add_rule landlock_create_ruleset landlock_restrict_self seccomp mount umount2"
          "~@clock @module @reboot @swap @privileged"
          "pivot_root"
        ];
        UMask = "0027";
      };
      unitConfig = {
        Description = "Polkadot Node";
        Documentation = "https://github.com/paritytech/polkadot";
      };
    };
  };
}
