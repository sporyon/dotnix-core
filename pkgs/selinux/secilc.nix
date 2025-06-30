{ lib, pkgs, stdenv }:

stdenv.mkDerivation rec {
  pname = "secilc";
  version = "3.8.1";
  se_url = "https://github.com/SELinuxProject/selinux/releases/download";

  src = pkgs.fetchurl {
    url = "${se_url}/${version}/secilc-${version}.tar.gz";
    hash = "sha256-PbKXTdmjyEA62gOS3v8mewOYp0tOegsFGvdkVycISNE=";
  };

  patchPhase = ''
    sed -i 's/$(XMLTO)/& --skip-validation/g' Makefile
  '';

  nativeBuildInputs = [
    pkgs.checkpolicy
    pkgs.xmlto
  ];

  buildInputs = [
    pkgs.libsepol
  ];

  outputs = [
    "bin"
    "man"
    "out"
  ];

  makeFlags = [
    "PREFIX=$(out)"
    "BINDIR=$(bin)/bin"
    "MANDIR=$(man)/share/man"
  ];

  enableParallelBuilding = true;

  meta = {
    description = "SELinux Common Intermediate Language (CIL) Compiler";
    homepage = "https://github.com/SELinuxProject/selinux/tree/main/secilc";
    platforms = lib.platforms.linux;
    license = lib.licenses.gpl2Plus;
  };
}
