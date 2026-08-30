# X Repository Guide

This guide describes how the custom X package repository is configured and consumed.

## Repository Configuration

The repository is declared in `pacman.conf`:

```ini
[x]
SigLevel = Optional TrustAll
Server = https://xlnux.github.io/x-repo/repo/x86_64
```

## Usage in This Project

- Build scripts use `pacman.conf`, so the `[x]` repository is available during image/rootfs creation.
- The package manifest includes X packages such as `x-release`.
- The live/rootfs environment receives this repository configuration through copied config files.

## Add to an Existing Arch System

1. Append the `[x]` block to `/etc/pacman.conf`.
2. Refresh package databases and install X base package:

```bash
sudo pacman -Sy x-release
```

## Security Note

`SigLevel = Optional TrustAll` is convenient for early-stage development and testing, but signed packages and stricter trust settings are recommended for production-grade release workflows.
