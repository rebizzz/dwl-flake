# Options

Generated from the modules. Run `nix run .#update-docs` after changing an option.

All options live under `programs.dwl`, in the NixOS, Home Manager and hjem modules.
`useHomeManagerBuild`, `polkitAgent` and `keyring` only exist in the NixOS module.

## programs.dwl.enable

Whether to enable dwl, a dwm-like Wayland compositor\.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

## programs.dwl.package

The dwl package to use\.

*Type:*
package

*Default:*
dwl built from the options above

## programs.dwl.appearance.borderWidth

Window border width in pixels\. dwl default: ` 1 `\.

*Type:*
null or (unsigned integer, meaning >=0)

*Default:*

```nix
null
```

## programs.dwl.appearance.bypassSurfaceVisibility

Idle inhibitors disable idle tracking even when their surface isn’t visible\. dwl default: ` false `\.

*Type:*
null or boolean

*Default:*

```nix
null
```

## programs.dwl.appearance.colors.border

Border of unfocused windows\. dwl default: ` #444444 `\. Removed by the bar patch\.

*Type:*
null or string matching the pattern \#(\[0-9a-fA-F]{6}|\[0-9a-fA-F]{8})

*Default:*

```nix
null
```

## programs.dwl.appearance.colors.focus

Border of the focused window\. dwl default: ` #005577 `\. Removed by the bar patch\.

*Type:*
null or string matching the pattern \#(\[0-9a-fA-F]{6}|\[0-9a-fA-F]{8})

*Default:*

```nix
null
```

## programs.dwl.appearance.colors.fullscreenBackground

Background behind fullscreen windows, as a color or four floats\. dwl default: black\.

*Type:*
null or string matching the pattern \#(\[0-9a-fA-F]{6}|\[0-9a-fA-F]{8}) or list of floating point number

*Default:*

```nix
null
```

## programs.dwl.appearance.colors.root

Background color\. dwl default: ` #222222 `\.

*Type:*
null or string matching the pattern \#(\[0-9a-fA-F]{6}|\[0-9a-fA-F]{8})

*Default:*

```nix
null
```

## programs.dwl.appearance.colors.urgent

Border of urgent windows\. dwl default: ` #ff0000 `\. Removed by the bar patch\.

*Type:*
null or string matching the pattern \#(\[0-9a-fA-F]{6}|\[0-9a-fA-F]{8})

*Default:*

```nix
null
```

## programs.dwl.appearance.sloppyFocus

Focus follows the mouse\. dwl default: ` true `\.

*Type:*
null or boolean

*Default:*

```nix
null
```

## programs.dwl.appearance.snap

Snap distance in pixels when moving floating windows (main only)\. dwl default: ` 32 `\.

*Type:*
null or (unsigned integer, meaning >=0)

*Default:*

```nix
null
```

## programs.dwl.autostart

Commands started with dwl\. Adds the autostart patch\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Example:*

```nix
[
  "waybar"
]
```

## programs.dwl.axes

Scroll wheel bindings as ` "Modifiers+direction" = action ` (main only)\. Directions: up, down, left, right\. Replaces dwl’s example bindings\.

*Type:*
attribute set of (string or attribute set of anything)

*Default:*

```nix
{ }
```

*Example:*

```nix
{
  "Mod+up".spawn = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
  "Mod+down".spawn = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
}

```

## programs.dwl.buttons

Mouse bindings as ` "Modifiers+button" = action `\. Buttons: left, right, middle, side, extra\.

*Type:*
attribute set of (string or attribute set of anything)

*Default:*

```nix
{ }
```

*Example:*

```nix
{
  "Mod+left".moveresize = "move";
  "Mod+right".moveresize = "resize";
  "Mod+middle" = "togglefloating";
}

```

## programs.dwl.channel

Build dwl main or the latest dwl release\.

*Type:*
one of “main”, “stable”

*Default:*

```nix
"main"
```

## programs.dwl.configH

Your own config\.h\. The declarative options are ignored when set\.

*Type:*
null or absolute path or strings concatenated with “\\n”

*Default:*

```nix
null
```

*Example:*

```nix
./config.h
```

## programs.dwl.defaultButtons

Keep dwl’s default mouse bindings next to yours\.

*Type:*
boolean

*Default:*

```nix
true
```

## programs.dwl.defaultKeybinds

Keep dwl’s default keybinds next to yours\.

*Type:*
boolean

*Default:*

```nix
true
```

## programs.dwl.environment

Environment variables set for dwl and everything it starts\.

*Type:*
attribute set of string

*Default:*

```nix
{ }
```

*Example:*

```nix
{
  NIXOS_OZONE_WL = "1";
}
```

## programs.dwl.extraBuildInputs

Libraries a patch needs that aren’t detected\.

*Type:*
list of package

*Default:*

```nix
[ ]
```

## programs.dwl.extraConfig

C code added to the top of config\.h\.

*Type:*
strings concatenated with “\\n”

*Default:*

```nix
""
```

## programs.dwl.extraOptions

Command line arguments passed to dwl\.

*Type:*
list of string

*Default:*

