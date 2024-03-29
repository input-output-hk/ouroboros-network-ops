# Table of Contents

- [Table of Contents](#table-of-contents)
  * [TODOs](#todos)
    + [Additional TODOs](#additional-todos)
  * [Steps to deploy with Terraform](#steps-to-deploy-with-terraform)
  * [How to deploy](#how-to-deploy)
    + [Cardano Tracer](#cardano-tracer)
      - [Setting things up](#setting-things-up)
    + [Current deployment notes](#current-deployment-notes)
    + [Tweaking nodes / configurations](#tweaking-nodes---configurations)
      - [Changing node version](#changing-node-version)
      - [Changing a particular instances version](#changing-a-particular-instances-version)
  * [Scripts to generate graphs](#scripts-to-generate-graphs)
  * [Material](#material)
    + [Flakes](#flakes)
    + [Deploy with nix](#deploy-with-nix)
    + [Cardano](#cardano)
    + [AWS](#aws)

## TODOs

- [x] Remove NixOS AMI generation dependency
  - [x] PR to nixpkgs adding the all the regions currently available in order to get NixOS
    AMIs available on them
  - [x] Make sure that the AMIs are available
  - [x] Refactor the Terraform config to just use the available AMIs instead of generating
        them
- [x] Figure out a way to hide the secrets
  - [x] Change personal AWS tokens (due to commit history)
  - [x] confirm that IOHK tokens have never been committed
- [x] Add 2 different cardano-node versions to niv
- [x] Add a let in replacement for all the servers targetHost

### Additional TODOs

- [x] Get [#4196](https://github.com/input-output-hk/cardano-node/pull/4196/) merged
- [x] Add monitoring node configuration

## Steps to deploy with Terraform

- There are regions that do not have NixOS AMIs so one need to generate one and upload it
to those:
  - jp
  - sg
  - au
  - br
- Export AWS Secrets
- ~~For that we need an S3 bucket in each region and a set of specific IAM roles (https://docs.aws.amazon.com/vm-import/latest/userguide/vmimport-image-import.html)~~
- ~~It is not possible to copy official NixOS AMIs from other regions to the ones we need,
  so we need to generate ours and upload them~~
  - ~~https://nixos.wiki/wiki/Install_NixOS_on_Amazon_EC2~~
  - ~~https://github.com/NixOS/nixpkgs/issues/85857~~
  - ~~The links above can help.~~
  - ~~Notes: change home_region, bucket and regions vars and edit lines to make_image_public
  if needed.~~
- ~~After that get the AMIs for each region and add them to terraform configuration~~

_**NOTE:** As of NixOS 22.05 release, AMIs for all AWS regions are available, so this step
is no longer needed_

## How to deploy

In folder `dev-deployer-terraform`, there's `main.tf` that has the terraform
configuration to deploy NixOS machines on different AWS regions. ~~This
Terraform config also runs 2 bash commands: 1 to create a NixOS image,
and a script to upload the image to an AWS bucket and import it as an image,
making it available in all the regions necessary.~~

To run the terraform config from a clean AWS configuration do the following:

- Make sure all the regions you want are enabled;
  - At the current time we do not have any instance in Bahrain, for example.
    If we did, then we'd also need to enable global permissions, see:
    https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_enable-regions.html?icmpid=docs_iam_console
- Make sure the account has the necessary permissions;
- Make sure your credentials are correctly configured:
  - `aws configure`
- ~~Make sure you edit `main.tf` and `create-ami.sh` to be in sync (e.g. S3 Bucket name,
  home-regions, etc.);~~
- Do `terraform init`;
- Do `terraform plan` to check you haven't forgotten anything;
- If everything looks good do `terraform apply` and let it run;
- After finished you should have:
  - ~~An S3 bucket;~~
  - ~~A role and policy called `vmimport`;~~
  - A security role for each machine's region enabling traffic;
  - A key pair for each machine's region;
  - An EC2 instance.

~~Due to the way S3 buckets work if something goes wrong during the plan execution,
you might not be able to perform `terraform destroy`. If that is the case you will have to
delete all the stuff by hand if you want to rerun a script from a clean state. Maybe you can
get without deleting everything and only the S3 bucket and then do `terraform destroy`. On
the other hand if everything finishes successfully you will be able to perform `terraform
destroy`, just make sure the bucket is empty before hand. NOTE: That the AMIs and
respective snapshots won't get deleted so you will have to delete those by hand.~~

~~I believe we'll only need to run the deployment once and if needed only rerun the script
to make NixOS AMIs available in new regions. For deployment we should run something like
`terraform apply -target=resource`.~~

_**NOTE:** As of NixOS 22.05 release, AMIs for all AWS regions are available, so this
information is no longer accurate_

~~_THINGS TO HAVE IN MIND_:~~

- ~~The `create-ami.sh` script will cache things in `$PWD/ami/ec2-images` so you might want
to delete that when trying to obtain a clean state;~~
- ~~You ought to rename the bucket if wanting to rerun the deployment from a previously
deleted bucket since AWS might take some time to recognize that bucket was deleted.~~

After having run the terraform configuration, you have to manually get the public ips
for each machine and add them to the `machine-ips.nix` file. Then you should create a
new nixops network and deploy it with `nixops create -d my-network network.nix` after
`nixops deploy -d my-network`. You should be able to get the IPs for each regions by
running the following command:

`terraform show -json | jq '.values.root_module.child_modules[].resources[].values | "\(.availability_zone) : \(.public_ip)"' | grep -v "null : null"`

_If one updates the NixOS version of the AMIs be sure to also update the nixpkgs version on
niv to the same one._

nixops will try to ssh into the machines as root so you might need to run:

````
> eval `ssh-agent`
> ssh-add ssh-keys/id_rsa_aws
````

Please _NOTE_ that if the machine you're using to deploy (local machine) has a different
or incompatible nixpkgs version with the one in the remote side (remote machine that is
going to get deployed) - you will notice this with stange errors such as
"service.zfs.expandOnBoot does not exist" - you will need to modify your deployment to use
a different nix path. So after creating the deployment and if you get weird errors as the
one described previously:

- Run `niv show` to get the nixpkgs version and url;
- Copy the nixpkgs url being used;
- Run `nixops modify -I nixpkgs=<url> -d my-network network.nix`
- Try again

If you want to further configure each individual server you can look into:
https://github.com/input-output-hk/cardano-node/blob/master/nix/nixos/cardano-node-service.nix#L136
to see all the options available for configuration.

### Cardano Tracer

After deploying you can setup `cardano-tracer` to monitor the nodes with RTView or
Prometheus and EKG servers (Please see more [here](https://github.com/input-output-hk/cardano-node/tree/master/cardano-tracer#readme))

Currently this deployment repository is configured to work with cardano-tracer and
monitoring the nodes via RTView (please check the specific [RTView page](https://github.com/input-output-hk/cardano-node/blob/master/cardano-tracer/docs/cardano-rtview.md)).
Succintly there are 2 ways of running RTView:

- Local
- Distributed

In the local setup, `cardano-tracer` and `cardano-node` run on the same
machine. In a distributed setup `cardano-tracer` can be used to monitor multiple `cardano-node`s which all run on different machines.

The one we want is the distributed one, where `cardano-tracer` runs on the deployer
machine and the nodes on the deployed AWS instances.

There are two particular things about the distributed way of setting up `cardano-tracer`:
it can act as a Server or as a Client. As a Server, `cardano-tracer` waits for connections
from `cardano-node` instances (so nodes are clients); and as a Client, `cardano-tracer`
connects to `cardano-node` instances (so nodes are servers). We pick which way we want by
configuring `cardano-tracer` with an `AcceptAt` or `ConnectTo` attribute and running the
nodes with a `--tracer-socket-connect` or `--tracer-socket-accept`.

For our particular situation, we are going to use `cardano-tracer` as a client and
`cardano-node` instances as servers, since we can only establish a one-way connection
from the deployer machine to the AWS instances via SSH. As our configuration is static and
we won't be adding/removing nodes very often this shouldn't be much of a problem.
More details about this tool can be found on its homepage.

#### Setting things up

This repository has a folder called `dev-deployer-cardano-tracer` where you can find a
`config.json` and `make-tunnels.nix` files. If you have filled the `./machine-ips.nix`
and you have the machines running then all it is needed is to run:

```
> nix-build makeScripts.nix
```

This is going to generate `make-tunnels-mainnet.sh` and `make-tunnels-testnet.sh` that are
responsible for launching `cardano-tracer` and start up all needed ssh local port
forwardings. These scripts however are stored in the nix store, but their symlinked
counterparts are named `result` and `result-2`, which can be found in the same
directory that last command was run. `result` is for mainnet and `result-2` is for
testnet.

At last one can setup one last local port forwarding from its personal
computer to the `dev-deployer` machine in order to access the WebUI:

```
> ssh -nNT \
      -L 3100:0.0.0.0:3100 \
      -L 3101:0.0.0.0:3101 \
      -L 3200:0.0.0.0:3200 \
      -L 3300:0.0.0.0:3300 \
      -o "ServerAliveInterval 60" \
      -o "ServerAliveCountMax 120" \
      -o "StreamLocalBindUnlink yes" \
      dev-deployer
```

for the mainnet monitor. And

```
> ssh -nNT \
      -L 4100:0.0.0.0:4100 \
      -L 4101:0.0.0.0:4101 \
      -L 4200:0.0.0.0:4200 \
      -L 4300:0.0.0.0:4300 \
      -o "ServerAliveInterval 60" \
      -o "ServerAliveCountMax 120" \
      -o "StreamLocalBindUnlink yes" \
      dev-deployer
```

for the testnet monitor.

_NOTE_: That this is going to launch several programs in the background, if you wish to
completely terminate those make a quick search with:

```
> ps aux | grep 'ssh -nNT'
> ps aux | grep 'cardano-tracer'
```

And killing whatever process you wish.

_OR_ you can run `clean.sh` but be careful that there might be other non-related
processes under the same grep regex.

### Current deployment notes

There a couple of things one should note about the current deployment, the first one being that the cardano-node service depends on a particular commit as one can read in the `network.nix` file:

```nix
  # Common configuration shared between all servers
  defaults = { config, lib, ... }: {
    # import nixos modules:
    # - Amazon image configuration (that was used to create the AMI)
    # - The cardano-node-service nixos module
    imports = [
      "${sources.nixpkgs.outPath}/nixos/modules/virtualisation/amazon-image.nix"

      # It should not matter if we use the mainnet or testnet ones since we are going to
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
      cardano-node-mainnet.nixosModules.cardano-node
    ];
```

Current release (1.35.5) does not contemplate PR [#4196](https://github.com/input-output-hk/cardano-node/pull/4196/), for this reason one has to cherry pick the changes on that PR on top of the release 1.35.5 tag.
If the cardano-node version used already has this changes ignore this paragraph.

The second thing to note is that currently `server-us-west` is overwriting `service.cardano-node.cardanoNodePackages` to test a particular cardano-node revision. One should take this into consideration if wanting to update the node.

### Tweaking nodes / configurations

#### Changing node version

If you want to test how a given node version/branch/revision does in mainnet/testnet
all you have to do is to change the `services.cardano-node.cardanoNodePackages` attribute, for the server's instance of your choosing.

In `network.nix` you will find more details:

```nix
# If you wish to overwrite the cardano-node package to a different one.
# By default it runs the cardano-node-mainnet one.
# You ought to put this on a particular server instead of in the default atttribute

# cardanoNodePackages =
#   cardano-node-mainnet.legacyPackages.x86_64-linux.cardanoNodePackages;
```

A good way to do this is to add a new cardano-node version with niv:

```
niv add input-output-hk/cardano-node -n <name>
niv update <name> -b <branch>
```

or

```
niv update <name> -r <rev>
```

And then add it at the top-level of the `network.nix` file:

```nix
let
  ...
  <name> = (import sources.<name> {});
in
...
```

and use it:

```nix
cardanoNodePackages =
  <name>.legacyPackages.x86_64-linux.cardanoNodePackages;
```

#### Changing a particular instances version

If you want to have a different configuration for a particular server's instance, e.g. enable a set of traces on testnet but not on mainnet, you can do that by changing the `services.cardano-node.extraNodeInstanceConfig`.

In `network.nix` you can find examples of this, e.g.:

- In common `service.cardano-node` configuration:

```nix
      extraNodeInstanceConfig =
        # Custom common node configuration for both mainnet and testnet
        # instances.
        let custom = i : {
          ...
        };
        in
        ifMainnetC lib.recursiveUpdate
                   custom
                   config.services.cardano-node.environments.mainnet.nodeConfig
                   config.services.cardano-node.environments.testnet.nodeConfig;
````

- In a particular server's `service.cardano-node` configuration:

```nix
# Add particular RTView Config
extraNodeInstanceConfig = i : { TraceOptionNodeName = "server-us-west-${toString i}"; };
```

## Scripts to generate graphs

In the `scripts` folder you'll find `scripts/collect-resources.sh` running `./scripts/collect-resources.sh` will generate a file called `combined.png`. That file will have a 2x4 montage of all 8 deployed machines heap consumption information.

## Material

### Flakes

- https://nixos.wiki/wiki/Flakes
- https://www.tweag.io/blog/2020-07-31-nixos-flakes/

### Deploy with nix

- https://zimbatm.com/notes/deploying-to-aws-with-terraform-and-nix
- https://github.com/tweag/terraform-nixos
- https://github.com/colemickens/nixos-flake-example
- https://github.com/edolstra/flake-compat
- https://github.com/serokell/pegasus-infra
- https://github.com/serokell/deploy-rs


### Cardano

- https://outline.zw3rk.com/share/15015d9b-a6c3-4a71-84fc-6c2ca0cac7cb
- https://github.com/input-output-hk/cardano-node/blob/master/doc/getting-started/building-the-node-using-nix.md

### AWS

- https://nixos.wiki/wiki/Install_NixOS_on_Amazon_EC2
- https://github.com/nh2/nixos-ami-building
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/CopyingAMIs.html#ami-copy-steps

