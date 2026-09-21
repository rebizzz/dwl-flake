import subprocess
import json
import os
import sys

def run(cmd, capture=True):
    print(f">> {cmd}", flush=True)
    res = subprocess.run(cmd, shell=True, text=True, capture_output=capture)
    return res

print("Evaluating derivations for individual patches...", flush=True)
eval_cmd = """nix eval --impure --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (pkgs) lib;
in lib.mapAttrs (channel: names: lib.genAttrs names (name:
  let
    pkg = (flake.lib.mkDwl pkgs channel).override { patches = [ name ]; };
  in {
    drv = builtins.unsafeDiscardStringContext pkg.drvPath;
    out = builtins.unsafeDiscardStringContext pkg.outPath;
  }
)) flake.lib.compatible'
"""
res = run(eval_cmd)
if res.returncode != 0:
    print(f"Eval failed: {res.stderr}")
    sys.exit(1)

matrix = json.loads(res.stdout)

results = {"main": {}, "stable": {}}

for channel in ["main", "stable"]:
    patches = matrix[channel]
    print(f"\n==========================================")
    print(f"Testing {len(patches)} individual patches on {channel}...")
    print(f"==========================================")
    
    drv_list = [info["drv"] for info in patches.values()]
    
    # Build in parallel using nix build
    build_cmd = f"nix build --keep-going --no-link {' '.join(drv_list)}"
    print(f"Starting build of {len(drv_list)} derivations for {channel}...", flush=True)
    b_res = run(build_cmd, capture=False)
    
    # Now check each patch individually
    for name, info in patches.items():
        drv = info["drv"]
        out = info["out"]
        chk = run(f"nix path-info {out} 2>/dev/null")
        if chk.returncode == 0:
            results[channel][name] = {"status": "SUCCESS"}
            print(f"  [{channel}] {name}: SUCCESS")
        else:
            log_res = run(f"nix log {drv}")
            log = log_res.stdout + "\n" + log_res.stderr
            fail_type = "UNKNOWN"
            if "conflicts outside config.def.h" in log or "patch: ****" in log or "FAILED" in log or "Reversed (or previously applied) patch" in log:
                fail_type = "PATCH_REJECTION"
            elif "error:" in log or "fatal error:" in log:
                fail_type = "COMPILATION_ERROR"
            
            lines = [l.strip() for l in log.splitlines() if any(k in l for k in ["error:", "fatal error:", "FAILED", "conflicts outside", "rejected"])]
            snippet = "\n".join(lines[:10])
            
            results[channel][name] = {
                "status": "FAIL",
                "failure_type": fail_type,
                "error_snippet": snippet,
                "log": log[-2000:]
            }
            print(f"  [{channel}] {name}: FAIL ({fail_type})")
            print(f"      Snippet: {snippet[:150]}")

with open("scratch/matrix_individual_results.json", "w") as f:
    json.dump(results, f, indent=2)

print("\nIndividual testing complete! Results written to scratch/matrix_individual_results.json")
