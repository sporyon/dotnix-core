# List dependencies
#
# This test spawns a machine running the list-dependencies tests on glibc-2.35.
# The tests succeed if the result matches the sha256 of list dependencies stdout

{ inputs, system }:

inputs.nixpkgs.lib.nixos.runTest {
  name = "list-dependencies";

  hostPkgs = inputs.nixpkgs.legacyPackages.${system};

  nodes = {
    alice = { config, pkgs, ... }: {
      # Files used in testScript.
      environment.etc."mockdep".source = import ./mockdep.nix;
      environment.etc."mockdep.all.sha256sums".source = builtins.toFile "mockdep.all.sha256sums" ''
        0e4bce8f2fa87b551d73db72c5a5565968ffa2fd916c2dbccc7bc533ba1687b2  -
      '';
      environment.etc."mockdep.runtime.sha256sums".source = builtins.toFile "mockdep.runtime.sha256sums" ''
        026374dc4f48f74804898e445111a64b40cd003d3aebeec9e7133b608aeabb9a  -
      '';

      # Helper utilities to be used in testScript.
      environment.systemPackages = [
        pkgs.coreutils
        pkgs.list-dependencies
      ];

      nixpkgs.overlays = [
        inputs.self.overlays.default
      ];
    };
  };

  testScript = ''
    alice.succeed("list-dependencies --all /etc/mockdep | sort -u | sha256sum -c /etc/mockdep.all.sha256sums")
    alice.succeed("list-dependencies --runtime /etc/mockdep | sort -u | sha256sum -c /etc/mockdep.runtime.sha256sums")
  '';
}
