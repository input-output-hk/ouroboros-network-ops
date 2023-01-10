variable "ami" {}
variable "instance_type" { default = "t3a.2xlarge" }

# If universal access is needed from another machine this is the place to add it.
#                                        ---v dev-deployer machine
variable "allowed-to-access" { default = [ "<dev deployer IP>"
                                         ] }

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_security_group" "allow_deployer_sg" {
  name        = "allow_deployer_sg"

  ingress {
    description = "allow all from deployer"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.allowed-to-access
  }
}

resource "aws_security_group" "allow_all_sg" {
  name    = "allow_all_sg"

  ingress {
    description = "allow all hosts to access any port greater than 1023 (IPv4)"
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "allow all hosts to access any port greater than 1023 (IPv6)"
    from_port        = 1024
    to_port          = 65535
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
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

resource "aws_key_pair" "admin_kp" {
  key_name   = "admin_kp"
  public_key = "<admin key>"
}

resource "aws_instance" "cad-2694-node" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = "admin_kp"
  ebs_optimized = true
  root_block_device {
    volume_size = 160
    volume_type = "standard"
  }
  security_groups = [
    aws_security_group.allow_deployer_sg.name,
    aws_security_group.allow_all_sg.name
  ]
}