```nix
[ ]
```

*Example:*

```nix
[
  "-d"
]
```

## programs.dwl.extraPackages

Programs installed alongside dwl\. The default is what dwl’s own keybinds launch\.

*Type:*
list of package

*Default:*

```nix
with pkgs; [ foot wmenu ]
```

*Example:*

```nix
with pkgs; [ foot rofi swaybg grim slurp ]
```

## programs.dwl.extraSessionCommands

Shell commands run before dwl starts\.

*Type:*
strings concatenated with “\\n”

*Default:*

```nix
""
```

*Example:*

```nix
"export MOZ_ENABLE_WAYLAND=1"
```

## programs.dwl.finalConfig

Path to the config\.h dwl is built with\.

*Type:*
string *(read only)*

*Default:*
the generated config\.h

## programs.dwl.input.keyboard.repeatDelay

Milliseconds before a key starts repeating\. dwl default: ` 600 `\.

*Type:*
null or (unsigned integer, meaning >=0)

*Default:*

```nix
null
```

## programs.dwl.input.keyboard.repeatRate

Key repeats per second\. dwl default: ` 25 `\.

*Type:*
null or (unsigned integer, meaning >=0)

*Default:*

```nix
null
```

## programs.dwl.input.keyboard.xkb.layout

XKB layout, e\.g\. ` us,de `\.

*Type:*
null or string

*Default:*

```nix
null
```

## programs.dwl.input.keyboard.xkb.model

XKB model\.

*Type:*
null or string

*Default:*

```nix
null
```

## programs.dwl.input.keyboard.xkb.options

XKB options, e\.g\. ` caps:escape `\.

*Type:*
null or string

*Default:*

```nix
null
```

## programs.dwl.input.keyboard.xkb.rules

XKB rules\.

*Type:*
null or string

*Default:*

```nix
null
```

## programs.dwl.input.keyboard.xkb.variant

XKB variant\.

*Type:*
null or string

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.accelProfile

Pointer acceleration profile\. dwl default: ` adaptive `\.

*Type:*
null or one of “adaptive”, “flat”

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.accelSpeed

Pointer acceleration, from -1 to 1\. dwl default: ` 0 `\.

*Type:*
null or integer or floating point number between -1\.0 and 1\.0 (both inclusive)

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.clickMethod

Click method\. dwl default: ` button-areas `\.

*Type:*
null or one of “button-areas”, “clickfinger”, “none”

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.disableWhileTyping

Disable the touchpad while typing\. dwl default: ` true `\.

*Type:*
null or boolean

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.dragLock

Drag lock\. dwl default: ` true `\.

*Type:*
null or boolean

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.leftHanded

Left-handed mode\. dwl default: ` false `\.

*Type:*
null or boolean

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.middleButtonEmulation

Emulate a middle click\. dwl default: ` false `\.

*Type:*
null or boolean

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.naturalScroll

Natural scrolling\. dwl default: ` false `\.

*Type:*
null or boolean

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.scrollMethod

Scroll method\. dwl default: ` two-finger `\.

*Type:*
null or one of “edge”, “none”, “on-button-down”, “two-finger”

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.sendEvents

When the touchpad sends events\. dwl default: ` enabled `\.

*Type:*
null or one of “disabled”, “disabled-on-external-mouse”, “enabled”

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.tapAndDrag

Tap and drag\. dwl default: ` true `\.

*Type:*
null or boolean

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.tapButtonMap

What 1, 2 and 3 finger taps click\. dwl default: ` left-right-middle `\.

*Type:*
null or one of “left-middle-right”, “left-right-middle”

*Default:*

```nix
null
```

## programs.dwl.input.touchpad.tapToClick

Tap to click\. dwl default: ` true `\.

*Type:*
null or boolean

*Default:*

```nix
null
```

## programs.dwl.keybinds

Keybinds as ` "Modifiers+keysym" = action `\.

*Type:*
attribute set of (string or attribute set of anything)

*Default:*

```nix
{ }
```

*Example:*

```nix
{
  "Mod+Return".spawn = "foot";
  "Mod+q" = "killclient";
  "Mod+1".view = 1;
  "Mod+Shift+1".tag = 1;
}

```

## programs.dwl.keyring.enable

Whether to enable gnome-keyring for storing secrets in the dwl session\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```

## programs.dwl.layouts

Layouts, in order\. ` setlayout ` indexes into this list\. dwl default: tile, floating, monocle\.

*Type:*
null or (list of (submodule))

*Default:*

```nix
null
```

*Example:*

```nix
[
  { symbol = "[]="; arrange = "tile"; }
  { symbol = "><>"; }
  { symbol = "[M]"; arrange = "monocle"; }
]

