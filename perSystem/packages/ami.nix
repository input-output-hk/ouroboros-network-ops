{
  inputs,
  config,
  ...
}: {
  perSystem = {system, ...}: {
    # The virtiofs virtualisation seems to require >= 1M nofile hard limit to build successfully.
    packages.ami =
      (inputs.nixpkgs.lib.nixosSystem {
        modules = [
          config.flake.nixosModules.ami
          {
            nixpkgs.hostPlatform = system;
            system.stateVersion = "25.11";
          }

          # for sops with KMS
          inputs.cardano-parts.nixosModules.profile-common
          {programs.auth-keys-hub.enable = false;}
        ];
      }).config.system.build.amazonImage;
  };
}
