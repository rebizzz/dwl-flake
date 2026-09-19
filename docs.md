# Options

Generated from the modules. Run `nix run .#update-docs` after changing an option.

All options live under `programs.dwl`, in the NixOS, Home Manager and hjem modules.
`useHomeManagerBuild`, `extraSessionCommands`, `startupCommand`, `polkitAgent` and `keyring` only exist in the NixOS module.

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

## programs.dwl.defaultKeybinds

Keep dwl’s default keybinds next to yours\.

*Type:*
boolean

*Default:*

```nix
true
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

