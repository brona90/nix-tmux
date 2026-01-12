# nix-tmux

A Nix flake for tmux with custom configuration, wrapped with all dependencies for easy installation.

## Features

- **Self-contained**: Includes tmux binary and all dependencies (perl for plugins)
- **Auto-configuring**: Automatically sets up config on first launch
- **Portable**: Works on any system with Nix
- **Reproducible**: Same configuration everywhere

## Quick Start

### Use in home-manager

This is the recommended way to use nix-tmux:

```nix
{
  inputs = {
    nix-tmux.url = "github:brona90/nix-tmux";
  };

  outputs = { self, nixpkgs, nix-tmux, ... }: {
    homeConfigurations.yourname = home-manager.lib.homeManagerConfiguration {
      # ...
      modules = [{
        home.packages = [
          nix-tmux.packages.x86_64-linux.default
        ];
      }];
    };
  };
}
```

### Standalone Usage

Try without installing:
```bash
nix run github:brona90/nix-tmux
```

Install to your profile:
```bash
nix profile install github:brona90/nix-tmux
```

## Configuration

The tmux configuration is stored in `tmux-config/`:
- `.tmux.conf` - Main tmux configuration
- `.tmux.conf.local` - Local customizations
- `plugins/` - Tmux plugins (if any)

On first launch, these files are copied to `~/.config/tmux/`, making them writable for runtime customization.

### Modifying Configuration

1. Edit files in `tmux-config/` directory
2. Test changes:
   ```bash
   nix run .
   ```
3. Commit and push to GitHub
4. Update in home-manager with `nix flake update`

### Manually Sync Config

If you've made changes and want to re-sync from the repo:

```bash
nix run .#sync-tmux-config
```

This overwrites `~/.config/tmux/` with the latest from the flake.

## Configuration Location

The configuration is placed in:
```
~/.config/tmux/
├── .tmux.conf       # Main config (copied from flake on first run)
├── .tmux.conf.local # Local customizations
└── plugins/         # Tmux plugins
```

You can customize these files directly, or modify the source in `tmux-config/` and rebuild.

## How It Works

The flake creates a wrapper script that:
1. Checks if config exists in `~/.config/tmux/`
2. If not, copies config from the Nix store
3. Sets `TMUX_CONF` and `TMUX_CONF_LOCAL` environment variables
4. Adds perl to PATH (required by some tmux plugins)
5. Launches tmux with the custom configuration

## Development

```bash
# Enter development shell
nix develop

# Test tmux with your config
tmux

# Sync config manually
sync-tmux-config
```

## Building

```bash
# Build the package
nix build

# Result will be in ./result/bin/tmux
./result/bin/tmux
```

## Customization Examples

### Add to your home-manager flake

See the [home-manager example](https://github.com/brona90/home-manager) for how to integrate this with other tool flakes.

### Change tmux prefix key

Edit `tmux-config/.tmux.conf`:
```tmux
# Change prefix from C-b to C-a
unbind C-b
set -g prefix C-a
bind C-a send-prefix
```

Then rebuild with `nix build` or update your home-manager configuration.

## Requirements

- [Nix](https://nixos.org/download.html) with flakes enabled
- Linux (x86_64)

Enable flakes by adding to `~/.config/nix/nix.conf`:
```
experimental-features = nix-command flakes
```

## Part of Tool Suite

This flake is part of a modular development environment:
- [nix-vim](https://github.com/brona90/nix-vim) - LazyVim configuration
- [nix-zsh](https://github.com/brona90/nix-zsh) - Zsh with oh-my-zsh
- [nix-tmux](https://github.com/brona90/nix-tmux) - This repository
- [nix-emacs](https://github.com/brona90/nix-emacs) - Doom Emacs
- [nix-git](https://github.com/brona90/nix-git) - Git with aliases
- [home-manager](https://github.com/brona90/home-manager) - Orchestrates all tools

## License

MIT

## Author

Gregory Foster ([@brona90](https://github.com/brona90))
