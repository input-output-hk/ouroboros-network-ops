variable "ami" {}
variable "instance_type" { default = "t3a.2xlarge" }

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.13.0"
    }
  }
}

resource "aws_security_group" "allow_deployer" {
  name        = "allow_deployer"
  #vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "allow all from deployer"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["3.124.147.122/32"]
  }
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  #vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "allow all from 1024"
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = ""
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    description      = ""
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_key_pair" "admin" {
  key_name   = "admin"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7DmrNylD3NQ0Z1I0i9EqNiPp++gXxgDIrno4jJIR8RBE3oFXjhbY0yJUZt9Tn4uDESQfL0INDO0alWb79OURUL7fKaeXWqbcYolUiCqaxM2bPf8s4giTY0JdG7xaBJq5jSlO34+l1p7DV+tyTHTUYN69jgrc+FMLuQcVDKrXeBKnbyt4YD/hXOuX898D0P554CmM/OMzs0x3DAboqgjmBhoMbdpBqeO6Wmc663SP9D2sTHyOuuUBJFFK9mPNstLMMLJGHsPzzQxsGTp8bwl2yOu9Z3gEp9tC6uvLUHW+P3OCh1vFsLCgYi6L4q/RKAqWni6Oc3i/5i9rF+mJqmBRV7E1zfe9CY9clSSgWgN6vLbhKEIzRvXfzHY+1zUpcziL0aniet0s2yGq5yRhlJWRM9BC/LTcEA8lJJUdEI1C0sI3iEYYKGgKefFhbjTGTNsBk0CzbFKQJqKeMH/wQRBu1sZJwk9khRissDoNGHVWSY9CwS+z/IOfzSDT5eAG5C3M= dev@dev-deployer"
}

resource "aws_instance" "cad-2694-node" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = "admin"
  ebs_optimized = true
  root_block_device {
    volume_size = 90
    volume_type = "standard"
  }
  security_groups = [
    aws_security_group.allow_deployer.name,
    aws_security_group.allow_all.name
  ]
}
