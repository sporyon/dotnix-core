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

    chain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Specify the chain specification.

        It can be one of the predefined ones (dev, local, or staging) or it
        can be a path to a file with the chainspec (such as one exported by
        the `build-spec` subcommand).
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["--sync=fast"];
      description = ''
        Additional arguments to be passed to polkadot.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.polkadot;
      defaultText = lib.literalExpression "pkgs.polkadot";
      description = ''
        Polkadot package to use.
      '';
    };

    keyFile = lib.mkOption {
      type = lib.types.str;
      default = "/root/polkadot-validator.node_key";
      description = ''
        Path to the Polkadot node key.
      '';
    };

    enableLoadCredentialWorkaround = lib.mkEnableOption "workaround when LoadCredential= doesn't work" // {
      interal = true;
    };
  };
  config = let
    cfg = config.dotnix.polkadot-validator;
  in lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writers.writeBashBin "polkadot-validator" ''
        # polkadot-validator - Management Utility for the Polkadot Validator
        #
        # SYNOPSIS
        #   polkadot-validator --set-node-key
        #   polkadot-validator --unset-node-key
        #
        set -efu
        KEY_FILE=${lib.escapeShellArg cfg.keyFile}
        PATH=${lib.makeBinPath [
          pkgs.coreutils
          pkgs.xxd
        ]}
        main() {
          case $1 in
            --set-node-key) set_node_key;;
            --unset-node-key) unset_node_key;;
            *)
              echo "$0: error: bad argument: $1" >&2
              exit 1
          esac
        }
        set_node_key() {
          if test -t 0; then
            read -p 'Polkadot validator node key: ' -r -s node_key
          else
            node_key=$(cat)
          fi
          umask 0077
          echo -n "$node_key" > "$KEY_FILE"
        }
        unset_node_key() {
          rm -f "$KEY_FILE"
        }
        main "$@"
      '')
    ];
    systemd.services.polkadot-validator = {
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/polkadot ${lib.escapeShellArgs (lib.flatten [
          "--validator"
          (lib.optional (cfg.name != null) "--name=${cfg.name}")
          (lib.optional (cfg.chain != null) "--chain=${cfg.chain}")
          "--base-path=%S/polkadot-validator"
          "--node-key-file=%d/node_key"
          cfg.extraArgs
        ])}";
        LoadCredential = [
          "node_key:${cfg.keyFile}"
        ];
        StateDirectory = "polkadot-validator";
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
    systemd.paths.polkadot-validator-orchestrator = {
      wantedBy = [
        "multi-user.target"
      ];
      pathConfig.PathChanged = cfg.keyFile;
    };
    systemd.services.polkadot-validator-orchestrator = {
      environment = {
        CHECKSUM_FILE = "%t/checksums";
        KEY_FILE = cfg.keyFile;
      };
      path = [
        pkgs.coreutils
        pkgs.systemd
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writers.writeDash "polkadot-validator-orchestrator" ''
          if test -e "$KEY_FILE"; then
            if systemctl is-active --quiet polkadot-validator.service; then
              if ! sha1sum --check --status "$CHECKSUM_FILE"; then
                sha1sum "$KEY_FILE" > "$CHECKSUM_FILE"
                ${lib.optionalString cfg.enableLoadCredentialWorkaround ''
                  install -D -m 0444 "$KEY_FILE" /run/credentials/polkadot-validator.service/node_key
                ''}
                systemctl restart polkadot-validator.service
              else
                : # nothing to do
              fi
            else
              sha1sum "$KEY_FILE" > "$CHECKSUM_FILE"
              ${lib.optionalString cfg.enableLoadCredentialWorkaround ''
                install -D -m 0444 "$KEY_FILE" /run/credentials/polkadot-validator.service/node_key
              ''}
              systemctl start polkadot-validator.service
            fi
          else
            if systemctl is-active --quiet polkadot-validator.service; then
              systemctl stop polkadot-validator.service
              rm "$CHECKSUM_FILE"
            else
              : # nothing to do
            fi
          fi
        '';
        RuntimeDirectory = "polkadot-validator-orchestrator";
        RuntimeDirectoryPreserve = true;
      };
      unitConfig = {
        Description = "Polkadot Validator Orchestrator";
        Documentation = "file:${pkgs.writeText "polkadot-validator-orchestrator.txt" ''
          The Polkadot Validator Orchestrator gets active whenever the
          Validator node key gets created, changed, or removed.  It is
          responsible for starting, restarting, stopping the Polkadot
          Validator, respectively.
        ''}";
      };
    };
    systemd.paths.polkadot-validator-orchestrator-starter = {
      wantedBy = [
        "multi-user.target"
      ];
      pathConfig = {
        PathExists = cfg.keyFile;
      };
    };
    systemd.services.polkadot-validator-orchestrator-starter = {
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.systemd}/bin/systemctl start polkadot-validator-orchestrator";
      };
      unitConfig = {
        Description = "Polkadot Validator Orchestrator Starter";
        Documentation = "file:${pkgs.writeText "polkadot-validator-orchestrator.txt" ''
          The Polkadot Validator Orchestrator Starter is responsible for
          starting the Polkadot Orchestrator on systems that have a node key
          configured but haven't experienced any key modifications.

          This ensures that the Polkadot Validator gets started after reboot on
          an already configured system.

          The separation of Polkadot Validator Orchestrator and Starter is
          required because of how systemd's PathChange= and PathExists= work:
          PathChange= activates its target unit once on each change while
          PathExists= activates its target unit continuously as long as the
          path exists.
        ''}";
      };
    };
  };
}
