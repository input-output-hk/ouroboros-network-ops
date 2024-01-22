let
  # ifMainnet abstracts over the 2 cardano-node instances we will be running.
  # i == 0 means the first instance that's going to run mainnet, other instances
  # will run preview-net.
  ifMainnet = mainnet: preview-net: i: if i == 0 then mainnet else preview-net;

  # Same as 'ifMainnet' but applies a function with a common argument.
  # This is useful in extraNodeInstanceConfig for applying a recursiveUpdate
  # to both cardano-node services configs
  ifMainnetC = f: common: mainnet: preview-net: i:
    if i == 0 then f mainnet (common 0) else f preview-net (common i);

  # import pinned niv sources
  sources = import ../nix/sources.nix;
  pkgs    = import sources.nixpkgs {};

  # Double check if they are not pinned to the same version.
  # If you want to change the version of a particular branch, for example:
  # niv update cardano-node-preview-net -b <branch>
  cardano-node-mainnet     = (import sources.cardano-node-mainnet {});
  cardano-node-preview-net = (import sources.cardano-node-preview-net {});
  # Add here all other cardano-node versions you might want to deploy and test:
  # niv add input-output-hk/cardano-node -n <name>
  # niv update <name> -b <branch>
  # OR
  # niv update <name> -r <rev>
  cardano-node-development = (import sources.cardano-node-development {});
  cardano-node-development-2 = (import sources.cardano-node-development-2 {});

  # Machines IP addresses
  machine-ips = import ../machine-ips.nix;

  mainnet-port = 3001;
  preview-net-port = 3002;

