{ pkgs }:

pkgs.writers.writeDashBin "build-image" ''
  # SYNOPSIS
  #   build-image [FLAKE]
  #
  # DESCRIPTION
  #   Build an image using the provided flake URI.
  set -efu

  flake_uri=''${1-.#nixosConfigurations.example-$(${pkgs.coreutils}/bin/uname -m)-linux.config.system.build.diskImage}

  image_path=$(
    exec ${pkgs.nix}/bin/nix build --no-link --print-build-logs --print-out-paths --show-trace "$flake_uri"
  )

  if [ -z "$image_path" ]; then
    echo 'ERROR: could not extract image path' >&2
    exit 1
  fi

  echo "$image_path"
''
