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

    # Needed for EFI.
    boot.initrd.supportedFilesystems = [ "vfat" ];

    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      autoGenerateKeys.enable = true;
    };

    environment.systemPackages = [
      pkgs.sbctl
    ];

    security.selinux.packages = [
      (pkgs.writeTextFile {
        name = "secure-boot-selinux-module";
        destination = "/share/selinux/modules/secure-boot.cil";
        text = /* cil */ ''
          (allow sysadm_systemd_t default_t (dir (create remove_name)))
          (allow sysadm_systemd_t default_t (file (lock map read setattr unlink)))
          (allow sysadm_systemd_t default_t (lnk_file (create getattr read rename unlink)))
          (allow sysadm_systemd_t dosfs_t (dir (getattr open read search)))
          (allow sysadm_systemd_t dosfs_t (file (getattr open read)))
          (allow sysadm_systemd_t efivarfs_t (dir (add_name read write)))
          (allow sysadm_systemd_t efivarfs_t (file (create setattr write)))
          (allow sysadm_systemd_t loop_control_device_t (chr_file (getattr)))
          (allow sysadm_systemd_t self (capability (linux_immutable)))
          (allow sysadm_systemd_t self (process (signull)))
          (allow sysadm_systemd_t var_lib_t (dir (add_name create read remove_name rmdir setattr write)))
          (allow sysadm_systemd_t var_lib_t (file (create getattr open read rename setattr unlink write)))
        '';
      })
    ];

    virtualisation.vmVariant = {
      virtualisation = {
        useBootLoader = true;
        useEFIBoot = true;
        useSecureBoot = true;
        efi.OVMF = let
          OVMF = (pkgs.OVMF.override { secureBoot = true; }).fd;
        in
          OVMF // {
            variables = pkgs.runCommand "OVMF_VARS.SecureBoot.fd" {} ''
              ${pkgs.python3Packages.virt-firmware}/bin/virt-fw-vars \
                  -i ${OVMF.variables} \
                  -o $out \
                  --set-true SecureBoot
            '';
          };
      };
    };
  };
}
