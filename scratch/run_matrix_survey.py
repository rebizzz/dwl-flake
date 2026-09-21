import subprocess
import json
import os
import sys

def run(cmd):
    return subprocess.run(cmd, shell=True, text=True, capture_output=True)

print("Step 1: Evaluating all individual patch derivations...", flush=True)
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

survey_results = {
    "individual": {"main": {}, "stable": {}},
    "combinations": {}
}

# 1. Build and verify individual patches
for channel in ["main", "stable"]:
    patches = matrix[channel]
    print(f"\nBuilding {len(patches)} individual patches on {channel}...", flush=True)
    
    # We can pass all drv^* to nix build --keep-going --no-link
    targets = [f"'{info['drv']}^*'" for info in patches.values()]
    
    # Build in batches of 25 to avoid overwhelming arguments / memory
    batch_size = 30
    for i in range(0, len(targets), batch_size):
        batch = targets[i:i+batch_size]
        print(f"  Building batch {i//batch_size + 1} ({len(batch)} targets)...", flush=True)
        b_res = run(f"nix build --keep-going --no-link {' '.join(batch)}")
        # print b_res.stderr if needed
    
    # Check outcomes
    success_count = 0
    fail_count = 0
    for name, info in patches.items():
        drv = info["drv"]
        out = info["out"]
        chk = run(f"nix path-info {out}")
        if chk.returncode == 0:
            survey_results["individual"][channel][name] = {
                "status": "SUCCESS",
                "out": out
            }
            success_count += 1
        else:
            log_res = run(f"nix log {drv}")
            log = log_res.stdout + "\n" + log_res.stderr
            fail_type = "UNKNOWN"
            if "conflicts outside config.def.h" in log or "patch: ****" in log or "FAILED" in log or "Reversed (or previously applied) patch" in log:
                fail_type = "PATCH_REJECTION"
            elif "error:" in log or "fatal error:" in log:
                fail_type = "COMPILATION_ERROR"
            
            error_lines = [l.strip() for l in log.splitlines() if any(k in l for k in ["error:", "fatal error:", "FAILED", "conflicts outside", "rejected", "undefined reference"])]
            snippet = "\n".join(error_lines[:8])
            survey_results["individual"][channel][name] = {
                "status": "FAIL",
                "failure_type": fail_type,
                "error_snippet": snippet,
                "log_tail": log[-1500:]
            }
            fail_count += 1
            print(f"  FAILED [{channel}] {name}: {fail_type} -> {snippet[:100]}...", flush=True)
            
    print(f"[{channel}] Complete: {success_count} succeeded, {fail_count} failed out of {len(patches)}")

# 2. Test Combination Suites
print("\nStep 2: Testing Combination Suites...", flush=True)

