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

    # XXX why don't we need this anymore?
    #system.activationScripts.create-secure-boot-keys = ''
    #  ${pkgs.util-linux}/bin/mount /dev/vda1 /boot
    #'';

    # XXX Part of ~/.project's "Lösungsansatz #3"
    #system.activationScripts.create-secure-boot-keys = ''
    #  ${pkgs.coreutils}/bin/mkdir -p /var/lib
    #  ${pkgs.sbctl}/bin/sbctl create-keys
    #'';

    # XXX debug instrument
    services.journald.console = "/dev/ttyS0";

    # fileSystems gehören in example.nix oder so
    # XXX fixes an issue where early boot doesn't know about vfat
    #     but that doesn't seem to be a problem? investigate!
    boot.initrd.supportedFilesystems = [ "vfat" ];

    # XXX do we need that, and if yes, why?
    #boot.loader.efi.canTouchEfiVariables = true;

    boot.lanzaboote = {
      enable = true;
      pkiBundle = ../tmp/sbctl;
    };

    environment.systemPackages = [
      # XXX For debugging and troubleshooting Secure Boot.
      #     keep this only if the README uses the sbctl command
      pkgs.sbctl

      # XXX What's that? Keep it only if README uses it.
      #pkgs.lanzaboote-tool
    ];
  };
}
