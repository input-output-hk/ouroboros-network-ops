{
  # Define cluster-wide configuration.
  # This has to evaluate fast and is imported in various places.
  flake.cardano-parts.cluster = rec {
    infra.aws = {
      orgId = "471112995006";
      region = "eu-central-1";
      profile = "ouroboros-network-ops";

      # A list of all regions in use, with a bool indicating inUse status.
      # Set a region to false to set its count to 0 in terraform.
      # After terraform applying once the line can be removed.
      regions = {
        # alias: sa (South Africa -- Cape Town)
        af-south-1 = true;

        # alias: jp (Japan -- Tokyo)
        ap-northeast-1 = true;

        # alias: sg (Singapore)
        ap-southeast-1 = true;

        # alias: au (Australia -- Sydney)
        ap-southeast-2 = true;

        # We locate our TF infra in eu-central-1 so this stays as our main ref
        # alias: eu1 (Europe -- Frankfurt)
        eu-central-1 = true;

        # alias eu3 (Europe -- Paris)
        eu-west-3 = true;

        # alias: br (Brazil)
        sa-east-1 = true;

        # alias: us2
        us-east-2 = true;

        # alias: us1
        us-west-1 = true;
      };

      domain = "network-team.dev.cardano.org";

      # Preset defaults matched to default terraform rain infra
      # kms = "arn:aws:kms:${region}:${orgId}:alias/kmsKey";
      # bucketName = "${profile}-terraform";
    };

    infra.generic = {
      # Update basic info about the cluster here.
      # This will be used for generic resource tagging where possible.

      organization = "iog";
      tribe = "coretech";
      function = "cardano-parts";
      repo = "https://github.com/input-output-hk/ouroboros-network-ops";

      # By default abort and warn if the ip-module is missing:
      abortOnMissingIpModule = true;
      warnOnMissingIpModule = true;
    };

    # If using grafana cloud stack based monitoring.
    infra.grafana.stackName = "networkteam";

    # For defining deployment groups with varying configuration.  Adjust as needed.
    groups = {
      mainnet1 = {
        groupPrefix = "mainnet1-";
        meta.environmentName = "mainnet";
        bookRelayMultivalueDns = null;
        groupRelayMultivalueDns = "mainnet1-node.${infra.aws.domain}";
      };
    };
  };
}
