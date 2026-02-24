{ config, lib, pkgs, ... }: {
  options = {
    security.selinux.enable = lib.mkEnableOption "SELinux";

    security.selinux.policy = lib.mkOption {
      description = ''
        This is the SELinux policy to be installed.

        When installing a custom policy, consider whether any parts of
        `security.selinux.packages` should be incorporated, as these
        packages are included in the default policy.
      '';
      default = pkgs.selinux.makePolicy "selinux-policy" {
        base = pkgs.selinux.makePolicy "selinux-policy-base" {
          packages = [ pkgs.selinux.refpolicy ];
          store = "refpolicy";
        };
        packages = config.security.selinux.packages;
        mode = "permissive";
        store = "strict";
      };
      defaultText = lib.literalExpression ''
        pkgs.selinux.makePolicy "selinux-policy" {
          base = pkgs.selinux.makePolicy "selinux-policy-base" {
            packages = [ pkgs.selinux.refpolicy ];
            store = "refpolicy";
          };
          packages = config.security.selinux.packages;
          mode = "permissive";
          store = "strict";
        }
      '';
    };

    security.selinux.packages = lib.mkOption {
      description = ''
        These are packages containing SELinux modules that should be built into
        the default `security.selinux.policy`.

        This option provides a convenient way to add custom policy modules
        based on `pkgs.selinux.refpolicy`. To install a policy with a different
        base or without any base, use `security.selinux.policy` instead.
      '';
      type = lib.types.listOf lib.types.package;
      default = [];
    };
  };
  config = lib.mkIf config.security.selinux.enable {
    boot.kernelPatches = [
      {
        name = "selinux-config";
        patch = null;
        structuredExtraConfig = {
          SECURITY_SELINUX = lib.kernel.yes;
        };
      }
    ];

    environment.etc =
      lib.genAttrs [
        "selinux/config"
        "selinux/semanage.conf"
        "selinux/${config.security.selinux.policy.meta.store}/policy/policy.${toString config.security.selinux.policy.meta.policyVersion}"
        "selinux/${config.security.selinux.policy.meta.store}/seusers"
        "selinux/${config.security.selinux.policy.meta.store}/contexts/default_contexts"
        "selinux/${config.security.selinux.policy.meta.store}/contexts/files/file_contexts"
        "selinux/${config.security.selinux.policy.meta.store}/contexts/files/file_contexts.bin"
        "selinux/${config.security.selinux.policy.meta.store}/contexts/files/file_contexts.homedirs"
        "selinux/${config.security.selinux.policy.meta.store}/contexts/files/file_contexts.homedirs.bin"
        "selinux/${config.security.selinux.policy.meta.store}/contexts/users/root"
      ] (name: {
        source = "${config.security.selinux.policy}/etc/${name}";
      });

    security.lsm = [
      "selinux"
    ];

    security.pam.services.login.rules.session.selinux-close = {
      control = "required";
      order = config.security.pam.services.sshd.rules.session.unix.order + 1;
      modulePath = "${pkgs.selinux.linux-pam}/lib/security/pam_selinux.so";
      args = ["close"];
    };

    security.pam.services.login.rules.session.selinux-open = {
      control = "required";
      order = config.security.pam.services.sshd.rules.session.unix.order + 2;
      modulePath = "${pkgs.selinux.linux-pam}/lib/security/pam_selinux.so";
      args = ["open"];
    };

    security.pam.services.sshd.rules.session.selinux-close = {
      control = "required";
      order = config.security.pam.services.sshd.rules.session.unix.order + 1;
      modulePath = "${pkgs.selinux.linux-pam}/lib/security/pam_selinux.so";
      args = ["close"];
    };

    security.pam.services.sshd.rules.session.selinux-open = {
      control = "required";
      order = config.security.pam.services.sshd.rules.session.unix.order + 2;
      modulePath = "${pkgs.selinux.linux-pam}/lib/security/pam_selinux.so";
      args = ["open"];
    };

    security.selinux.packages = [
      (pkgs.writeTextFile {
        name = "system-selinux-module";
        destination = "/share/selinux/modules/system.cil";
        text = /* cil */ ''
          ;; This module contains rules needed by systemd before transitioning
          ;; to service contexts.

          ; Allow root to log in.
          (typeattributeset can_exec_unlabeled (sysadm_systemd_t))
          (allow init_t sysadm_systemd_t (process2 (nosuid_transition)))
          (allow sysadm_systemd_t default_t (dir (search)))
          (allow sysadm_systemd_t default_t (file (append getattr open read write)))
          (allow sysadm_systemd_t kernel_t (fd (use)))
          (allow sysadm_systemd_t nscd_runtime_t (dir (search)))
          (allow sysadm_systemd_t tty_device_t (chr_file (getattr ioctl read write)))
          (allow sysadm_systemd_t unlabeled_t (dir (getattr search)))
          (allow sysadm_systemd_t unlabeled_t (file (entrypoint getattr execute open map read)))
          (allow sysadm_systemd_t unlabeled_t (lnk_file (read)))

          ; Allow basic operations.
          (allow sysadm_systemd_t default_t (dir (add_name getattr open read write)))
          (allow sysadm_systemd_t default_t (file (create)))
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
          (allow sysadm_systemd_t self (tcp_socket (connect create getattr getopt read setopt write)))
          (allow sysadm_systemd_t ssh_home_t (dir (getattr read)))
          (allow sysadm_systemd_t sysctl_vm_t (dir (search)))
          (allow sysadm_systemd_t sysctl_vm_overcommit_t (file (open read)))
          (allow sysadm_systemd_t systemd_journal_t (dir (getattr open read remove_name search watch write)))
          (allow sysadm_systemd_t systemd_journal_t (file (getattr map open read unlink write)))
          (allow sysadm_systemd_t systemd_passwd_runtime_t (dir (getattr open read watch)))
          (allow sysadm_systemd_t tmpfs_t (dir (create rename reparent rmdir setattr)))
          (allow sysadm_systemd_t tmpfs_t (file (getattr)))
          (allow sysadm_systemd_t tmpfs_t (lnk_file (create getattr read setattr unlink)))
          (allow sysadm_systemd_t tmp_t (dir (add_name create read remove_name rmdir write)))
          (allow sysadm_systemd_t tmp_t (file (create open read setattr write)))
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
          (allow sysadm_systemd_t var_t (dir (read)))
          (allow sysadm_systemd_t var_log_t (dir (getattr search)))
          (allow sysadm_systemd_t var_run_t (dir (add_name create search write)))
          (allow sysadm_systemd_t var_run_t (file (create getattr ioctl open setattr write)))
          (allow sysadm_systemd_t default_t (dir (rmdir setattr)))
          (allow sysadm_systemd_t tmp_t (file (getattr)))

          ; Allow systemd to run services.
          (allow init_t self (user_namespace (create)))
          (allow init_t self (capability2 (checkpoint_restore audit_read)))
          (allow init_t unlabeled_t (service (start status stop)))

          ; Allow systemd to start sessions.
          (allow init_t self (system (start stop)))
        '';
      })
    ];

    system.activationScripts.selinux = ''
      mkdir -p /var/lib/selinux
      ${pkgs.rsync}/bin/rsync \
          --chmod=D700,F600 \
          --delete \
          --recursive \
          ${config.security.selinux.policy}/lib/selinux/${config.security.selinux.policy.meta.store} \
          /var/lib/selinux
    '';

    systemd.package = pkgs.selinux.systemd;

    systemd.tmpfiles.rules = [
      "d /root 0700 - -"
    ];
  };
}
