{ pkgs }:

pkgs.writers.writeDashBin "create-vm-efi-vars" ''
  set -efu
  output=$1
  exec ${pkgs.python3Packages.virt-firmware}/bin/virt-fw-vars \
      -i "${pkgs.OVMF.variables}" \
      -o "$output" \
      --secure-boot
''