in
{
  network.description = "IOHK Networking Team - Network";

  # Each deployment creates a new profile generation to able to run nixops
  # rollback
  network.enableRollback = true;

  # Common configuration shared between all servers
  defaults = { config, lib, ... }: {
    # import nixos modules:
    # - Amazon image configuration (that was used to create the AMI)
    # - The cardano-node-service nixos module
    imports = [
      "${sources.nixpkgs.outPath}/nixos/modules/virtualisation/amazon-image.nix"

      # It should not matter if we use the mainnet or preview-net ones since we are going to
      # overwrite the cardano-node packages in the cardano-node service if needed.
      #
      # NOTE that currently we need to be running the mainnet one since it is the version
      # that is pinned to the bolt12/cardano-node-service-release - this branch has currently:
      # - node version 1.35.x with a needed bug fix
      # - is rebased on top of bolt12/cardano-node-service which extends the cardano-node-service
      #   with much needed improvements
      #
      # While this is the case be sure to include commit 9642ffec16ac51e6aeef6901d8a1fbb147751d72
      # (https://github.com/input-output-hk/cardano-node/pull/4196) # in the most recent master version
      cardano-node-development.nixosModules.cardano-node

      # CF systemd unit to provide data
      ./blockperf-v2.nix
      ./installBlockPerf.nix
    ];

    # Packages to be installed system-wide. We need at least cardano-node
    environment = {
      systemPackages = with pkgs; [
        cardano-node-mainnet.cardano-cli
        cardano-node-mainnet.cardano-node
        git
        htop
        jq
        lsof
        mosquitto
        python3
        vim
        yq
        mosquitto
      ];

      sessionVariables = {
        LLRN_MaxCaughtUpAge = "60";
      };
    };

    # Firewall config
    #
    # This needs to be synced with AWS Security Groups
    networking.firewall.allowPing = true;
    networking.firewall.allowedTCPPortRanges =
      [
        { from = 1024;
          to   = 65535;
        }
      ];

    # Needed according to:
    # https://www.mikemcgirr.com/blog/2020-05-01-deploying-a-blog-with-terraform-and-nixos.html
    ec2.hvm = true;

    # limit tmp folders size since we don't need to occupy so much space for them
    boot = {
      tmpOnTmpfs = false;
      runSize = "5%";
      devShmSize = "5%";
    };

    services.openssh.extraConfig = ''
        ClientAliveInterval 60
        ClientAliveCountMax 120
      '';

    # configure journald to not suppress any messages and to keep more logs by
    # raising the SystemMaxUse value
    services.journald = {
      rateLimitInterval = "0";
      rateLimitBurst = 0;
      extraConfig = ''
        SystemMaxUse=30G
        SystemKeepFree=10G
        SystemMaxFileSize=500M
        SystemMaxFiles=65
        RuntimeMaxUse=30G
        RuntimeKeepFree=10G
        RuntimeMaxFileSize=500M
        RuntimeMaxFiles=65
      '';
    };
    # Upload files to /run/keys/
    deployment.keys.iog-network-team-certificate.keyFile = "";
    deployment.keys.iog-network-team-private.keyFile = "";
    deployment.keys.iog-network-team-mqtt.keyFile = "";
    deployment.keys.iog-network-team-blockperf = {
      keyFile = ./blockPerf.sh;
      user = "root";
      group = "root";
      permissions = "0400"; # r--------
    };

    # Upload files to /run/keys/
    deployment.keys.iog-network-team-certificate.keyFile = ../secrets/iog-network-team-certificate.pem;
    deployment.keys.iog-network-team-private.keyFile = ../secrets/iog-network-team-private.key;
    deployment.keys.iog-network-team-mqtt.keyFile = ../secrets/iog-network-team-mqtt.ca;

    deployment.keys.iog-network-team-installBlockperf = {
      keyFile = ./installBlockPerf.sh;
      user = "root";
      group = "root";
      permissions = "0400"; # r--------
    };

    # Enable the CF data feed service
    services.blockperf-v2.enable = true;
    services.installBlockperf.enable = true;

    # prometheus
    services.prometheus = {
      enable = true;
      port = 9001;

      # Export the current system metrics
      exporters = {
          node = {
              enable = true;
              enabledCollectors =
                [ "systemd"
                ];
              port = 9002;
          };
      };
      globalConfig = {
        scrape_interval = "15s";
        external_labels =
          { monitor = "codelab-monitor";
          };
      };
      scrapeConfigs = [
        # Scrape the current system
        {
          job_name = "System Info Scrape Own";
          static_configs = [{
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
          }];
        }
      ];
    };

    services.cardano-node = {
      enable = true;
      instances = 1; # Change this to 1 to run mainnet and preview-net instances # Change this to 2 to run mainnet and testnet instances
      useNewTopology = true;
      useLegacyTracing = true;

      # Needed in order to connect to the outside world
      hostAddr = "0.0.0.0";

      # Whether to compile using assertions
      asserts = true;

      rtsArgs = [ "-N4" "-I3" "-A16m" "-M14336.000000M" ];

      # If you wish to overwrite the cardano-node package to a different one.
      # By default it runs the cardano-node-mainnet one.
      # You ought to put this on a particular server instead of in the default atttribute

      # cardanoNodePackages =
      #   cardano-node-mainnet.legacyPackages.x86_64-linux.cardanoNodePackages;

      # Note that in the output of `systemctl status`, the preview-net instance will
      # be running on a file called 'db-preview-net-0', since the default environment
      # is "preview-net" and the db file is called after this environment variable.
      # 'extraNodeInstanceConfig' does not overwrite the environment variable,
      # only the nodeConfig values so, although misleading we will be running
      # a preview-net node only with a 'db-testnet-0' file.
      # To really make sure an instance is running mainnet vs preview-net one can
      # always check its configuration files

      extraNodeInstanceConfig =
        # Custom common node configuration for both mainnet and preview-net
        # instances.
        let custom = i : {
          ## Legacy tracing configuration ##

          # Make the scribes defined in setupScribes available
          #
          # Logs appear in /var/lib/cardano-node
          defaultScribes = [
            [
              "FileSK"
              "cardano-node-${toString i}-logs/node.log"
            ]
          ];
          # Define multiple scribes
          setupScribes = [
            {
              scFormat = "ScJson";
              scKind   = "FileSK";
              scName   = "cardano-node-${toString i}-logs/node.log";
              scRotation = {
                rpKeepFilesNum = 100;
                rpLogLimitBytes = 5000000;
                rpMaxAgeHours = 128;
              };
            }
          ];

          hasPrometheus = [
            "0.0.0.0"
            12798
          ];

          ## Options for cardano-tracer RTView on Linux ##

          # This enables the new tracing
          UseTraceDispatcher = false;

          EnableP2P = true;
          TargetNumberOfActivePeers = 20;
          TargetNumberOfEstablishedPeers = 50;
          TargetNumberOfKnownPeers = 100;
          TargetNumberOfRootPeers = 80;
          TraceAcceptPolicy = true;
          TraceBlockFetchClient = true;
          TraceBlockFetchDecisions = true;
          TraceBlockFetchProtocol = false;
          TraceBlockFetchProtocolSerialised = false;
          TraceBlockFetchServer = false;
          TraceChainDb = true;
          TraceChainSyncBlockServer = false;
          TraceChainSyncClient = true;
          TraceChainSyncHeaderServer = false;
          TraceChainSyncProtocol = false;
          TraceConnectionManager = true;
          TraceConnectionManagerTransitions = true;
          TraceDNSResolver = true;
          TraceDNSSubscription = true;
          TraceDiffusionInitialization = true;
          TraceErrorPolicy = true;
          TraceForge = true;
          TraceHandshake = false;
          TraceInboundGovernor = true;
          TraceIpSubscription = true;
          TraceLabelCreds = true;
          TraceLedgerPeers = true;
          TraceLocalChainSyncProtocol = false;
          TraceLocalErrorPolicy = true;
          TraceLocalHandshake = false;
          TraceLocalRootPeers = true;
          TraceLocalTxSubmissionProtocol = false;
          TraceLocalTxSubmissionServer = false;
          TraceMempool = true;
          TraceMux = false;
          TraceOptionPeerFrequency = 2000;
          TraceOptionResourceFrequency = 5000;
          TracePeerSelection = true;
          TracePeerSelectionActions = true;
          DebugPeerSelectionInitiator = true;
          ServerTrace = true;

          DebugPeerSelectionInitiatorResponder = true;
          TracePublicRootPeers = true;
          TraceServer = true;
          TraceTxInbound = false;
          TraceTxOutbound = false;
          TraceTxSubmissionProtocol = false;
          TracingVerbosity = "NormalVerbosity";
          minSeverity = "Info";
          TurnOnLogMetrics = false;
          TurnOnLogging = true;

          options.mapSeverity = {
            "cardano.node.DebugPeerSelection" = "Debug";
          };

          ExperimentalProtocolsEnabled = true;

          # The maximum number of used peers during bulk sync.
          MaxConcurrencyBulkSync = 2;

          # The MaxConcurrencyDeadline configuration option controls how many
          # attempts the node will run in parallel to fetch the same block
          MaxConcurrencyDeadline = 4;
        };
        in
        ifMainnetC lib.recursiveUpdate
                   custom
                   config.services.cardano-node.environments.mainnet.nodeConfig
                   config.services.cardano-node.environments.preview.nodeConfig;

      # Accept connections from cardano-tracer.
      tracerSocketPathAccept = i : "/run/${config.services.cardano-node.runtimeDir i}/cardano-node.sock";

      # Connect to cardano-tracer
      # Currently disabled since our topology only allows 1-way connection from deployer
      # to nodes, not the other way around
      # tracerSocketPathConnect = i : "/run/${config.services.cardano-node.runtimeDir i}/cardano-node.sock";

      # We can not programatically give a particular environment for each
      # instance, but luckily we can programatically give different
      # producers/publicProducers (local and public root peers in P2P)
      # depending on the instance.
      #
      # And due to the first fact we have to manually change the iohk
      # relays depending on the correct instance environment

      publicProducers = [ ];
      instancePublicProducers =
        ifMainnet [{
          accessPoints = [{
            address = "relays-new.cardano-mainnet.iohk.io";
            port = 3001;
          }];
          advertise = false;
        }]
          [{
            accessPoints = [{
              address = "preview-node.world.dev.cardano.org";
              port = 3002;
            }];
            advertise = false;
          }];

      usePeersFromLedgerAfterSlot = 99532743;
      # useBootstrapPeers = [];
    };

  };

  # Server definitions

  server-us-west = { config, lib, pkgs, nodes, ... }: {
    # Says we are going to deploy to an already existing NixOS machine
    deployment.targetHost = machine-ips.us-west-1;

    # Set up blockperf public ip configuration parameter
    services.blockperf-v2.publicIP = machine-ips.us-west-1;
    services.blockperf-v2.publicPort = mainnet-port;

    # cardano-node service configuration
    services.cardano-node = {

      # kesKey = "/var/lib/cardano-preview-net/keys/kes.skey";
      # vrfKey = "/var/lib/cardano-preview-net/keys/vrf.skey";
      # operationalCertificate = "/var/lib/cardano-preview-net/keys/opcert.cert";

      # extraArgs = ["--start-as-non-producing-node" ];

      # Running 8.7.3 bootstrapPeers branch
      # https://github.com/IntersectMBO/cardano-node/commits/bolt12/bootstrapPeers
      cardanoNodePackages =
        cardano-node-development.legacyPackages.x86_64-linux.cardanoNodePackages;

      # Add particular RTView Config
      extraNodeInstanceConfig =
        i : { TraceOptionNodeName = "server-us-west-${toString i}";
              PeerSharing = "PeerSharingEnabled";
            };

      instanceProducers =
        ifMainnet [ { accessPoints = [
                        { address = nodes.server-us-east.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-br.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-jp.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-au.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                      ];
                      advertise = true;
                      valency = 4;
                      # peerTrustable = true;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-us-east.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-br.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-jp.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-au.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                      ];
                      advertise = true;
                      # peerTrustable = true;
                      valency = 4;
                    }
                  ];
    };
  };

  server-us-east = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.us-east-2;

    # Set up blockperf public ip configuration parameter
    services.blockperf-v2.publicIP = machine-ips.us-east-2;
    services.blockperf-v2.publicPort = mainnet-port;

    # cardano-node service configuration
    services.cardano-node = {

      # Add particular RTView Config
      extraNodeInstanceConfig =
        i : { TraceOptionNodeName = "server-us-east-${toString i}";
              PeerSharing = "PeerSharingEnabled";
            };

      # Running 8.7.3 bootstrapPeers branch
      # https://github.com/IntersectMBO/cardano-node/commits/bolt12/bootstrapPeers
      cardanoNodePackages =
        cardano-node-development.legacyPackages.x86_64-linux.cardanoNodePackages;

      instanceProducers =
        ifMainnet [ { accessPoints = [
                        { address = nodes.server-eu.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-us-west.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-br.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                      ];
                      valency = 3;
                      advertise = true;
                      # peerTrustable = true;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-eu.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-us-west.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-br.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                      ];
                      advertise = true;
                      # peerTrustable = true;
                      valency = 4;
                    }
                  ];
    };
  };

  server-jp = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.ap-northeast-1;

    # Set up blockperf public ip configuration parameter
    services.blockperf-v2.publicIP = machine-ips.ap-northeast-1;
    services.blockperf-v2.publicPort = mainnet-port;

    # cardano-node service configuration
    services.cardano-node = {

      # Add particular RTView Config
      extraNodeInstanceConfig =
        i : { TraceOptionNodeName = "server-us-jp-${toString i}";
              PeerSharing = "PeerSharingEnabled";
            };

      # Running 8.7.0 peer sharing branch
      # https://github.com/input-output-hk/cardano-node/commits/bolt12/peerSharing
      cardanoNodePackages =
        cardano-node-development.legacyPackages.x86_64-linux.cardanoNodePackages;

      instanceProducers =
        ifMainnet [ { accessPoints = [
                        { address = nodes.server-sg.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-us-west.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-au.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                      ];
                      advertise = true;
                      valency = 3;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-sg.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-us-west.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-au.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                      ];
                      advertise = true;
                      valency = 4;
                    }
                  ];
    };
  };

  server-sg = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.ap-southeast-1;

    # Set up blockperf public ip configuration parameter
    services.blockperf-v2.publicIP = machine-ips.ap-southeast-1;
    services.blockperf-v2.publicPort = mainnet-port;

    # cardano-node service configuration
    services.cardano-node = {

      # Add particular RTView Config
      extraNodeInstanceConfig =
        i : { TraceOptionNodeName = "server-sg-${toString i}";
              PeerSharing = "PeerSharingEnabled";
            };

      # Running 8.7.0 peer sharing branch
      # https://github.com/input-output-hk/cardano-node/commits/bolt12/peerSharing
      cardanoNodePackages =
        cardano-node-development.legacyPackages.x86_64-linux.cardanoNodePackages;

      instanceProducers =
        ifMainnet [ { accessPoints = [
                        { address = nodes.server-sa.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-eu.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-au.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-jp.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                      ];
                      advertise = true;
                      valency = 4;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-sa.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-eu.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-au.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-jp.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                      ];
                      advertise = true;
                      valency = 5;
                    }
                  ];
    };
  };

  server-au = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.ap-southeast-2;

    # Set up blockperf public ip configuration parameter

    services.blockperf-v2.publicIP = machine-ips.ap-southeast-2;
    services.blockperf-v2.publicPort = mainnet-port;

    # cardano-node service configuration
    services.cardano-node = {
      # Add particular RTView Config
      extraNodeInstanceConfig =
        i : { TraceOptionNodeName = "server-au-${toString i}";
              PeerSharing = "PeerSharingDisabled";
            };

      # Running 8.7.0 peer sharing branch
      # https://github.com/input-output-hk/cardano-node/commits/bolt12/peerSharing
      cardanoNodePackages =
        cardano-node-development.legacyPackages.x86_64-linux.cardanoNodePackages;

      instanceProducers =
        ifMainnet [ { accessPoints = [
                        { address = nodes.server-sg.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-jp.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-us-west.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                      ];
                      advertise = false;
                      valency = 3;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-sg.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-jp.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-us-west.config.deployment.targetHost;
                          port = testnet-port;
                        }
                      ];
                      advertise = false;
                      valency = 3;
                    }
                  ];
    };
  };

  server-br = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.sa-east-1;

    # Set up blockperf public ip configuration parameter
    services.blockperf-v2.publicIP = machine-ips.sa-east-1;
    services.blockperf-v2.publicPort = mainnet-port;

    # cardano-node service configuration
    services.cardano-node = {

      # Add particular RTView Config
      extraNodeInstanceConfig =
        i : { TraceOptionNodeName = "server-br-${toString i}";
              PeerSharing = "PeerSharingEnabled";
            };

      # Running 8.7.0 peer sharing branch
      # https://github.com/input-output-hk/cardano-node/commits/bolt12/peerSharing
      cardanoNodePackages =
        cardano-node-development.legacyPackages.x86_64-linux.cardanoNodePackages;

      instanceProducers =
        ifMainnet [ { accessPoints = [
                        { address = nodes.server-sa.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-us-west.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-us-east.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                      ];
                      advertise = true;
                      valency = 3;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-sa.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-us-west.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-us-east.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                      ];
                      advertise = true;
                      valency = 4;
                    }
                  ];
    };
  };

  server-sa = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.af-south-1;

    # Set up blockperf public ip configuration parameter
    services.blockperf-v2.publicIP = machine-ips.af-south-1;
    services.blockperf-v2.publicPort = mainnet-port;

    # cardano-node service configuration
    services.cardano-node = {
      # Add particular RTView Config
      extraNodeInstanceConfig =
        i : { TraceOptionNodeName = "server-sa-${toString i}";
              PeerSharing = "PeerSharingEnabled";
            };

      # Running 8.7.0 peer sharing branch
      # https://github.com/input-output-hk/cardano-node/commits/bolt12/peerSharing
      cardanoNodePackages =
        cardano-node-development.legacyPackages.x86_64-linux.cardanoNodePackages;

      instanceProducers =
        ifMainnet [ { accessPoints = [
                        { address = nodes.server-sg.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-br.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-eu.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                      ];
                      advertise = true;
                      valency = 3;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-sg.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-br.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-eu.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                      ];
                      advertise = true;
                      valency = 3;
                    }
                  ];
    };
  };

  server-eu = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.eu-west-3;

    # Set up blockperf public ip configuration parameter
    services.blockperf-v2.publicIP = machine-ips.eu-west-3;
    services.blockperf-v2.publicPort = mainnet-port;

    # cardano-node service configuration
    services.cardano-node = {
      # Add particular RTView Config
      extraNodeInstanceConfig =
        i : { TraceOptionNodeName = "server-eu-${toString i}";
              PeerSharing = "PeerSharingEnabled";
            };

      # Running 8.7.3 bootstrapPeers branch
      # https://github.com/IntersectMBO/cardano-node/commits/bolt12/bootstrapPeers
      cardanoNodePackages =
        cardano-node-development.legacyPackages.x86_64-linux.cardanoNodePackages;

      instanceProducers =
        ifMainnet [ { accessPoints = [
                        { address = nodes.server-sa.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-sg.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                        { address = nodes.server-us-east.config.deployment.targetHost;
                          port = mainnet-port;
                        }
                      ];
                      advertise = true;
                      # peerTrustable = true;
                      valency = 5;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-sa.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-sg.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                        { address = nodes.server-us-east.config.deployment.targetHost;
                          port = preview-net-port;
                        }
                      ];
                      advertise = true;
                      # peerTrustable = true;
                      valency = 5;
                    }
                  ];
    };
  };

  server-monitoring = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.eu-west-monitoring;

    # Disable cardano-node service
    services.cardano-node.enable = lib.mkForce false;

    # Disable the CF data feed service
    services.blockperf-v2.enable     = lib.mkForce false;
    services.installBlockperf.enable = lib.mkForce false;


    # grafana configuration
    services.grafana = {
      enable = true;
      port = 2342;
      addr = "0.0.0.0";

      provision = {
        enable = true;
        # Set up the datasources
        datasources.settings.datasources = [
          { name   = "Prometheus";
            type   = "prometheus";
            access = "proxy";
            url    = "http://localhost:9001";
            isDefault = true;
          }
        ];
      };
    };

    # prometheus
    services.prometheus = {
      enable = true;
      port = 9001;

      # Export the current system metrics
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = 9002;
        };
      };
      globalConfig = {
        scrape_interval = "15s";
        external_labels = { monitor = "codelab-monitor"; };
      };
      scrapeConfigs = [
        # Scrape the current system
        {
          job_name = "System Info Scrape Others";
          static_configs = [
            {
              targets = [ "${nodes.server-us-west.config.deployment.targetHost}:${toString nodes.server-us-west.config.services.prometheus.exporters.node.port}" ];
              labels = { server = "us-west"; };
            }
            {
              targets = [ "${nodes.server-us-east.config.deployment.targetHost}:${toString nodes.server-us-east.config.services.prometheus.exporters.node.port}" ];
              labels = { server = "us-east"; };
            }
            {
              targets = [ "${nodes.server-jp.config.deployment.targetHost}:${toString nodes.server-jp.config.services.prometheus.exporters.node.port}" ];
              labels = { server = "jp"; };
            }
            {
              targets = [ "${nodes.server-sg.config.deployment.targetHost}:${toString nodes.server-sg.config.services.prometheus.exporters.node.port}" ];
              labels = { server = "sg"; };
            }
            {
              targets = [ "${nodes.server-au.config.deployment.targetHost}:${toString nodes.server-au.config.services.prometheus.exporters.node.port}" ];
              labels = { server = "au"; };
            }
            {
              targets = [ "${nodes.server-br.config.deployment.targetHost}:${toString nodes.server-br.config.services.prometheus.exporters.node.port}" ];
              labels = { server = "br"; };
            }
            {
              targets = [ "${nodes.server-sa.config.deployment.targetHost}:${toString nodes.server-sa.config.services.prometheus.exporters.node.port}" ];
              labels = { server = "sa"; };
            }
            {
              targets = [ "${nodes.server-eu.config.deployment.targetHost}:${toString nodes.server-eu.config.services.prometheus.exporters.node.port}" ];
              labels = { server = "eu"; };
            }
          ];
        }
        {
          job_name = "Cardano node";
          static_configs = [
            {
              targets = [ "${nodes.server-us-west.config.deployment.targetHost}:12798" ];
              labels = { server = "us-west"; };
            }
            {
              targets = [ "${nodes.server-us-east.config.deployment.targetHost}:12798" ];
              labels = { server = "us-east"; };
            }
            {
              targets = [ "${nodes.server-jp.config.deployment.targetHost}:12798" ];
              labels = { server = "jp"; };
            }
            {
              targets = [ "${nodes.server-sg.config.deployment.targetHost}:12798" ];
              labels = { server = "sg"; };
            }
            {
              targets = [ "${nodes.server-au.config.deployment.targetHost}:12798" ];
              labels = { server = "au"; };
            }
            {
              targets = [ "${nodes.server-br.config.deployment.targetHost}:12798" ];
              labels = { server = "br"; };
            }
            {
              targets = [ "${nodes.server-sa.config.deployment.targetHost}:12798" ];
              labels = { server = "sa"; };
            }
            {
              targets = [ "${nodes.server-eu.config.deployment.targetHost}:12798" ];
              labels = { server = "eu"; };
            }
          ];
        }
      ];
    };
  };
}
