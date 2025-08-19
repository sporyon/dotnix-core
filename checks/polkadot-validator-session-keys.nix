# polkadot-validator-session-keys
#
# This test checks whether session keys can be rotated.
#

{ inputs, system }:

inputs.nixpkgs.lib.nixos.runTest {
  name = "polkadot-validator-session-keys";

  hostPkgs = inputs.nixpkgs.legacyPackages.${system};

  nodes.alice = { config, pkgs, ... }: {
    imports = [
      inputs.self.nixosModules.polkadot-validator
      inputs.self.nixosModules.selinux
    ];

    # Validator configuration.
    dotnix.polkadot-validator.enable = true;
    dotnix.polkadot-validator.name = "alice";
    dotnix.polkadot-validator.chain = "westend";
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
    alice.wait_until_succeeds("systemctl is-active multi-user.target")

    # Set some generated node keys to start the validator.
    alice.succeed("polkadot key generate-node-key | polkadot-validator --set-node-key")
    alice.wait_until_succeeds("rpc system_name")

    alice.succeed("polkadot-validator --rotate-keys > /tmp/key1")
    alice.succeed("polkadot-validator --rotate-keys > /tmp/key2")
    alice.succeed("diff -u /tmp/key1 /tmp/key2 || test $? = 1")
  '';
}
