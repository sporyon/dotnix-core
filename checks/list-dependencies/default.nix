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
      # Helper utilities to be used in testScript.
      environment.systemPackages = [
        pkgs.coreutils
        pkgs.list-dependencies
        (pkgs.writers.writeDashBin "derp" ''
          echo ${import ./mockdep.nix}
        '')
      ];

      nixpkgs.overlays = [
        inputs.self.overlays.default
      ];
    };
  };


  testScript = let
    mockdep = import ./mockdep.nix;
    sha256sums.all = builtins.toFile "all-dependencies.sha256sum" ''
      0e4bce8f2fa87b551d73db72c5a5565968ffa2fd916c2dbccc7bc533ba1687b2  -
    '';
    sha256sums.runtime = builtins.toFile "runtime-dependencies.sha256sum" ''
      026374dc4f48f74804898e445111a64b40cd003d3aebeec9e7133b608aeabb9a  -
    '';
  in ''
    alice.succeed("list-dependencies --all ${mockdep} | sort | sha256sum -c ${sha256sums.all}")
    alice.succeed("list-dependencies --runtime ${mockdep} | sort | sha256sum -c ${sha256sums.runtime}")
  '';
}
