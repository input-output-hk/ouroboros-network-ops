# This will be the provider region where the bucket is going to be created.
# Note that this region should be the same home_region in the create-amis.sh
# file.
#
provider "aws" {
  # Configuration options
  region = "eu-west-1"
}


# AWS S3 Bucket to hold the AMIs
# NOTE: Buckets don't get destroyed by Terraform as they might
# still have things inside. If planning on rerunning this multiple times
# Terraform will issue an "Already exists" error so it is best to delete the bucket
# manually and change the name of the bucket. Make sure to also edit the create-ami.sh
# script.
#
resource "aws_s3_bucket" "ami-nixos-bucket" {
  bucket = "test-ami-nixos-bucket-2"
}

# AWS VMIMPORT role is required to import VM as an image
# https://docs.aws.amazon.com/vm-import/latest/userguide/vmimport-image-import.html
# https://docs.aws.amazon.com/vm-import/latest/userguide/vmie_prereqs.html#vmimport-role
#
resource "aws_iam_role" "vmimport" {
  name               = "vmimport"
  assume_role_policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
            "StringEquals":{
               "sts:Externalid": "vmimport"
            }
         }
      }
   ]
}
EOF
}

resource "aws_iam_policy" "vmimport" {
  name = "vmimport"
  description = "Policy for vmimport role"

  policy = <<EOF
{
   "Version":"2012-10-17",
   "Statement": [
      {
         "Effect":"Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket"
         ],
         "Resource": [
            "arn:aws:s3:::${aws_s3_bucket.ami-nixos-bucket.bucket}",
            "arn:aws:s3:::${aws_s3_bucket.ami-nixos-bucket.bucket}/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:PutObject",
            "s3:GetBucketAcl"
         ],
         "Resource": [
            "arn:aws:s3:::${aws_s3_bucket.ami-nixos-bucket.bucket}",
            "arn:aws:s3:::${aws_s3_bucket.ami-nixos-bucket.bucket}/*"
         ]
      },
      {
         "Effect":"Allow",
         "Action": [
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource":"*"
      }
   ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "vmimport" {
  role       = aws_iam_role.vmimport.name
  policy_arn = aws_iam_policy.vmimport.arn
}


# Create NixOS Image
#
resource "null_resource" "create-nixos-image" {
  depends_on = [ aws_s3_bucket.ami-nixos-bucket ]
  provisioner "local-exec" {
      command = "nix-build ../iohk-nixpkgs/nixos/release.nix -vA amazonImage.x86_64-linux"
    }
}

# Script to upload NixOS Image to S3 Bucket and create AMIs
# and save the AMIs info in a file
#
resource "null_resource" "create-nixos-amis" {
  depends_on = [ null_resource.create-nixos-image ]
  provisioner "local-exec" {
      command = "NIXOS=../iohk-nixpkgs/nixos NIXPKGS=../iohk-nixpkgs ../iohk-nixpkgs/nixos/maintainers/scripts/ec2/create-amis.sh ./result | tail -n +2 > ${path.module}/amis.json"
    }
}

# Load the created AMI infos file
#
data "local_file" "created-amis" {
  depends_on = [ null_resource.create-nixos-amis ]
  filename = "${path.module}/amis.json"
}

module "us-west" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)["${data.aws_region.us-west.name}.x86_64-linux"]
  providers = {
    aws = aws.us-west
  }
}

module "us-east" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)["${data.aws_region.us-east.name}.x86_64-linux"]
  providers = {
    aws = aws.us-east
  }
}

module "jp" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)["${data.aws_region.jp.name}.x86_64-linux"]
  providers = {
    aws = aws.jp
  }
}

module "sg" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)["${data.aws_region.sg.name}.x86_64-linux"]
  providers = {
    aws = aws.sg
  }
}

module "au" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)["${data.aws_region.au.name}.x86_64-linux"]
  providers = {
    aws = aws.au
  }
}

module "br" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)["${data.aws_region.br.name}.x86_64-linux"]
  providers = {
    aws = aws.br
  }
}

module "sa" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)["${data.aws_region.sa.name}.x86_64-linux"]
  instance_type = "t3.2xlarge"
  providers = {
    aws = aws.sa
  }
}

module "eu" {
  source = "./modules/multi-region"
  ami    = jsondecode(data.local_file.created-amis.content)["${data.aws_region.eu.name}.x86_64-linux"]
  providers = {
    aws = aws.eu
  }
}
