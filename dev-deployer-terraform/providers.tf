terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  alias  = "us-west"
  region = "us-west-1"
}

# Needed to get the region for this particular provider
data "aws_region" "us-west" {
  provider = aws.us-west
}

provider "aws" {
  alias  = "us-east"
  region = "us-east-2"
}

# Needed to get the region for this particular provider
data "aws_region" "us-east" {
  provider = aws.us-east
}

provider "aws" {
  alias  = "jp"
  region = "ap-northeast-1"
}

# Needed to get the region for this particular provider
data "aws_region" "jp" {
  provider = aws.jp
}

provider "aws" {
  alias  = "sg"
  region = "ap-southeast-1"
}

# Needed to get the region for this particular provider
data "aws_region" "sg" {
  provider = aws.sg
}

provider "aws" {
  alias  = "au"
  region = "ap-southeast-2"
}

# Needed to get the region for this particular provider
data "aws_region" "au" {
  provider = aws.au
}

provider "aws" {
  alias  = "br"
  region = "sa-east-1"
}

# Needed to get the region for this particular provider
data "aws_region" "br" {
  provider = aws.br
}

provider "aws" {
  alias  = "sa"
  region = "af-south-1"
}

# Needed to get the region for this particular provider
data "aws_region" "sa" {
  provider = aws.sa
}

provider "aws" {
  alias  = "eu"
  region = "eu-west-3"
}

# Needed to get the region for this particular provider
data "aws_region" "eu" {
  provider = aws.eu
}
