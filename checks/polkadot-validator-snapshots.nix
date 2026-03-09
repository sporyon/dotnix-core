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
      inputs.self.nixosModules.selinux
    ];

    # Validator configuration.
    dotnix.polkadot-validator.canonicalInstanceName = "default";
    dotnix.polkadot-validator.instances.default.enable = true;
    dotnix.polkadot-validator.instances.default.name = "alice";
    dotnix.polkadot-validator.instances.default.chain = "westend";
    dotnix.polkadot-validator.instances.default.extraArgs = [
      "--db-storage-threshold=0"
    ];

    # Helper utilities to be used in testScript.
    environment.systemPackages = [
      config.dotnix.polkadot-validator.instances.default.package
      pkgs.polkadot-rpc
    ];

    nixpkgs.overlays = [
      inputs.self.overlays.default
    ];

    system.stateVersion = "24.11";
  };

  testScript = ''
    start_all()
    alice.wait_until_succeeds("systemctl is-active multi-user.target")

    # Set some generated node keys to start the validator.
    alice.succeed("polkadot key generate-node-key | polkadot-validator --set-node-key")
    alice.wait_until_succeeds("rpc system_name")

    alice.succeed("polkadot-validator --snapshot > /tmp/snapshot-path")
    alice.wait_until_succeeds("rpc system_name")

    alice.succeed("polkadot-validator --restore $(cat /tmp/snapshot-path)")
    alice.wait_until_succeeds("rpc system_name")
  '';
}
