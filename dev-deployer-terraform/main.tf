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

variable "nixos-version" { default = "23.11" }

# Assuming the AMIs for older NixOS versions do not change with each new release
resource "null_resource" "get-amis" {
  depends_on = []
  provisioner "local-exec" {
      command = "wget https://raw.githubusercontent.com/NixOS/nixpkgs/master/nixos/modules/virtualisation/amazon-ec2-amis.nix"
    }
}

resource "null_resource" "create-ami-json" {
  depends_on = [ null_resource.get-amis ]
  provisioner "local-exec" {
      command = "nix eval --json -f amazon-ec2-amis.nix | jq > amis.json"
    }
}

# Load the AMI information file
#
data "local_file" "created-amis" {
  depends_on = [ null_resource.create-ami-json ]
  filename = "${path.module}/amis.json"
}

module "us-west" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)[var.nixos-version]["${data.aws_region.us-west.name}"]["x86_64-linux"]["hvm-ebs"]
  providers = {
    aws = aws.us-west
  }
}

module "us-east" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)[var.nixos-version]["${data.aws_region.us-east.name}"]["x86_64-linux"]["hvm-ebs"]
  providers = {
    aws = aws.us-east
  }
}

module "jp" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)[var.nixos-version]["${data.aws_region.jp.name}"]["x86_64-linux"]["hvm-ebs"]
  providers = {
    aws = aws.jp
  }
}

module "sg" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)[var.nixos-version]["${data.aws_region.sg.name}"]["x86_64-linux"]["hvm-ebs"]
  providers = {
    aws = aws.sg
  }
}

module "au" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)[var.nixos-version]["${data.aws_region.au.name}"]["x86_64-linux"]["hvm-ebs"]
  providers = {
    aws = aws.au
  }
}

module "br" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)[var.nixos-version]["${data.aws_region.br.name}"]["x86_64-linux"]["hvm-ebs"]
  providers = {
    aws = aws.br
  }
}

module "sa" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)[var.nixos-version]["${data.aws_region.sa.name}"]["x86_64-linux"]["hvm-ebs"]
  providers = {
    aws = aws.sa
  }
}

module "eu" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)[var.nixos-version]["${data.aws_region.eu.name}"]["x86_64-linux"]["hvm-ebs"]
  providers = {
    aws = aws.eu
  }
  create_monitoring_instance = true
}