```

## programs.dwl.layouts.\*.arrange

Arrange function, e\.g\. ` tile ` or ` monocle `\. ` null ` means floating\.

*Type:*
null or string

*Default:*

```nix
null
```

## programs.dwl.layouts.\*.symbol

Symbol shown for the layout\.

*Type:*
string

## programs.dwl.logLevel

wlroots log level\. dwl default: ` error `\.

*Type:*
null or one of “debug”, “error”, “info”, “silent”

*Default:*

```nix
null
```

## programs.dwl.modKey

What ` Mod ` means in keybinds and in dwl’s defaults: Super, Alt, Ctrl or Shift\.

*Type:*
null or string

*Default:*

```nix
null
```

*Example:*

```nix
"Super"
```

## programs.dwl.monitors

Monitor rules\. A catch-all rule is added at the end\.

*Type:*
list of (submodule)

*Default:*

```nix
[ ]
```

*Example:*

```nix
[ { name = "eDP-1"; scale = 1.5; } ]
```

## programs.dwl.monitors.\*.layout

Index into layouts\.

*Type:*
unsigned integer, meaning >=0

*Default:*

```nix
0
```

## programs.dwl.monitors.\*.mfact

Size of the master area\.

*Type:*
integer or floating point number between 0\.05 and 0\.95 (both inclusive)

*Default:*

```nix
0.55
```

## programs.dwl.monitors.\*.name

Output name, e\.g\. eDP-1\.

*Type:*
null or string

*Default:*

```nix
null
```

## programs.dwl.monitors.\*.nmaster

Number of windows in the master area\.

*Type:*
unsigned integer, meaning >=0

*Default:*

```nix
1
```

## programs.dwl.monitors.\*.scale

Output scale\.

*Type:*
positive integer or floating point number, meaning >0

*Default:*

```nix
1
```

## programs.dwl.monitors.\*.transform

Output rotation\.

*Type:*
one of “normal”, “90”, “180”, “270”, “flipped”, “flipped_90”, “flipped_180”, “flipped_270”

*Default:*

```nix
"normal"
```

## programs.dwl.monitors.\*.x

Position, or -1 to place automatically\.

*Type:*
signed integer

*Default:*

```nix
-1
```

## programs.dwl.monitors.\*.y

Position, or -1 to place automatically\.

*Type:*
signed integer

*Default:*

```nix
-1
```

## programs.dwl.patches

Patches to apply\. A name picks the file from dwl-patches that applies to the channel and adds its dependencies\.

*Type:*
list of (absolute path or package or string)

*Default:*

```nix
[ ]
```

*Example:*

```nix
[ "pertag" "movestack" ./my-fix.patch ]
```

## programs.dwl.polkitAgent.enable

Whether to enable a polkit authentication agent in the dwl session\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```

## programs.dwl.rules

Window rules\.

*Type:*
list of (submodule)

*Default:*

```nix
[ ]
```

*Example:*

```nix
[ { id = "firefox"; tags = [ 2 ]; } ]
```

## programs.dwl.rules.\*.floating

Start the window floating\.

*Type:*
boolean

*Default:*

```nix
false
```

## programs.dwl.rules.\*.id

Wayland app_id to match\.

*Type:*
null or string

*Default:*

```nix
null
```

## programs.dwl.rules.\*.monitor

Monitor index, or -1 for the current one\.

*Type:*
signed integer

*Default:*

```nix
-1
```

## programs.dwl.rules.\*.tags

Tags to put the window on\. Empty means the current ones\.

*Type:*
list of integer between 1 and 31 (both inclusive)

*Default:*

```nix
[ ]
```

## programs.dwl.rules.\*.title

Window title to match\.

*Type:*
null or string

*Default:*

```nix
null
```

## programs.dwl.settings

Any variable or define from config\.def\.h, including ones added by patches\.

*Type:*
attribute set of anything

*Default:*

```nix
{ }
```

*Example:*

```nix
{ borderpx = 2; focuscolor = "#89b4fa"; }
```

## programs.dwl.startupCommand

Shell commands run once dwl is up, with the Wayland environment set\. Its standard input is dwl’s status output\.

*Type:*
strings concatenated with “\\n”

*Default:*

```nix
""
```

*Example:*

```nix
"exec waybar"
```

## programs.dwl.statusCommand

Shell command whose output lines become the status text in the bar patch\.

*Type:*
null or string

*Default:*

```nix
null
```

*Example:*

```nix
"while true; do date +%H:%M; sleep 30; done"
```

## programs.dwl.tagCount

Number of tags\. dwl default: ` 9 `\.

*Type:*
null or integer between 1 and 31 (both inclusive)

*Default:*

```nix
null
```

## programs.dwl.useHomeManagerBuild

Start the dwl each user builds with the Home Manager module\. Users without one get the build from these options\.

*Type:*
boolean

*Default:*

```nix
false
```

## programs.dwl.xwayland

Whether to enable XWayland support\.

*Type:*
boolean

*Default:*

```nix
true
```

*Example:*

```nix
true
```


# Keybind actions

Functions dwl itself provides, usable in `keybinds` and `buttons`. Patches add more.

- `chvt`
- `focusmon`
- `focusstack`
- `incnmaster`
- `killclient`
- `moveresize`
- `quit`
- `setlayout`
- `setmfact`
- `spawn`
- `tag`
- `tagmon`
- `togglefloating`
- `togglefullscreen`
- `toggletag`
- `toggleview`
- `view`
- `zoom`
