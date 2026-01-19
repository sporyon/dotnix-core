{ pkgs }:

pkgs.writers.writeDashBin "generate-secrets" ''
  # XXX hier kommt alles oder teile von setup-sb.sh
  echo DERP

  ...

  # Generate Secure Boot keys
  /nix/store/vshcibj8d7p3z42v0d0nqsqzvhlsc3cp-coreutils-full-9.7/bin/mkdir -p tmp/sbctl
  nix-shell -p sbctl --run 'sbctl create-keys --disable-landlock --export tmp/sbctl/keys'

  # Create tarball and encrypt with agenix
  cd tmp/sbctl
  /nix/store/8av8pfs7bnyc6hqj764ns4z1fnr9bva1-gnutar-1.35/bin/tar -czf ../sbctl-keys.tar.gz keys/
  cd ../..

  # Note: You need to manually encrypt the tarball:
  /nix/store/8ksax0a2mxglr5hlkj2dzl556jx7xqn5-coreutils-9.7/bin/echo "Run: agenix -e secrets/sbctl-keys.age"

  /nix/store/8ksax0a2mxglr5hlkj2dzl556jx7xqn5-coreutils-9.7/bin/echo "Then paste the base64 content of tmp/sbctl-keys.tar.gz"
  
  # Generate OVMF variables
  nix-shell -p python3Packages.virt-firmware --run '
  workdir=$(mktemp -d)
  trap "rm -rf $workdir" EXIT
  mkdir -p $workdir/keys/{PK,KEK,db}
  cp -r tmp/sbctl/keys/* $workdir/keys/
  virt-fw-vars \
    -i "$(nix build --print-out-paths --no-link .#nixosConfigurations.example-x86_64-linux.config.virtualisation.efi.OVMF.variables)" \
    -o tmp/OVMF_VARS.fd \
    --secure-boot \
    --set-pk  8BE4DF61-93CA-11d2-AA0D-00E098032B8C $workdir/keys/PK/PK.pem \
    --add-kek 8BE4DF61-93CA-11d2-AA0D-00E098032B8C $workdir/keys/KEK/KEK.pem \
    --add-db  8BE4DF61-93CA-11d2-AA0D-00E098032B8C $workdir/keys/db/db.pem
'

# Clean up
/nix/store/8ksax0a2mxglr5hlkj2dzl556jx7xqn5-coreutils-9.7/bin/rm -rf tmp/sbctl/keys tmp/sbctl-keys.tar.gz

'
