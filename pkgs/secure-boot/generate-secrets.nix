{ pkgs }:

pkgs.writers.writeDashBin "generate-secrets" ''
  echo DERP
''