suites_to_test = [
    {
        "id": "chadwm_stable",
        "name": "Chadwm Full Suite",
        "channel": "stable",
        "patches": [
            "bar", "barpadding", "barcolors", "vanitygaps", "gaplessgrid",
            "movestack", "attachbottom", "decklayout", "centeredmaster"
        ],
        "category": "chadwm"
    },
    {
        "id": "chadwm_with_pertag_stable",
        "name": "Chadwm Full Suite + pertag",
        "channel": "stable",
        "patches": [
            "bar", "barpadding", "barcolors", "vanitygaps", "gaplessgrid",
            "movestack", "attachbottom", "decklayout", "centeredmaster", "pertag"
        ],
        "category": "chadwm"
    },
    {
        "id": "chadwm_layouts_stable",
        "name": "Chadwm Layouts Suite (gaplessgrid + decklayout + centeredmaster)",
        "channel": "stable",
        "patches": ["gaplessgrid", "decklayout", "centeredmaster"],
        "category": "chadwm_layouts"
    },
    {
        "id": "chadwm_layouts_vanitygaps_stable",
        "name": "Chadwm Layouts + Vanitygaps",
        "channel": "stable",
        "patches": ["gaplessgrid", "decklayout", "centeredmaster", "vanitygaps"],
        "category": "chadwm_layouts"
    },
    {
        "id": "chadwm_layouts_vanitygaps_bar_stable",
        "name": "Chadwm Layouts + Vanitygaps + Bar",
        "channel": "stable",
        "patches": ["gaplessgrid", "decklayout", "centeredmaster", "vanitygaps", "bar"],
        "category": "chadwm_layouts"
    },
    {
        "id": "chadwm_layouts_vanitygaps_bar_pertag_stable",
        "name": "Chadwm Layouts + Vanitygaps + Bar + Pertag",
        "channel": "stable",
        "patches": ["gaplessgrid", "decklayout", "centeredmaster", "vanitygaps", "bar", "pertag"],
        "category": "chadwm_layouts"
    },
    {
        "id": "multilayout_quad_stable",
        "name": "Multi-Layout Quad (bottomstack + decklayout + gaplessgrid + centeredmaster)",
        "channel": "stable",
        "patches": ["bottomstack", "decklayout", "gaplessgrid", "centeredmaster"],
        "category": "multi-layout"
    },
    {
        "id": "multilayout_quad_main",
        "name": "Multi-Layout Quad Main (bottomstack + decklayout + gaplessgrid + btrtile)",
        "channel": "main",
        "patches": ["bottomstack", "decklayout", "gaplessgrid", "btrtile"],
        "category": "multi-layout"
    },
    {
        "id": "multilayout_all_stable",
        "name": "All Layouts Stable (bottomstack + decklayout + gaplessgrid + centeredmaster + btrtile + dwindle + snail)",
        "channel": "stable",
        "patches": ["bottomstack", "decklayout", "gaplessgrid", "centeredmaster", "btrtile", "dwindle", "snail"],
        "category": "multi-layout"
    },
    {
        "id": "multilayout_all_main",
        "name": "All Layouts Main (bottomstack + decklayout + gaplessgrid + btrtile + dwindle + snail)",
        "channel": "main",
        "patches": ["bottomstack", "decklayout", "gaplessgrid", "btrtile", "dwindle", "snail"],
        "category": "multi-layout"
    },
    {
        "id": "bar_padding_colors_stable",
        "name": "Bar Base + Padding + Colors",
        "channel": "stable",
        "patches": ["bar", "barpadding", "barcolors"],
        "category": "bar"
    },
    {
        "id": "bar_centeredtitle_stable",
        "name": "Bar + Padding + Colors + True Centered Title",
        "channel": "stable",
        "patches": ["bar", "barpadding", "barcolors", "bartruecenteredtitle"],
        "category": "bar"
    },
    {
        "id": "bar_border_config_stable",
        "name": "Bar + Border + Config",
        "channel": "stable",
        "patches": ["bar", "barborder", "barconfig"],
        "category": "bar"
    },
    {
        "id": "bar_vacant_tags_stable",
        "name": "Bar + Hide Vacant Tags",
        "channel": "stable",
        "patches": ["bar", "hide_vacant_tags"],
        "category": "bar"
    },
    {
        "id": "bar_awesomebar_stable",
        "name": "Bar + Awesomebar",
        "channel": "stable",
        "patches": ["bar", "bar-awesomebar"],
        "category": "bar"
    },
    {
        "id": "bar_notitle_stable",
        "name": "Bar + Notitle",
        "channel": "stable",
        "patches": ["bar", "bar-notitle"],
        "category": "bar"
    },
    {
        "id": "bar_all_addons_stable",
        "name": "Bar + All Addons (padding, colors, border, config, truecenteredtitle)",
        "channel": "stable",
        "patches": ["bar", "barpadding", "barcolors", "barborder", "barconfig", "bartruecenteredtitle"],
        "category": "bar"
    },
    {
        "id": "vanitygaps_bar_stable",
        "name": "Vanitygaps + Bar",
        "channel": "stable",
        "patches": ["vanitygaps", "bar"],
        "category": "vanitygaps"
    },
    {
        "id": "vanitygaps_pertag_stable",
        "name": "Vanitygaps + Pertag",
        "channel": "stable",
        "patches": ["vanitygaps", "pertag"],
        "category": "vanitygaps"
    },
    {
        "id": "vanitygaps_smartborders_stable",
        "name": "Vanitygaps + Smartborders",
        "channel": "stable",
        "patches": ["vanitygaps", "smartborders"],
        "category": "vanitygaps"
    },
    {
        "id": "vanitygaps_bar_pertag_stable",
        "name": "Vanitygaps + Bar + Pertag",
        "channel": "stable",
        "patches": ["vanitygaps", "bar", "pertag"],
        "category": "vanitygaps"
    },
    {
        "id": "pertag_bar_stable",
        "name": "Pertag + Bar",
        "channel": "stable",
        "patches": ["pertag", "bar"],
        "category": "pertag"
    },
    {
        "id": "pertag_bottomstack_stable",
        "name": "Pertag + Bottomstack",
        "channel": "stable",
        "patches": ["pertag", "bottomstack"],
        "category": "pertag"
    },
    {
        "id": "pertag_bottomstack_main",
        "name": "Pertag + Bottomstack (Main)",
        "channel": "main",
        "patches": ["pertag", "bottomstack"],
        "category": "pertag"
    },
    {
        "id": "pertag_multilayout_main",
        "name": "Pertag + Multi-Layout (Main: bottomstack, decklayout, gaplessgrid)",
        "channel": "main",
        "patches": ["pertag", "bottomstack", "decklayout", "gaplessgrid"],
        "category": "pertag"
    },
    {
        "id": "pertag_autostart_main",
        "name": "Pertag + Autostart (Main)",
        "channel": "main",
        "patches": ["pertag", "autostart"],
        "category": "pertag"
    },
    {
        "id": "pertag_autostart_stable",
        "name": "Pertag + Autostart (Stable)",
        "channel": "stable",
        "patches": ["pertag", "autostart"],
        "category": "pertag"
    }
]

