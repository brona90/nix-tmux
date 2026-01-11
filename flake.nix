{
  description = "Gregory's tmux configuration via Nix";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    tmux-config = {
      url = "path:./tmux-config";
      flake = false;
    };
  };
  
  outputs = { self, nixpkgs, tmux-config, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      
      # Create a wrapper that sets up tmux with our config
      tmuxWithConfig = pkgs.writeShellScriptBin "tmux" ''
        # Set up config directory
        TMUX_CONFIG_DIR="''${TMUX_CONFIG_DIR:-$HOME/.config/tmux}"
        
        # Auto-sync config if it doesn't exist or is outdated
        if [ ! -f "$TMUX_CONFIG_DIR/.tmux.conf" ]; then
          echo "Setting up tmux config for first time..."
          mkdir -p "$TMUX_CONFIG_DIR"
          cp -f "${tmux-config}/.tmux.conf" "$TMUX_CONFIG_DIR/.tmux.conf"
          cp -f "${tmux-config}/.tmux.conf.local" "$TMUX_CONFIG_DIR/.tmux.conf.local"
          
          if [ -d "${tmux-config}/plugins" ]; then
            mkdir -p "$TMUX_CONFIG_DIR/plugins"
            cp -rf "${tmux-config}/plugins/"* "$TMUX_CONFIG_DIR/plugins/"
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
        SOURCE_DIR="${tmux-config}"
        
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
    {
      packages.${system} = {
        default = tmuxPackage;
        tmux = tmuxPackage;
        sync-tmux-config = syncConfig;
      };
      
      apps.${system} = {
        default = {
          type = "app";
          program = "${tmuxWithConfig}/bin/tmux";
        };
        sync-tmux-config = {
          type = "app";
          program = "${syncConfig}/bin/sync-tmux-config";
        };
      };
      
      devShells.${system}.default = pkgs.mkShell {
        packages = [ tmuxPackage syncConfig ];
        
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
    };
}