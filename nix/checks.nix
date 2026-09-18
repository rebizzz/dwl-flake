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

  evalSystem = nixpkgs': dwlConfig:
    (nixpkgs'.lib.nixosSystem {
      inherit system;
      modules = [
        base
        self.nixosModules.default
        {programs.dwl = {enable = true;} // dwlConfig;}
      ];
    }).config;

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

    index-fresh = pkgs.runCommand "dwl-patches-index-fresh" {} ''
      ${lib.getExe gen-index} ${genIndexArgs} > fresh.json
      diff -u ${../nix/patches.json} fresh.json
      touch $out
    '';

    module-full = (evalSystem nixpkgs full).programs.dwl.package;
    module-stable-channel = (evalSystem nixpkgs (full // {channel = "stable";})).programs.dwl.package;
    nixos-unstable = evaluates "nixos-unstable" (evalSystem nixpkgs full);
    nixos-stable = evaluates "nixos-stable" (evalSystem nixpkgs-stable {channel = "stable";});
    nixos-home-manager-build = evaluates "hm-build" (evalSystem nixpkgs {useHomeManagerBuild = true;});

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
