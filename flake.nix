{
  description = "Cardano New Parts Project";

  inputs = {
    nixpkgs.follows = "cardano-parts/nixpkgs";
    nixpkgs-unstable.follows = "cardano-parts/nixpkgs-unstable";
    flake-parts.follows = "cardano-parts/flake-parts";

    # Using cardano-parts release v2026-03-30 as the last completed
    # cardano-parts migration. Currently `cardano-parts` gives us access to
    # cardano-node `10.6.4` and `10.7.0` for pre.
    cardano-parts.url = "github:input-output-hk/cardano-parts/next-2026-03-31";

    # Local pins for additional customization -- old examples are commented:
    # cardano-node-tx-submission.url = "github:IntersectMBO/cardano-node/coot/tx-submission-10.5";
    # cardano-node-srv.url = "github:IntersectMBO/cardano-node/mwojtowicz/srv-test";
    # cardano-node-readbuffer-ig-turbo.url = "github:IntersectMBO/cardano-node/karknu/10_3_0_ig_readbuffer";
    # cardano-node-10-3.url = "github:IntersectMBO/cardano-node/10.3.0";
    # cardano-node-10-3-readbuffer.url = "github:IntersectMBO/cardano-node/karknu/10_3_0_read_buffer";
    # cardano-node-cardano-diffusion.url = "github:IntersectMBO/cardano-node/coot/cardano-diffusion-integration";

    # Earliest iohk-nix that supports nodeConfigLegacy attribute used in newer cardano-node-group modules
    # Note that the minNodeVersion at this pin is `10.4.0` for recognition of the `LedgerDb` node config key.
    # Node versions prior to `10.4.0` will simply ignore this key if present.
    # iohk-nix-10-4-0.url = "github:input-output-hk/iohk-nix/dbf6e86e78440c75b15c68c66ba58dca91ace376";

    # For supporting older cardano-node nixos service modules:
    # cardano-node-service-10-3-0 = {
    #   url = "github:IntersectMBO/cardano-node/f11e0f303ddf3e5b8975daf72ceaa522ddb98426";
    #   flake = false;
    # };

    # Pin determined by prior master with successful builds
    # cardano-parts-service-10-3-0.url = "github:input-output-hk/cardano-parts/39dcc23e3977984c3f01b4d8b9474cedec282def";
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
