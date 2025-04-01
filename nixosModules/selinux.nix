{ config, lib, pkgs, ... }: {
  options = {
    security.selinux.enable = lib.mkEnableOption "SELinux";
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

    systemd.package = pkgs.selinux.systemd;
  };
}

