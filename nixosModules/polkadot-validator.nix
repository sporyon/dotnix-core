{ config, lib, pkgs, ... }: {
  options.dotnix.polkadot-validator = {
    enable = lib.mkEnableOption "Polkadot validator";
  };
  config = lib.mkIf config.dotnix.polkadot-validator.enable {
    systemd.services.polkadot-validator = {
      wantedBy = [
        "multi-user.target"
      ];
      serviceConfig = {
        ExecStartPre = "${pkgs.polkadot}/bin/polkadot --version";
        ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
      };
    };
  };
}
