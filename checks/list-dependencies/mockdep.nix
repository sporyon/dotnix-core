{ system }:
let
  mockdep-c = derivation {
    inherit system;
    name = "mockdep-c";
    builder = ./builder.sh;
    runtime = [mockdep-d];
  };

  mockdep-d = derivation {
    inherit system;
    name = "mockdep-d";
    builder = ./builder.sh;
  };

  mockdep-b = derivation {
    inherit system;
    name = "mockdep-b";
    builder = ./builder.sh;
    runtime = [mockdep-c];
  };

  mockdep-f = derivation {
    inherit system;
    name = "mockdep-f";
    builder = ./builder.sh;
    runtime = [mockdep-g];
  };

  mockdep-g = derivation {
    inherit system;
    name = "mockdep-g";
    builder = ./builder.sh;
  };

  mockdep-e = derivation {
    inherit system;
    name = "mockdep-e";
    builder = ./builder.sh;
    buildtime = [mockdep-c mockdep-b];
  };

  mockdep-a = derivation {
    inherit system;
    name = "mockdep-a";
    builder = ./builder.sh;
    buildtime = [mockdep-e];
    runtime = [mockdep-b mockdep-c];
  };
in
  mockdep-a
