# polkadot-validator-selinux tests
#
# This test checks whether a user with sudo privileges can touch secrets, if the validator has network access.
#

{ inputs, system }:

inputs.nixpkgs.lib.nixos.runTest {
  name = "polkadot-validator-selinux-check";

  hostPkgs = inputs.nixpkgs.legacyPackages.${system};

  nodes.alice = { config, pkgs, ... }: {
    imports = [
      inputs.self.nixosModules.polkadot-validator
      inputs.self.nixosModules.selinux.nix
    ];

    # Validator configuration.
    dotnix.polkadot-validator.enable = true;
    dotnix.polkadot-validator.name = "alice";
    dotnix.polkadot-validator.chain = "dev";
    dotnix.polkadot-validator.extraArgs = [
      "--db-storage-threshold=0"
    ];

    # Helper utilities to be used in testScript.
    environment.systemPackages = [
      config.dotnix.polkadot-validator.package
      pkgs.polkadot-rpc
      # T: selinuxpkgs need to be added
    ];

    nixpkgs.overlays = [
      inputs.self.overlays.default
    ];

    system.stateVersion = "24.11";
  };

  testScript = ''
    start_all()

    # Set some generated node keys to start the validator.
    alice.succeed("polkadot key generate-node-key | polkadot-validator --set-node-key")
    alice.wait_until_succeeds("rpc system_name")

    # Test if validator secrets are protected
    alice.succeed("setenforce 1")
    alice.failed("sudo cat /#Todo add keylocations")

    # Test if the Validator can communicate over the network
    alice.succeed("curl http://localhost:9944")

    # Test if the Bootnode can communicate over the network
    alice.succeed("curl http://localhost:30310")
    alice.succeed("curl http://localhost:30311")
    alice.succeed("curl http://localhost:30312")

  '';
}
