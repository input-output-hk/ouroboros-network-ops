{
  inputs,
  config,
  lib,
  self,
  ...
}: let
  inherit (config.flake) nixosModules nixosConfigurations;
  # inherit (config.flake.cardano-parts.cluster.infra.aws) domain;
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
      c8i-16xlarge.aws.instance.instance_type = "c8i.16xlarge";

      # Helper fns:
      ebs = size: {aws.instance.root_block_device.volume_size = mkDefault size;};

      # ebsIops = iops: {aws.instance.root_block_device.iops = mkDefault iops;};
      # ebsTp = tp: {aws.instance.root_block_device.throughput = mkDefault tp;};
      # ebsHighPerf = recursiveUpdate (ebsIops 10000) (ebsTp 1000);

      # Required module code for any new machines spun up using the new zfs AMI
      amiZfs = {imports = [nixosModules.ami];};

      # Helper defs:
      # disableAlertCount.cardano-parts.perNode.meta.enableAlertCount = false;
      # delete.aws.instance.count = 0;

      # mkCustomNode = flakeInput: iohkNixInput:
      #   node
      #   // {
      #     cardano-parts.perNode = {
      #       lib.cardanoLib = config.flake.cardano-parts.pkgs.special.cardanoLibCustom inputs.${iohkNixInput} "x86_64-linux";
      #       pkgs = {inherit (inputs.${flakeInput}.packages.x86_64-linux) cardano-cli cardano-node cardano-submit-api;};
      #     };
      #   };

      # Example use of mkCustomNode:
      # node-tx-submission = mkCustomNode "cardano-node-tx-submission" "iohk-nix-10-4-0";

      # Cardano group assignments:
      group = name: {
        cardano-parts.cluster.group = config.flake.cardano-parts.cluster.groups.${name};

        # Since all machines are assigned a group, this is a good place to include default aws instance tags
        aws.instance.tags = {
          # This group environment name will override the
          # flake.cluster.infra.generic environment name for aws instances.
          environment = config.flake.cardano-parts.cluster.groups.${name}.meta.environmentName;
          group = name;
        };
      };

      # Cardano-node modules for group deployment
      node = {
        imports = [
          # Base cardano-node service
          config.flake.cardano-parts.cluster.groups.default.meta.cardano-node-service
          config.flake.cardano-parts.cluster.groups.default.meta.cardano-tracer-service

          # Config for cardano-node group deployments
          inputs.cardano-parts.nixosModules.profile-cardano-node-group
          inputs.cardano-parts.nixosModules.profile-cardano-custom-metrics

          # Keep legacy tracing for now
          # {
          #   services.cardano-node.useLegacyTracing = true;
          # }
        ];
      };

      # node-pre = {
      #   imports = [
      #     # Base cardano-node service
      #     config.flake.cardano-parts.cluster.groups.default.meta.cardano-node-service-ng
      #     config.flake.cardano-parts.cluster.groups.default.meta.cardano-tracer-service-ng
      #
      #     # Config for cardano-node group deployments
      #     inputs.cardano-parts.nixosModules.profile-cardano-node-group
      #     inputs.cardano-parts.nixosModules.profile-cardano-custom-metrics
      #
      #     pre
      #   ];
      # };
      #
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

      peerSharingDisabled = {
        services.cardano-node = {
          extraNodeConfig = {
            PeerSharing = false;
          };
        };
      };

      # pre = {imports = [inputs.cardano-parts.nixosModules.profile-pre-release];};

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

      # The cardano-node-topology module is already imported in the fn above,
      # so no need to import it again if we are already using that fn.
      # mkExtraSrvProducers = list: {
      #   services.cardano-node-topology.extraProducers =
      #     map (srv: {
      #       address = srv;
      #     })
      #     list;
      # };

      # Custom declared localRoots topologies
      # us1 runs the new tx-submission, that's why we connect all the nodes to
      # it.
      topoAu = mkExtraNodeListProducers ["us1" "sg" "jp"];
      topoBr = mkExtraNodeListProducers ["us1" "sa" "us1" "us2"];
      topoEu3 = mkExtraNodeListProducers ["sa" "sg" "us2"];
      # topoEu3 = mkExtraNodeListProducers [] // (mkExtraSrvProducers ["_cardano._tcp.${domain}"]);
      topoJp = mkExtraNodeListProducers ["sg" "us1" "au"];
      topoSa = mkExtraNodeListProducers ["sg" "br" "eu3" "us1"];
      topoSg = mkExtraNodeListProducers ["us1" "sa" "eu3" "au" "jp"];
      topoUs1 = mkExtraNodeListProducers ["us1" "us2" "br" "jp" "au"];
      topoUs2 = mkExtraNodeListProducers ["us1" "eu3" "us1" "br"];

      # Roles
      # bp = {
      #   imports = [
      #     inputs.cardano-parts.nixosModules.role-block-producer
      #     topoBp
      #     # Disable machine DNS creation for block producers to avoid ip discovery
      #     {cardano-parts.perNode.meta.enableDns = false;}
      #   ];
      # };

      # When customized per machine topology is needed:
      rel = {
        imports = [
          # Relay role (opens the node port)
          inputs.cardano-parts.nixosModules.role-relay

          # Include blockPerf monitoring on all relay class nodes
          bperf

          # Group relay auto-topology is not used because each machine's topology is custom defined above, ex: "topoAu", etc.
          # topoRel
        ];
      };

      # Blockperf for bootstrap nodes
      # Utilize the /etc/hosts list for bp ip lookups
      # bpDnsList = map (bpNode: "${bpNode}.public-ipv4") (filter (hasInfix "-bp-") (attrNames nixosConfigurations));

      bperf = {
        imports = [
          inputs.cardano-parts.nixosModules.profile-blockperf
          {
            services.blockperf = {
              name = "iog-network-team";
              amazonCa = "blockperf-amazon-ca.pem.enc";
              clientCert = "blockperf-iog-network-team-certificate.pem.enc";
              clientKey = "blockperf-iog-network-team-private.key.enc";
            };
          }
        ];
      };
      # Include blockPerf by default with no upstream push to CF -- only push prom metrics
      # bperfNoPublish = {
      #   imports = [
      #     inputs.cardano-parts.nixosModules.profile-blockperf
      #     {
      #       services.blockperf = {
      #         publish = false;
      #         useSopsSecrets = false;
      #       };
      #     }
      #   ];
      # };
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
      ];

      # Mainnet group
      mainnet1-rel-au-1 = {imports = [au m6i-2xlarge (ebs 300) (group "mainnet1") node rel topoAu];};
      mainnet1-rel-br-1 = {imports = [br m6i-2xlarge (ebs 300) (group "mainnet1") node rel topoBr];};
      mainnet1-rel-eu3-1 = {imports = [eu3 m6i-2xlarge (ebs 300) (group "mainnet1") node rel topoEu3];};
      mainnet1-rel-jp-1 = {imports = [jp m6i-2xlarge (ebs 300) (group "mainnet1") node rel topoJp];};
      mainnet1-rel-sa-1 = {imports = [sa m6i-2xlarge (ebs 300) (group "mainnet1") node rel topoSa];};
      mainnet1-rel-sg-1 = {imports = [sg m6i-2xlarge (ebs 300) (group "mainnet1") node rel topoSg peerSharingDisabled];};
      mainnet1-rel-us1-1 = {imports = [us1 m6i-2xlarge (ebs 300) (group "mainnet1") node rel topoUs1];};
      mainnet1-rel-us2-1 = {imports = [us2 m6i-2xlarge (ebs 300) (group "mainnet1") node rel topoUs2];};
    };

    flake.colmenaHive = inputs.cardano-parts.inputs.colmena.lib.makeHive self.outputs.colmena;
  }
