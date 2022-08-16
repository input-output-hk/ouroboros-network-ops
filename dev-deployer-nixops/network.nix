let
  # ifMainnet abstracts over the 2 cardano-node instances we will be running.
  # i == 0 means the first instance that's going to run mainnet, other instances
  # will run testnet.
  ifMainnet = mainnet: testnet: i: if i == 0 then mainnet else testnet;

  # Same as 'ifMainnet' but applies a function with a common argument.
  # This is useful in extraNodeInstanceConfig for applying a recursiveUpdate
  # to both cardano-node services configs
  ifMainnetC = f: common: mainnet: testnet: i: if i == 0 then f mainnet (common 0) else f testnet (common i);

  # import pinned niv sources
  sources = import ../nix/sources.nix;
  pkgs    = import sources.nixpkgs {};

  # Double check if they are not pinned to the same version.
  # If you want to change the version of a particular branch, for example:
  # niv update cardano-node-testnet -b <branch>
  cardano-node-mainnet = (import sources.cardano-node-mainnet {});
  cardano-node-testnet = (import sources.cardano-node-testnet {});

  # Machines IP addresses
  machine-ips = import ../machine-ips.nix;

  mainnet-port = 7776;
  testnet-port = 7777;

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

      # Doesn't matter if we use the mainnet or testnet ones since we are going to
      # overwrite the cardano-node packages in the cardano-node service if needed.
      #
      # I am making t he assummption that it does not matter (at least for now) which
      # service version we import here.
      cardano-node-mainnet.nixosModules.cardano-node
    ];

    # Packages to be installed system-wide. We need at least cardano-node
    environment = {
      systemPackages = with pkgs; [
        vim
        yq
        jq
        lsof
        htop
      ];
    };

    # Needed according to:
    # https://www.mikemcgirr.com/blog/2020-05-01-deploying-a-blog-with-terraform-and-nixos.html
    ec2.hvm = true;

    services.openssh.extraConfig = ''
        ClientAliveInterval 60
        ClientAliveCountMax 120
      '';

    services.cardano-node = {
      enable = true;
      instances = 2;
      useNewTopology = true;

      # Needed in order to connect to the outside world
      hostAddr = "0.0.0.0";

      # If you wish to overwrite the cardano-node package to a different one.
      # By default it runs the cardano-node-mainnet one.
      # You ought to put this on a particular server instead of in the default atttribute

      # cardanoNodePackages =
      #   cardano-node-mainnet.legacyPackages.x86_64-linux.cardanoNodePackages;

      # Needed in order to connect to the outside world
      hostAddr = "0.0.0.0";

      # Note that in the `systemctl status` call we are going the instance
      # running on a file called 'db-testnet-0', since the default environment
      # is "testnet" and the db file is called after this environment variable.
      # 'extraNodeInstanceConfig' does not overwrite the environment variable,
      # only the nodeConfig values so, although misleading we will be running
      # a mainnet node with a 'db-testnet-0' file.

      extraNodeInstanceConfig =
        # Custom common node configuration for both mainnet and testnet
        # instances.
        let custom = i : {
          ## Legacy tracing configuration ##

          # Make the scribes defined in setupScribes available
          defaultScribes = [
            [
              "FileSK"
              "cardano-node-${toString i}-logs/node.log"
            ]
            [
              "StdoutSK"
              "stdout"
            ]
          ];
          # Define multiple scribes
          setupScribes = [
            { scFormat = "ScText";
              scKind   = "StdoutSK";
              scName   = "stdout";
              scRotation = null;
            }
            {
              scFormat = "ScJson";
              scKind   = "FileSK";
              scName   = "cardano-node-${toString i}-logs/node.log";
              scRotation = {
                rpKeepFilesNum = 10;
                rpLogLimitBytes = 25000000;
                rpMaxAgeHours = 120;
              };
            }
          ];

          ## Non Legacy tracing configuration ##
          ## Options for cardano-tracer RTView on Linux ##

          UseTraceDispatcher = true;
          TraceOptions = {
            "" = {
              severity = "Notice";
              detail = "DNormal";
              backends = [
                "Stdout MachineFormat"
                "EKGBackend"
                "Forwarder"
                ];
            };
            KeepAliveClient = {
              severity = "Notice";
            };
            ConnectionManager = {
              severity = "Debug";
            };
            ConnectionManagerTransitions = {
              severity = "Debug";
            };
            LedgerPeers = {
              severity = "Debug";
            };
          };
          TraceOptionPeerFrequency = 2000;
          TraceOptionResourceFrequency = 5000;
          TurnOnLogMetrics = false;

          ## Non-default traces to enable ##

          # The maximum number of used peers during bulk sync.
          MaxConcurrencyBulkSync = 2;

          # The MaxConcurrencyDeadline configuration option controls how many
          # attempts the node will run in parallel to fetch the same block
          MaxConcurrencyDeadline = 4;

          TraceBlockFetchClient = true;
          TraceBlockFetchDecisions = true;
          TraceChainSyncClient = true;
          TraceChainSyncReqRsp = true;
          TraceInboundGovernorCounters = true;
          TraceMux = true;
          TraceHandshake = true;
          TraceLocalHandshake = true;
        };
        in
        ifMainnetC lib.recursiveUpdate
                   custom
                   config.services.cardano-node.environments.mainnet.nodeConfig
                   config.services.cardano-node.environments.testnet.nodeConfig;

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
              address = "relays-new.cardano-testnet.iohkdev.io";
              port = 3001;
            }];
            advertise = false;
          }];
    };
  };

  # Server definitions

  server-us-west = { config, lib, pkgs, nodes, ... }: {
    # Says we are going to deploy to an already existing NixOS machine
    deployment.targetHost = machine-ips.us-west-1;

    # cardano-node service configuration
    services.cardano-node = {
      # Add particular RTView Config
      extraNodeInstanceConfig = i : { TraceOptionNodeName = "server-us-west-${toString i}"; };

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
                      advertise = false;
                      valency = 4;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-us-east.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-br.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-jp.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-au.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = "13.52.93.226";
                          port = testnet-port;
                        }
                      ];
                      advertise = false;
                      valency = 4;
                    }
                  ];
    };
  };

  server-us-east = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.us-east-2;

    # cardano-node service configuration
    services.cardano-node = {
      # Add particular RTView Config
      extraNodeInstanceConfig = i : { TraceOptionNodeName = "server-us-east-${toString i}"; };

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
                      advertise = false;
                      valency = 3;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-eu.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-us-west.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-br.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = "3.142.182.220";
                          port = 3001;
                        }
                      ];
                      advertise = false;
                      valency = 4;
                    }
                  ];
    };
  };

  server-jp = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.ap-northeast-1;

    # cardano-node service configuration
    services.cardano-node = {
      # Add particular RTView Config
      extraNodeInstanceConfig = i : { TraceOptionNodeName = "server-us-jp-${toString i}"; };

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
                      advertise = false;
                      valency = 3;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-sg.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-us-west.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-au.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = "54.238.39.214";
                          port = testnet-port;
                        }
                      ];
                      advertise = false;
                      valency = 4;
                    }
                  ];
    };
  };

  server-sg = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.ap-southeast-1;

    # cardano-node service configuration
    services.cardano-node = {
      # Add particular RTView Config
      extraNodeInstanceConfig = i : { TraceOptionNodeName = "server-us-sg-${toString i}"; };

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
                      advertise = false;
                      valency = 4;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-sa.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-eu.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-au.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-jp.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = "52.74.94.66";
                          port = testnet-port;
                        }
                      ];
                      advertise = false;
                      valency = 5;
                    }
                  ];
    };
  };

  server-au = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.ap-southeast-2;

    # cardano-node service configuration
    services.cardano-node = {
      # Add particular RTView Config
      extraNodeInstanceConfig = i : { TraceOptionNodeName = "server-us-au-${toString i}"; };

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

    # cardano-node service configuration
    services.cardano-node = {
      # Add particular RTView Config
      extraNodeInstanceConfig = i : { TraceOptionNodeName = "server-us-br-${toString i}"; };

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
                      advertise = false;
                      valency = 3;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-sa.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-us-west.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-us-east.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = "18.229.177.239";
                          port = testnet-port;
                        }
                      ];
                      advertise = false;
                      valency = 4;
                    }
                  ];
    };
  };

  server-sa = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.af-south-1;

    # cardano-node service configuration
    services.cardano-node = {
      # Add particular RTView Config
      extraNodeInstanceConfig = i : { TraceOptionNodeName = "server-us-sa-${toString i}"; };

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
                      advertise = false;
                      valency = 3;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-sg.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-br.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-eu.config.deployment.targetHost;
                          port = testnet-port;
                        }
                      ];
                      advertise = false;
                      valency = 3;
                    }
                  ];
    };
  };

  server-eu = { config, lib, pkgs, nodes, ... }: {
    deployment.targetHost = machine-ips.eu-west-3;

    # cardano-node service configuration
    services.cardano-node = {
      # Add particular RTView Config
      extraNodeInstanceConfig = i : { TraceOptionNodeName = "server-us-eu-${toString i}"; };

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
                        { address = "88.99.169.172";
                          port = mainnet-port;
                        }
                        { address = "95.217.1.58";
                          port = mainnet-port;
                        }
                      ];
                      advertise = false;
                      valency = 5;
                    }
                  ]
                  [ { accessPoints = [
                        { address = nodes.server-sa.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-sg.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        { address = nodes.server-us-east.config.deployment.targetHost;
                          port = testnet-port;
                        }
                        {
                          address = "88.99.169.172";
                          port = testnet-port;
                        }
                        {
                          address = "18.169.36.236";
                          port = 3001;
                        }
                      ];
                      advertise = false;
                      valency = 5;
                    }
                  ];
    };
  };
}
