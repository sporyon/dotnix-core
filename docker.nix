{ inputs, nixosModules, system }:

(inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    ({ config, ... }: {
      imports = [
        (inputs.nixpkgs + "/nixos/modules/virtualisation/docker-image.nix")
        nixosModules.polkadot-validator
      ];

      users.users.dotnix = {
        isNormalUser = true;
        password = "dotnix";
        extraGroups = [ "wheel" ];
      };

      # Enabling flakes in docker
      nix.settings.experimental-features = [ "nix-command" "flakes" ];

      # Validator configuration
      dotnix.polkadot-validator.enable = true;
      dotnix.polkadot-validator.name = "dotnix-docker";
      dotnix.polkadot-validator.chain = "westend";
      dotnix.polkadot-validator.extraArgs = [
        "--db-storage-threshold=0"
      ];

      environment.systemPackages = [
        config.dotnix.polkadot-validator.package
      ];
    })
  ];
}).config.system.build.tarball
