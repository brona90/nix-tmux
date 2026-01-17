{
  description = "Gregory's tmux configuration via Nix";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  
  outputs = { self, nixpkgs, ... }:
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
      mkTmuxPackage = system:
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
          
          # Create a wrapper that sets up tmux with our config
          tmuxWithConfig = pkgs.writeShellScriptBin "tmux" ''
            # Set up config directory
            TMUX_CONFIG_DIR="''${TMUX_CONFIG_DIR:-$HOME/.config/tmux}"
            
            # Auto-sync config if it doesn't exist or is outdated
            if [ ! -f "$TMUX_CONFIG_DIR/.tmux.conf" ]; then
              echo "Setting up tmux config for first time..."
              mkdir -p "$TMUX_CONFIG_DIR"
              cp -f "${tmuxConfig}/.tmux.conf" "$TMUX_CONFIG_DIR/.tmux.conf"
              cp -f "${tmuxConfig}/.tmux.conf.local" "$TMUX_CONFIG_DIR/.tmux.conf.local"
              
              if [ -d "${tmuxConfig}/plugins" ]; then
                mkdir -p "$TMUX_CONFIG_DIR/plugins"
                cp -rf "${tmuxConfig}/plugins/"* "$TMUX_CONFIG_DIR/plugins/"
              fi
              
              echo "✓ Config initialized in $TMUX_CONFIG_DIR"
            fi
            
            # Use our configs
            export TMUX_CONF="$TMUX_CONFIG_DIR/.tmux.conf"
            export TMUX_CONF_LOCAL="$TMUX_CONFIG_DIR/.tmux.conf.local"
            
            # Add perl to PATH for tmux plugins
            export PATH="${pkgs.perl}/bin:$PATH"
            
            exec ${pkgs.tmux}/bin/tmux -f "$TMUX_CONF" "$@"
          '';
          
          # Script to sync config from repo to writable location
          syncConfig = pkgs.writeShellScriptBin "sync-tmux-config" ''
            TMUX_CONFIG_DIR="$HOME/.config/tmux"
            SOURCE_DIR="${tmuxConfig}"
            
            echo "Syncing tmux config from repo to $TMUX_CONFIG_DIR..."
            
            mkdir -p "$TMUX_CONFIG_DIR"
            
            cp -f "$SOURCE_DIR/.tmux.conf" "$TMUX_CONFIG_DIR/.tmux.conf"
            cp -f "$SOURCE_DIR/.tmux.conf.local" "$TMUX_CONFIG_DIR/.tmux.conf.local"
            
            if [ -d "$SOURCE_DIR/plugins" ]; then
              mkdir -p "$TMUX_CONFIG_DIR/plugins"
              cp -rf "$SOURCE_DIR/plugins/"* "$TMUX_CONFIG_DIR/plugins/"
            fi
            
            echo "✓ Config synced to $TMUX_CONFIG_DIR"
          '';
          
          # Combine tmux and perl into a buildEnv
          tmuxPackage = pkgs.buildEnv {
            name = "tmux-with-deps";
            paths = [ tmuxWithConfig pkgs.perl ];
          };
        in
        { inherit tmuxPackage syncConfig tmuxWithConfig; };
      
    in
    {
      packages = forAllSystems (system:
        let
          built = mkTmuxPackage system;
        in
        {
          default = built.tmuxPackage;
          tmux = built.tmuxPackage;
          sync-tmux-config = built.syncConfig;
        }
      );
      
      apps = forAllSystems (system:
        let
          built = mkTmuxPackage system;
        in
        {
          default = {
            type = "app";
            program = "${built.tmuxWithConfig}/bin/tmux";
          };
          sync-tmux-config = {
            type = "app";
            program = "${built.syncConfig}/bin/sync-tmux-config";
          };
        }
      );
      
      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          built = mkTmuxPackage system;
        in
        {
          default = pkgs.mkShell {
            packages = [ built.tmuxPackage built.syncConfig ];
            
            shellHook = ''
              echo "Tmux environment"
              echo ""
              echo "Commands:"
              echo "  tmux              - Launch tmux with your config"
              echo "  sync-tmux-config  - Manually sync config from repo to ~/.config/tmux"
              echo ""
              echo "The config will be automatically set up on first 'tmux' launch."
            '';
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}
