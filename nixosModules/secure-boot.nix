{ config, inputs, lib, pkgs, ... }: {
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];
  options.dotnix.secure-boot = {
    enable = lib.mkEnableOption "Secure Boot";
  };
  config = lib.mkIf config.dotnix.secure-boot.enable {
    assertions = [
      {
        assertion = config.boot.loader.systemd-boot.enable == false;
        message = ''
          'dotnix.secure-boot.enable' requires 'boot.loader.systemd-boot.enable' to be disabled,
          because Lanzaboote will be used instead.
        '';
      }
    ];




    # fileSystems gehören in example.nix oder so
    # XXX fixes an issue where early boot doesn't know about vfat
    #     but that doesn't seem to be a problem? investigate!
    boot.initrd.supportedFilesystems = [ "vfat" ];

    # XXX do we need that, and if yes, why?
    #boot.loader.efi.canTouchEfiVariables = true;

    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    environment.systemPackages = [
      # XXX For debugging and troubleshooting Secure Boot.
      #     keep this only if the README uses the sbctl command
      pkgs.sbctl

      # XXX What's that? Keep it only if README uses it.
      #pkgs.lanzaboote-tool
    ];

    security.selinux.packages = [
      (pkgs.writeTextFile {
        name = "secure-boot-selinux-module";
        destination = "/share/selinux/modules/secure-boot.cil";
        text = /* cil */ ''
          (allow sysadm_systemd_t dosfs_t (dir (search)))
          (allow sysadm_systemd_t loop_control_device_t (chr_file (getattr)))
          (allow sysadm_systemd_t self (process (signull)))
        '';
      })
    ];
  };

}
