# This will be the provider region where the bucket is going to be created.
# Note that this region should be the same home_region in the create-amis.sh
# file.
#
# Source for AMIs:
# https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/amazon-ec2-amis.nix#L445
provider "aws" {
  # Configuration options
  region = "eu-west-1"
}

module "us-west" {
  source = "./modules/multi-region"
  ami    = "ami-0d72ab697beab5ea5"
  providers = {
    aws = aws.us-west
  }
}

module "us-east" {
  source = "./modules/multi-region"
  ami    = "ami-0a743534fa3e51b41"
  providers = {
    aws = aws.us-east
  }
}

module "jp" {
  source = "./modules/multi-region"
  ami    = "ami-009c422293bcf3721"
  providers = {
    aws = aws.jp
  }
}

module "sg" {
  source = "./modules/multi-region"
  ami    = "ami-0f59f7f33cba8b1a4"
  providers = {
    aws = aws.sg
  }
}

module "au" {
  source = "./modules/multi-region"
  ami    = "ami-0d1e49fe30aec165d"
  providers = {
    aws = aws.au
  }
}

module "br" {
  source = "./modules/multi-region"
  ami    = "ami-0732aa0f0c28f281b"
  providers = {
    aws = aws.br
  }
}

module "sa" {
  source = "./modules/multi-region"
  ami    = "ami-0d3a6166c1ea4d7b4"
  instance_type = "t3.2xlarge"
  providers = {
    aws = aws.sa
  }
}

module "eu" {
  source = "./modules/multi-region"
  ami    = "ami-04b50c79dc4009c97
  providers = {
    aws = aws.eu
  }
}
