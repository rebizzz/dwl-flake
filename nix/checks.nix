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

    docs-fresh = pkgs.runCommand "dwl-docs-fresh" {} ''
      diff -u ${../docs.md} ${self.packages.${system}.docs}
      touch $out
    '';

    index-fresh = pkgs.runCommand "dwl-patches-index-fresh" {} ''
      ${lib.getExe gen-index} ${genIndexArgs} > fresh.json
      diff -u ${../nix/patches.json} fresh.json
      touch $out
    '';

    module-full = (evalSystem nixpkgs full).programs.dwl.package;
    module-stable-channel = (evalSystem nixpkgs (full // {channel = "stable";})).programs.dwl.package;
    nixos-unstable = evaluates "nixos-unstable" (evalSystem nixpkgs full);
    nixos-stable = evaluates "nixos-stable" (evalSystem nixpkgs-stable {channel = "stable";});
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
    status-command = (evalSystem nixpkgs {statusCommand = "echo hi";}).programs.dwl.package;
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

    example-1-minimal = (evalWith nixpkgs [../examples/1-minimal.nix]).programs.dwl.package;
    example-2-everyday = (evalWith nixpkgs [../examples/2-everyday.nix]).programs.dwl.package;
    example-3-patches = (evalWith nixpkgs [../examples/3-patches.nix]).programs.dwl.package;
    example-4-home-manager-nixos = evaluates "example-4" (evalWith nixpkgs [{inherit (import ../examples/4-home-manager.nix) programs;}]);
    example-4-home-manager-user = standalone self.homeModules.default "homeManager" (import ../examples/4-home-manager.nix).home-manager.users.alice {home.packages = packagesOption;};
    example-5-own-config-h = (evalWith nixpkgs [../examples/5-own-config-h]).programs.dwl.package;

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
    dwl-stable-bar = dwl-stable.override {patches = ["bar"];};
    dwl-stable-bar-addon = dwl-stable.override {patches = ["barpadding" "barcolors"];};
  }
  // lib.optionalAttrs (!(compatible "main" "bar") && compatible "stable" "bar") {
    assert-patch-channel = failsWith "patch-channel" "works with channel = \"stable\"" {patches = ["bar"];};
  }
  // lib.optionalAttrs (system == "x86_64-linux") {
    vm = pkgs.testers.runNixOSTest {
      name = "dwl-flake";
      nodes.machine = {
        imports = [
          self.nixosModules.default
          "${nixpkgs}/nixos/tests/common/user-account.nix"
        ];
        programs.dwl = {
          enable = true;
          modKey = "Super";
          keybinds."Mod+Return".spawn = "foot";
          autostart = lib.optionals (compatible "main" "autostart") ["touch /tmp/autostart"];
          startupCommand = "touch /tmp/startup";
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
        environment.systemPackages = [pkgs.foot];
        virtualisation.qemu.options = ["-vga none -device virtio-gpu-pci"];
      };
      testScript = ''
        machine.wait_for_file("/run/user/1000/wayland-0")
        machine.wait_for_file("/tmp/startup")
        ${lib.optionalString (compatible "main" "autostart") ''machine.wait_for_file("/tmp/autostart")''}
        machine.wait_until_succeeds("su alice -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active dwl-session.target'")
        machine.sleep(2)
        machine.send_key("meta_l-ret")
        machine.wait_until_succeeds("pgrep -u alice foot")
        machine.screenshot("dwl")
      '';
    };
  }
