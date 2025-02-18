{
  inputs,
  config,
  lib,
  self,
  ...
}: let
  inherit (config.flake) nixosModules nixosConfigurations;
  # inherit (config.flake.cardano-parts.cluster.infra.aws) domain regions;

  cfgGeneric = config.flake.cardano-parts.cluster.infra.generic;
in
  with builtins;
  with lib; {
    flake.colmena = let
      # Region defs:
      au.aws.region = "ap-southeast-2";
      br.aws.region = "sa-east-1";
      # eu1.aws.region = "eu-central-1";
      eu3.aws.region = "eu-west-3";
      jp.aws.region = "ap-northeast-1";
      sa.aws.region = "af-south-1";
      sg.aws.region = "ap-southeast-1";
      us1.aws.region = "us-west-1";
      us2.aws.region = "us-east-2";

      # Instance defs:
      # t3a-small.aws.instance.instance_type = "t3a.small";
      m6i-2xlarge.aws.instance.instance_type = "m6i.2xlarge";

      # Helper fns:
      ebs = size: {aws.instance.root_block_device.volume_size = mkDefault size;};

      # ebsIops = iops: {aws.instance.root_block_device.iops = mkDefault iops;};
      # ebsTp = tp: {aws.instance.root_block_device.throughput = mkDefault tp;};
      # ebsHighPerf = recursiveUpdate (ebsIops 10000) (ebsTp 1000);

      # Helper defs:
      # disableAlertCount.cardano-parts.perNode.meta.enableAlertCount = false;
      # delete.aws.instance.count = 0;

      mkCustomNode = flakeInput:
        node
        // {
          cardano-parts.perNode = {
            pkgs = {inherit (inputs.${flakeInput}.packages.x86_64-linux) cardano-cli cardano-node cardano-submit-api;};
          };
        };

      node-9-2-1 = mkCustomNode "cardano-node-9-2-1";
      node-10-2-1-coot = mkCustomNode "cardano-node-10-2-1-coot";
      node-10-2-reusable-diffusion = mkCustomNode "cardano-node-10-2-reusable-diffusion";
      node-10-2 = mkCustomNode "cardano-node-10-2";
      node-10-2-bolt = mkCustomNode "cardano-node-10-2-bolt";
      node-10-2-genesis = mkCustomNode "cardano-node-10-2-genesis";

      # Cardano group assignments:
      group = name: {
        cardano-parts.cluster.group = config.flake.cardano-parts.cluster.groups.${name};

        # Since all machines are assigned a group, this is a good place to include default aws instance tags
        aws.instance.tags = {
          inherit (cfgGeneric) organization tribe function repo;
          environment = config.flake.cardano-parts.cluster.groups.${name}.meta.environmentName;
          group = name;
        };
      };

      # Declare a static ipv6. This should only be used for public machines
      # where ip exposure in committed code is acceptable and a vanity address
      # is needed. Ie: don't use this for bps.
      #
      # In the case that a staticIpv6 is not declared, aws will assign one
      # automatically.
      #
      # NOTE: As of aws provider 5.66.0, switching from ipv6_address_count to
      # ipv6_addresses will force an instance replacement. If a self-declared
      # ipv6 is required but destroying and re-creating instances to change
      # ipv6 is not acceptable, then until the bug is fixed, continue using
      # auto-assignment only, manually change the ipv6 in the console ui, and
      # run tf apply to update state.
      #
      # Ref: https://github.com/hashicorp/terraform-provider-aws/issues/39433
      # staticIpv6 = ipv6: {aws.instance.ipv6 = ipv6;};

      # Cardano-node modules for group deployment
      node = {
        imports = [
          # Base cardano-node service
          config.flake.cardano-parts.cluster.groups.default.meta.cardano-node-service

          # Config for cardano-node group deployments
          inputs.cardano-parts.nixosModules.profile-cardano-node-group
          inputs.cardano-parts.nixosModules.profile-cardano-custom-metrics
        ];
      };

      node-tx-submission = mkCustomNode "cardano-node-tx-submission";

      # Blockperf for bootstrap nodes
      # Utilize the /etc/hosts list for bp ip lookups
      # bpDnsList = map (bpNode: "${bpNode}.public-ipv4") (filter (hasInfix "-bp-") (attrNames nixosConfigurations));

      bperf = {
        imports = [
          inputs.cardano-parts.nixosModules.profile-blockperf
          {
            services.blockperf = {
              name = "iog-network-team";
              clientCert = "blockperf-iog-network-team-certificate.pem.enc";
              clientKey = "blockperf-iog-network-team-private.key.enc";
            };
          }
        ];
      };

      # Profiles
      # customRts = (nixos: let
      #   cfg = nixos.config.services.cardano-node;
			# in {
      #   services.cardano-node.rtsArgs = nixos.lib.mkForce [
      #     # "-N${toString (cfg.totalCpuCount / cfg.instances)}"
      #     "-N4"
      #     "-A16m"
      #     "-M${toString (cfg.totalMaxHeapSizeMiB / cfg.instances)}M"
      #   ];
      # });

      # Tracing
      tracers = {
        services.cardano-node.extraNodeConfig.TraceTxInbound = true;
        services.cardano-node.extraNodeConfig.LocalTxMonitorProtocol = true;
        services.cardano-node.extraNodeConfig.options = {
          mapSeverity = {
            "cardano.node.LocalTxMonitorProtocol" = "Debug";
          };
        };
      };

      peerSharingDisabled = {
        services.cardano-node = {
          extraNodeConfig = {
            PeerSharing = false;
          };
        };
      };

      genesisDebugTracers = {
        services.cardano-node = {
          extraNodeConfig = {
            TraceTxInbound = false;
            LocalTxMonitorProtocol = false;
            TraceBlockFetchClient = false;
            TraceAcceptPolicy = false;
            TraceChainSyncClient = false;
            TraceConnectionManager = false;
            TraceHandshake = false;
            TraceInboundGovernor = false;
            TracePublicRootPeers = false;
            TraceServer = false;
            options = {
              mapSeverity = {
                "cardano.node.TraceChainDb" = "Debug";
              };
            };
          };

          # extraInstanceNodeConfig = _: {
          #   TraceBlockFetchClient = false;
          #   TraceAcceptPolicy = false;
          #   TraceChainSyncClient = false;
          # };
        };
      };

      # Flags
      configFlags = {
        services.cardano-node.extraNodeConfig.ConsensusMode = "GenesisMode";
        services.cardano-node.extraNodeConfig.SyncTargetNumberOfActivePeers = 15;
        services.cardano-node.peerSnapshotFile = "/etc/cardano-node/peerSnapshotFile.json";
      };

      # pre = {imports = [inputs.cardano-parts.nixosModules.profile-pre-release];};
      #
      # Topology profiles
      # Note: not including a topology profile will default to edge topology if module profile-cardano-node-group is imported
      # topoBp = {imports = [inputs.cardano-parts.nixosModules.profile-cardano-node-topology {services.cardano-node-topology = {role = "bp";};}];};
      #
      # Note: When a relay role is used, topology will automatically set localRoots for all other machines in the group
      # topoRel = {imports = [inputs.cardano-parts.nixosModules.profile-cardano-node-topology {services.cardano-node-topology = {role = "relay";};}];};
      #
      # To customize localRoots, the standard cardano-node service options can be used, but more convienent options are found in
      # cardano-parts flake/nixosModules/profile-cardano-node-topology.nix and flakeModules/lib/topology.nix.
      # Example: when localRoots nodes belong to the cluster, using `extraNodeListProducers` is handy:
      mkExtraNodeListProducers = list: {
        imports = [
          inputs.cardano-parts.nixosModules.profile-cardano-node-topology
          {
            services.cardano-node-topology = {
              role = null;
              producerTopologyFn = "empty";
              extraNodeListProducers =
                map (s: {
                  name = "mainnet1-rel-${s}-1";
                  trustable = true;
                })
                list;
            };
          }
        ];
      };

      # Custom declared localRoots topologies
      topoEmpty = mkExtraNodeListProducers [];
      topoAu = mkExtraNodeListProducers ["sg" "jp" "us1"];
      topoBr = mkExtraNodeListProducers ["sa" "us1" "us2"];
      topoEu3 = mkExtraNodeListProducers ["sa" "sg" "us2"];
      topoJp = mkExtraNodeListProducers ["sg" "us1" "au"];
      topoSa = mkExtraNodeListProducers ["sg" "br" "eu3"];
      topoSg = mkExtraNodeListProducers ["sa" "eu3" "au" "jp"];
      topoUs1 = mkExtraNodeListProducers ["us2" "br" "jp" "au"];
      topoUs2 = mkExtraNodeListProducers ["eu3" "us1" "br"];

      # Roles
      # bp = {
      #   imports = [
      #     inputs.cardano-parts.nixosModules.role-block-producer
      #     topoBp
      #     # Disable machine DNS creation for block producers to avoid ip discovery
      #     {cardano-parts.perNode.meta.enableDns = false;}
      #   ];
      # };

      # When the relay role is used:
      # rel = {imports = [inputs.cardano-parts.nixosModules.role-relay topoRel];};

      # When customized per machine topology is needed:
      rel = {
        imports = [
          # Relay role (opens the node port)
          inputs.cardano-parts.nixosModules.role-relay

          # Include blockPerf monitoring on all relay class nodes
          bperf
        ];
      };

      relNoBperf = {
        imports = [
          # Relay role (opens the node port)
          inputs.cardano-parts.nixosModules.role-relay
        ];
      };
    in {
      meta = {
        nixpkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
        };

        nodeSpecialArgs =
          foldl'
          (acc: node: let
            instanceType = node: nixosConfigurations.${node}.config.aws.instance.instance_type;
          in
            recursiveUpdate acc {
              ${node} = {
                nodeResources = {
                  inherit
                    (config.flake.cardano-parts.aws.ec2.spec.${instanceType node})
                    provider
                    coreCount
                    cpuCount
                    memMiB
                    nodeType
                    threadsPerCore
                    ;
                };
              };
            })
          {} (attrNames nixosConfigurations);
      };

      defaults.imports = [
        inputs.cardano-parts.nixosModules.module-aws-ec2
        inputs.cardano-parts.nixosModules.profile-aws-ec2-ephemeral
        inputs.cardano-parts.nixosModules.profile-cardano-parts
        inputs.cardano-parts.nixosModules.profile-basic
        inputs.cardano-parts.nixosModules.profile-common
        inputs.cardano-parts.nixosModules.profile-grafana-alloy
        nixosModules.common
        nixosModules.ip-module-check
        # customRts
        tracers
      ];

      #mainnet1-rel-au-1 = {imports = [au m6i-2xlarge (ebs 300) (group "mainnet1") node-10-2-genesis rel topoAu];};
      mainnet1-rel-au-1 = {imports = [au m6i-2xlarge (ebs 300) (group "mainnet1") node-10-2-genesis relNoBperf topoEmpty genesisDebugTracers];};
      mainnet1-rel-br-1 = {imports = [br m6i-2xlarge (ebs 300) (group "mainnet1") node-10-2-bolt rel topoBr];};
      #mainnet1-rel-eu3-1 = {imports = [eu3 m6i-2xlarge (ebs 300) (group "mainnet1") node-10-2-genesis rel topoEu3 ];};
      mainnet1-rel-eu3-1 = {imports = [eu3 m6i-2xlarge (ebs 300) (group "mainnet1") node-10-2-genesis relNoBperf topoEu3 configFlags genesisDebugTracers];};
      mainnet1-rel-jp-1 = {imports = [jp m6i-2xlarge (ebs 300) (group "mainnet1") node-10-2-bolt rel topoJp];};
      mainnet1-rel-sa-1 = {imports = [sa m6i-2xlarge (ebs 300) (group "mainnet1") node-10-2-bolt rel topoSa];};
      # sg-1 runs `cardano-node-10.2.1` with disabled peer-sharing option
      mainnet1-rel-sg-1 = {imports = [sg m6i-2xlarge (ebs 300) (group "mainnet1") node-10-2-1-coot rel topoSg peerSharingDisabled];};
      #mainnet1-rel-sg-1 = {imports = [sg m6i-2xlarge (ebs 300) (group "mainnet1") node-10-2-1-coot rel topoSg];};
      mainnet1-rel-us1-1 = {imports = [us1 m6i-2xlarge (ebs 300) (group "mainnet1") node-10-2-bolt rel topoUs1];};
      #mainnet1-rel-us2-1 = {imports = [us2 m6i-2xlarge (ebs 300) (group "mainnet1") node-10-2-genesis rel topoUs2];};
      mainnet1-rel-us2-1 = {imports = [us2 m6i-2xlarge (ebs 300) (group "mainnet1") node-10-2-genesis relNoBperf topoEmpty configFlags genesisDebugTracers];};
    };

    flake.colmenaHive = inputs.cardano-parts.inputs.colmena.lib.makeHive self.outputs.colmena;
  }
