# polkadot-validator-snapshots
#
# This test checks whether snapshots can be generated and restored.
#

{ inputs, system }:

inputs.nixpkgs.lib.nixos.runTest {
  name = "polkadot-validator-snapshots";

  hostPkgs = inputs.nixpkgs.legacyPackages.${system};

  nodes.alice = { config, pkgs, ... }: {
    imports = [
      inputs.self.nixosModules.polkadot-validator
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

    alice.succeed("polkadot-validator --snapshot > /tmp/snapshot-path")
    alice.wait_until_succeeds("rpc system_name")

    alice.succeed("polkadot-validator --restore $(cat /tmp/snapshot-path)")
    alice.wait_until_succeeds("rpc system_name")
  '';
}
