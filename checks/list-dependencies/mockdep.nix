let
  mockdep-c = derivation {
    name = "mockdep-c";
    builder = ./builder.sh;
    system = "x86_64-linux";
    runtime = [mockdep-d];
  };

  mockdep-d = derivation {
    name = "mockdep-d";
    builder = ./builder.sh;
    system = "x86_64-linux";
  };

  mockdep-b = derivation {
    name = "mockdep-b";
    builder = ./builder.sh;
    system = "x86_64-linux";
    runtime = [mockdep-c];
  };

  mockdep-f = derivation {
    name = "mockdep-f";
    builder = ./builder.sh;
    system = "x86_64-linux";
    runtime = [mockdep-g];
  };

  mockdep-g = derivation {
    name = "mockdep-g";
    builder = ./builder.sh;
    system = "x86_64-linux";
  };

  mockdep-e = derivation {
    name = "mockdep-e";
    builder = ./builder.sh;
    system = "x86_64-linux";
    buildtime = [mockdep-c mockdep-b];
  };

  mockdep-a = derivation {
    name = "mockdep-a";
    builder = ./builder.sh;
    system = "x86_64-linux";
    buildtime = [mockdep-e];
    runtime = [mockdep-b mockdep-c];
  };
in
  mockdep-a
