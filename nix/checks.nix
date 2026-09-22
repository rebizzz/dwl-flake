{
  self,
  lib,
  pkgs,
  nixpkgs,
  nixpkgs-stable,
  compatible,
  genIndexArgs,
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (self.packages.${system}) dwl dwl-stable gen-index;

  base = {
    system.stateVersion = "26.05";
    fileSystems."/" = {
      device = "/dev/sda1";
      fsType = "ext4";
    };
    boot.loader.systemd-boot.enable = true;
  };

  evalWith = nixpkgs': modules:
    (nixpkgs'.lib.nixosSystem {
      inherit system;
      specialArgs.inputs.dwl-flake = self;
      modules = [base self.nixosModules.default] ++ modules;
    }).config;

  evalSystem = nixpkgs': dwlConfig: evalWith nixpkgs' [{programs.dwl = {enable = true;} // dwlConfig;}];

  standalone = flakeModule: class: module: extraOptions: let
    config =
      (lib.evalModules {
        inherit class;
        modules = [
          flakeModule
          module
          {
            options = with lib;
              {
                assertions = mkOption {
                  type = types.listOf types.unspecified;
                  default = [];
                };
                warnings = mkOption {
                  type = types.listOf types.str;
                  default = [];
                };
                lib = mkOption {
                  type = types.attrsOf types.attrs;
                  default = {};
                };
              }
              // extraOptions;
            config._module.args.pkgs = pkgs;
          }
        ];
      }).config;
    failed = map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);
  in
    lib.throwIf (failed != []) (lib.concatStringsSep "\n" failed) config.programs.dwl.package;

  packagesOption = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [];
  };

  evaluates = name: config:
    pkgs.writeText "dwl-check-${name}" (builtins.unsafeDiscardStringContext config.system.build.toplevel.drvPath);

  failsWith = name: expected: dwlConfig: let
    config = evalSystem nixpkgs dwlConfig;
    messages = map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);
  in
    if lib.any (lib.hasInfix expected) messages
    then pkgs.writeText "dwl-assert-${name}" (lib.concatStringsSep "\n" messages)
    else throw "check ${name}: expected an assertion containing '${expected}', got: ${builtins.toJSON messages}";

  brokenPatch = lib.findFirst (name: self.lib.index.${name}.default.stable != null && self.lib.fileFor "stable" name == null) null (lib.attrNames self.lib.index);

  full = {
    modKey = "Super";
    patches = lib.filter (compatible "main") ["pertag"];
    autostart = lib.optionals (compatible "main" "autostart") ["true"];
    keybinds = {
      "Mod+Return".spawn = "foot";
      "Mod+d".spawn = ["fuzzel" "--list-executables-in-path"];
      "Mod+q" = "killclient";
      "Mod+h".setmfact = -0.05;
      "Mod+F1".view = 1;
      "Mod+Shift+F2".tag = [1 2];
      "Mod+m".setlayout = 2;
      "Mod+comma".focusmon = "left";
      "Mod+j" = {
        fn = "focusstack";
        arg = 1;
      };
    };
    rules = [
      {
        id = "firefox";
        tags = [2];
      }
      {
        title = "Picture-in-Picture";
        floating = true;
      }
    ];
    monitors = [
      {
        name = "eDP-1";
        scale = 1.5;
        transform = "90";
      }
    ];
    settings = {
      borderpx = 2;
      sloppyfocus = false;
      focuscolor = "#89b4fa";
      fullscreen_bg = [0.1 0.1 0.1 1.0];
      accel_speed = -0.5;
      accel_profile = "LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT";
      xkb_rules = {
        layout = "us,de";
        options = "grp:alt_shift_toggle";
      };
      layouts = with self.lib; [
        {
          symbol = "[]=";
          arrange = c "tile";
        }
        {symbol = "><>";}
        {
          symbol = "[M]";
          arrange = c "monocle";
        }
      ];
    };
  };
