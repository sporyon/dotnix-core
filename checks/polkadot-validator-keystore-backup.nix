# polkadot-validator-keystore-backup
#
# This test checks whether the keystore can be backupped.
#

{ inputs, system }:

inputs.nixpkgs.lib.nixos.runTest {
  name = "polkadot-validator-keystore-backup";

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
      pkgs.gnutar
      pkgs.lz4
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

    alice.succeed("polkadot-validator --backup-keystore > /tmp/backup-path")
    alice.succeed("mkdir /tmp/testdir")
    alice.succeed("tar --use-compress-program=lz4 -C /tmp/testdir -x -f $(cat /tmp/backup-path)")
    alice.succeed("diff -ru /var/lib/polkadot-validator/chains/rococo_dev/keystore /tmp/testdir/keystore || test $? = 1")
  '';
}
