{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    nativeBuildInputs = [ pkgs.awscli2
                          pkgs.terraform
                          pkgs.ec2-api-tools
                          pkgs.ec2-ami-tools
                          pkgs.nixops
                        ];
}
