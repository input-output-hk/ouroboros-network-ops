{
  description = "Cardano New Parts Project";

  inputs = {
    nixpkgs.follows = "cardano-parts/nixpkgs";
    nixpkgs-unstable.follows = "cardano-parts/nixpkgs-unstable";
    flake-parts.follows = "cardano-parts/flake-parts";

    # Using cardano-parts release v2025-06-24, we get SSH over SSM migration completed.
    # Currently `cardano-parts` gives us access to cardano-node `10.4.1` and `10.5.0`.
    cardano-parts.url = "github:input-output-hk/cardano-parts/v2025-06-24";

    # Local pins for additional customization:
    cardano-node-tx-submission.url = "github:IntersectMBO/cardano-node/coot/tx-submission-10.5";
    cardano-node-srv.url = "github:IntersectMBO/cardano-node/mwojtowicz/srv-test";
    cardano-node-readbuffer-ig-turbo.url = "github:IntersectMBO/cardano-node/karknu/10_3_0_ig_readbuffer";
    cardano-node-10-3.url = "github:IntersectMBO/cardano-node/10.3.0";
    cardano-node-10-3-readbuffer.url = "github:IntersectMBO/cardano-node/karknu/10_3_0_read_buffer";
    cardano-node-cardano-diffusion.url = "github:IntersectMBO/cardano-node/coot/cardano-diffusion-integration";
    iohk-nix-9-2-1.url = "github:input-output-hk/iohk-nix/master";
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
