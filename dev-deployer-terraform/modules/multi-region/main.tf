variable "ami" {}
variable "instance_type" { default = "m6i.xlarge" }
variable "create_monitoring_instance" {
  description = "A boolean flag to control whether the resource should be created"
  type        = bool
  default     = false
}

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
  name = "allow_deployer_sg"
  ingress {
    description = "allow ssh from deployer"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed-to-access
  }
}

resource "aws_security_group" "allow_all_sg" {
  name = "allow_all_sg"
  ingress {
    description = "allow all hosts to access any port greater than 1023 (IPv4 and IPv6)"
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "allow_icmp_sg" {
  name = "allow_icmp_sg"
  ingress {
    description = "allow all ICMP (IPv4)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow all ICMP (IPv6)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmpv6"
    ipv6_cidr_blocks = ["::/0"]
  }
}

output "sg_allow_icmp_sg_id" {
  value = aws_security_group.allow_icmp_sg.id
}

resource "aws_security_group" "allow_grafana_sg" {
  name = "allow_grafana_sg"
  ingress {
    description = "allow only grafana 2342 port (IPv4 and IPv6)"
    from_port   = 2342
    to_port     = 2342
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description     = ""
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_key_pair" "admin_kp" {
  key_name   = "admin_kp"
  public_key = "<admin key>"
}

resource "aws_key_pair" "admin_kp_2" {
  key_name   = "admin_kp_2"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7DmrNylD3NQ0Z1I0i9EqNiPp++gXxgDIrno4jJIR8RBE3oFXjhbY0yJUZt9Tn4uDESQfL0INDO0alWb79OURUL7fKaeXWqbcYolUiCqaxM2bPf8s4giTY0JdG7xaBJq5jSlO34+l1p7DV+tyTHTUYN69jgrc+FMLuQcVDKrXeBKnbyt4YD/hXOuX898D0P554CmM/OMzs0x3DAboqgjmBhoMbdpBqeO6Wmc663SP9D2sTHyOuuUBJFFK9mPNstLMMLJGHsPzzQxsGTp8bwl2yOu9Z3gEp9tC6uvLUHW+P3OCh1vFsLCgYi6L4q/RKAqWni6Oc3i/5i9rF+mJqmBRV7E1zfe9CY9clSSgWgN6vLbhKEIzRvXfzHY+1zUpcziL0aniet0s2yGq5yRhlJWRM9BC/LTcEA8lJJUdEI1C0sI3iEYYKGgKefFhbjTGTNsBk0CzbFKQJqKeMH/wQRBu1sZJwk9khRissDoNGHVWSY9CwS+z/IOfzSDT5eAG5C3M= dev@dev-deployer"
}

resource "aws_instance" "cad-2694-node" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = "admin_kp"
  ebs_optimized = true
  root_block_device {
    volume_size = 200
    volume_type = "standard"
  }
  security_groups = [
    aws_security_group.allow_all_sg.name,
    aws_security_group.allow_icmp_sg.name,
    aws_security_group.allow_deployer_sg.name,
    aws_security_group.allow_icmp_sg.name
  ]
}

resource "aws_instance" "cad-2694-node-monitoring" {
  count         = var.create_monitoring_instance ? 1 : 0
  ami           = var.ami
  instance_type = "t3.nano"
  key_name      = "admin_kp_2"
  ebs_optimized = true
  root_block_device {
    volume_size = 64
    volume_type = "standard"
  }
  security_groups = [
    aws_security_group.allow_deployer_sg.name,
    aws_security_group.allow_grafana_sg.name,
    aws_security_group.allow_icmp_sg.name
  ]
}
