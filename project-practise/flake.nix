{
  description = "CQUniAI NixOS fleet config";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }:
    let
      inherit (nixpkgs) lib;
      hostNames = builtins.attrNames (builtins.readDir ./hosts);
    in
    {
      nixosConfigurations = builtins.listToAttrs (map (name: {
        name = name;
        value = nixpkgs.lib.nixosSystem {
          modules = [
            { networking.hostName = name; }
            ./hosts/${name}/configuration.nix
            # Explicitly include hardware-configuration.nix even though it is gitignored.
            # This ensures it is always available to the flake (required for nixos-rebuild).
            # The file is generated per-machine during install.sh and lives only on that host.
          ] ++ lib.optional (builtins.pathExists ./hosts/${name}/hardware-configuration.nix)
            (import (builtins.path {
              path = ./hosts/${name}/hardware-configuration.nix;
              name = "hardware-configuration-${name}";
            }));
          specialArgs = {
            unstable = import nixpkgs-unstable {
              config.allowUnfree = true;
            };
          };
        };
      }) hostNames);
    };
}
