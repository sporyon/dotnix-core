{ config, lib, pkgs, ... }: {
  options = {
    security.selinux.enable = lib.mkEnableOption "SELinux";

    security.selinux.packages = lib.mkOption {
      description = ''
        Packages containing SELinux policy that should be installed.
      '';
      type = lib.types.listOf lib.types.package;
      default = [];
    };
    security.selinux.refpolicy = lib.mkOption {
      description = ''
        SELinux reference policy that should be installed.
      '';
      type = lib.types.nullOr lib.types.package;
      default = pkgs.selinux.refpolicy;
      defaultText = lib.literalExpression "pkgs.selinux.refpolicy";
    };
  };
  config = lib.mkIf config.security.selinux.enable {
    boot.kernelPatches = [
      {
        name = "selinux-config";
        patch = null;
        extraConfig = ''
          DEFAULT_SECURITY_SELINUX n
          SECURITY_SELINUX y
          SECURITY_SELINUX_AVC_STATS y
          SECURITY_SELINUX_BOOTPARAM n
          SECURITY_SELINUX_DEVELOP y
        '';
      }
    ];

    boot.kernelParams = [
      "security=selinux"
    ];

    environment.etc."selinux/config".text = ''
      SELINUX=permissive
      SELINUXTYPE=strict
    '';

    environment.etc."selinux/semanage.conf".text = ''
      compiler-directory = ${pkgs.policycoreutils}/libexec/selinux/hll

      [load_policy]
      path = ${pkgs.policycoreutils}/bin/load_policy
      [end]

      [sefcontext_compile]
      path = ${pkgs.libselinux}/bin/sefcontext_compile
      args = $@
      [end]

      [setfiles]
      path = ${pkgs.policycoreutils}/bin/setfiles
      args = -q -c $@ $<
      [end]
    '';

    environment.etc."selinux/packages".text = ''
      ${lib.concatMapStringsSep "\n"
          (package: "${package.pname or package.name} ${package}")
          config.security.selinux.packages
      }
    '';

    security.selinux.packages =
      lib.mkBefore
        (lib.optional
          (config.security.selinux.refpolicy != null)
          config.security.selinux.refpolicy);

    systemd.package = pkgs.selinux.systemd;

    systemd.services.selinux-modular-setup = {
      description = "Modular SELinux Setup";
      requiredBy = [
        "sysinit.target"
      ];
      requires = [
        "system.slice"
      ];
      before = [
        "sysinit.target"
      ];
      after = [
        "local-fs.target"
        "system.slice"
      ];
      unitConfig = {
        DefaultDependencies = false;
      };
      restartTriggers = [
        config.environment.etc."selinux/packages".text
      ];
      serviceConfig = {
        ExecStart = pkgs.writers.writeDash "selinux-modular-setup" ''
          set -efu

          # Ensure module store exists
          mkdir -p /var/lib/selinux/strict

          # Install policies
          cat /etc/selinux/packages |
          while read -r name package; do
            marker=/var/lib/selinux/strict/$name
            if test "$package" != "$(readlink "$marker")";  then
              echo "install $name $package" >&2
              find "$package/share/selinux" -name \*.pp \
                  -exec ${pkgs.policycoreutils}/bin/semodule --noreload --install {} +
              ln -fns "$package" "$marker"
            fi
          done

          # Load installed policy
          ${pkgs.policycoreutils}/bin/semodule --reload
        '';
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}

