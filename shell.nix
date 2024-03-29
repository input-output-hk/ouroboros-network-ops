# import pinned niv sources
let sources = import ./nix/sources.nix;
    pkgs    = import sources.nixpkgs { };
    cardano-tracer = (import sources.cardano-node-mainnet { }).cardano-tracer;

in pkgs.mkShell {
  # nativeBuildInputs is usually what you want -- tools you need to run
  nativeBuildInputs = [ pkgs.awscli2
                        pkgs.terraform
                        pkgs.ec2-api-tools
                        pkgs.ec2-ami-tools
                        pkgs.nixops
                        pkgs.nix
                        pkgs.wget
                        pkgs.niv
                        cardano-tracer
                      ];
                }