in
  {
    inherit dwl dwl-stable;
    dwl-no-xwayland = dwl.override {enableXWayland = false;};
    dwl-own-keybinds-only = dwl.override {
      defaultKeybinds = false;
      keybinds."Super+Return".spawn = "foot";
    };

    apps-default = pkgs.runCommand "test-apps-default" {} ''
      test -x ${self.apps.${system}.default.program}
      touch $out
    '';
    overlay-default = (pkgs.extend self.overlays.default).dwl;
    overlay-dwl-stable = (pkgs.extend self.overlays.dwl-stable).dwl;

    docs-fresh = pkgs.runCommand "dwl-docs-fresh" {} ''
      diff -u ${../docs.md} ${self.packages.${system}.docs}
      diff -u ${../patches.md} ${self.packages.${system}.patch-docs}
      touch $out
    '';

    index-fresh = pkgs.runCommand "dwl-patches-index-fresh" {} ''
      ${lib.getExe gen-index} ${genIndexArgs} > fresh.json
      diff -u ${../nix/patches.json} fresh.json
      touch $out
    '';

    # Unit tests for the patch engine's conflict resolution. These are pure and
    # take under a second, so they run on every check rather than only in CI.
    conflict-engine =
      pkgs.runCommand "dwl-conflict-engine-tests" {
        nativeBuildInputs = [pkgs.python3 pkgs.patch pkgs.diffutils];
      } ''
        # The test finds the engine relative to the repo root.
        mkdir -p nix/engine tests
        cp ${../nix/engine}/*.py nix/engine/
        cp ${../tests/test_conflict_engine.py} tests/test_conflict_engine.py
        python3 tests/test_conflict_engine.py
        touch $out
      '';

    module-full = (evalSystem nixpkgs full).programs.dwl.package;
    module-stable-channel = (evalSystem nixpkgs (full // {channel = "stable";})).programs.dwl.package;
    nixos-unstable = evaluates "nixos-unstable" (evalSystem nixpkgs full);
    nixos-stable = evaluates "nixos-stable" (evalSystem nixpkgs-stable {channel = "stable";});

    # A config written with only upstream's options must still produce the
    # whole upstream session surface.
    nixos-upstream-options-compat = let
      sentinel = "DWL_UPSTREAM_COMPAT_SENTINEL";
      upstreamOptions = ["enable" "package" "extraSessionCommands"];
      eval = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs.inputs.dwl-flake = self;
        modules = [
          base
          self.nixosModules.default
          {
            programs.dwl = {
              enable = true;
              package = dwl;
              extraSessionCommands = "export ${sentinel}=1";
            };
          }
        ];
      };
      cfg = eval.config;
      failedAssertions = map (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions);
      missingOptions = lib.filter (o: !(eval.options.programs.dwl ? ${o})) upstreamOptions;
      problems =
        lib.optional (missingOptions != []) "options missing relative to upstream: ${lib.concatStringsSep ", " missingOptions}"
        ++ lib.optional (failedAssertions != []) "assertions failed on a pure upstream config: ${lib.concatStringsSep "; " failedAssertions}"
        ++ lib.optional (!(cfg.environment.etc ? "xdg/dwl-session")) "missing the /etc/xdg/dwl-session wrapper"
        ++ lib.optional (!(cfg.systemd.user.targets ? dwl-session)) "missing systemd.user.targets.dwl-session"
        ++ lib.optional (!(lib.elem cfg.programs.dwl.package cfg.environment.systemPackages)) "programs.dwl.package absent from environment.systemPackages"
        # sessionPackages reads providedSessions off the package; passthru lands there too.
        ++ lib.optional (!(lib.any (p: lib.elem "dwl" (p.providedSessions or p.passthru.providedSessions or [])) cfg.services.displayManager.sessionPackages)) "no session package advertising providedSessions = [\"dwl\"]"
        ++ lib.optional ((cfg.xdg.portal.config.dwl.default or null) == null) "missing xdg.portal.config.dwl.default";
    in
      lib.throwIf (problems != []) ("nixos-upstream-options-compat:\n" + lib.concatStringsSep "\n" problems)
      (pkgs.runCommand "dwl-check-upstream-options-compat" {} ''
        # extraSessionCommands must actually reach the generated session wrapper.
        grep -q '${sentinel}' ${cfg.environment.etc."xdg/dwl-session".source} \
          || { echo "extraSessionCommands is not honoured by the dwl-session wrapper" >&2; exit 1; }
        echo ${builtins.unsafeDiscardStringContext cfg.system.build.toplevel.drvPath} > $out
      '');
    typed-options =
      (evalSystem nixpkgs {
        appearance = {
          sloppyFocus = false;
          bypassSurfaceVisibility = true;
          borderWidth = 3;
          snap = 16;
          colors = {
            root = "#1e1e2e";
            border = "#313244";
            focus = "#89b4fa";
            urgent = "#f38ba8";
            fullscreenBackground = [0.1 0.1 0.1 1.0];
          };
        };
        tagCount = 5;
        logLevel = "info";
        layouts = [
          {
            symbol = "[]=";
            arrange = "tile";
          }
          {symbol = "><>";}
        ];
        input = {
          keyboard = {
            xkb = {
              layout = "us,de";
              options = "caps:escape";
            };
            repeatRate = 50;
            repeatDelay = 250;
          };
          touchpad = {
            tapToClick = false;
            tapAndDrag = false;
            dragLock = false;
            naturalScroll = true;
            disableWhileTyping = false;
            leftHanded = true;
            middleButtonEmulation = true;
            scrollMethod = "edge";
            clickMethod = "clickfinger";
            sendEvents = "disabled-on-external-mouse";
            accelProfile = "flat";
            accelSpeed = -0.3;
            tapButtonMap = "left-middle-right";
          };
        };
        buttons = {
          "Mod+left".moveresize = "move";
          "Mod+Shift+right".moveresize = "resize";
          "Mod+middle" = "togglefloating";
        };
        environment.NIXOS_OZONE_WL = "1";
        statusCommand = "echo hi";
      }).programs.dwl.package;
    buttons-with-bar = dwl-stable.override {
      patches = ["bar"];
      defaultButtons = false;
      buttons."Mod+left".moveresize = "move";
    };
    axes = dwl.override {
      axes = {
        "Mod+up".spawn = "true";
        "Mod+Shift+down" = "zoom";
      };
    };
    assert-axis = failsWith "axis" "unknown direction 'sideways'" {axes."Mod+sideways" = "zoom";};
    assert-axes-stable = failsWith "axes-stable" "setting 'axes'" {
      channel = "stable";
      axes."Mod+up" = "zoom";
    };
    assert-button = failsWith "button" "unknown button 'wheel'" {buttons."Mod+wheel" = "zoom";};
    nixos-home-manager-build = evaluates "hm-build" (evalSystem nixpkgs {useHomeManagerBuild = true;});

    lib-helper = evaluates "lib-helper" (evalWith nixpkgs [
      ({config, ...}: {
        programs.dwl = {
          enable = true;
          settings.accel_profile = config.lib.dwl.c "LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT";
        };
      })
    ]);

    home-manager-module = standalone self.homeModules.default "homeManager" {programs.dwl.enable = true;} {home.packages = packagesOption;};
    hjem-module = standalone self.hjemModules.default "hjem" {programs.dwl.enable = true;} {packages = packagesOption;};

    example-minimal = (evalWith nixpkgs [../examples/minimal.nix]).programs.dwl.package;
    example-everyday = (evalWith nixpkgs [../examples/everyday.nix]).programs.dwl.package;
    example-patches = (evalWith nixpkgs [../examples/patches.nix]).programs.dwl.package;
    example-home-manager-nixos = evaluates "example-home-manager" (evalWith nixpkgs [{inherit (import ../examples/home-manager.nix) programs;}]);
    example-home-manager-user = standalone self.homeModules.default "homeManager" (import ../examples/home-manager.nix).home-manager.users.alice {home.packages = packagesOption;};
    example-config-h = (evalWith nixpkgs [../examples/config-h]).programs.dwl.package;
    example-chadwm = (evalWith nixpkgs [../examples/chadwm.nix]).programs.dwl.package;

    assert-modifier = failsWith "modifier" "unknown modifier 'Hyper'" {keybinds."Hyper+x" = "quit";};
    assert-modkey = failsWith "modkey" "modKey 'Meta'" {modKey = "Meta";};
    assert-empty-key = failsWith "empty-key" "no key after" {keybinds."Mod+" = "quit";};
    assert-action = failsWith "action" "should be a function name" {
      keybinds."Mod+x" = {
        a = 1;
        b = 2;
      };
    };
    assert-setting = failsWith "setting" "setting 'bordrpx'" {settings.bordrpx = 2;};
    assert-function = failsWith "function" "function 'togglebarr'" {keybinds."Mod+b" = "togglebarr";};
    assert-patch-name = failsWith "patch-name" "doesn't exist in dwl-patches" {patches = ["no-such-patch"];};
  }
  // lib.optionalAttrs (compatible "stable" "bar") {
    patch-merge = dwl-stable.override {patches = ["bar" "vanitygaps"];};
    dwl-stable-bar-addon = dwl-stable.override {patches = ["barpadding" "barcolors"];};
  }
  # Combination suites. verify-patches covers patches individually; these cover
  # pairs that edit the same code, as real compiles, so a bad merge fails loudly.
  // (let
    suites = {
      # bar plus the addons that shift its geometry; two of them adjust the
      # same expression, so both offsets have to survive.
      suite-bar-addons.stable = ["bar" "barpadding" "barcolors" "bartruecenteredtitle" "hide_vacant_tags" "bar-awesomebar"];
      suite-bar-border.stable = ["bar" "barpadding" "barborder"];
      suite-bar-border-notitle.stable = ["bar" "bar-notitle" "barpadding" "barborder"];

      # vanitygaps and pertag both rewrite the tag handling around bar. The
      # reversed order is deliberate: patch order must not change the result.
      suite-gaps-pertag.stable = ["bar" "vanitygaps" "pertag"];
      suite-gaps-pertag-reversed.stable = ["pertag" "vanitygaps" "bar"];

      # Several layouts at once, which all append to layouts[] in config.def.h.
      suite-layouts.stable = ["bottomstack" "centeredmaster" "decklayout" "gaplessgrid" "dwindle" "snail" "btrtile"];
      suite-layouts.main = ["bottomstack" "decklayout" "gaplessgrid" "dwindle" "snail" "btrtile"];
      suite-layouts-stack-pertag.main = ["gaplessgrid" "decklayout" "movestack" "attachbottom" "pertag"];

      # The full chadwm set, which is what examples/chadwm.nix builds.
      suite-chadwm.stable = ["bar" "barpadding" "barcolors" "vanitygaps" "gaplessgrid" "movestack" "attachbottom" "decklayout" "centeredmaster" "pertag"];
    };

    basePackage = {
      stable = dwl-stable;
      main = dwl;
    };

    # One check per suite and channel, skipped when the channel lacks a patch.
    forChannel = name: channel: patches:
      lib.optionalAttrs (lib.all (compatible channel) patches) {
        "${name}-${channel}" = basePackage.${channel}.override {inherit patches;};
      };
  in
    lib.foldl' lib.mergeAttrs {} (
      lib.concatLists (
        lib.mapAttrsToList
        (name: byChannel: lib.mapAttrsToList (forChannel name) byChannel)
        suites
      )
    ))
  // lib.optionalAttrs (!(compatible "main" "bar") && compatible "stable" "bar") {
    assert-patch-channel = failsWith "patch-channel" "works with channel = \"stable\"" {patches = ["bar"];};
  }
  // lib.optionalAttrs (brokenPatch != null) {
    assert-broken-patch = failsWith "broken-patch" "doesn't build" {
      channel = "stable";
      patches = [brokenPatch];
    };
  }
  // lib.optionalAttrs (system == "x86_64-linux") {
    vm = pkgs.testers.runNixOSTest {
      name = "dwl-flake";
      nodes.machine = {
        imports = [
          self.nixosModules.default
          "${nixpkgs}/nixos/tests/common/user-account.nix"
        ];
        security.pam.services.swaylock = {};
        programs.dwl = {
          enable = true;
          modKey = "Super";
          keybinds = {
            "Mod+Return".spawn = "foot";
            "Mod+q" = "killclient";
            "Mod+Escape" = "quit";
            "Mod+l".spawn = "swaylock";
          };
          autostart = lib.optionals (compatible "main" "autostart") ["touch /tmp/autostart"];
          startupCommand = "touch /tmp/startup";
          extraPackages = with pkgs; [foot wmenu swaylock wayland-utils xdpyinfo];
        };
        services.greetd = {
          enable = true;
          settings = {
            default_session.command = "${pkgs.greetd}/bin/agreety --cmd dwl-session";
            initial_session = {
              user = "alice";
              command = "dwl-session";
            };
          };
        };
        virtualisation.qemu.options = ["-vga none -device virtio-gpu-pci"];
      };
      testScript = {nodes, ...}: ''
        def as_alice(cmd):
            env = "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0"
            return machine.succeed(f"su alice -c '{env} {cmd}'")

        start_all()
        machine.wait_for_unit("multi-user.target")
        print(machine.execute("dwl -v 2>&1")[1])

        with subtest("session starts"):
            machine.wait_for_file("/run/user/1000/wayland-0")
            machine.wait_for_file("/tmp/startup")
            ${lib.optionalString (compatible "main" "autostart") ''machine.wait_for_file("/tmp/autostart")''}
            machine.wait_until_succeeds("su alice -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active dwl-session.target'")

        with subtest("environment reaches systemd and D-Bus"):
            env = machine.succeed("su alice -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user show-environment'")
            assert "WAYLAND_DISPLAY=wayland-0" in env, env
            assert "XDG_CURRENT_DESKTOP=dwl" in env, env

        with subtest("wayland clients work"):
            print(as_alice("wayland-info"))

        with subtest("xwayland works"):
            machine.wait_until_succeeds("su alice -c 'XDG_RUNTIME_DIR=/run/user/1000 DISPLAY=:0 xdpyinfo'")

        with subtest("keybinds open and close windows"):
            machine.sleep(2)
            machine.send_key("meta_l-ret")
            machine.wait_until_succeeds("pgrep -u alice -x foot")
            machine.sleep(3)
            machine.screenshot("foot")
            machine.send_key("meta_l-q")
            machine.wait_until_fails("pgrep -u alice -x foot")

        with subtest("screen locking works"):
            machine.sleep(2)
            machine.send_key("meta_l-l")
            machine.wait_until_succeeds("pgrep -u alice swaylock")
            machine.sleep(3)
            machine.send_chars("${nodes.machine.users.users.alice.password}")
            machine.send_key("ret")
            machine.wait_until_fails("pgrep -u alice swaylock")

        with subtest("quitting ends the session"):
            machine.send_key("meta_l-esc")
            machine.wait_until_fails("pgrep -x dwl")
            machine.wait_until_fails("su alice -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active dwl-session.target'")
      '';
    };
  }
