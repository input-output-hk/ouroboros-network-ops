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

_THINGS TO HAVE IN MIND_:

- ~~The `create-ami.sh` script will cache things in `$PWD/ami/ec2-images` so you might want
to delete that when trying to obtain a clean state;~~
- ~~You ought to rename the bucket if wanting to rerun the deployment from a previously
deleted bucket since AWS might take some time to recognize that bucket was deleted.~~

After having run the terraform configuration, you have to manually get the public ips
for each machine and add them to the nixops network configuration file (inside folder
`dev-deployer-nixops`. Then you should create a new nixops network and deploy it with
`nixops create -d my-network network.nix` after `nixops deploy -d my-network`.
You should be able to get the IPs for each regions by running the following command:

`terraform show -json | jq '.values.root_module.child_modules[].resources[].values | "\(.availability_zone) : \(.public_ip)"' | grep -v "null : null"`

_If one updates the NixOS version of the AMIs be sure to also update the nixpkgs version on
niv to the same one._

nixops will try to ssh into the machines as root so you might need to run:

- `eval \`ssh-agent\``
- `ssh-add ssh-keys/id_rsa_aws`

Please _NOTE_ that if the machine you're using to deploy (local machine) has a different
or incompatible nixpkgs version with the one in the remote side (remote machine that is
going to get deployed) - you will notice this with stange errors such as
"service.zfs.expandOnBoot does not exist" - you will need to modify your deployment to use
a different nix path. So after creating the deployment and if you get weird errors as the
one described previously:

- Run `niv show` to get the nixpkgs version and url;
- Copy the nixpkgs url being used;
- Run `nixops modify -I nixpkgs=<url> -d my-network network.nix
- Try again

If you want to further configure each individual server you can look into:
https://github.com/input-output-hk/cardano-node/blob/master/nix/nixos/cardano-node-service.nix#L136
to see all the options available for configuration.

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

