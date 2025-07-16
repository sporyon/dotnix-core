{ lib, pkgs, stdenv }:

stdenv.mkDerivation rec {
  pname = "refpolicy";
  version = src.rev;

  src = pkgs.fetchFromGitHub {
    owner = "SELinuxProject";
    repo = "refpolicy";
    rev = "RELEASE_2_20250213";
    hash = "sha256-VsQRqigGwSVJ52uqFj1L2xzQqbWwQ/YaFI5Rsn/HbP8=";
  };

  nativeBuildInputs = [
    pkgs.getopt
    pkgs.m4
    pkgs.python3
  ];

  patches = [
    ./can_exec_unlabeled.patch
  ];

  prePatch = ''
    sed -i 's@^prefix := $(DESTDIR)/usr$@prefix := '"$out"'@' Makefile
  '';

  configurePhase = ''
    sed -Ei 's/^(# *)?(OUTPUT_POLICY) *=.*/\2 = 33/' build.conf
    sed -Ei 's/^(# *)?(SYSTEMD) *=.*/\2 = y/' build.conf
    make conf
  '';

  DESTDIR = placeholder "out";

  BINDIR = lib.makeBinPath [
    (pkgs.symlinkJoin {
      name = "refpolicy-bindir-for-make";
      paths = [
        pkgs.checkpolicy
        pkgs.libxml2
        pkgs.semodule-utils
      ];
    })
  ];

  SBINDIR = lib.makeBinPath [
    (pkgs.symlinkJoin {
      name = "refpolicy-sbindir-for-make";
      paths = [
        pkgs.policycoreutils
      ];
    })
  ];
}
