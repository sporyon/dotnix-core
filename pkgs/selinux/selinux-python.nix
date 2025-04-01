{ pkgs }:

let
  libselinux =
    (pkgs.libselinux.override {
      enablePython = true;
      python3 = pkgs.python3;
      python3Packages = pkgs.python3Packages;
    }).overrideAttrs (old: {
      postInstall = old.postInstall or "" + ''
        cp src/build/lib.*/selinux/*.so $py/${pkgs.python3.sitePackages}/selinux
      '';
    });

  libsemanage =
    pkgs.libsemanage.overrideAttrs (old: {
      makeFlags =
        map (x: if x == "PYTHON=python" then "PYTHON=${pkgs.python3}/bin/python" else x) old.makeFlags;
    });

  selinux-python =
    pkgs.selinux-python.overrideAttrs (old: {
      SHAREDIR = "${placeholder "out"}/share";
      patchPhase = old.patchPhase or "" + ''
        sed -i \
            -e s:/usr/bin/checkmodule:${pkgs.checkpolicy}/bin/checkmodule: \
            -e s:/usr/bin/semodule_package:${pkgs.semodule-utils}/bin/semodule_package: \
            -e s:/usr/bin/make:${pkgs.gnumake}/bin/make: \
            sepolgen/src/sepolgen/module.py
      '';
      postInstall = old.postInstall or "" + ''
        install -D -t $out/${pkgs.python3.sitePackages}/selinux \
            ${libselinux.py}/${pkgs.python3.sitePackages}/selinux/*
        install -D -t $out/${pkgs.python3.sitePackages} \
            ${libsemanage.py}/${pkgs.python3.sitePackages}/*
      '';
    });
in

selinux-python
