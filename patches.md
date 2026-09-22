# Patches

All patches available from `dwl-patches`, indexed automatically from `nix/patches.json`.
Run `nix run .#update-docs` to regenerate.

| Patch | Channels | Requires | Description |
| --- | --- | --- | --- |
| `accessnthmon` | stable | - | Port of dwm's accessnthmon. Adds functions to tag and focus monitor by index. |
| `alwayscenter` | main, stable | - | Automatically center floating windows. |
| `attachbottom` | main, stable | - | Newly created windows are placed at the bottom of the client tile stack. |
| `attachfocused` | main, stable | - | Makes windows attach below the currently active window. |
| `attachtop` | main, stable | - | This is a port of attachtop patch for dwm: https://dwm.suckless.org/patches/attachtop |
| `autostart` | main, stable | - | Allow dwl to execute commands from autostart array in your config.h file. And when you exit dwl all processes from autostart array will be killed. |
| `bar` | stable | - | Add a bar identical to dwm's bar. |
| `bar-appicons` | unsupported | - | Adds support for app icons that can replace the tag indicator and tag name. This feature is configurable through an additional option in `rules`. |
| `bar-awesomebar` | stable | `bar` | Based on the corresponding `dwm` patch, this patch implements the AwesomeWM-style bar for `dwl`. |
| `bar-modes` | unsupported | - | Add a mode indicator to bar that tells which mode you are in, just like river-classic's [dam](https://codeberg.org/sewn/dam) bar. |
| `bar-notitle` | stable | `bar` | Add a `window_title` option to toggle showing window titles in the bar, similar to the DWM `notitle` patch. |
| `bar-recolr` | unsupported | - |  |
| `bar-systray` | unsupported | - | Add a system tray to the [bar](/dwl/dwl-patches/src/branch/main/patches/bar). |
| `barborder` | stable | `bar` | Add a border around the [bar](/dwl/dwl-patches/wiki/bar) similar to how a client is given a border. |
| `barcolors` | stable | `bar` | Add support for colored status text to the [bar](/dwl/dwl-patches/src/branch/main/patches/bar). Text can be colored in the same manner as with dwlb, namely by wrapping it between `^fg(color)` and `^fg()` or `^bg(color)` and `^bg()`, where `color` is a 6-digit hexadecimal value. |
| `barconfig` | stable | `bar` | This patch **requires** the dwl [barconfig](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/bar) patch be applied first! The barconfig patch provides configuration for the dwl bar via the variable `barlayout`. This determines which of the elements listed below to display on the bar and in which order: |
| `barpadding` | stable | `bar` | Add vertical and horizontal space between the [bar](/dwl/dwl-patches/wiki/bar) and the edge of the screen. |
| `bartruecenteredtitle` | stable | `bar` | A homegrown port of dwm's _truecenteredtitle_ patch, with the addition of a config option to toggle its effects.<br>Requires [the bar patch](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/bar) to be applied beforehand. |
| `better-resize` | unsupported | - | This patch allows you to configure window resizing more flexibly. It introduces three options with the following possible values: |
| `borderlessrule` | unsupported | - | Borderless client if rule set to borderless |
| `borders` | stable | - | Adds 2 more borders to each side (top, bottom, left, right) of every window. |
| `bottomstack` | main, stable | - | bstack and bstackhoriz are two stack layouts for dwl. |
| `btrtile` | stable | - | # btrtile - A Focus-Driven Tiling Layout |
| `buttonbystate` | stable | - | Adds "state" (`enum wlr_button_state`) to configure a button action on either press or release. This basically enables release to be used for button actions. |
| `center-terminal` | main | - | Add a keybinding that toggles centering the terminally horizontally when it's the only window, while still tiling multiple windows. |
| `centeredmaster` | stable | - | This is a port of centeredmaster patch for dwm: <https://dwm.suckless.org/patches/centeredmaster> |
| `cfact` | unsupported | - | A port of the [dwm cfacts patch](https://dwm.suckless.org/patches/cfacts/) (with the limits removed) |
| `cfact-snail` | unsupported | - | This patch implements [cfact][cfact] for [snail][snail] layout. This patch must be applied on top of cfact and snail patches. |
| `chainkeys` | unsupported | - | Implements chained keybindings (like the dwm [keychain](https://dwm.suckless.org/patches/keychain/) patch). |
| `client-opacity` | unsupported | - | This patch adds default transparency parameters to config.h which specify the starting transparencies of all windows. |
| `client-opacity-focus` | unsupported | - | This patch is based on the [client-opacity](https://codeberg.org/dwl/dwl-patches/raw/branch/main/patches/client-opacity/client-opacity.patch) patch. This patch adds differing opacity levels depending upon whether the client is focused or not. |
| `color_manager` | stable | - | Adds simple support for color management using `wp_color_manager_v1`. |
| `column` | unsupported | - | A column layout patch. This patch just puts the visible clients into equal-width columns on the screen. |
| `controlled_fullscreen` | stable | - | 	This patch allows a window to adjust its layout as if it was fullscreen, but it won't change its size and position, and it will stays under the control of dwl. For example a video on a browser can occupy the whole space reserved to the window, but we can still resize it and move it and see the status bar. |
| `coredump` | main, stable | - | Generate a coredump if dwl exited abnormally (to be more useful you need to compile dwl and wlroots with debug symbols) |
| `cursortheme` | unsupported | - | Adds ability to change cursor's theme and size. |
| `customfloat` | main, stable | - | Rules for floating windows support default x, y, width, height. Defaults to the center of the screen and the client size. |
| `decklayout` | main, stable | - | Deck is a dwl-layout which is inspired by the dwm Deck layout (which is inspired by TTWM window manager). It applies the monocle-layout to the clients in the stack. The master-client is still visible. The stacked clients are like a deck of cards, hence the name. |
| `dim-unfocused` | unsupported | - | Implements dimming of clients which are unfocused. |
| `disable-keybindings-on-fullscreen` | unsupported | - | This patch disables all keybindings except `togglefullscreen` when the focused window is fullscreen. Might help prevent fat-fingering. |
| `disable-keybindings-on-fullscreen-toggle` | unsupported | - | This patch changes the default behavior of the [disable-keybindings-on-fullscreen](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/disable-keybindings-on-fullscreen) patch by only taking effect when you explicitly toggle the functionality. You must apply that patch prior to applying this one. |
| `dragmfact` | main, stable | - | Change mfact by dragging the mouse. |
| `dragresize` | unsupported | - | implement rio-like window resizing |
| `drm_lease` | stable | - | Adds support for drm-lease-v1 for embedded displays such as VR headsets |
| `dwindle` | main, stable | - | Adds a dwindle (fibonacci-style) layout to dwl. Windows are arranged by recursively splitting the remaining space, alternating between horizontal and vertical splits |
| `en-keycodes` | stable | - | Always use the English keymap to get keycodes, so key bindings work even when using a non-English keyboard layout. |
| `envcfg` | stable | - | Input device configuration (click method, tap-and-drag, acceleration, etc), border size and colors via environment variables. |
| `extrabar` | unsupported | - |  |
| `fakefullscreenclient` | unsupported | - | Allow setting fake fullscreen per client |
| `fallback` | main, stable | - | Tries a different display mode if the preferred mode doesn't work. |
| `focusdir` | unsupported | - | Focus the window to the left, right, above or below the current focused window |
| `focusonurgent` | main, stable | - | By default, dwl responds to client requests to client messages by setting the urgency bit on the named window. This patch changes the focus to the window instead. Both behaviours are legitimate according to the cursed spec. This is the approximately the equivalent of the focusonactive patch of dwm. If you want a more controlled behavior, for example setting which clients can focus, check [activation-rule patch](https://codeberg.org/sevz/dwl-patches/src/branch/activation-rules). |
| `follow` | main, stable | - | An extremely simple patch that adds the option to change DWL's window sending behavior; when active, sent windows will be followed, i.e. when a window is sent to another tag, the view changes to that tag.<br>No dependencies. |
| `foreign-toplevel-management` | unsupported | - | Implement `foreign-toplevel-management`, it add handlers for activate, close, fullscreen and destroy request events, it's missing minimize and maximize request handlers. |
| `fullscreenadaptivesync` | main, stable | - | # fullscreenadaptivesync - Enables adaptive sync/VRR when a client is fullscreen. |
| `gamepad-bindings` | stable | - | Gamepad bindings to dwl. Press `LB + RB` toggle gamepad bindings. |
| `gaplessgrid` | main, stable | - | Arranges windows in a grid. Except it adjusts the number of windows in the first few columns to avoid empty cells. |
| `gaps` | unsupported | - | Adds gaps between clients, providing the ability to disable them at run-time. |
| `genericgaps` | stable | - | This patch adds gaps around windows and works with any layout (the layout code does not need to know about the gaps). This patch is a modified version of [vanitygaps][vanitygaps] patch. |
| `globalkey` | stable | - | This patch adds the ability to pass keys that are specified in the config header globally, similar to Hyprland's approach. This might deal with Wayland's lack of global shortcuts. |
| `hide-behind-deck` | unsupported | - | Hides all slave clients behind last focused slave in deck layout. |
| `hide-behind-fullscreen` | unsupported | - | Hide all clients (and layer surfaces) behind the current client if it is fullscreen, only the background (layer surfaces at the background layer) will be shown |
| `hide-behind-monocle` | stable | - | Hide all clients behind the focused one in the monocle layout |
| `hide-cursor-when-typing` | stable | - | Hide the mouse cursor when you start typing, and restore it again when the mouse cursor moves or a mouse button is pressed, just like [xbanish](https://github.com/jcs/xbanish). |
| `hide_vacant_tags` | stable | `bar` | Prevent [bar](/dwl/dwl-patches/wiki/bar) from drawing tags with no clients (i.e. vacant). It also stops drawing empty rectangles on the bar for non-vacant tags as there is no need anymore to distinguish vacant tags and it offers a more visible contrast than if there were filled/empty rectangles. |
| `hiderule` | unsupported | - | Adds a `ishidden` option to client rules, that allows hiding any matching clients entirely. |
| `hot-reload` | unsupported | - | Enables hot-reloading of dwl; meaning almost all logic can be changed at runtime. This obviously requires some black magic so for now there's a glibc 2.0 or later dependency to this. In particular this allows for every option in config.h to be changed at runtime. |
| `inputdevicerules` | main, stable | - | Input device rules implemented using custom device create functions for keyboards and pointing devices. |
| `ipc` | unsupported | - | Largely based on [raphi](https://sr.ht/~raphi/)'s [somebar](https://sr.ht/~raphi/somebar/), this patch provides an ipc for wayland clients to get and set dwl state. The ipc is intended for status bars, but can also be scripted with tools like [dwlmsg](https://codeberg.org/julmajustus/dwlmsg). |
| `kblayout` | stable | - | This patch adds per-client keyboard layout and ability to send current keyboard layout information to a status bar. |
| `keyboardshortcutsinhibit` | unsupported | - | Allows clients to use the keyboard-shortcuts-inhibit protocol to block the compositor from using keybinds. This is useful for virtualization software like looking-glass which requires this protocol to run. |
| `keycodes` | unsupported | - | Use keycodes instead of keysyms. This way, input is independent from keyboard layout (you can use the keys.h file to customize, or get the keycodes with `wev` or `xkbcli interactive-wayland` (x11-libs/libxkbcommon[tools] in gentoo)). |
| `killunsel` | unsupported | - | A very simple patch that introduces the functionality to terminate all visible, unselected clients, similar to the dwm [killunsel](https://dwm.suckless.org/patches/killunsel/) patch. |
| `launchtag` | unsupported | - | Straight port of the dwm taglayouts patch, renamed because I have a hard time finding it on the suckless site. |
| `limitnmaster` | main, stable | - | Limits nmaster to within the range of currently-opened windows (nmaster will not change past the full horizontal split layout) |
| `lock-size` | main, stable | - |  |
| `lockedkeys` | stable | - | This patch allows you to add keybindings to the lockscreen. |
| `mastercolumn` | unsupported | - | This patch adds a layout, `mastercol`, in which the windows in the master area are arranged in columns of equal size. The number of columns is always nmaster + 1, and the last column is a stack of leftover windows (as in the normal tile layout). It effectively differs from the default tile layout only in that master windows are arranged horizontally rather than vertically. |
| `menu` | main, stable | - | This patch adds `menu` command, which allows dwl to interface with dmenu-like programs. |
| `menurule` | unsupported | - | This patch adds a dmenu interface to [setrule][setrule], which allows to add or change client rules at runtime. It must be applied on top of [setrule][setrule] and [menu][menu] patches. |
| `meson` | main, stable | - | Add the meson build system. |
| `modes` | stable | - | Implement modes, that way each mapping is associated with a mode and is only active while in that mode, default mode is `NORMAL` |
| `monitorconfig` | main, stable | - | Allows more monitor configuration in config.h |
| `mouse-trackpad-split` | main, stable | - | Separates natural scrolling and acceleration settings for trackpad and mouse. |
| `movecenter` | unsupported | - | > This patch is no longer being maintained by me [wochap](https://codeberg.org/wochap), since I'm now using a different patch specific to my use case: https://codeberg.org/wochap/dwl/src/branch/v0.6-c/betterfloat/betterfloat-diff.patch. |
| `moveresizekb` | main, stable | - | This allows the user to change size and placement of floating windows using only the keyboard, default keybindings: |
| `movestack` | main, stable | - | Allows you to move a window up and down the stack. |
| `namedscratchpads` | stable | - | Allows for the creation of multiple scratchpad windows, each assigned to a different keybinding. In simple terms, it enables 'run or raise' functionality |
| `naturalscrolltrackpad` | main, stable | - | Set natural scrolling only for trackpads. Without this patch, setting `natural_scrolling` to 1 in `config.h` results in a regular mouse wheel having natural scrolling enabled as well. |
| `nextlayout` | unsupported | - | Change the current layout to the next available one. |
| `numlock-capslock` | stable | - | Allows activating numlock or capslock at startup. |
| `passthrough` | unsupported | - | allows pausing keybind handling |
| `per-app-cast` | unsupported | - | Adds per-window screen sharing aka toplevel capture via `ext-foreign-toplevel-image-capture-source-v1` based on the sway implementation <br> XWayland clients work in basic testing but it should be considered rather experimental. There is some possible restacking edge-cases but I was not able to reproduce them yet <br> Note that the captured surface is rendered a second time into its own scene, so there's a small GPU cost while a capture is active |
| `perinputconfig` | main, stable | - | Replace the singular keyboard and pointer input configuration with an array allowing to set different variables matching by name. |
| `pertag` | stable | - | Makes layout, mwfact and nmaster individual for every tag. |
| `pointer-gestures-unstable-v1` | stable | - | Forward the following events to client: swipe_begin, swipe_update, swipe_end, pinch_begin, pinch_update and pinch_end |
| `primaryselection` | stable | - | Adds a config option to disable/enable primary selection (middle-click paste). |
| `push` | stable | - | Adds functions `pushup` and `pushdown` to move windows within the tiling order. |
| `regexrules` | unsupported | - | Allows the use of regular expressions for window rules "app_id" and "title" |
| `regions` | unsupported | - | This patch will allow for a program to be used and have the current window regions on all monitors to be passed to the program as standard input.		 |
| `relative-mouse-resize` | main, stable | - | When resizing windows, the mouse will jump and resize the window in the quadrant that the resize starts at. |
| `reorganizetags` | main, stable | - |  |
| `restore-monitor` | main, stable | - | Moves clients to their old output when it is reattached. |
| `right` | main, stable | - | Put newly connected monitors on the right, like X does. |
| `riverctl` | unsupported | - | This patch adds river-control-unstable-v1 support to dwl. This protocol allows sending args to dwl to execute functions via the included dwlctl. This is used to allow changing rules and binds, at runtime via dwlctl. |
| `rlimit_max` | unsupported | - | Sets the current maximum open file descriptors to the maximum available limit. |
| `rotate-clients` | unsupported | - | Rotate clients on current monitor. |
| `rotatetags` | unsupported | - | This patch provides the ability to rotate the tagset left / right. It implements a new function rotatetags which modifies the current tagset. Same as original dwm patch. Also adds ability to move focused client to left / right adjacent tag by specifying appropriate enum value as argument. |
| `setrule` | main, stable | - | This patch adds an ability to add or change client rules at runtime. |
| `setupenv` | main, stable | - | Allow configuring environment variables in config.h |
| `shifttag` | main, stable | - | Shift to next/previous tag, with skipping occupied/unoccupied variants. |
| `shiftview` | main, stable | - | Add keybindings to cycle through tags with visible clients. |
| `simple_scratchpad` | main, stable | - | # simple_scratchpad - A very simple scratchpad utility. |
| `simpleborders` | main, stable | - | Like smartborders. Don't put borders when there is only one window on the screen. |
| `singlemaster` | unsupported | - | Restricts layout to only having one client in the master area. |
| `singletagset` | unsupported | - | Single set of tags shared between multiple monitors. |
| `singletagset-pertag` | unsupported | - | Pertag keeps layouts, mfact and nmaster per tag instead of per output. |
| `singletagset-sticky` | unsupported | - | Makes sticky work as expected with singletagset. The sticky window will stay on original output until you explicitly put it to a different monitor. |
| `skipfocus` | unsupported | - | Adds a rule-based ability to skip automatically focusing a window on creation. Expected use-case is for transient windows like notifications etc. The window can still be focused by mouse or keyboard movement. |
| `smartborders` | stable | - | The borders of a window aren't drawn when the window is the only tiling window in its tag OR if the window is in a monocle layout. |
| `snail` | main, stable | - | This layout is a scalable alternative to the "tile" and "spiral" layouts, optimized for wide monitors. Both the master area and the stack are "spirals", but windows in the master area are split horizontally as long as the master area has enough horizontal space, and the first window in the stack is split vertically unless the stack is wide. |
| `snail-gaps` | unsupported | - | Adds support for the [gaps patch](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/gaps) to the [snail layout patch](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/snail). |
| `spawninfo` | stable | - | This patch adds `spawninfo` function that is very similar to `spawn`, except it also passes some information about the focused client via stdin. |
| `spawnorfocus` | unsupported | - | Allows to assign a keybind to focus on a client with an app_id/title that contains a specified substring, or spawn command if there is no match. |
| `stacker` | unsupported | - | Stacker is a patch that allows moving around the stack more freely. With only one keybinding, quickly move, swap and jump around the window stack. |
| `stairs` | unsupported | - | Port of the [stairs](https://dwm.suckless.org/patches/stairs/) patch from dwm. |
| `startargv` | main, stable | - | allow passing startup command on argv |
| `sticky` | stable | - | Adds a toggleable function that makes a sticky client that is visible on all tags. |
| `swallow` | stable | - | This patch adds "window swallowing" to dwl. |
| `swapandfocusdir` | main, stable | - | Focus the window (floating or no) to the left, right, above, or below the current focused window. |
| `swapfocus` | main, stable | - | Swapfocus adds a new function on dwl: a shortcut to change the focus to the last focused window. - If the last focused window is in another tag, then the focus will change to that tag. - Alternatively: edit the patch and uncomment and comment out the lines instructed to keep the swapfocus shortcut from changing to another tag. |
| `swapmons` | stable | - | This patch is for dual-monitor setups (and can be extended for more monitors). It swaps the active client on Monitor-A with the active client on Monitor-B while preserving original tags of the swapped clients. |
| `switchtotag` | main | - | Add a rule option to switch to the configured tag when a window opens, then switch back when it closes. |
| `systemd` | main, stable | - | This is a simple patch that runs `systemctl --user import-environment WAYLAND_DISPLAY DISPLAY`, and `systemctl --user start dwl-session.target` after Dwl initializes, and then `systemctl --user stop dwl-session.target` when Dwl quits. This allows you to handle graceful startup and shutdown of your graphical systemd services, with the proper environment variables set. This is similar to [uwsm](https://github.com/Vladimir-csp/uwsm?tab=readme-ov-file), but it integrates natively with your existing systemd user services, and doesn't have uwsm's runtime overhead. |
| `tablet-input` | stable | - | Implements wlr-tablet-v2 for drawing tablets with cursor emulation. Inspired by @guyuming76's [branch](https://codeberg.org/guyuming76/dwl/commits/branch/graphic_tablet), with coding help from @Palanix and testing by @Thanatos. |
| `tagshift` | unsupported | - | Port of the [tagshift](https://dwm.suckless.org/patches/tagshift/) patch into dwl. |
| `tearing` | stable | - | This patch adds support for tearing protocol. To get it working `export WLR_DRM_NO_ATOMIC=1` is probably required. Some apps would send ASYNC hint and tearing will "just work", otherwise it's possible to force specified clients to tear with a rule. |
| `titleurgent` | unsupported | - | Whenever a client title changes set the client's urgent flag. |
| `tmux-borders` | unsupported | - | This patch replaces the window borders of tiled windows with borders that are similar to those found in tmux. The result is that there are no more unnecessary borders along the monitor edges in tiled mode. Borders of floating windows are not affected. |
| `toggle_constraints` | main, stable | - | Adds a function called togglepointerconstraints to turn pointer constraint enforcement on and off with a keybind. |
| `togglekblayoutandoptions` | stable | - | Switch between multiple keyboard layouts, variants, and options at runtime. Supports both assigning a specific keyboard to a shortcut and cycling through keyboards. |
| `touch-input` | stable | - | Adds touchscreen functionality. |
| `unclutter` | main | - | Hide the mouse cursor if it isn't being used for a certain period of time. |
| `ungroup-keyboards` | unsupported | - | Ungroup keyboard input devices based on device name. |
| `vanitygaps` | stable | - | Adds (inner) gaps between client windows and (outer) gaps between windows and the screen edge in a flexible manner. |
| `varcol` | unsupported | - | A variable column layout. |
| `viewnextocctag` | unsupported | - | View the next or previous tag, skipping any tags that do not have any clients. |
| `virtual-pointer` | unsupported | - | implement wlr_virtual_pointer_v1 for things like wayvnc server to work |
| `warpcursor` | main, stable | - | Warp cursor to the centre of newly focused clients. |
| `wayland-socket-handover` | main, stable | - | When your Wayland compositor crashes, your entire session dies with it. This patch allows your session to survive a restart or crash of dwl by passing in the Wayland socket from an outside wrapper program such as [wl-restart](https://github.com/Ferdi265/wl-restart). |
| `winview` | stable | - | Implements the function `winview` which switches the visible tags to the tags on which the current client is visible. |
| `xwayland-handle-minimize` | unsupported | - | Some windows (wine) games go black screen after losing focus and never recover https://github.com/swaywm/sway/issues/4324. This patch fixes this by handling minimize requests that some xwayland clients do. |
| `zerotag` | stable | `bar` |  |
| `zoomswap` | main, stable | - | This patch swaps the current window (C) with the previous master (P) when zooming. |
