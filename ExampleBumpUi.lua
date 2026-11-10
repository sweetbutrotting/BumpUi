

local LIB_URL = "https://raw.githubusercontent.com/sweetbutrotting/BumpUi/refs/heads/main/BumpUI%20MAIN.lua"

local win = loadstring(game:HttpGet(LIB_URL))()

-- Page 1
local home = win:Page("Home", "MENU")
local main = home:Tab("main")
local s1 = main:Section("Main", "left")
s1:Toggle("Enabled", true, function(v) print("Enabled", v) end)
s1:Slider("Range", 0, 500, 250, 0, function(v) print("Range", v) end)
s1:Dropdown("Mode", { "Option A", "Option B", "Option C" }, "Option A", function(v) print("Mode", v) end)
s1:Slider("Value", 0, 1, 0, 2, function(v) print("Value", v) end)
s1:Dropdown("Targets", { "Head", "Neck", "Torso", "Arms", "Hands", "Legs", "Feet" }, { "Head" }, function(v) print("Targets", table.concat(v, ", ")) end, { multi = true })
local s2 = main:Section("Filter", "right")
s2:Toggle("Option one", false)
s2:Toggle("Option two", true)
s2:Slider("Limit", 0, 1000, 300, 0)
local s3 = main:Section("Binds", "right")
s3:Keybind("Example key", Enum.KeyCode.E, function(v) print("Example key", v) end, "Toggle")
s3:Textbox("Name", "", "Type here", function(t) print("Textbox", t) end)

local checks = home:Tab("checks")
local c1 = checks:Section("Checks", "left")
c1:Toggle("Check A", true)
c1:Toggle("Check B", false)
c1:Button("Send notification", function() win:Notify("Hello", "This is a notification.", 3) end)
c1:Button("Success / warning / error", function()
	win:Notify("Success", "Everything went fine.", 3, "success")
	win:Notify("Warning", "Something looks odd.", 3, "warning")
	win:Notify("Error", "Something went wrong.", 3, "error")
end)

win:Page("Visuals", "MENU"):Tab("main"):Section("Visuals", "left"):Label("Add your content here")
win:Page("Misc", "MENU"):Tab("main"):Section("Misc", "left"):Label("Add your content here")

-- Settings page (noSave = true: its elements are not stored inside configs)
local settings = win:Page("Settings", "SYSTEM", true)

local theme = settings:Tab("theme")
local presetSec = theme:Section("Preset", "left")
for _, name in ipairs(win.PresetOrder) do
	presetSec:Button(name, function() win:SetPreset(name) end)
end
local winSec = theme:Section("Window", "right")
local modeDrop = winSec:Dropdown("Mode", { "PC", "Mobile" }, win.mode, function(v) win:SetMode(v) end)
winSec:Button("Reset size", function() win:ResetSize() end)
winSec:Label("Drag the cute handle in the bottom-right")
winSec:Label("corner to resize width and height freely")

local pickerTab = settings:Tab("color picker")
local accentPicker = pickerTab:Section("UI accent", "left"):ColorPicker("Accent color", win:GetAccent(), function(c) win:SetAccent(c) end)
pickerTab:Section("Example", "right"):ColorPicker("Your own color", Color3.fromRGB(50, 168, 82), function(c) print("Picked", c) end)
win.onPreset = function(_, accent) accentPicker:Set(accent) end

local binds = settings:Tab("keybinds")
local bindSec = binds:Section("Menu", "left")
local menuBind = bindSec:Keybind("Menu key", win.menuKey, nil, "Press", function(key)
	if key then
		win.menuKey = key
		win:_saveSoon()
		return nil
	end
	return win.menuKey -- the menu key cannot be cleared
end)
bindSec:Label("Left click = rebind, right click = mode")
bindSec:Label("Esc / Backspace clears a key")
local bindDemo = binds:Section("Demo", "right")
bindDemo:Keybind("Press mode", Enum.KeyCode.Q, function() win:Notify("Keybind", "Press mode fired", 1.5) end, "Press")
bindDemo:Keybind("Toggle mode", Enum.KeyCode.R, function(v) win:Notify("Keybind", "Toggle: " .. tostring(v), 1.5) end, "Toggle")
bindDemo:Keybind("Hold mode", Enum.KeyCode.F, function(v) print("Hold", v) end, "Hold")

-- Configs: saved in workspace/Bumps/Configs/<name>.json (managed only from this tab)
local cfgTab = settings:Tab("configs")
local cfgSec = cfgTab:Section("Saved configs", "left")
local browser = cfgSec:ConfigBrowser(150)
local function selectedConfig()
	if not browser.selected then
		win:Notify("Configs", "Select a config in the list first.", 2.5, "warning")
	end
	return browser.selected
end
cfgSec:Button("Load selected", function()
	local n = selectedConfig()
	if n then win:LoadConfig(n) end
end)
cfgSec:Button("Overwrite selected", function()
	local n = selectedConfig()
	if n then win:SaveConfig(n) end
end, true)
cfgSec:Button("Delete selected", function()
	local n = selectedConfig()
	if n then
		win:DeleteConfig(n)
		browser.selected = nil
	end
end, true)
cfgSec:Button("Refresh list", function()
	browser.refresh()
	win:Notify("Configs", browser.count .. " config(s) found", 2)
end)

local newSec = cfgTab:Section("New config", "right")
local nameBox = newSec:Textbox("Name", "", "my config")
newSec:Button("Save as new", function()
	if win:SaveConfig(nameBox:Get()) then nameBox:Set("") end
end)
newSec:Label("Put .json files in Bumps/Configs, then press Refresh")

local misc = settings:Tab("misc")
local fx = misc:Section("Effects", "left")
local animToggle = fx:Toggle("Animations", win:GetAnimations(), function(v) win:SetAnimations(v) end)
local sys = misc:Section("System", "right")
sys:Button("Unload UI", function() win:Destroy() end, true)

-- keeps the Settings widgets in sync after a config changes the window settings
win.onUIApplied = function()
	modeDrop:Set(win.mode)
	animToggle:Set(win:GetAnimations())
	menuBind:Set(win.menuKey)
end

win:Show()

return win
