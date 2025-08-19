# polkadot-validator-secrets
#
# This test checks the validator behavior with respect to secrets.
# The different scenarios are documented in the comments in `testScript` below.
#

{ inputs, system }:

inputs.nixpkgs.lib.nixos.runTest {
  name = "polkadot-validator-secrets";

  hostPkgs = inputs.nixpkgs.legacyPackages.${system};

  nodes = {
    # alice is a machine that starts without secrets.
    alice = { config, pkgs, ... }: {
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
        pkgs.coreutils
        pkgs.diffutils
        pkgs.systemd
      ];

      system.stateVersion = "24.11";
    };

    # bob is a machine that starts with secrets.
    bob = { config, pkgs, ... }: {
      imports = [
        inputs.self.nixosModules.polkadot-validator
        inputs.self.nixosModules.selinux
      ];

      # Validator configuration.
      dotnix.polkadot-validator.enable = true;
      dotnix.polkadot-validator.name = "bob";
      dotnix.polkadot-validator.chain = "westend";
      dotnix.polkadot-validator.extraArgs = [
        "--db-storage-threshold=0"
      ];
      dotnix.polkadot-validator.keyFile =
        toString (pkgs.writeText "dummysecret" "0000000000000000000000000000000000000000000000000000000000000000");

      # Helper utilities to be used in testScript.
      environment.systemPackages = [
        pkgs.systemd
      ];

      system.stateVersion = "24.11";
    };
  };

  testScript = ''
    # Ensure the validator did't start without secrets.
    alice.fail("systemctl is-active polkadot-validator.service")

    # Ensure that the validator starts when secrets are provided.
    # The timestamp gets recorded to test the restart behavior subsequently.
    alice.succeed("polkadot key generate-node-key | polkadot-validator --set-node-key")
    alice.wait_until_succeeds("systemctl is-active polkadot-validator.service")
    alice.succeed("systemctl show --property=ActiveEnterTimestamp polkadot-validator.service >/tmp/t1")

    # Sleep so a restart doesn't happen within the same second as the previous start.
    alice.succeed("sleep 1")

    # Ensure that the validator gets restarted when secrets are changed.
    alice.succeed("polkadot key generate-node-key | polkadot-validator --set-node-key")
    alice.wait_until_fails("systemctl show --property=ActiveEnterTimestamp polkadot-validator.service >/tmp/t2 && diff -u /tmp/t1 /tmp/t2")
    alice.succeed("systemctl is-active polkadot-validator.service")

    # Ensure that the validator gets stopped when secrets get removed.
    alice.succeed("polkadot-validator --unset-node-key")
    alice.wait_until_fails("systemctl is-active polkadot-validator.service")

    # Ensure the validator starts automatically if there is a secrets.
    bob.wait_until_succeeds("systemctl is-active polkadot-validator.service")
  '';
}
