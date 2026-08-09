# MangoWM Layout Manager

A simple DMS widget for switching the active MangoWM layout from the bar.

![MangoWM Layout Manager screenshot](./screenshot.png)

## Dependency

This plugin requires MangoWM's IPC helper:

- `mmsg`

The widget uses:

- `mmsg get monitor <name>` / `mmsg watch monitor <name>` to read the current layout
- `mmsg dispatch setlayout,<layout>` to switch layouts

## Usage

Left-click the bar widget to open a popout grid and pick any layout directly.
Right-click, middle-click and scrolling (or a two-finger swipe) each act as
shortcuts, configurable from the plugin's Settings page:

- **Left-click**: opens the layout picker popout, showing every layout
  enabled in "Scroll cycle" (see Settings below).
- **Right-click**: switches to a configured target layout, or back to
  whatever was active before it if that target is already active. Defaults
  to `monocle`.
- **Middle-click**: same toggle behaviour as right-click, against its own
  independently configured target. Disabled (no target) until set in
  Settings.
- **Scroll / two-finger swipe**: cycles forward or backward through the
  layouts listed under "Scroll cycle", in the order configured there.

## Settings

Configurable from the plugin's page in DMS' Plugins settings tab:

- **Right-click toggle target** / **Middle-click toggle target**: pick which
  layout each toggle switches to. Choosing **None** disables that toggle
  entirely (no-op on click).
- **Scroll cycle**: the ordered list of layouts used both by the
  scroll/swipe cycle and by the left-click popout grid.
  - The eye icon on each row shows or hides that layout from the list
    without removing it — hidden layouts are skipped by scrolling and the
    grid, but stay reachable via the right-click/middle-click targets
    (which always list every layout, regardless of this setting).
  - The drag handle reorders rows; scroll cycling and the popout grid
    follow this order.
- **Scroll speed**: minimum time (ms) between two scroll-triggered layout
  switches, to avoid a trackpad swipe jumping through several layouts at
  once.

## Supported Layouts

The chooser ships with the layouts documented by MangoWM at:

- https://mangowm.github.io/window-management/layouts/

Included layouts:

- `tile`
- `scroller`
- `monocle`
- `grid`
- `deck`
- `center_tile`
- `vertical_tile`
- `right_tile`
- `vertical_scroller`
- `vertical_grid`
- `vertical_deck`
- `dwindle`
- `fair`
- `vertical_fair`

## Install

Copy this directory into:

- `~/.config/DankMaterialShell/plugins/mangoWmLayoutManager`

Then restart DMS and enable the plugin in the Plugins settings tab.

## Notes

- Layout changes are applied through MangoWM's currently focused context.
- If `mmsg` is missing or MangoWM is not running, the widget shows an unavailable state.
