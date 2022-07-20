let
  # import pinned niv sources
  sources = import ../nix/sources.nix;
  pkgs    = import sources.nixpkgs {};

  # data sources
  config = pkgs.lib.importJSON "${builtins.toString ./.}/config-template.json";
  machine-ips = import ../machine-ips.nix;

  # filter empty attributes
  machine-ips-filtered = pkgs.lib.attrsets.filterAttrs (_: value: value != "") machine-ips;

  # filtered configurations for mainnet
  mainnet-config = {
    network = {
      contents =
        pkgs.lib.attrsets.mapAttrsToList
        (name: _:
          "/tmp/${name}-0.sock")
        machine-ips-filtered;
    };
  };

  testnet-config = {
    networkMagic = 1097911063;
    network = {
      contents =
        pkgs.lib.attrsets.mapAttrsToList
        (name: _:
          "/tmp/${name}-1.sock")
        machine-ips-filtered;
    };
    hasEKG = [
      {
        epHost = "0.0.0.0";
        epPort = 4100;
      }
      {
        epHost = "0.0.0.0";
        epPort = 4101;
      }
    ];
    hasPrometheus = {
      epPort = 4200;
    };
    hasRTView = {
      epPort = 4300;
    };
    logging = [
      {
        logRoot = "/tmp/cardano-tracer-h-testnet-logs";
        logMode = "FileMode";
        logFormat = "ForHuman";
      }
      {
        logRoot = "/tmp/cardano-tracer-m-testnet-logs";
        logMode = "FileMode";
        logFormat = "ForMachine";
      }
    ];
  };

  # filtered configuration files
  mainnet-config-file =
    builtins.toFile "cardano-tracer-config-mainnet.json"
                    (builtins.toJSON
                      (pkgs.lib.attrsets.recursiveUpdate config mainnet-config));
  testnet-config-file =
    builtins.toFile "cardano-tracer-config-testnet.json"
                    (builtins.toJSON
                      (pkgs.lib.attrsets.recursiveUpdate config testnet-config));

  # generate local port forwarding for mainnet
  portForwardingMainnet = name: value:
  "ssh -nNTf \\
    -i ../../ssh-keys/id_rsa_aws \\
    -L /tmp/${name}-0.sock:/run/cardano-node-0/cardano-node.sock \\
    -o \"ExitOnForwardFailure yes\" \\
    -o \"ServerAliveInterval 60\" \\
    -o \"ServerAliveCountMax 120\" \\
    -o \"StreamLocalBindUnlink yes\" \\
    root@${value} \n";

  # generate local port forwarding for testnet
  portForwardingTestnet = name: value:
  "ssh -nNTf \\
    -i ../../ssh-keys/id_rsa_aws \\
    -L /tmp/${name}-1.sock:/run/cardano-node-1/cardano-node.sock \\
    -o \"ExitOnForwardFailure yes\" \\
    -o \"ServerAliveInterval 60\" \\
    -o \"ServerAliveCountMax 120\" \\
    -o \"StreamLocalBindUnlink yes\" \\
    root@${value} \n";
in
{
  make-tunnels-mainnet =
    pkgs.writeShellScript "make-tunnels-mainnet.sh" ''
  ${pkgs.lib.concatStrings (pkgs.lib.attrsets.mapAttrsToList portForwardingMainnet machine-ips-filtered)}
  cardano-tracer -c ${mainnet-config-file} &
    '';
  make-tunnels-testnet =
    pkgs.writeShellScript "make-tunnels-testnet.sh" ''
  ${pkgs.lib.concatStrings (pkgs.lib.attrsets.mapAttrsToList portForwardingTestnet machine-ips-filtered)}
  cardano-tracer -c ${testnet-config-file} &
    '';
}
