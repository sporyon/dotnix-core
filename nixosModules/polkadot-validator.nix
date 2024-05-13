{ config, lib, pkgs, ... }: {
  options.dotnix.polkadot-validator = {
    enable = lib.mkEnableOption "Polkadot validator";

    name = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        The human-readable name for this node.

        It's used as network node name.
      '';
    };
  };
  config = let
    cfg = config.dotnix.polkadot-validator;
  in lib.mkIf cfg.enable {
    systemd.services.polkadot-validator = {
      wantedBy = [
        "multi-user.target"
      ];
      after = [
        "network.target"
      ];
      serviceConfig = {
        ExecStart = "${pkgs.polkadot}/bin/polkadot ${lib.escapeShellArgs (lib.flatten [
          "--validator"
          (lib.optional (cfg.name != null) "--name=${cfg.name}")
        ])}";
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
        Description = "Polkadot Validator";
        Documentation = "https://github.com/paritytech/polkadot";
      };
    };
  };
}
