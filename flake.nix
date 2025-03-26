{
  description = "Cardano New Parts Project";

  inputs = {
    nixpkgs.follows = "cardano-parts/nixpkgs";
    nixpkgs-unstable.follows = "cardano-parts/nixpkgs-unstable";
    flake-parts.follows = "cardano-parts/flake-parts";

    # Latest commits on branch next-2025-02-27 will introduce some tracing system issues,
    # so pin it at an earlier commit on that branch for now.
    cardano-parts.url = "github:input-output-hk/cardano-parts/8881275acb18dd4fcc6aaee9c5c7f834e526f562";
    # currently `cardano-parts` gives us access to `cardano-node-10.2.1`

    # Local pins for additional customization:
    cardano-node-tx-submission.url = "github:IntersectMBO/cardano-node/coot/tx-submission-10.3";
    cardano-node-srv.url = "github:IntersectMBO/cardano-node/mwojtowicz/srv-test";
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
