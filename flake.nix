{
  description = "Cardano New Parts Project";

  inputs = {
    nixpkgs.follows = "cardano-parts/nixpkgs";
    nixpkgs-unstable.follows = "cardano-parts/nixpkgs-unstable";
    flake-parts.follows = "cardano-parts/flake-parts";
    cardano-parts.url = "github:input-output-hk/cardano-parts/v2025-02-04";

    # Local pins for additional customization:
    cardano-node-tx-submission.url = "github:IntersectMBO/cardano-node/bolt12/tx-submission";
    cardano-node-9-2-1.url = "github:IntersectMBO/cardano-node/9.2.1";
    iohk-nix-9-2-1.url = "github:input-output-hk/iohk-nix/master";
    cardano-node-10-2-1-coot.url = "github:IntersectMBO/cardano-node/coot/ouroboros-network-0.19.0.2";

    cardano-node-10-2-reusable-diffusion.url = "github:IntersectMBO/cardano-node/bolt12/reusable-diffusion-3";
    cardano-node-10-2.url = "github:IntersectMBO/cardano-node/nm/release-srp";
    cardano-node-10-2-bolt.url = "github:IntersectMBO/cardano-node/bolt12/nm/release-srp";

    # marcinw genesis testing
    cardano-node-10-2-genesis.url = "github:IntersectMBO/cardano-node/mwojtowicz/genesis-outbound-to-non-big-peers";
  };

  outputs = inputs: let
    inherit (inputs.nixpkgs.lib) mkOption types;
    inherit (inputs.cardano-parts.lib) recursiveImports;
  in
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      imports =
        recursiveImports [
          ./flake
          ./perSystem
        ]
        ++ [
          inputs.cardano-parts.flakeModules.aws
          inputs.cardano-parts.flakeModules.cluster
          inputs.cardano-parts.flakeModules.entrypoints
          inputs.cardano-parts.flakeModules.jobs
          inputs.cardano-parts.flakeModules.lib
          inputs.cardano-parts.flakeModules.pkgs
          inputs.cardano-parts.flakeModules.process-compose
          inputs.cardano-parts.flakeModules.shell
          {options.flake.opentofu = mkOption {type = types.attrs;};}
        ];
      systems = ["x86_64-linux"];
      debug = true;
    };

  nixConfig = {
    extra-substituters = ["https://cache.iog.io"];
    extra-trusted-public-keys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="];
    allow-import-from-derivation = true;
  };
}
