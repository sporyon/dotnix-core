{ pkgs }:

pkgs.writers.writeDashBin "build-image" ''
  # SYNOPSIS
  #   build-image [FLAKE]
  #
  # DESCRIPTION
  #   Build an ISO image using the provided flake URI.
  #   If no flake URI is provided, the default .#example-x86_64-linux is used.
  set -efu

  flake_uri=''${1-.#example-x86_64-linux}

  image_path=$(
    ${pkgs.nixos-rebuild}/bin/nixos-rebuild build-image \
      --image-variant iso \
      --show-trace \
      --print-build-logs \
      -j 1 \
      --flake "$flake_uri" \
      2>&1 \
      | ${pkgs.coreutils}/bin/tee /dev/stderr \
      | ${pkgs.gnused}/bin/sed -nr '$s/^Done\. *The disk image can be found in //p'
  )

  if [ -z "$image_path" ]; then
    echo 'ERROR: could not extract image path' >&2
    exit 1
  fi

  echo "$image_path"
''
