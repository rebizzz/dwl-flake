# Format nix files
fmt:
    nix fmt -- .

# Check formatting
fmt-check:
    nix fmt -- --check .

# Run all checks
check:
    nix flake check -L

# Run the patch engine unit tests
test:
    python3 tests/test_conflict_engine.py

# Eval-only check, all systems
eval:
    nix flake check --no-build --all-systems

# Boot the VM integration test
test-vm:
    nix build .#checks.x86_64-linux.vm.driver && ./result/bin/nixos-test-driver

# Update dwl, patches, lockfile
update:
    nix run .#update

# Regenerate nix/patches.json
update-index:
    nix run .#update-index

# Verify all default patches apply
verify-patches:
    nix run .#verify-patches

# Compare with upstream nixpkgs module
compare-upstream:
    nix run .#compare-upstream

# Regenerate docs.md
update-docs:
    nix run .#update-docs
