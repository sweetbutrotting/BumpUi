[README.md](https://github.com/user-attachments/files/34614455/README.md)
# Bump UI

A pastel-style Roblox UI library that works on **PC and Mobile**, with smooth animations, a built-in config system and a set of ready-made elements.

## Features

- 6 color presets (Blue, Pink, Lavender, Mint, Cream, Navy), each with its own 2 decals (header logo + bottom-right corner decor)
- Animated load screen that preloads every decal and font before the UI shows
- Animations on almost everything (can be turned off in Settings > misc)
- **PC** and **Mobile** modes
- Drag the header to move, drag the handle in the bottom-right corner to resize (width and height independently)
- Sidebar search bar that finds any feature on any page
- Smooth collapsible sections
- Notifications (info / success / warning / error), up to 5 at once
- Configs can be saved / loaded / deleted right inside the UI (Settings > configs)
- Elements: Toggle, Slider, Dropdown (searchable + multi-select), Button (with confirm), Label, Textbox, Keybind, ColorPicker

## Installation

The repo has 2 files:

| File | Purpose |
|---|---|
| `BumpUI.lua` | The UI library (contains no menu) |
| `Example.lua` | An example menu, use it as a reference |

### Run the example

1. Open `Example.lua` and set `LIB_URL` to the raw link of `BumpUI.lua` in your repo:

```lua
local LIB_URL = "https://raw.githubusercontent.com/sweetbutrotting/BumpUi/refs/heads/main/BumpUI%20MAIN.lua"
```

2. Run it with your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sweetbutrotting/BumpUi/refs/heads/main/BumpUI%20MAIN.lua"))()
```

## Quick start

```lua
local win = loadstring(game:HttpGet("https://raw.githubusercontent.com/<user>/<repo>/main/BumpUI.lua"))()

local page = win:Page("Home", "MENU")          -- sidebar page (category = "MENU")
local tab  = page:Tab("main")                  -- tab inside the page
local sec  = tab:Section("Main", "left")       -- left column ("right" = right column)

sec:Toggle("Enabled", true, function(v) print("Enabled", v) end)
sec:Slider("Range", 0, 500, 250, 0, function(v) print("Range", v) end)
sec:Button("Hello", function() win:Notify("Hi", "Hello there!", 3, "success") end)

win:Show() -- remember to call Show once your menu is built
```

## API

### Structure

```
Window  ->  Page  ->  Tab  ->  Section  ->  Element
```

### Window (`win`)

| Function | Description |
|---|---|
| `win:Page(name, category, noSave)` | Creates a page. `category` groups pages in the sidebar. With `noSave = true` the elements of that page are **not** stored in configs (used for the Settings page) |
| `win:Show()` / `win:Hide()` / `win:Toggle()` | Show / hide the UI |
| `win:Notify(title, message, duration, kind)` | Notification. `kind`: `nil` (accent color), `"success"`, `"warning"`, `"error"` |
| `win:SetPreset(name)` | Change the color preset |
| `win:SetAccent(color3)` / `win:GetAccent()` | Set / get the accent color |
| `win:SetMode("PC" \| "Mobile")` | Change the mode |
| `win:SetSize(w, h)` / `win:ResetSize()` | Set / reset the window size |
| `win:SetAnimations(bool)` / `win:GetAnimations()` | Turn animations on / off |
| `win:SaveConfig(name)` | Save a config |
| `win:LoadConfig(name)` | Load a config |
| `win:DeleteConfig(name)` | Delete a config |
| `win:RefreshConfigs()` | Refresh the config list |
| `win:Destroy()` | Remove the UI |

Useful properties and callbacks:

| Name | Description |
|---|---|
| `win.PresetOrder` | List of preset names in order |
| `win.mode` | Current mode (`"PC"` or `"Mobile"`) |
| `win.menuKey` | Key that shows / hides the UI (default Right Ctrl) |
| `win.onPreset = function(name, accent)` | Called when the preset changes |
| `win.onUIApplied = function()` | Called after a config changed the window settings |

### Section (elements)

| Function | Notes |
|---|---|
| `sec:Label(text)` | A line of text |
| `sec:Toggle(label, default, cb)` | `cb(state)` |
| `sec:Slider(label, min, max, default, decimals, cb)` | `cb(value)` |
| `sec:Dropdown(label, options, default, cb, opts)` | `opts = { multi = true }` for multi-select (then `default` and the returned value are tables). `opts.search` forces the search box on / off (shown automatically with more than 6 options) |
| `sec:Button(label, cb, confirm)` | `confirm = true`: the first click shows "Click again to confirm" |
| `sec:Textbox(label, default, placeholder, cb)` | `cb(text)` fires when Enter is pressed |
| `sec:Keybind(label, defaultKeyCode, cb, mode, changed)` | `mode`: `"Press"`, `"Toggle"`, `"Hold"`. Left click = rebind, right click = change mode, Esc/Backspace = clear the key |
| `sec:ColorPicker(label, default, cb)` | `cb(color3)`, includes HEX, RGB, CMYK, HSV, HSL |
| `sec:ConfigBrowser(height)` | List of saved configs |
| `sec:SetCollapsed(bool)` | Collapse / expand the section |

Elements that hold a value return a table with `:Get()` and `:Set(value)`:

```lua
local t = sec:Toggle("Option", false)
t:Set(true)
print(t:Get())
```

> `:Set()` only changes the value shown in the UI and does **not** fire the callback. Loading a config does fire callbacks.

## Configs

- User configs are saved to `workspace/Bumps/Configs/<name>.json`
- Window settings (preset, size, position...) are saved to `workspace/Bumps/ui.json`
- Manage configs inside the UI: **Settings > configs** (Load, Overwrite, Delete, Refresh, Save as new)
- A config stores the value of every element **except** those on pages with `noSave = true`, plus the window settings
- Each element is identified by `Page/Tab/Section/Label`, so **renaming any of these means old configs will no longer apply to that element**

## Controls

| Action | How |
|---|---|
| Hide the UI | The `-` button in the header |
| Show it again (PC) | The menu key (default **Right Ctrl**, changeable in Settings > keybinds) |
| Show it again (Mobile) | Tap the small square button (it can be dragged) |
| Move | Drag the header |
| Resize | Drag the handle in the bottom-right corner |

## Customization

The options are at the top of `BumpUI.lua`:

| Variable | Meaning |
|---|---|
| `CONFIG` | Title, subtitle, menu key, PC / Mobile sizes |
| `PRESETS` | Colors and decals of each preset |
| `LOAD_IMAGES` | Image on the load screen |
| `STAR_ID` | Id of a (white) star image scattered in the background, the stars twinkle. Leave `""` to disable |
| `IMAGE_OVERRIDES` | Force a specific image id for a decal id |
| `FONT`, `FONT_BOLD` | Fonts |


## Executor requirements

| Needed for | Functions |
|---|---|
| Configs | `writefile`, `readfile`, `isfile`, `isfolder`, `makefolder`, `listfiles`, `delfile` |
| ColorPicker Copy button | `setclipboard` or `toclipboard` |
| Finding a decal's image id | `game:GetObjects` or `game:HttpGet` (fallbacks use `getcustomasset`) |
| Safe UI parenting | `gethui` (falls back to CoreGui, then PlayerGui) |

If an executor lacks the file functions, the UI still works, but the config features are disabled and a notification explains why.

## Notes

- Running the script a second time removes the old UI first.
- The current UI instance is stored in `getgenv().BumpUI`.
