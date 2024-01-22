{ config, pkgs, lib, ... }:
{
  options.services.blockperf-v2 = {
    enable = lib.mkEnableOption "Cardano Node - Block Performance - V2";

    publicIP = lib.mkOption {
      type = lib.types.str;
      description = "Relay public IP parameter";
    };

    publicPort = lib.mkOption {
      type = lib.types.either lib.types.int lib.types.str;
      description = "Relay public port parameter";
    };

  };

  config.systemd.services.blockperf-v2 = lib.mkIf config.services.blockperf-v2.enable {
    description = "Cardano Node - Block Performance - V2";
    bindsTo = [ "cardano-node.service" ];

    # This service depends on keys from deployment.keys, by doing this we are
    # opting to let systemd track that dependency. Each key gets a
    # corresponding systemd service "${keyname}-key.service" which is active
    # while the key is present, and otherwise inactive when the key is absent.
    after = [ "iog-network-team-certificate-key.service"
              "iog-network-team-private-key.service"
              "iog-network-team-mqtt-key.service"
              "iog-network-team-blockperf-key.service"
              "iog-network-team-installBlockperf.service"
              "cardano-node.service"
            ];
    wants = [ "iog-network-team-certificate-key.service"
              "iog-network-team-private-key.service"
              "iog-network-team-mqtt-key.service"
              "iog-network-team-blockperf-key.service"
              "iog-network-team-installBlockperf.service"
            ];
    wantedBy = [ "cardano-node.service" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 20;
      User = "root";
      Environment = "BLOCKPERF_NODE_LOGFILE=/var/lib/cardano-node/cardano-node-0-logs/node.log BLOCKPERF_RELAY_PUBLIC_PORT=${toString config.services.blockperf-v2.publicPort} BLOCKPERF_AMAZON_CA='/run/keys/iog-network-team-mqtt' BLOCKPERF_CLIENT_KEY='/run/keys/iog-network-team-private' BLOCKPERF_CLIENT_CERT='/run/keys/iog-network-team-certificate' BLOCKPERF_NAME='iog-network-team' BLOCKPERF_RELAY_PUBLIC_IP=${config.services.blockperf-v2.publicIP}";
      ExecStart = "/run/keys/blockperf/.venv/bin/blockperf run";
      KillSignal = "SIGINT";
      SyslogIdentifier = "cardano-node-tu-blockperf";
      TimeoutStopSec = 5;
    };
  };
}
