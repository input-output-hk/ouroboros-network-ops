{
  description = "Cardano New Parts Project";

  inputs = {
    nixpkgs.follows = "cardano-parts/nixpkgs";
    flake-parts.follows = "cardano-parts/flake-parts";
    cardano-parts.url = "github:input-output-hk/cardano-parts/next-2026-10-12";

    # Leios prototype node. Keep this on the same pin as cardano-playground's
    # leios hosts, since they run the network this relay joins.
    cardano-node-leios.url = "github:input-output-hk/ouroboros-leios?ref=refs/tags/rc-2026w44";

    # Leios observability source: the shared Alloy enrichment modules
    # (demo/proto-devnet/config/alloy-modules/*.alloy) used by leios-alloy-logs.
    leios-observability = {
      url = "github:input-output-hk/ouroboros-leios/jl/alloy-dash-enhance";
      flake = false;
    };
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
