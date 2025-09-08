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

    port = lib.mkOption {
      type = lib.types.port;
      default = 30333;
      description = ''
        Specify p2p protocol TCP port.
      '';
    };

    prometheusPort = lib.mkOption {
      type = lib.types.port;
      default = 9615;
      description = ''
        Specify Prometheus exporter TCP Port.
      '';
    };

    rpcPort = lib.mkOption {
      type = lib.types.port;
      default = 9944;
      description = ''
        Specify JSON-RPC server TCP port.
      '';
    };

    keyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/secrets/polkadot-validator.node_key";
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

    snapshotDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/var/snapshots";
      description = ''
        Path to the directory where snapshots should be created.
      '';
    };

    backupDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/var/backups";
      description = ''
        Path to the directory where backups should be created.
      '';
    };

    credentialsDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/run/credentials/polkadot-validator.service";
      description = ''
        Path to the directory where credentials are stored.
      '';
    };

    stateDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/private/polkadot-validator";
      description = ''
        Path to the directory where state should be stored.
      '';
    };

    selinux.orchestratorDomainType = lib.mkOption {
      type = lib.types.str;
      default = "polkadot_validator_orchestrator_t";
      description = ''
        SELinux domain the Polkadot Validator Orchestrator should run in.
      '';
    };

    selinux.validatorDomainType = lib.mkOption {
      type = lib.types.str;
      default = "polkadot_validator_service_t";
      description = ''
        SELinux domain the Polkadot Validator should run in.
      '';
    };

    selinux.credentialsObjectType = lib.mkOption {
      type = lib.types.str;
      default = "polkadot_validator_credentials_t";
      description = ''
        SELinux object type of Polkadot Validator state directories and files.
      '';
    };

    selinux.secretsObjectType = lib.mkOption {
      type = lib.types.str;
      default = "secrets_t";
      description = ''
        SELinux object type of Polkadot Validator snapshot directory and files.
      '';
    };

    selinux.snapshotsObjectType = lib.mkOption {
      type = lib.types.str;
      default = "polkadot_validator_snapshots_t";
      description = ''
        SELinux object type of Polkadot Validator snapshot directory and files.
      '';
    };

    selinux.stateObjectType = lib.mkOption {
      type = lib.types.str;
      default = "polkadot_validator_state_t";
      description = ''
        SELinux object type of Polkadot Validator state directory and files.
      '';
    };

    selinux.p2pPortType = lib.mkOption {
      type = lib.types.str;
      default = "polkadot_p2p_port_t";
      description = ''
        SELinux port type of Polkadot P2P port.
      '';
    };

    selinux.prometheusPortType = lib.mkOption {
      type = lib.types.str;
      default = "polkadot_prometheus_port_t";
      description = ''
        SELinux port type of the Polkadot Prometheus port.
      '';
    };

    selinux.rpcPortType = lib.mkOption {
      type = lib.types.str;
      default = "polkadot_rpc_port_t";
      description = ''
        SELinux port type of Polkadot RPC port.
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

        KEY_FILE=${lib.escapeShellArg cfg.keyFile}
        PATH=${lib.makeBinPath [
          # XXX `or pkgs.emptyDirectory` is required here because there appears
          # to be an inconsistency evaluating overlays, causing checks to fail
          # with error: attribute 'polkadot-rpc' missing
          (pkgs.polkadot-rpc or pkgs.emptyDirectory)

          self.polkadot
          self.polkadot-get_chain_path

          self.coreutils
          self.curl
          self.gnused
          self.gnutar
          self.jq
          self.lz4
          self.systemd
          self.xxd
        ]}
        main() {
          if test "$UID" != 0; then
            echo "$0: error: this command must be run as root" >&2
            exit 1
          fi
          case $1 in
            # Node key management
            --set-node-key) set_node_key;;
            --unset-node-key) unset_node_key;;

            # Session key management
            --rotate-keys)
              wait_for_polkadot_validator
              rotate_keys
              ;;

            # Keystore management
            --backup-keystore)
              wait_for_polkadot_validator
              backup_keystore
              ;;

            # Service management
            --clean-logs) clean_logs;;
            --restart) restart;;
            --stop) stop;;

            # Database snapshot management
            --snapshot)
              wait_for_polkadot_validator
              snapshot
              ;;
            --restore)
              wait_for_polkadot_validator
              shift
              restore "$@"
              ;;

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

        # Wait until the Polkadot Validator service is ready
        wait_for_polkadot_validator() {
          if test "$(systemctl is-active polkadot-validator.service)" != active; then
            echo "$0: error: Polkadot Validator service not running" >&2
            return 1
          fi
          if ! rpc system_name >/dev/null 2>&1; then
            echo "$0: info: waiting for the Polkadot Validator service to start..." >&2
            until rpc system_name >/dev/null 2>&1; do
              sleep 1
            done
          fi
        }

        # Node key management
        set_node_key() {
          if test -t 0; then
            read -p 'Polkadot validator node key: ' -r -s node_key
          else
            node_key=$(cat)
          fi
          if ! echo -n "$node_key" | polkadot key inspect-node-key 2>/dev/null >&2; then
            echo "$0: set_node_key: invalid input: bad node key" >&2
            return 1
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
          service=polkadot-validator-backup-keystore.service
          start_time=$(date -Is)
          systemctl start "$service"
          Result=$(systemctl show "$service" -p Result | cut -d= -f2-)
          if test "$Result" != success; then
            echo "$0: backup_keystore: failed." >&2
            ExecMainStatus=$(systemctl show "$service" -p ExecMainStatus | cut -d= -f2-)
            exit $ExecMainStatus
          fi
          id=$(
            journalctl -o json -u "$service" --since '1 minute ago' |
            jq -sr 'map(._SYSTEMD_INVOCATION_ID | select(. != null))[-1]'
          )
          path=$(
            journalctl -o cat _SYSTEMD_INVOCATION_ID="$id" |
            sed -nr '\|^${cfg.backupDirectory}|p' | tail -n 1
          )
          if test -z "$path"; then
            echo "$0: backup_keystore: error: failed to obtain backup path." >&2
            exit 1
          fi
          echo "$path"
        )

        # Service management
        clean_logs() {
          journalctl --vacuum-time=2d
        }
        restart() {
          systemctl restart polkadot-validator.service
        }
        stop() {
          systemctl stop polkadot-validator.service
        }

        # Database snapshot management
        snapshot() (
          journalctl -f -n 0 -u polkadot-validator-snapshot-create.service >&2 &
          trap 'kill %1' EXIT
          start_time=$(date -Is)
          systemctl start polkadot-validator-snapshot-create.service
          Result=$(systemctl show polkadot-validator-snapshot-create.service -p Result | cut -d= -f2-)
          ExecMainStatus=$(systemctl show polkadot-validator-snapshot-create.service -p ExecMainStatus | cut -d= -f2-)
          if test "$Result" != success; then
            echo "$0: snapshot: error: failed." >&2
            exit $ExecMainStatus
          fi
          path=$(
            journalctl --since="$start_time" -u polkadot-validator-snapshot-create.service |
            sed -nr 's|.*(file://.*)|\1|p' | tail -n 1
          )
          if test -z "$path"; then
            echo "$0: snapshot: error: failed to obtain snapshot path." >&2
            exit 1
          fi
          echo "$path"
        )
        restore() (
          snapshot_url=$1
          journalctl -f -n 0 -u polkadot-validator-snapshot-restore.service >&2 &
          trap 'kill %1' EXIT
          systemctl set-environment POLKADOT_VALIDATOR_SNAPSHOT_RESTORE_URL="$snapshot_url"
          systemctl start polkadot-validator-snapshot-restore.service
          systemctl unset-environment POLKADOT_VALIDATOR_SNAPSHOT_RESTORE_URL
          Result=$(systemctl show polkadot-validator-snapshot-restore.service -p Result | cut -d= -f2-)
          ExecMainStatus=$(systemctl show polkadot-validator-snapshot-restore.service -p Result | cut -d= -f2-)
          if test "$Result" != success; then
            echo "$0: restore: error: failed." >&2
            exit $ExecMainStatus
          fi
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
      polkadot-get_chain_path = pkgs.writers.writeDashBin "get_chain_path" ''
        set -efu
        spec=$(${cfg.package}/bin/polkadot build-spec ${lib.escapeShellArgs (lib.flatten [
          (lib.optional (cfg.chain != null) "--chain=${cfg.chain}")
        ])})
        chain_id=$(echo "$spec" | ${pkgs.jq}/bin/jq -er .id)
        path=${cfg.stateDirectory}/chains/$chain_id
        if ! test -d "$path"; then
          echo "$0: error: path not found." >&2
          return 1
        fi
        echo "$path"
      '';
    })];
    security.selinux.packages = [
      (pkgs.writeTextFile {
        name = "system-selinux-module";
        destination = "/share/selinux/modules/system.cil";
        text = /* cil */ ''
          ;; This module contains rules needed by systemd before transitioning
          ;; to service contexts.

          ; Allow root to log in.
          (typeattributeset can_exec_unlabeled (sysadm_systemd_t))
          (allow sysadm_systemd_t default_t (dir (search)))
          (allow sysadm_systemd_t kernel_t (fd (use)))
          (allow sysadm_systemd_t nscd_runtime_t (dir (search)))
          (allow sysadm_systemd_t tty_device_t (chr_file (getattr ioctl read write)))
          (allow sysadm_systemd_t unlabeled_t (dir (getattr search)))
          (allow sysadm_systemd_t unlabeled_t (file (entrypoint getattr execute open map read)))
          (allow sysadm_systemd_t unlabeled_t (lnk_file (read)))

          ; Allow basic operations.
          (allow sysadm_systemd_t default_t (dir (getattr)))
          (allow sysadm_systemd_t default_t (sock_file (getattr write)))
          (allow sysadm_systemd_t fs_t (filesystem (remount)))
          (allow sysadm_systemd_t http_port_t (tcp_socket (name_connect)))
          (allow sysadm_systemd_t init_runtime_t (dir (add_name create write)))
          (allow sysadm_systemd_t init_runtime_t (fifo_file (create open read)))
          (allow sysadm_systemd_t init_tmpfs_t (file (getattr)))
          (allow sysadm_systemd_t init_t (system (reload status)))
          (allow sysadm_systemd_t init_t (unix_stream_socket (connectto)))
          (allow sysadm_systemd_t init_var_lib_t (dir (search)))
          (allow sysadm_systemd_t init_var_lib_t (file (getattr map open read)))
          (allow sysadm_systemd_t kernel_t (dir (getattr)))
          (allow sysadm_systemd_t kernel_t (system (syslog_read)))
          (allow sysadm_systemd_t kmsg_device_t (chr_file (read)))
          (allow sysadm_systemd_t kvm_device_t (chr_file (read write)))
          (allow sysadm_systemd_t nscd_runtime_t (sock_file (write)))
          (allow sysadm_systemd_t nsfs_t (file (open read)))
          (allow sysadm_systemd_t security_t (security (read_policy)))
          (allow sysadm_systemd_t self (capability2 (syslog)))
          (allow sysadm_systemd_t self (capability (sys_admin)))
          (allow sysadm_systemd_t self (process (setpgid)))
          (allow sysadm_systemd_t self (tcp_socket (getopt read write)))
          (allow sysadm_systemd_t ssh_home_t (dir (getattr read)))
          (allow sysadm_systemd_t systemd_journal_t (dir (getattr open read remove_name search watch write)))
          (allow sysadm_systemd_t systemd_journal_t (file (getattr map open read unlink write)))
          (allow sysadm_systemd_t systemd_passwd_runtime_t (dir (getattr open read watch)))
          (allow sysadm_systemd_t tmpfs_t (dir (create rename reparent rmdir setattr)))
          (allow sysadm_systemd_t tmpfs_t (file (getattr)))
          (allow sysadm_systemd_t tmpfs_t (lnk_file (create getattr read setattr unlink)))
          (allow sysadm_systemd_t tmp_t (dir (add_name create read remove_name rmdir write)))
          (allow sysadm_systemd_t tmp_t (lnk_file (create getattr rename unlink)))
          (allow sysadm_systemd_t tty_device_t (chr_file (open)))
          (allow sysadm_systemd_t unlabeled_t (dir (add_name create open read remove_name write)))
          (allow sysadm_systemd_t unlabeled_t (file (create execute_no_trans ioctl lock open setattr unlink write)))
          (allow sysadm_systemd_t unlabeled_t (lnk_file (create getattr rename unlink)))
          (allow sysadm_systemd_t unlabeled_t (service (start status stop)))
          (allow sysadm_systemd_t user_home_dir_t (dir (add_name create getattr read remove_name search write)))
          (allow sysadm_systemd_t user_home_dir_t (file (create getattr lock open read setattr write)))
          (allow sysadm_systemd_t user_home_dir_t (lnk_file (create getattr read rename unlink)))
          (allow sysadm_systemd_t user_home_t (dir (getattr search)))
          (allow sysadm_systemd_t user_home_t (file (append getattr open read setattr)))
          (allow sysadm_systemd_t user_home_t (lnk_file (read)))
          (allow sysadm_systemd_t var_log_t (dir (getattr search)))
          (allow sysadm_systemd_t var_run_t (dir (add_name create search write)))
          (allow sysadm_systemd_t var_run_t (file (create getattr ioctl open setattr write)))

          ; Defines the object type governing access to the secrets directory and its contents.
          (type ${cfg.selinux.secretsObjectType})
          (roletype object_r ${cfg.selinux.secretsObjectType})
          (filecon "${builtins.dirOf cfg.keyFile}(/.*)?" any (system_u object_r ${cfg.selinux.secretsObjectType} (systemlow systemlow)))

          ; Allow labling files.
          (allow ${cfg.selinux.secretsObjectType} fs_t (filesystem (associate)))

          ; Allow systemd to manage secrets.
          (allow init_t ${cfg.selinux.secretsObjectType} (file (getattr create open read watch write)))

          ; Allow systemd to pass secrets to services.
          (allow init_t ${cfg.selinux.secretsObjectType} (dir (add_name create getattr read relabelfrom relabelto search watch write)))

          ; Allow systemd to run services.
          (allow init_t self (user_namespace (create)))
          (allow init_t self (capability2 (checkpoint_restore audit_read)))
          (allow init_t unlabeled_t (service (start status stop)))

          ; Allow systemd to start sessions.
          (allow init_t self (system (start stop)))
        '';
      })
      (pkgs.writeTextFile {
        name = "polkadot-selinux-module";
        destination = "/share/selinux/modules/polkadot.cil";
        text = /* cil */ ''
          ;; This modules contains rules needed systemd to manage the polkadot
          ;; validator service as well as rules needed by polkadot to run
          ;; properly.

          ; Defines the SELinux domain within which the polkadot validator service runs.
          (type ${cfg.selinux.validatorDomainType})
          (typeattributeset domain (${cfg.selinux.validatorDomainType}))
          (typeattributeset can_exec_unlabeled (${cfg.selinux.validatorDomainType}))
          (roletype system_r ${cfg.selinux.validatorDomainType})

          ; Defines the SELinux domain within which the polkadot validator orchestrator runs.
          (type ${cfg.selinux.orchestratorDomainType})
          (typeattributeset domain (${cfg.selinux.orchestratorDomainType}))
          (typeattributeset can_exec_unlabeled (${cfg.selinux.orchestratorDomainType}))
          (roletype system_r ${cfg.selinux.orchestratorDomainType})

          ; Defines the object type governing access to polkadot validator's state directory and its contents.
          (type ${cfg.selinux.stateObjectType})
          (roletype object_r ${cfg.selinux.stateObjectType})
          (filecon "${cfg.stateDirectory}(/.*)?" any (system_u object_r ${cfg.selinux.stateObjectType} (systemlow systemlow)))

          ; Defines the object type governing access to polkadot validator's credentials directory and its contents.
          (type ${cfg.selinux.credentialsObjectType})
          (roletype object_r ${cfg.selinux.credentialsObjectType})
          (filecon "${cfg.credentialsDirectory}(/.*)?" any (system_u object_r ${cfg.selinux.credentialsObjectType} (systemlow systemlow)))

          ${lib.optionalString (cfg.backupDirectory != "/var/backups") /* cil */ ''
            (filecon "${cfg.backupDirectory}(/.*)?" any (system_u object_r backup_store_t (systemlow systemlow)))
          ''}

          ; Defines the object type governing access to snapshots.
          (type ${cfg.selinux.snapshotsObjectType})
          (roletype object_r ${cfg.selinux.snapshotsObjectType})
          (filecon "${cfg.snapshotDirectory}(/.*)?" any (system_u object_r ${cfg.selinux.snapshotsObjectType} (systemlow systemlow)))

          ; Allow labeling files.
          (allow ${cfg.selinux.credentialsObjectType} tmpfs_t (filesystem (associate)))
          (allow ${cfg.selinux.stateObjectType} fs_t (filesystem (associate)))
          (allow ${cfg.selinux.snapshotsObjectType} fs_t (filesystem (associate)))

          ; Allow systemd to configure/label the polkadot state directory.
          (allow init_t ${cfg.selinux.stateObjectType} (dir (open getattr read relabelfrom relabelto search setattr)))

          ; Allow systemd to configure/label the polkadot snapshots directory.
          (allow init_t ${cfg.selinux.snapshotsObjectType} (dir (create getattr relabelfrom relabelto)))

          ; Allow systemd to create the credentials directory for the polkadot validator.
          (allow init_t ${cfg.selinux.credentialsObjectType} (dir (add_name create getattr mounton open read relabelto remove_name rmdir search setattr write)))
          (allow init_t ${cfg.selinux.credentialsObjectType} (file (create getattr open read rename setattr unlink write)))

          ; Allow systemd to transition to the polkadot validator service domain.
          (allow init_t ${cfg.selinux.validatorDomainType} (process (transition)))
          (allow init_t ${cfg.selinux.validatorDomainType} (process2 (nnp_transition)))

          ; Allow systemd to transition to the polkadot validator orchestrator domain.
          (allow init_t ${cfg.selinux.orchestratorDomainType} (process (transition)))
          (allow init_t ${cfg.selinux.orchestratorDomainType} (process2 (nnp_transition)))

          ; Allow creating backups.
          (allow ${cfg.selinux.validatorDomainType} backup_store_t (dir (add_name search write)))
          (allow ${cfg.selinux.validatorDomainType} backup_store_t (file (create getattr ioctl open write)))

          ; Allow creating and restoring a snapshots.
          (allow init_t ${cfg.selinux.credentialsObjectType} (file (relabelto)))
          (allow init_t ${cfg.selinux.stateObjectType} (dir (add_name create write rmdir remove_name rename reparent)))
          (allow init_t ${cfg.selinux.stateObjectType} (file (create getattr open read setattr unlink write)))
          (allow init_t ${cfg.selinux.stateObjectType} (lnk_file (create getattr read unlink)))

          ; Allow root to inspect services.
          (allow sysadm_systemd_t ${cfg.selinux.orchestratorDomainType} (dir (search)))
          (allow sysadm_systemd_t ${cfg.selinux.orchestratorDomainType} (file (read)))
          (allow sysadm_systemd_t ${cfg.selinux.validatorDomainType} (dir (search)))
          (allow sysadm_systemd_t ${cfg.selinux.validatorDomainType} (file (getattr ioctl open read)))
          (allow sysadm_systemd_t ${cfg.selinux.stateObjectType} (dir (getattr search)))

          ; Allow root setting and unsetting node keys.
          (allow sysadm_systemd_t ${cfg.selinux.secretsObjectType} (dir (add_name remove_name search write)))
          (allow sysadm_systemd_t ${cfg.selinux.secretsObjectType} (file (create getattr open unlink write)))
          (allow sysadm_systemd_t sysctl_vm_t (dir (search)))
          (allow sysadm_systemd_t sysctl_vm_overcommit_t (file (read)))
          (allow sysadm_systemd_t sysctl_vm_overcommit_t (file (open)))

          ; Allow to use FDs inherited from systemd.
          (allow ${cfg.selinux.orchestratorDomainType} init_t (fd (use)))

          ; Allow to execute unlabled executable in the Nix store.
          (allow ${cfg.selinux.orchestratorDomainType} unlabeled_t (dir (getattr mounton open read search)))
          (allow ${cfg.selinux.orchestratorDomainType} unlabeled_t (file (entrypoint getattr map open read execute execute_no_trans)))
          (allow ${cfg.selinux.orchestratorDomainType} unlabeled_t (lnk_file (read)))

          ; Allow running Polkadot Validator Orchestrator.
          (allow ${cfg.selinux.orchestratorDomainType} devlog_t (sock_file (write)))
          (allow ${cfg.selinux.orchestratorDomainType} init_runtime_t (dir (search)))
          (allow ${cfg.selinux.orchestratorDomainType} init_runtime_t (sock_file (write)))
          (allow ${cfg.selinux.orchestratorDomainType} init_t (dir (search)))
          (allow ${cfg.selinux.orchestratorDomainType} init_t (file (read)))
          (allow ${cfg.selinux.orchestratorDomainType} init_t (lnk_file (read)))
          (allow ${cfg.selinux.orchestratorDomainType} init_t (unix_dgram_socket (sendto)))
          (allow ${cfg.selinux.orchestratorDomainType} init_t (unix_stream_socket (connectto getattr ioctl read write)))
          (allow ${cfg.selinux.orchestratorDomainType} kernel_t (fd (use)))
          (allow ${cfg.selinux.orchestratorDomainType} kmsg_device_t (chr_file (open write)))
          (allow ${cfg.selinux.orchestratorDomainType} nscd_runtime_t (dir (search)))
          (allow ${cfg.selinux.orchestratorDomainType} nscd_runtime_t (sock_file (write)))
          (allow ${cfg.selinux.orchestratorDomainType} proc_t (filesystem (getattr)))
          (allow ${cfg.selinux.orchestratorDomainType} ${cfg.selinux.secretsObjectType} (dir (search)))
          (allow ${cfg.selinux.orchestratorDomainType} ${cfg.selinux.secretsObjectType} (file (getattr open read)))
          (allow ${cfg.selinux.orchestratorDomainType} self (capability (net_admin sys_resource)))
          (allow ${cfg.selinux.orchestratorDomainType} self (unix_dgram_socket (connect create getopt setopt write)))
          (allow ${cfg.selinux.orchestratorDomainType} sysctl_kernel_t (dir (search)))
          (allow ${cfg.selinux.orchestratorDomainType} sysctl_kernel_t (file (open read)))
          (allow ${cfg.selinux.orchestratorDomainType} syslogd_runtime_t (dir (search)))
          (allow ${cfg.selinux.orchestratorDomainType} tmpfs_t (dir (search)))
          (allow ${cfg.selinux.orchestratorDomainType} unlabeled_t (file (ioctl)))
          (allow ${cfg.selinux.orchestratorDomainType} unlabeled_t (service (start status stop)))
          (allow ${cfg.selinux.orchestratorDomainType} var_run_t (dir (add_name create remove_name write)))
          (allow ${cfg.selinux.orchestratorDomainType} var_run_t (file (create getattr ioctl open read setattr unlink write)))

          ; Allow retrieving file metadata.
          (allow ${cfg.selinux.validatorDomainType} fs_t (filesystem (getattr)))

          ; Allow restarting polkadot-validator.service.
          (allow ${cfg.selinux.validatorDomainType} fs_t (filesystem (unmount)))

          ; Allow to access its state directory.
          (allow ${cfg.selinux.validatorDomainType} var_lib_t (lnk_file (getattr read)))
          (allow ${cfg.selinux.validatorDomainType} var_lib_t (dir (search)))
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.stateObjectType} (dir (add_name create getattr mounton open read remove_name rmdir search write)))
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.stateObjectType} (file (append create getattr lock open read rename setattr unlink write)))

          ; Allow to access its credentials directory.
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.credentialsObjectType} (dir (search)))
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.credentialsObjectType} (file (getattr open read)))

          ; Allow to contact the name service caching daemon.
          (allow ${cfg.selinux.validatorDomainType} nscd_runtime_t (dir (search)))
          (allow ${cfg.selinux.validatorDomainType} nscd_runtime_t (sock_file (write)))
          (allow ${cfg.selinux.validatorDomainType} init_t (unix_stream_socket (connectto getattr ioctl read write)))

          ; Allow to access its private temporary directory.
          (allow ${cfg.selinux.validatorDomainType} tmpfs_t (dir (search)))
          (allow ${cfg.selinux.validatorDomainType} tmpfs_t (file (getattr map open read write)))

          ; Allow to use FDs inherited from systemd.
          (allow ${cfg.selinux.validatorDomainType} init_t (fd (use)))

          ; Allow apply additional memory protection after relocation
          (allow ${cfg.selinux.validatorDomainType} kernel_t (fd (use)))

          ; Allow to execute unlabled executable in the Nix store.
          (allow ${cfg.selinux.validatorDomainType} unlabeled_t (dir (getattr mounton open read search)))
          (allow ${cfg.selinux.validatorDomainType} unlabeled_t (file (entrypoint getattr map open read execute execute_no_trans)))
          (allow ${cfg.selinux.validatorDomainType} unlabeled_t (lnk_file (read)))

          ; Allow creating snapshots.
          (allow ${cfg.selinux.validatorDomainType} devlog_t (sock_file (write)))
          (allow ${cfg.selinux.validatorDomainType} init_runtime_t (dir (search)))
          (allow ${cfg.selinux.validatorDomainType} init_runtime_t (sock_file (write)))
          (allow ${cfg.selinux.validatorDomainType} init_t (dir (search)))
          (allow ${cfg.selinux.validatorDomainType} init_t (file (read)))
          (allow ${cfg.selinux.validatorDomainType} init_t (lnk_file (read)))
          (allow ${cfg.selinux.validatorDomainType} init_t (unix_dgram_socket (sendto)))
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.rpcPortType} (tcp_socket (name_connect)))
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.snapshotsObjectType} (dir (add_name search write)))
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.snapshotsObjectType} (file (create getattr ioctl open write)))
          (allow ${cfg.selinux.validatorDomainType} proc_t (filesystem (getattr)))
          (allow ${cfg.selinux.validatorDomainType} self (capability (dac_override dac_read_search sys_resource)))
          (allow ${cfg.selinux.validatorDomainType} self (capability (net_admin)))
          (allow ${cfg.selinux.validatorDomainType} self (fifo_file (getattr ioctl)))
          (allow ${cfg.selinux.validatorDomainType} self (unix_dgram_socket (connect create getopt setopt write)))
          (allow ${cfg.selinux.validatorDomainType} syslogd_runtime_t (dir (search)))
          (allow ${cfg.selinux.validatorDomainType} system_dbusd_runtime_t (dir (search)))
          (allow ${cfg.selinux.validatorDomainType} system_dbusd_runtime_t (sock_file (write)))
          (allow ${cfg.selinux.validatorDomainType} unlabeled_t (service (start status stop)))
          (allow ${cfg.selinux.validatorDomainType} user_home_dir_t (dir (search)))

          ; Allow restoring snapshots.
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.snapshotsObjectType} (file (read)))
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.stateObjectType} (dir (rename reparent setattr)))
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.stateObjectType} (lnk_file (create getattr read unlink)))
          (allow ${cfg.selinux.validatorDomainType} self (capability (chown fowner fsetid)))

          ; Allow to sandbox workers.
          (allow ${cfg.selinux.validatorDomainType} self (cap_userns (sys_admin)))
          (allow ${cfg.selinux.validatorDomainType} self (user_namespace (create)))

          (allow ${cfg.selinux.validatorDomainType} self (anon_inode (create map read write)))
          (allow ${cfg.selinux.validatorDomainType} self (fifo_file (read write)))
          (allow ${cfg.selinux.validatorDomainType} self (process (execmem getsched)))

          ; Allow accessing various virtual file systems.
          (allow ${cfg.selinux.validatorDomainType} cgroup_t (dir (search)))
          (allow ${cfg.selinux.validatorDomainType} cgroup_t (file (getattr read open)))
          (allow ${cfg.selinux.validatorDomainType} proc_t (file (getattr open read)))
          (allow ${cfg.selinux.validatorDomainType} sysctl_kernel_t (dir (search)))
          (allow ${cfg.selinux.validatorDomainType} sysctl_kernel_t (file (open read)))
          (allow ${cfg.selinux.validatorDomainType} sysctl_vm_overcommit_t (file (open read)))
          (allow ${cfg.selinux.validatorDomainType} sysctl_vm_t (dir (search)))
          (allow ${cfg.selinux.validatorDomainType} sysfs_t (file (getattr open read)))
          (allow ${cfg.selinux.validatorDomainType} sysfs_t (lnk_file (read)))

          ; Allow working with sockets.
          (allow ${cfg.selinux.validatorDomainType} self (netlink_route_socket (bind create nlmsg_read read write)))
          (allow ${cfg.selinux.validatorDomainType} self (tcp_socket (accept bind connect create getattr getopt listen read setopt shutdown write)))
          (allow ${cfg.selinux.validatorDomainType} self (udp_socket (create bind setopt write read)))
          (allow ${cfg.selinux.validatorDomainType} node_t (tcp_socket (node_bind)))
          (allow ${cfg.selinux.validatorDomainType} node_t (udp_socket (node_bind)))

          ; Allow binding to the mDNS port (5353).
          (allow ${cfg.selinux.validatorDomainType} howl_port_t (udp_socket (name_bind)))

          ; Allow binding and connecting to the default outbound peer-to-peer networking port.
          (type ${cfg.selinux.p2pPortType})
          (roletype object_r ${cfg.selinux.p2pPortType})
          (portcon tcp ${toString cfg.port} (system_u object_r ${cfg.selinux.p2pPortType} (systemlow systemlow)))
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.p2pPortType} (tcp_socket (name_bind name_connect)))

          ; Allow binding to the default polkadot RPC port.
          (type ${cfg.selinux.rpcPortType})
          (roletype object_r ${cfg.selinux.rpcPortType})
          (portcon tcp ${toString cfg.rpcPort} (system_u object_r ${cfg.selinux.rpcPortType} (systemlow systemlow)))
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.rpcPortType} (tcp_socket (name_bind)))

          ; Allow root to interactively connect to the RPC port, e.g. let the validator rotate keys.
          (allow init_t ${cfg.selinux.rpcPortType} (tcp_socket (name_connect)))
          (allow sysadm_systemd_t self (tcp_socket (connect create getattr setopt)))
          (allow sysadm_systemd_t ${cfg.selinux.rpcPortType} (tcp_socket (name_connect)))

          ; Allow binding to the default polkadot prometheus port.
          (type ${cfg.selinux.prometheusPortType})
          (roletype object_r ${cfg.selinux.prometheusPortType})
          (portcon tcp ${toString cfg.prometheusPort} (system_u object_r ${cfg.selinux.prometheusPortType} (systemlow systemlow)))
          (allow ${cfg.selinux.validatorDomainType} ${cfg.selinux.prometheusPortType} (tcp_socket (name_bind)))

          ; Allow inbound p2p connections.
          ;
          ; Ideally we would to create our own port context, but this is not
          ; sensibly possible as earlier portcon entries take precedence and
          ; refpolicy has contexts for all ports. Defining our portcons before
          ; loading refpolicy is also not sensibly possible because we want to
          ; use definitions from refpolicy itself there. This leaves us with
          ; patching refpolicy or just reusing its portcons, and as refpolicy
          ; only contains two ranges that are used by polkadot for inbound p2p
          ; connections, we're doing the latter here.
          (allow ${cfg.selinux.validatorDomainType} unreserved_port_t (udp_socket (name_bind)))
          (allow ${cfg.selinux.validatorDomainType} traceroute_port_t (udp_socket (name_bind)))

          ; Allow connecting to boot nodes.
          ; As boot nodes can run on any port, so we cannot really put a restriction here.
          (allow ${cfg.selinux.validatorDomainType} port_type (tcp_socket (name_connect)))
        '';
      })
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
        SELinuxContext = "system_u:system_r:${cfg.selinux.validatorDomainType}";
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
    systemd.tmpfiles.rules = [
      "d ${builtins.dirOf cfg.keyFile} 0700 - -"
      "d ${cfg.backupDirectory} 0700 - -"
      "d ${cfg.snapshotDirectory} 0700 - -"
      "d ${cfg.stateDirectory} 0700 - -"
    ];
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
        SELinuxContext = "system_u:system_r:${cfg.selinux.orchestratorDomainType}";
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
    systemd.services.polkadot-validator-backup-keystore = {
      environment = {
        CHAIN = cfg.chain;
        BACKUP_DIR = cfg.backupDirectory;
      };
      path = [
        pkgs.coreutils
        pkgs.gnutar
        pkgs.lz4
        pkgs.polkadot-get_chain_path
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writers.writeDash "polkadot-validator-backup-keystore" ''
          set -efu
          chain_path=$(get_chain_path)
          now=$(date -Is)
          archive=$BACKUP_DIR/''${CHAIN}_keystore_$now.tar.lz4
          tar --use-compress-program=lz4 -C "$chain_path" -v -c -f "$archive" keystore >&2
          echo "$archive"
        '';
        SELinuxContext = "system_u:system_r:${cfg.selinux.validatorDomainType}";
        UMask = "0027";
      };
      unitConfig = {
        Description = "Polkadot Validator Keystore Backupper";
      };
    };
    systemd.services.polkadot-validator-snapshot-create = {
      environment = {
        CHAIN = cfg.chain;
        SNAPSHOT_DIR = cfg.snapshotDirectory;
      };
      path = [
        # XXX `or pkgs.emptyDirectory` is required here because there appears
        # to be an inconsistency evaluating overlays, causing checks to fail
        # with error: attribute 'polkadot-rpc' missing
        (pkgs.polkadot-rpc or pkgs.emptyDirectory)

        pkgs.coreutils
        pkgs.gnutar
        pkgs.jq
        pkgs.lz4
        pkgs.polkadot-get_chain_path
        pkgs.systemd
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writers.writeDash "polkadot-validator-snapshot-create" ''
          set -efu
          chain_path=$(get_chain_path)
          response=$(rpc chain_getBlock)
          block_height_base16=$(echo "$response" | jq -er .result.block.header.number)
          block_height_base10=$(printf %d "$block_height_base16")
          archive=$SNAPSHOT_DIR/''${CHAIN}_$block_height_base10.tar.lz4
          (
            trap 'systemctl restart polkadot-validator.service' EXIT
            systemctl stop polkadot-validator.service
            tar --use-compress-program=lz4 -C "$chain_path" -v -c -f "$archive" db >&2
          )
          echo "file://$archive"
        '';
        SELinuxContext = "system_u:system_r:${cfg.selinux.validatorDomainType}";
        UMask = "0027";
      };
      unitConfig = {
        Description = "Polkadot Validator Snapshot Creator";
      };
    };
    systemd.services.polkadot-validator-snapshot-restore = {
      environment = {
        # POLKADOT_VALIDATOR_SNAPSHOT_RESTORE_URL is set by systemctl set-environment
      };
      path = [
        pkgs.coreutils
        pkgs.curl
        pkgs.gnutar
        pkgs.lz4
        pkgs.polkadot-get_chain_path
        pkgs.systemd
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writers.writeDash "polkadot-validator-snapshot-restore" ''
          set -efu
          chain_path=$(get_chain_path)
          mkdir -p "$chain_path"
          (
            trap 'rmdir "$chain_path"/snapshot' EXIT
            mkdir "$chain_path"/snapshot
            (
              trap 'rm "$chain_path"/snapshot/tarball' EXIT
              case $POLKADOT_VALIDATOR_SNAPSHOT_RESTORE_URL in
                file:*)
                  ln -s "''${POLKADOT_VALIDATOR_SNAPSHOT_RESTORE_URL#file://}" "$chain_path"/snapshot/tarball
                  ;;
                http:*|https:*)
                  curl "$POLKADOT_VALIDATOR_SNAPSHOT_RESTORE_URL" -O "$chain_path"/snapshot/tarball
                  ;;
                *)
                  echo "$0: unknown scheme: $POLKADOT_VALIDATOR_SNAPSHOT_RESTORE_URL" >&2
                  return 1
              esac
              tar --use-compress-program=lz4 -C "$chain_path"/snapshot -v -x -f "$chain_path"/snapshot/tarball
              chown -R nobody:nogroup "$chain_path"/snapshot/db
              (
                trap 'systemctl restart polkadot-validator.service' EXIT
                systemctl stop polkadot-validator.service
                rm -fR "$chain_path"/db.backup
                mv -T "$chain_path"/db "$chain_path"/db.backup
                mv "$chain_path"/snapshot/db "$chain_path"/db
              )
            )
          )
        '';
        SELinuxContext = "system_u:system_r:${cfg.selinux.validatorDomainType}";
        UMask = "0027";
      };
      unitConfig = {
        Description = "Polkadot Validator Snapshot Restorer";
      };
    };
  };
}
