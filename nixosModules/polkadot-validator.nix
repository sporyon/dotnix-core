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
          if test "$UID" != 0; then
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
              chown -R nobody:nogroup "$chain_path"/snapshot/db
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
    security.selinux.packages = [
      (pkgs.writeTextFile {
        name = "system-selinux-module";
        destination = "/share/selinux/modules/system.cil";
        text = /* cil */ ''
          ;; This module contains rules needed by systemd before transitioning
          ;; to polkadot_validator_service_t

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

          ; secrets_t governs access to secret file and directories containing secrets.
          (type secrets_t)
          (roletype object_r secrets_t)
          (context secrets_context (system_u object_r secrets_t (systemlow systemlow)))
          (filecon "${builtins.dirOf cfg.keyFile}(/.*)?" any secrets_context)

          ; Allow labling files.
          (allow secrets_t fs_t (filesystem (associate)))

          ; Allow systemd to manage secrets.
          (allow init_t secrets_t (file (getattr create open read watch write)))

          ; Allow systemd to pass secrets to services.
          (allow init_t secrets_t (dir (add_name create getattr read relabelfrom relabelto search watch write)))

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

          ; polkadot_validator_service_t defines the SELinux domain within which the polkadot validator service runs.
          (type polkadot_validator_service_t)
          (typeattributeset domain (polkadot_validator_service_t))
          (typeattributeset can_exec_unlabeled (polkadot_validator_service_t))
          (roletype system_r polkadot_validator_service_t)

          ; polkadot_validator_orchestrator_t defines the SELinux domain within which the polkadot validator orchestrator runs.
          (type polkadot_validator_orchestrator_t)
          (typeattributeset domain (polkadot_validator_orchestrator_t))
          (typeattributeset can_exec_unlabeled (polkadot_validator_orchestrator_t))
          (roletype system_r polkadot_validator_orchestrator_t)

          ; polkadot_validator_state_t governs access to polkadot validator's state directory.
          (type polkadot_validator_state_t)
          (roletype object_r polkadot_validator_state_t)
          (filecon "/var/lib/private/polkadot-validator(/.*)?" any (system_u object_r polkadot_validator_state_t (systemlow systemlow)))

          ; polkadot_validator_credentials_t governs access to polkadot validator's credentials directory.
          (type polkadot_validator_credentials_t)
          (roletype object_r polkadot_validator_credentials_t)
          (filecon "/run/credentials/polkadot-validator.service(/.*)?" any (system_u object_r polkadot_validator_credentials_t (systemlow systemlow)))

          ; polkadot_validator_snapshots_t governs access to snapshots.
          (type polkadot_validator_snapshots_t)
          (roletype object_r polkadot_validator_snapshots_t)
          (context snapshots_context (system_u object_r polkadot_validator_snapshots_t (systemlow systemlow)))
          (filecon "${cfg.snapshotDirectory}(/.*)?" any snapshots_context)

          ; Allow labeling files.
          (allow polkadot_validator_credentials_t tmpfs_t (filesystem (associate)))
          (allow polkadot_validator_state_t fs_t (filesystem (associate)))
          (allow polkadot_validator_snapshots_t fs_t (filesystem (associate)))

          ; Allow systemd to configure/label the polkadot state directory.
          (allow init_t polkadot_validator_state_t (dir (open getattr read relabelfrom relabelto search setattr)))

          ; Allow systemd to configure/label the polkadot snapshots directory.
          (allow init_t polkadot_validator_snapshots_t (dir (create getattr relabelfrom relabelto)))

          ; Allow systemd to create the credentials directory for the polkadot validator.
          (allow init_t polkadot_validator_credentials_t (dir (add_name create getattr mounton open read relabelto remove_name rmdir search setattr write)))
          (allow init_t polkadot_validator_credentials_t (file (create getattr open read rename setattr unlink write)))

          ; Allow systemd to transition to the polkadot validator service to the polkadot_validator_service_t domain.
          (allow init_t polkadot_validator_service_t (process (transition)))
          (allow init_t polkadot_validator_service_t (process2 (nnp_transition)))

          ; Allow systemd to transition to the polkadot validator orchestrator to the polkadot_validator_orchestrator_t domain.
          (allow init_t polkadot_validator_orchestrator_t (process (transition)))
          (allow init_t polkadot_validator_orchestrator_t (process2 (nnp_transition)))

          ; Allow creating and restoring a snapshots.
          (allow init_t polkadot_validator_credentials_t (file (relabelto)))
          (allow init_t polkadot_validator_state_t (dir (add_name create write rmdir remove_name rename reparent)))
          (allow init_t polkadot_validator_state_t (file (create getattr open read setattr unlink write)))
          (allow init_t polkadot_validator_state_t (lnk_file (create getattr read unlink)))

          ; Allow root to inspect services.
          (allow sysadm_systemd_t polkadot_validator_orchestrator_t (dir (search)))
          (allow sysadm_systemd_t polkadot_validator_orchestrator_t (file (read)))
          (allow sysadm_systemd_t polkadot_validator_service_t (dir (search)))
          (allow sysadm_systemd_t polkadot_validator_service_t (file (getattr ioctl open read)))
          (allow sysadm_systemd_t polkadot_validator_state_t (dir (getattr search)))

          ; Allow root setting and unsetting node keys.
          (allow sysadm_systemd_t secrets_t (dir (add_name remove_name search write)))
          (allow sysadm_systemd_t secrets_t (file (create getattr open unlink write)))
          (allow sysadm_systemd_t sysctl_vm_t (dir (search)))
          (allow sysadm_systemd_t sysctl_vm_overcommit_t (file (read)))
          (allow sysadm_systemd_t sysctl_vm_overcommit_t (file (open)))

          ; Allow to use FDs inherited from systemd.
          (allow polkadot_validator_orchestrator_t init_t (fd (use)))

          ; Allow to execute unlabled executable in the Nix store.
          (allow polkadot_validator_orchestrator_t unlabeled_t (dir (getattr mounton open read search)))
          (allow polkadot_validator_orchestrator_t unlabeled_t (file (entrypoint getattr map open read execute execute_no_trans)))
          (allow polkadot_validator_orchestrator_t unlabeled_t (lnk_file (read)))

          ; Allow running Polkadot Validator Orchestrator.
          (allow polkadot_validator_orchestrator_t devlog_t (sock_file (write)))
          (allow polkadot_validator_orchestrator_t init_runtime_t (dir (search)))
          (allow polkadot_validator_orchestrator_t init_runtime_t (sock_file (write)))
          (allow polkadot_validator_orchestrator_t init_t (dir (search)))
          (allow polkadot_validator_orchestrator_t init_t (file (read)))
          (allow polkadot_validator_orchestrator_t init_t (lnk_file (read)))
          (allow polkadot_validator_orchestrator_t init_t (unix_dgram_socket (sendto)))
          (allow polkadot_validator_orchestrator_t init_t (unix_stream_socket (connectto getattr ioctl read write)))
          (allow polkadot_validator_orchestrator_t kernel_t (fd (use)))
          (allow polkadot_validator_orchestrator_t kmsg_device_t (chr_file (open write)))
          (allow polkadot_validator_orchestrator_t nscd_runtime_t (dir (search)))
          (allow polkadot_validator_orchestrator_t nscd_runtime_t (sock_file (write)))
          (allow polkadot_validator_orchestrator_t proc_t (filesystem (getattr)))
          (allow polkadot_validator_orchestrator_t secrets_t (dir (search)))
          (allow polkadot_validator_orchestrator_t secrets_t (file (getattr open read)))
          (allow polkadot_validator_orchestrator_t self (capability (net_admin sys_resource)))
          (allow polkadot_validator_orchestrator_t self (unix_dgram_socket (connect create getopt setopt write)))
          (allow polkadot_validator_orchestrator_t sysctl_kernel_t (dir (search)))
          (allow polkadot_validator_orchestrator_t sysctl_kernel_t (file (open read)))
          (allow polkadot_validator_orchestrator_t syslogd_runtime_t (dir (search)))
          (allow polkadot_validator_orchestrator_t tmpfs_t (dir (search)))
          (allow polkadot_validator_orchestrator_t unlabeled_t (file (ioctl)))
          (allow polkadot_validator_orchestrator_t unlabeled_t (service (start status stop)))
          (allow polkadot_validator_orchestrator_t var_run_t (dir (add_name create remove_name write)))
          (allow polkadot_validator_orchestrator_t var_run_t (file (create getattr ioctl open read setattr unlink write)))

          ; Allow retrieving file metadata.
          (allow polkadot_validator_service_t fs_t (filesystem (getattr)))

          ; Allow restarting polkadot-validator.service.
          (allow polkadot_validator_service_t fs_t (filesystem (unmount)))

          ; Allow to access its state directory.
          (allow polkadot_validator_service_t var_lib_t (lnk_file (getattr read)))
          (allow polkadot_validator_service_t var_lib_t (dir (search)))
          (allow polkadot_validator_service_t polkadot_validator_state_t (dir (add_name create getattr mounton open read remove_name rmdir search write)))
          (allow polkadot_validator_service_t polkadot_validator_state_t (file (append create getattr lock open read rename setattr unlink write)))

          ; Allow to access its credentials directory.
          (allow polkadot_validator_service_t polkadot_validator_credentials_t (dir (search)))
          (allow polkadot_validator_service_t polkadot_validator_credentials_t (file (getattr open read)))

          ; Allow to contact the name service caching daemon.
          (allow polkadot_validator_service_t nscd_runtime_t (dir (search)))
          (allow polkadot_validator_service_t nscd_runtime_t (sock_file (write)))
          (allow polkadot_validator_service_t init_t (unix_stream_socket (connectto getattr ioctl read write)))

          ; Allow to access its private temporary directory.
          (allow polkadot_validator_service_t tmpfs_t (dir (search)))
          (allow polkadot_validator_service_t tmpfs_t (file (getattr map open read write)))

          ; Allow to use FDs inherited from systemd.
          (allow polkadot_validator_service_t init_t (fd (use)))

          ; Allow apply additional memory protection after relocation
          (allow polkadot_validator_service_t kernel_t (fd (use)))

          ; Allow to execute unlabled executable in the Nix store.
          (allow polkadot_validator_service_t unlabeled_t (dir (getattr mounton open read search)))
          (allow polkadot_validator_service_t unlabeled_t (file (entrypoint getattr map open read execute execute_no_trans)))
          (allow polkadot_validator_service_t unlabeled_t (lnk_file (read)))

          ; Allow creating snapshots.
          (allow polkadot_validator_service_t devlog_t (sock_file (write)))
          (allow polkadot_validator_service_t init_runtime_t (dir (search)))
          (allow polkadot_validator_service_t init_runtime_t (sock_file (write)))
          (allow polkadot_validator_service_t init_t (dir (search)))
          (allow polkadot_validator_service_t init_t (file (read)))
          (allow polkadot_validator_service_t init_t (lnk_file (read)))
          (allow polkadot_validator_service_t init_t (unix_dgram_socket (sendto)))
          (allow polkadot_validator_service_t polkadot_rpc_port_t (tcp_socket (name_connect)))
          (allow polkadot_validator_service_t polkadot_validator_snapshots_t (dir (add_name search write)))
          (allow polkadot_validator_service_t polkadot_validator_snapshots_t (file (create getattr ioctl open write)))
          (allow polkadot_validator_service_t proc_t (filesystem (getattr)))
          (allow polkadot_validator_service_t self (capability (dac_override dac_read_search sys_resource)))
          (allow polkadot_validator_service_t self (capability (net_admin)))
          (allow polkadot_validator_service_t self (fifo_file (getattr ioctl)))
          (allow polkadot_validator_service_t self (unix_dgram_socket (connect create getopt setopt write)))
          (allow polkadot_validator_service_t syslogd_runtime_t (dir (search)))
          (allow polkadot_validator_service_t system_dbusd_runtime_t (dir (search)))
          (allow polkadot_validator_service_t system_dbusd_runtime_t (sock_file (write)))
          (allow polkadot_validator_service_t unlabeled_t (service (start status stop)))
          (allow polkadot_validator_service_t user_home_dir_t (dir (search)))

          ; Allow restoring snapshots.
          (allow polkadot_validator_service_t polkadot_validator_snapshots_t (file (read)))
          (allow polkadot_validator_service_t polkadot_validator_state_t (dir (rename reparent setattr)))
          (allow polkadot_validator_service_t polkadot_validator_state_t (lnk_file (create getattr read unlink)))
          (allow polkadot_validator_service_t self (capability (chown fowner fsetid)))

          ; Allow to sandbox workers.
          (allow polkadot_validator_service_t self (cap_userns (sys_admin)))
          (allow polkadot_validator_service_t self (user_namespace (create)))

          (allow polkadot_validator_service_t self (anon_inode (create map read write)))
          (allow polkadot_validator_service_t self (fifo_file (read write)))
          (allow polkadot_validator_service_t self (process (execmem getsched)))

          ; Allow accessing various virtual file systems.
          (allow polkadot_validator_service_t cgroup_t (dir (search)))
          (allow polkadot_validator_service_t cgroup_t (file (getattr read open)))
          (allow polkadot_validator_service_t proc_t (file (getattr open read)))
          (allow polkadot_validator_service_t sysctl_kernel_t (dir (search)))
          (allow polkadot_validator_service_t sysctl_kernel_t (file (open read)))
          (allow polkadot_validator_service_t sysctl_vm_overcommit_t (file (open read)))
          (allow polkadot_validator_service_t sysctl_vm_t (dir (search)))
          (allow polkadot_validator_service_t sysfs_t (file (getattr open read)))
          (allow polkadot_validator_service_t sysfs_t (lnk_file (read)))

          ; Allow working with sockets.
          (allow polkadot_validator_service_t self (netlink_route_socket (bind create nlmsg_read read write)))
          (allow polkadot_validator_service_t self (tcp_socket (accept bind connect create getattr getopt listen read setopt shutdown write)))
          (allow polkadot_validator_service_t self (udp_socket (create bind setopt write read)))
          (allow polkadot_validator_service_t node_t (tcp_socket (node_bind)))
          (allow polkadot_validator_service_t node_t (udp_socket (node_bind)))

          ; Allow binding to the mDNS port (5353).
          (allow polkadot_validator_service_t howl_port_t (udp_socket (name_bind)))

          ; Allow binding and connecting to the default outbound peer-to-peer networking port.
          (type polkadot_p2p_port_t)
          (roletype object_r polkadot_p2p_port_t)
          (portcon tcp 30333 (system_u object_r polkadot_p2p_port_t (systemlow systemlow)))
          (allow polkadot_validator_service_t polkadot_p2p_port_t (tcp_socket (name_bind name_connect)))

          ; Allow binding to the default polkadot RPC port.
          (type polkadot_rpc_port_t)
          (roletype object_r polkadot_rpc_port_t)
          (portcon tcp 9944 (system_u object_r polkadot_rpc_port_t (systemlow systemlow)))
          (allow polkadot_validator_service_t polkadot_rpc_port_t (tcp_socket (name_bind)))

          ; Allow root to interactively connect to the RPC port, e.g. let the validator rotate keys.
          (allow init_t polkadot_rpc_port_t (tcp_socket (name_connect)))
          (allow sysadm_systemd_t self (tcp_socket (connect create getattr setopt)))
          (allow sysadm_systemd_t polkadot_rpc_port_t (tcp_socket (name_connect)))

          ; Allow binding to the default polkadot prometheus port.
          (type polkadot_prometheus_port_t)
          (roletype object_r polkadot_prometheus_port_t)
          (portcon tcp 9615 (system_u object_r polkadot_prometheus_port_t (systemlow systemlow)))
          (allow polkadot_validator_service_t polkadot_prometheus_port_t (tcp_socket (name_bind)))

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
          (allow polkadot_validator_service_t unreserved_port_t (udp_socket (name_bind)))
          (allow polkadot_validator_service_t traceroute_port_t (udp_socket (name_bind)))

          ; Allow connecting to boot nodes.
          ; As boot nodes can run on any port, so we cannot really put a restriction here.
          (allow polkadot_validator_service_t port_type (tcp_socket (name_connect)))
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
        SELinuxContext = "system_u:system_r:polkadot_validator_service_t";
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
      "d /var/lib/private/polkadot-validator 0700 - -"
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
