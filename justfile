# justfile for dwl-flake

# List available recipes
default:
    @just --list

# Format all Nix files
fmt:
    nix fmt -- .

# Check formatting without modifying
fmt-check:
    nix fmt -- --check .

# Run all checks
check:
    nix flake check -L

# Run evaluation checks across all systems without building
eval:
    nix flake check --no-build --all-systems

# Run the NixOS QEMU VM integration test driver
test-vm:
    nix build .#checks.x86_64-linux.vm.driver && ./result/bin/nixos-test-driver

# Update dwl, patches, and lockfile
update:
    nix run .#update

# Regenerate patch compatibility index (nix/patches.json)
update-index:
    nix run .#update-index

# Verify that all default patches apply cleanly
verify-patches:
    nix run .#verify-patches

# Compare patches with upstream dwl
compare-upstream:
    nix run .#compare-upstream

# Update docs.md from NixOS and Home Manager options
update-docs:
    nix run .#update-docs
