{
  description = "Gregory's tmux configuration via Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      # Support multiple systems
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Helper to generate attrs for each system
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Get pkgs for a specific system
      pkgsFor = system: import nixpkgs { inherit system; };

      # Build the tmux package for a specific system
      mkTmuxPackage =
        system:
        let
          pkgs = pkgsFor system;

          # Copy tmux-config to the Nix store instead of using a flake input
          tmuxConfig = pkgs.stdenv.mkDerivation {
            name = "tmux-config";
            src = ./tmux-config;
            dontBuild = true;
            installPhase = ''
              mkdir -p $out
              if [ -d "$src" ]; then
                cp -r $src/. $out/
              fi
            '';
          };

          # Create a wrapper that uses config directly from Nix store (immutable)
          tmuxWithConfig = pkgs.writeShellScriptBin "tmux" ''
            # Add perl to PATH for tmux plugins
            export PATH="${pkgs.perl}/bin:$PATH"

            # Set TMUX_CONF so the .local file gets sourced correctly
            export TMUX_CONF="${tmuxConfig}/.tmux.conf"

            # Use config directly from Nix store (immutable)
            exec ${pkgs.tmux}/bin/tmux -f "$TMUX_CONF" "$@"
          '';

          # Combine tmux and perl into a buildEnv
          tmuxPackage = pkgs.buildEnv {
            name = "tmux-with-deps";
            paths = [
              tmuxWithConfig
              pkgs.perl
            ];
          };
        in
        {
          inherit tmuxPackage tmuxWithConfig;
        };

    in
    {
      packages = forAllSystems (
        system:
        let
          built = mkTmuxPackage system;
        in
        {
          default = built.tmuxPackage;
          tmux = built.tmuxPackage;
        }
      );

      apps = forAllSystems (
        system:
        let
          built = mkTmuxPackage system;
        in
        {
          default = {
            type = "app";
            program = "${built.tmuxWithConfig}/bin/tmux";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          built = mkTmuxPackage system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              built.tmuxPackage
            ];

            shellHook = ''
              echo "Tmux environment (immutable config)"
              echo ""
              echo "Config is managed by Nix. To change config:"
              echo "  1. Edit tmux-config/.tmux.conf.local"
              echo "  2. nix build && commit && push"
              echo "  3. nfu && hms on target machine"
            '';
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}
