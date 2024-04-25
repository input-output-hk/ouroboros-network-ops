{
  inputs,
  config,
  lib,
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
      m6i-xlarge.aws.instance.instance_type = "m6i.xlarge";

      # Helper fns:
      ebs = size: {aws.instance.root_block_device.volume_size = mkDefault size;};

      # ebsIops = iops: {aws.instance.root_block_device.iops = mkDefault iops;};
      # ebsTp = tp: {aws.instance.root_block_device.throughput = mkDefault tp;};
      # ebsHighPerf = recursiveUpdate (ebsIops 10000) (ebsTp 1000);

      # Helper defs:
      # disableAlertCount.cardano-parts.perNode.meta.enableAlertCount = false;
      # delete.aws.instance.count = 0;

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

      # Cardano-node modules for group deployment
      node = {
        imports = [
          # Base cardano-node service
          config.flake.cardano-parts.cluster.groups.default.meta.cardano-node-service

          # Config for cardano-node group deployments
          inputs.cardano-parts.nixosModules.profile-cardano-node-group
        ];
      };
      # Profiles
      # pre = {imports = [inputs.cardano-parts.nixosModules.profile-pre-release];};
      #
      # Topology profiles
      # Note: not including a topology profile will default to edge topology if module profile-cardano-node-group is imported
      # topoBp = {imports = [inputs.cardano-parts.nixosModules.profile-cardano-node-topology {services.cardano-node-topology = {role = "bp";};}];};
      topoRel = {imports = [inputs.cardano-parts.nixosModules.profile-cardano-node-topology {services.cardano-node-topology = {role = "relay";};}];};
      #
      # Roles
      # bp = {
      #   imports = [
      #     inputs.cardano-parts.nixosModules.role-block-producer
      #     topoBp
      #     # Disable machine DNS creation for block producers to avoid ip discovery
      #     {cardano-parts.perNode.meta.enableDns = false;}
      #   ];
      # };
      rel = {imports = [inputs.cardano-parts.nixosModules.role-relay topoRel];};
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
        inputs.cardano-parts.nixosModules.profile-cardano-parts
        inputs.cardano-parts.nixosModules.profile-basic
        inputs.cardano-parts.nixosModules.profile-common
        inputs.cardano-parts.nixosModules.profile-grafana-agent
        nixosModules.common
        nixosModules.ip-module-check
      ];

      mainnet1-rel-au-1 = {imports = [au m6i-xlarge (ebs 200) (group "mainnet1") node rel];};
      mainnet1-rel-br-1 = {imports = [br m6i-xlarge (ebs 200) (group "mainnet1") node rel];};
      mainnet1-rel-eu3-1 = {imports = [eu3 m6i-xlarge (ebs 200) (group "mainnet1") node rel];};
      mainnet1-rel-jp-1 = {imports = [jp m6i-xlarge (ebs 200) (group "mainnet1") node rel];};
      mainnet1-rel-sa-1 = {imports = [sa m6i-xlarge (ebs 200) (group "mainnet1") node rel];};
      mainnet1-rel-sg-1 = {imports = [sg m6i-xlarge (ebs 200) (group "mainnet1") node rel];};
      mainnet1-rel-us1-1 = {imports = [us1 m6i-xlarge (ebs 200) (group "mainnet1") node rel];};
      mainnet1-rel-us2-1 = {imports = [us2 m6i-xlarge (ebs 200) (group "mainnet1") node rel];};
    };
  }
