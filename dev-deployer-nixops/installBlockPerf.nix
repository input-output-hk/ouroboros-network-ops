{ config, pkgs, lib, ... }:
{
  options.services.installBlockperf = {
    enable = lib.mkEnableOption "Cardano Node - Install blockperf";
  };

  config.systemd.services.installBlockperf = lib.mkIf config.services.installBlockperf.enable {
    description = "Cardano Node - Install blockperf";
    bindsTo = [ "cardano-node.service" ];

    # This service depends on keys from deployment.keys, by doing this we are
    # opting to let systemd track that dependency. Each key gets a
    # corresponding systemd service "${keyname}-key.service" which is active
    # while the key is present, and otherwise inactive when the key is absent.
    after = [ "iog-network-team-installBlockperf.service"
              "cardano-node.service"
            ];
    wants = [ "iog-network-team-installBlockperf.service"
            ];
    wantedBy = [ "cardano-node.service" ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "${pkgs.nix}/bin/nix-shell -I nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos -p ${pkgs.python3} ${pkgs.git} --run 'bash /run/keys/iog-network-team-installBlockperf'";
      KillSignal = "SIGINT";
      SyslogIdentifier = "cardano-node-tu-installBlockperf";
      TimeoutStopSec = 5;
      KillMode = "mixed";
    };
  };
}
