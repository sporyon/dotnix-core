{ inputs, nixosModules, system }:

(inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    ({
      imports = [
        (inputs.nixpkgs + "/nixos/modules/virtualisation/docker-image.nix")
      ];
    })
  ];
}).config.system.build.tarball
