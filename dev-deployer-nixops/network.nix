let
  # ifMainnet abstracts over the 2 cardano-node instances we will be running.
  # i == 0 means the first instance that's going to run mainnet, other instances
  # will run testnet.
  ifMainnet = mainnet: testnet: i: if i == 0 then mainnet else testnet;

  # import pinned niv sources
  sources = import ../nix/sources.nix;
  pkgs    = import sources.nixpkgs { };

  # Double check if they are not pinned to the same version.
  # If you want to change the version of a particular branch, for example:
  # niv update cardano-node-testnet -b <branch>
  cardano-node-mainnet = (import sources.cardano-node-mainnet {});
  cardano-node-testnet = (import sources.cardano-node-testnet {});

  # Machines IP addresses
  af-south-1     = "";
  us-west-1      = "";
  sa-east-1      = "";
  us-east-2      = "";
  ap-southeast-1 = "";
  ap-southeast-2 = "";
  ap-northeast-1 = "";
  eu-west-3      = "";

  mainnet-port = 7776;
  testnet-port = 7777;

in
{
  network.description = "IOHK Networking Team - Network";

  # Each deployment creates a new profile generation to able to run nixops
  # rollback
  network.enableRollback = true;

  # Common configuration shared between all servers
  defaults = { config, ... }: {
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
      ];
    };

    # Needed according to:
    # https://www.mikemcgirr.com/blog/2020-05-01-deploying-a-blog-with-terraform-and-nixos.html
    ec2.hvm = true;

    services.cardano-node = {
      enable = true;
      instances = 2;
      useNewTopology = true;

      # If you wish to overwrite the cardano-node package to a different one.
      # By default it runs the cardano-node-mainnet one.
      # You ought to put this on a particular server instead of in the default atttribute

      # cardanoNodePackages =
      #   cardano-node-mainnet.legacyPackages.x86_64-linux.cardanoNodePackages;


      # Note that in the `systemctl status` call we are going the instance
      # running on a file called 'db-testnet-0', since the default environment
      # is "testnet" and the db file is called after this environment variable.
      # 'extraNodeInstanceConfig' does not overwrite the environment variable,
      # only the nodeConfig values so, although misleading we will be running
      # a mainnet node with a 'db-testnet-0' file.

      extraNodeInstanceConfig =
        ifMainnet config.services.cardano-node.environments.mainnet.nodeConfig
                  config.services.cardano-node.environments.testnet.nodeConfig;

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
              address = "relays-new.cardano-testnet.iohk.io";
              port = 3001;
            }];
            advertise = false;
          }];
    };
  };

  # Server definitions

  server-us-west = { config, pkgs, ... }: {
    # Says we are going to deploy to an already existing NixOS machine
    deployment.targetHost = us-west-1;

    # cardano-node service configuration
    services.cardano-node = {
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

  server-us-east = { config, pkgs, ... }: {
    deployment.targetHost = us-east-2;

    # cardano-node service configuration
    services.cardano-node = {
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

  server-jp = { config, pkgs, ... }: {
    deployment.targetHost = ap-northeast-1;

    # cardano-node service configuration
    services.cardano-node = {
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

  server-sg = { config, pkgs, ... }: {
    deployment.targetHost = ap-southeast-1;

    # cardano-node service configuration
    services.cardano-node = {
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

  server-au = { config, pkgs, ... }: {
    deployment.targetHost = ap-southeast-2;

    # cardano-node service configuration
    services.cardano-node = {
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

  server-br = { config, pkgs, ... }: {
    deployment.targetHost = sa-east-1;

    # cardano-node service configuration
    services.cardano-node = {
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

  server-sa = { config, pkgs, ... }: {
    deployment.targetHost = af-south-1;

    # cardano-node service configuration
    services.cardano-node = {
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

  server-eu = { config, pkgs, ... }: {
    deployment.targetHost = eu-west-3;

    # cardano-node service configuration
    services.cardano-node = {
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
