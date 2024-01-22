{ config, pkgs, lib, ... }:
{
  options.services.blockperf = {
    enable = lib.mkEnableOption "Cardano Node - Block Performance";

    publicIP = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Relay public IP parameter for blockPerf.sh";
    };

  };

  config.systemd.services.blockperf = lib.mkIf config.services.blockperf.enable {
    description = "Cardano Node - Block Performance";
    bindsTo = [ "cardano-node.service" ];

    # This service depends on keys from deployment.keys, by doing this we are
    # opting to let systemd track that dependency. Each key gets a
    # corresponding systemd service "${keyname}-key.service" which is active
    # while the key is present, and otherwise inactive when the key is absent.
    after = [ "iog-network-team-certificate-key.service"
              "iog-network-team-private-key.service"
              "iog-network-team-mqtt-key.service"
              "iog-network-team-blockperf-key.service"
              "iog-network-team-blockperf-env-key.service"
              "cardano-node.service"
            ];
    wants = [ "iog-network-team-certificate-key.service"
              "iog-network-team-private-key.service"
              "iog-network-team-mqtt-key.service"
              "iog-network-team-blockperf-key.service"
              "iog-network-team-blockperf-env-key.service"
            ];
    wantedBy = [ "cardano-node.service" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 20;
      User = "root";
      ExecStart = "${pkgs.nix}/bin/nix-shell -I nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos -p ${pkgs.coreutils} ${pkgs.curl} ${pkgs.jq} ${pkgs.mosquitto} --run 'bash /run/keys/iog-network-team-blockperf ${config.services.blockperf.publicIP}'";
      KillSignal = "SIGINT";
      SyslogIdentifier = "cardano-node-tu-blockperf";
      TimeoutStopSec = 5;
      KillMode = "mixed";
      ExecStop = "${pkgs.coreutils}/bin/rm -f -- '/opt/cardano/cnode/blockPerf-running.pid'";
    };
  };
}
