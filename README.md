<p align="center">
  <img width='150px' src="docs/theme/cardano-logo.png" alt='Cardano Logo' />
</p>

<p align="center">
  Welcome to the Ouroboros-network-ops Repository
  <br />
</p>

Cardano is a decentralized third-generation proof-of-stake blockchain platform
and home to the ada cryptocurrency. It is the first blockchain platform to
evolve out of a scientific philosophy and a research-first driven approach.

# Ouroboros-network-ops

The ouroboros-network-ops project serves as a cardano-node test cluster for the
network team.

It utilizes [flake-parts](https://flake.parts/) and re-usable nixosModules and
flakeModules from
[cardano-parts](https://github.com/input-output-hk/cardano-parts).

## Getting started

While working on the next step, you can already start the devshell using:

    nix develop

This will be done automatically if you are using [direnv](https://direnv.net/)
and issue `direnv allow`.

## AWS

Create an AWS user with your name and `AdministratorAccess` policy in the
$REPO organization, then store your access key in
`~/.aws/credentials` under the profile name `$REPO`:

    [$REPO]
    aws_access_key_id = XXXXXXXXXXXXXXXXXXXX
    aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

## AGE

While cluster secrets are handled using AWS KMS, per machine secrets are
handled using sops-nix age.  For sops-nix age secrets access, place the
SRE cluster secret in `~/.age/credentials`:

    # $REPO: sre
    AGE-SECRET-KEY-***********************************************************

If needed, a new secret can be generated with `age-keygen`.

## SSH

If your credentials are correct, and the cluster is already bootstrapped with
openTofu infrastructure, you will be able to access SSH after creating an
`./.ssh_config` using:

    just save-ssh-config

With that you can then get started with:

    # Listing machines
    just list-machines

    # Ssh to machines
    just ssh $MACHINE

    # Finding other operations recipes to use
    just --list

## Cloudformation

We bootstrap our infrastructure using AWS Cloudformation, it creates resources
like S3 Buckets, a DNS Zone, KMS key, and OpenTofu state storage.

The distinction of what is managed by Cloudformation and OpenTofu is not very
strict, but generally anything that is not of the mentioned resource types will
go into OpenTofu since they are harder to configure and reuse otherwise.

All configuration is in `./flake/cloudFormation/terraformState.nix`

We use [Rain](https://github.com/aws-cloudformation/rain) to apply the
configuration. There is a wrapper that evaluates the config and deploys it:

    just cf terraformState

When arranging DNS zone delegation, the nameservers to delegate to are shown with:

    just show-nameservers

## OpenTofu

We use [OpenTofu](https://opentofu.org/) to create AWS instances, roles,
profiles, policies, Route53 records, EIPs, security groups, and similar.

All monitoring dashboards, alerts and recording rules are configured in `./flake/opentofu/grafana.nix`

All other cluster resource configuration is in `./flake/opentofu/cluster.nix`

The wrapper to setup the state, workspace, evaluate the config, and run `tofu`
for cluster resources is:

    just tofu [cluster] plan
    just tofu [cluster] apply

Similarly, for monitoring resources:

    just tofu grafana plan
    just tofu grafana apply

## Colmena

To deploy changes on an OS level, we use the excellent
[Colmena](https://github.com/zhaofengli/colmena).

All colmena configuration is in `./flake/colmena.nix`.

To deploy a machine:

    just apply $MACHINE

## Secrets

Secrets are encrypted using [SOPS](https://github.com/getsops/sops) and [KMS](https://aws.amazon.com/kms/).

All secrets live in `./secrets/`

You should be able to edit a KMS or sops age secret using:

    sops ./secrets/github-token.enc

Or simply decrypt a KMS or sops age secret with:

    sops -d ./secrets/github-token.enc

See also the `just sops-<encrypt|decrypt>-binary` recipes for encrypting or decrypting age binary blobs.

## Monitoring

Grafana monitoring of nodes managed by the networking team is available [here](https://networkteam.monitoring.aws.iohkdev.io/?orgId=1)

### Modify grafana dashboard

Grafana templates are available [here](./flake/opentofu/grafana/dashboards).
Note that one can modify a dashboard in Grafana, download the JSON model and
commit it in this repo.

### Deploying

`ssh` to `dev-deployer`, go to `ouroboros-network-ops` directory and execute:
```
just tf grafana apply
```
## Updating the Deployment

This deployment uses
[cardano-parts](https://github.com/input-output-hk/cardano-parts), which
periodically releases new features and `cardano-node` versions. Therefore,
it’s necessary to update the `cardano-parts` version in this repository. This
section provides a step-by-step guide to perform the update.

### Environment Setup

Before starting, ensure that you have the appropriate environment:

- **Using the `dev-deployer` machine**: The `direnv` tool will automatically
  load the Nix development shell.
- **Using a local copy**: If working from a local repository, run the
  following command to enable the necessary Nix features:

  ```bash
  nix --extra-experimental-features fetch-closure develop
  ```
  _Note_: Updating from the `dev-deployer` machine is recommended because you
  can immediately test the changes. However, updating from a local copy makes
  opening a PR easier, as the `dev-deployer` machine lacks GitHub credentials.

  _Note_: For those working regularly in this repo, it may be worth mentioning
  that the `fetch-closure` experimental feature can be added to the
  `nix.conf` file so it doesn't need to be included manually on the cli each
  time. This would then also allow using direnv to automatically load the nix
  develop default shell when entering the local repo directory.

### Step 1: Check Current `cardano-parts` Version

To check the current version of `cardano-parts`, run:

```bash
nix flake metadata | grep cardano-parts
```

This command will return an output similar to the following:

```
├───cardano-parts: github:input-output-hk/cardano-parts/01f54d8feac449f846f33988f7d74711a1b856da
│   │   ├───nixpkgs follows input 'cardano-parts/nixpkgs'
│   │   ├───nixpkgs follows input 'cardano-parts/nixpkgs'
│   │   │   └───nixpkgs follows input 'cardano-parts/haskell-nix/hydra/nix/nixpkgs'
│   │   ├───nixpkgs follows input 'cardano-parts/haskell-nix/nixpkgs-unstable'
│   │   └───stackage follows input 'cardano-parts/empty-flake'
│       └───nixpkgs follows input 'cardano-parts/nixpkgs'
├───flake-parts follows input 'cardano-parts/flake-parts'
├───nixpkgs follows input 'cardano-parts/nixpkgs'
└───nixpkgs-unstable follows input 'cardano-parts/nixpkgs-unstable'
```

At the time of writing, the repository uses the `cardano-parts` revision `01f54d8feac449f846f33988f7d74711a1b856da`.

### Step 2: Identify the Associated PR

To see which pull request (PR) corresponds to the current revision:

1. Visit the [cardano-parts `main` commits page](https://github.com/input-output-hk/cardano-parts/commits/main).
2. Locate the commit that matches your current revision, or go directly to the
   [commit URL for the current version](https://github.com/input-output-hk/cardano-parts/commits/01f54d8feac449f846f33988f7d74711a1b856da).

For example, revision `01f54d8feac449f846f33988f7d74711a1b856da` corresponds
to [PR #48](https://github.com/input-output-hk/cardano-parts/pull/48).

### Step 3: Review Following PRs

Once you’ve identified the current PR, determine which PRs have been merged
since. For instance, PR
[#48](https://github.com/input-output-hk/cardano-parts/pull/48) is followed by
the unfinished [PR #49](https://github.com/input-output-hk/cardano-parts/pull/49).

We'll focus on updating based on the latest merged PR (#48).

### Step 4: Update `cardano-parts` Version

To update `cardano-parts` to the latest version, run:

```bash
nix flake update cardano-parts
```

This updates to the latest version from the `main` branch. If you want to
point to a specific branch or revision, manually update the `flake.nix` file.
After updating, you can use the following commands to verify changes:

- Run `menu` to confirm that the `cardano-node` version has changed.
- Run `just` to list useful commands.

### Step 5: Apply Changes from the PR

Review the PR details for any changes or recommendations. For example, PR
[#48](https://github.com/input-output-hk/cardano-parts/pull/48) modifies the
following files:

```
Justfile                                                                # Adds IPv6 recipe support
flake/colmena.nix                                                       # Adds staticIpv6 declaration
flake/opentofu/cluster.nix                                              # Adds IPv6 Terraform support
flake/opentofu/grafana/alerts/cardano-node-divergence.nix-import        # Updates alerts for new tracing metrics
flake/opentofu/grafana/alerts/cardano-node-forge.nix-import             # Updates alerts for new tracing metrics
flake/opentofu/grafana/alerts/cardano-node-quality.nix-import           # Updates alerts for new tracing metrics
flake/opentofu/grafana/alerts/cardano-node.nix-import                   # Updates alerts for new tracing metrics
flake/opentofu/grafana/dashboards/cardano-node-new-tracing.json         # Updates dashboard for new tracing metrics
flake/opentofu/grafana/dashboards/cardano-node-p2p-new-tracing.json     # Updates dashboard for new tracing metrics
flake/opentofu/grafana/dashboards/cardano-performance-new-tracing.json  # Updates dashboard for new tracing metrics
```

Focus on inspecting changes to `flake/colmena.nix` and `flake/cluster.nix`, as
these are important. Use the following commands to review and apply changes:

- To diff a file, use:

  ```bash
  just template-diff "$FILE"
  ```

- To apply changes if the diff looks correct, use:

  ```bash
  just template-patch "$FILE"
  ```

For other files, you can clone them directly by running:

```bash
just template-clone "$FILE"
```

**Note**: Some files listed in the PR may not exist in your deployment. These
can typically be ignored unless explicitly mentioned in the PR description.

### Step 6: Apply the Changes

After updating the necessary files, apply the changes with:

```bash
just apply
```

For specific machines, use something similar to:

```bash
just apply "'mainnet*'"
```

_Important_: If changes were made to `opentofu` or `grafana` files, you also
need to run:

```bash
just tf grafana apply
```

_Important_: If changes were made to cluster resources changes, such as aws
ec2, route53, etc:

```bash
just tf apply # or just tf cluster apply
```

### Final Step: Create a PR

After successfully applying the changes, open a PR with the updated files.
**Remember:** If you're working from the `dev-deployer` machine, do not commit
the `ips-DONT-COMMIT` file.
```

## Customize deployment

Nix is a wonderful declarative configuration language, but it can be tricky to
understand where things come from due to it being untyped, all the implicit
arguments and abstraction layers. This section explains how one can update the
deployment to run a custom `cardano-node` version or a custom `cardano-node`
configuration.

### Custom `cardano-node` Version

The configuration entry point is the `./flake.nix` file, which defines inputs
and outputs for the deployment. Currently, the file includes local pins for
customizations, as shown below:

```nix
  inputs = {
    nixpkgs.follows = "cardano-parts/nixpkgs";
    nixpkgs-unstable.follows = "cardano-parts/nixpkgs-unstable";
    flake-parts.follows = "cardano-parts/flake-parts";
    cardano-parts.url = "github:input-output-hk/cardano-parts";

    # Local pins for additional customization:
    cardano-node-8-12-2.url = "github:IntersectMBO/cardano-node/8.12.2";
    iohk-nix-8-12-2.url = "github:input-output-hk/iohk-nix/577f4d5072945a88dda6f5cfe205e6b4829a0423";
  };
```

To add a custom node version, simply include a new input pointing to the
desired branch or revision. If you're using an older `cardano-node` version,
you might also need to pin an appropriate version of `iohk-nix`.

### Step 1: Modify `flake.nix`

Add your custom inputs in the `flake.nix` file. For example, to add a custom
`cardano-node` version:

```nix
  cardano-node-<version>.url = "github:<your-organization>/cardano-node/<version>";
```

If needed, also add the corresponding `iohk-nix` pin for compatibility with
older versions.

### Step 2: Update `colmena.nix`

Next, update the `./flake/colmena.nix` file, which contains the configuration
for each individual machine. Create a new variable for your custom node
version, for example:

```nix
node8-12-2 = {
  imports = [
    config.flake.cardano-parts.cluster.groups.default.meta.cardano-node-service
    inputs.cardano-parts.nixosModules.profile-cardano-node-group
    inputs.cardano-parts.nixosModules.profile-cardano-custom-metrics
    {
      cardano-parts.perNode = {
        lib.cardanoLib = config.flake.cardano-parts.pkgs.special.cardanoLibCustom inputs.iohk-nix-8-12-2 "x86_64-linux";
        pkgs = {
          inherit
            (inputs.cardano-node-8-12-2.packages.x86_64-linux)
            cardano-cli
            cardano-node
            cardano-submit-api
            ;
        };
      };
    }
  ];
};
```

This is based on the default `node` configuration, with custom inputs for the
specified node version.

### Step 3: Create Custom Configurations (Optional)

If you don’t need to include previous `cardano-node` versions, you can
simplify the configuration by omitting unused packages. For example:

```nix
node-tx-submission = {
  imports = [
    # Base cardano-node service
    config.flake.cardano-parts.cluster.groups.default.meta.cardano-node-service

    # Config for cardano-node group deployments
    inputs.cardano-parts.nixosModules.profile-cardano-node-group
    inputs.cardano-parts.nixosModules.profile-cardano-custom-metrics
    {
      cardano-parts.perNode = {
        pkgs = {
          inherit
            (inputs.cardano-node-tx-submission.packages.x86_64-linux)
            cardano-node
            ;
        };
      };
    }
  ];
};

You'll require to update `./flake.nix` file to include such an input.
```

### Step 4: Update Machine Configurations

Once the custom node variable is instantiated, update the machine
configurations. At the end of the `./flake/colmena.nix` file, you'll see
entries similar to:

```nix
mainnet1-rel-au-1 = {imports = [au m6i-xlarge (ebs 300) (group "mainnet1") node rel topoAu];};
mainnet1-rel-br-1 = {imports = [br m6i-xlarge (ebs 300) (group "mainnet1") node rel topoBr];};
mainnet1-rel-eu3-1 = {imports = [eu3 m6i-xlarge (ebs 300) (group "mainnet1") node-tx-submission rel topoEu3];};
mainnet1-rel-jp-1 = {imports = [jp m6i-xlarge (ebs 300) (group "mainnet1") node rel topoJp];};
mainnet1-rel-sa-1 = {imports = [sa m6i-xlarge (ebs 300) (group "mainnet1") node rel topoSa];};
mainnet1-rel-sg-1 = {imports = [sg m6i-xlarge (ebs 300) (group "mainnet1") node rel topoSg];};
mainnet1-rel-us1-1 = {imports = [us1 m6i-xlarge (ebs 300) (group "mainnet1") node-tx-submission rel topoUs1];};
mainnet1-rel-us2-1 = {imports = [us2 m6i-xlarge (ebs 300) (group "mainnet1") node-tx-submission rel topoUs2];};
```

Here, I've replaced `node` with `node-tx-submission` for the machines where
that configuration is required. You should make similar substitutions as
needed for your deployment.

### Step 5: Customize as Needed

If you want to adjust any configuration parameters, this section of the file
is where you should make changes. Update the machine definitions as necessary
to meet your specific requirements.
```