for s in suites_to_test:
    suite_id = s["id"]
    name = s["name"]
    ch = s["channel"]
    plist = json.dumps(s["patches"])
    print(f"Testing suite '{name}' ({ch})...", flush=True)
    
    expr = f"""
    let
      flake = builtins.getFlake (toString ./.);
      pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
      pkg = (flake.lib.mkDwl pkgs "{ch}").override {{ patches = {plist}; }};
    in {{
      drv = builtins.unsafeDiscardStringContext pkg.drvPath;
      out = builtins.unsafeDiscardStringContext pkg.outPath;
    }}
    """
    eval_r = run(f"nix eval --impure --json --expr '{expr}'")
    if eval_r.returncode != 0:
        print(f"  [SUITE EVAL FAIL] {name}: {eval_r.stderr[:100]}", flush=True)
        survey_results["combinations"][suite_id] = {
            "name": name,
            "channel": ch,
            "patches": s["patches"],
            "status": "EVAL_FAIL",
            "error": eval_r.stderr
        }
        continue
    
    suite_meta = json.loads(eval_r.stdout)
    drv = suite_meta["drv"]
    out = suite_meta["out"]
    
    # Try building
    b_res = run(f"nix build --no-link '{drv}^*'")
    chk = run(f"nix path-info {out}")
    if chk.returncode == 0:
        print(f"  [SUITE SUCCESS] {name}", flush=True)
        survey_results["combinations"][suite_id] = {
            "name": name,
            "channel": ch,
            "patches": s["patches"],
            "category": s["category"],
            "status": "SUCCESS",
            "out": out
        }
    else:
        log_res = run(f"nix log {drv}")
        log = log_res.stdout + "\n" + log_res.stderr
        fail_type = "UNKNOWN"
        if "conflicts outside config.def.h" in log or "patch: ****" in log or "FAILED" in log or "Reversed (or previously applied) patch" in log:
            fail_type = "PATCH_REJECTION"
        elif "error:" in log or "fatal error:" in log:
            fail_type = "COMPILATION_ERROR"
        
        error_lines = [l.strip() for l in log.splitlines() if any(k in l for k in ["error:", "fatal error:", "FAILED", "conflicts outside", "rejected", "undefined reference"])]
        snippet = "\n".join(error_lines[:10])
        print(f"  [SUITE FAIL] {name}: {fail_type}\n    {snippet[:150]}", flush=True)
        survey_results["combinations"][suite_id] = {
            "name": name,
            "channel": ch,
            "patches": s["patches"],
            "category": s["category"],
            "status": "FAIL",
            "failure_type": fail_type,
            "error_snippet": snippet,
            "log_tail": log[-2000:]
        }

with open("scratch/survey_results.json", "w") as f:
    json.dump(survey_results, f, indent=2)

print("\nFull Survey Complete! Saved to scratch/survey_results.json", flush=True)
