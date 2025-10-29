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
