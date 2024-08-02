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

    sessionPubkeysFile = lib.mkOption {
      type = lib.types.str;
      default = "/root/polkadot-validator.session_pubkeys";
      description = ''
        Path for storing the session public keys.
      '';
    };

    enableLoadCredentialWorkaround = lib.mkEnableOption "workaround when LoadCredential= doesn't work" // {
      interal = true;
    };

    snapshotDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/root";
      description = ''
        Path to the directory where snapshots should be created.
      '';
    };

    backupDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/root";
      description = ''
        Path to the directory where backups should be created.
      '';
    };
  };
  config = let
    cfg = config.dotnix.polkadot-validator;
  in lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.polkadot-validator
    ];
    nixpkgs.overlays = [(self: super: {
      polkadot-validator = self.writers.writeBashBin "polkadot-validator" ''
        # polkadot-validator - Management Utility for the Polkadot Validator
        #
        # SYNOPSIS
        #   polkadot-validator --set-node-key
        #   polkadot-validator --unset-node-key
        #
        #   polkadot-validator --rotate-keys
        #
        #   polkadot-validator --backup-keystore
        #
        #   polkadot-validator --clean-logs
        #   polkadot-validator --restart
        #   polkadot-validator --stop
        #
        #   polkadot-validator --snapshot
        #   polkadot-validator --restore SNAPSHOT_URL
        #
        #   polkadot-validator --full-archive-node-setup
        #   polkadot-validator --full-setup
        #   polkadot-validator --prepare
        #   polkadot-validator --update-process-exporter
        #   polkadot-validator --update-polkadot
        #   polkadot-validator --update-promtail
        #   polkadot-validator --update-snapshot-script
        #
        set -efu

        BACKUP_DIR=${lib.escapeShellArg cfg.backupDirectory}
        CHAIN=${lib.escapeShellArg cfg.chain}
        KEY_FILE=${lib.escapeShellArg cfg.keyFile}
        PATH=${lib.makeBinPath [
          # XXX `or null` is required here because there appears to be an
          # inconsistency evaluating overlays, causing checks to fail with
          # error: attribute 'polkadot-rpc' missing
          (self.polkadot-rpc or null)

          self.coreutils
          self.curl
          self.gnused
          self.gnutar
          self.jq
          self.lz4
          self.systemd
          self.xxd
        ]}
        SNAPSHOT_DIR=${lib.escapeShellArg cfg.snapshotDirectory}

        main() {
          if test "$(id -u)" != 0; then
            echo "$0: error: this command must be run as root" >&2
            exit 1
          fi
          case $1 in
            # Node key management
            --set-node-key) set_node_key;;
            --unset-node-key) unset_node_key;;

            # Session key management
            --rotate-keys) rotate_keys;;

            # Keystore management
            --backup-keystore) backup_keystore;;

            # Service management
            --clean-logs) clean_logs;;
            --restart) restart;;
            --stop) stop;;

            # Database snapshot management
            --snapshot) snapshot;;
            --restore) shift; restore "$@";;

            # Informative functions
            --full-archive-node-setup) full_archive_node_setup;;
            --full-setup) full_setup;;
            --prepare) prepare;;
            --update-process-exporter) update_process_exporter;;
            --update-polkadot) update_polkadot;;
            --update-promtail) update_promtail;;
            --update-snapshot-script) update_snapshot_script;;

            *)
              echo "$0: error: bad argument: $1" >&2
              exit 1
          esac
        }

        # Node key management
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

        # Session key management
        rotate_keys() (
          chain_path=$(get_chain_path)
          session_pubkeys=$(rpc author_rotateKeys | jq -er .result)
          echo "$session_pubkeys" | tee ${lib.escapeShellArg cfg.sessionPubkeysFile}
        )

        # Keystore management
        backup_keystore() (
          chain_path=$(get_chain_path)
          now=$(date -Is)
          archive=$BACKUP_DIR/''${CHAIN}_keystore_$now.tar.lz4
          tar --use-compress-program=lz4 -C "$chain_path" -v -c -f "$archive" keystore >&2
          echo "$archive"
        )

        # Service management
        clean_logs() {
          journalctl --vacuum-time=2d
        }
        restart() {
          systemctl stop polkadot-validator.service
          ${lib.optionalString cfg.enableLoadCredentialWorkaround ''
            install -D -m 0444 "$KEY_FILE" /run/credentials/polkadot-validator.service/node_key
          ''}
          systemctl start polkadot-validator.service
        }
        stop() {
          systemctl stop polkadot-validator.service
        }

        # Database snapshot management
        snapshot() (
          chain_path=$(get_chain_path)
          response=$(rpc chain_getBlock)
          block_height_base16=$(echo "$response" | jq -er .result.block.header.number)
          block_height_base10=$(printf %d "$block_height_base16")
          archive=$SNAPSHOT_DIR/''${CHAIN}_$block_height_base10.tar.lz4
          (
            trap restart EXIT
            stop
            tar --use-compress-program=lz4 -C "$chain_path" -v -c -f "$archive" db >&2
          )
          echo "file://$archive"
        )
        restore() (
          snapshot_url=$1
          chain_path=$(get_chain_path)
          mkdir -p "$chain_path"
          (
            trap 'rmdir "$chain_path"/snapshot' EXIT
            mkdir "$chain_path"/snapshot
            (
              trap 'rm "$chain_path"/snapshot/tarball' EXIT
              case $snapshot_url in
                file:*)
                  ln -s "''${snapshot_url#file://}" "$chain_path"/snapshot/tarball
                  ;;
                http:*|https:*)
                  curl "$snapshot_url" -O "$chain_path"/snapshot/tarball
                  ;;
                *)
                  echo "$0: restore: unknown scheme: $snapshot_url" >&2
                  return 1
              esac
              tar --use-compress-program=lz4 -C "$chain_path"/snapshot -v -x -f "$chain_path"/snapshot/tarball
              chown -R polkadot:polkadot "$chain_path"/snapshot/db
              (
                trap restart EXIT
                stop
                rm -fR "$chain_path"/db.backup
                mv -T "$chain_path"/db "$chain_path"/db.backup
                mv "$chain_path"/snapshot/db "$chain_path"/db
              )
            )
          )
        )

        # Informative functions
        full_archive_node_setup() {
          print_install_instructions
        }
        full_setup() {
          print_setup_instructions
        }
        prepare() {
          print_setup_instructions
        }
        update_process_exporter() {
          print_update_instructions
        }
        update_polkadot() {
          print_update_instructions
        }
        update_promtail() {
          print_update_instructions
        }
        update_snapshot_script() {
          print_update_instructions
        }

        # Helper functions
        get_chain_path() (
          pid=$(systemctl show --property MainPID --value polkadot-validator.service)
          path=$(ls -l /proc/"$pid"/fd | sed -nr '
            s:.* -> (/var/lib/private/polkadot-validator/chains/[^/]+)/db/.*:\1:p;T;q
          ')
          if test -z "$path"; then
            echo "$0: get_chain_path: error: path not found." >&2
            return 1
          fi
          echo "$path"
        )
        print_setup_instructions() (
          cat >&2 ${self.writeText "setup.txt" ''
            This function has no effect.
            The Polkadot validator has already been setup on this system.

            For details about Dotnix, see
            https://github.com/sporyon/dotnix-core/blob/main/README.md
          ''}
        )
        print_update_instructions() (
          cat >&2 ${self.writeText "update-instructions.txt" ''
            The Polkadot validator cannot be updated interactively.
            Instead, updated your Nix configuration and rebuild this system.

            For details about updating Nix flakes, see
            https://nix.dev/manual/nix/2.23/command-ref/new-cli/nix3-flake-update

            For details about Dotnix, see
            https://github.com/sporyon/dotnix-core/blob/main/README.md
          ''}
        )

        main "$@"
      '';
    })];
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
        pkgs.polkadot-validator
        pkgs.systemd
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writers.writeDash "polkadot-validator-orchestrator" ''
          if test -e "$KEY_FILE"; then
            if ! systemctl is-active --quiet polkadot-validator.service ||
               ! sha1sum --check --status "$CHECKSUM_FILE"
            then
              sha1sum "$KEY_FILE" > "$CHECKSUM_FILE"
              polkadot-validator --restart
            else
              : # nothing to do
            fi
          else
            if systemctl is-active --quiet polkadot-validator.service; then
              polkadot-validator --stop
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
