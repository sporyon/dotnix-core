{ pkgs }:

pkgs.writers.writeDashBin "rpc" ''
  # usage: rpc METHOD
  set -efu

  payload=$(${pkgs.jq}/bin/jq -n --arg method "$1" '
    {
      jsonrpc: "2.0",
      id: 1,
      method: $method,
      params: []
    }
  ')

  ${pkgs.curl}/bin/curl \
      -fSs \
      -H 'Content-Type: application/json' \
      -d "$payload" \
      http://localhost:9944
''
