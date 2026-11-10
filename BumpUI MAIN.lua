--[[
	Bump UI  |  pastel Roblox UI library (PC + Mobile)

	Features
	- 6 presets, each with its own 2 decals (header logo + corner decor)
	- Smooth animations everywhere (tweens only, can be turned off in Settings > misc)
	- Animated load screen (floating image, shiny progress bar) that preloads every decal and the fonts
	- PC mode (default) and Mobile mode
	- Cute corner handle: drag it to resize the window freely (width AND height), drag the header to move
	- PC: the hide button hides the UI completely, press the menu key (Right Ctrl) to show it
	- Mobile: hiding shows a small draggable square button to bring the UI back
	- Elements: Toggle, Slider, Dropdown, Button, Label, Textbox, Keybind, ColorPicker
	- Notifications (info / success / warning / error, max 5 at once)
	- Config system inside the UI (Settings > configs): workspace/Bumps/Configs/<name>.json
	- Search bar (sidebar), animated collapsible sections, searchable + multi-select dropdowns, confirm buttons

	This file is ONLY the library. See Example.lua for how to build a menu with it.
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Remove an older copy if the script is executed twice
pcall(function()
	local old = getgenv and getgenv().BumpUI
	if old then old:Destroy() end
end)

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local CONFIG = {
	Title = "Bump",
	Subtitle = "VANTA",
	ConfigFile = "Bumps/ui.json", -- small file with the window prefs (preset, size, position...)
	LegacyFile = "BumpUI_config.json",
	MenuKey = Enum.KeyCode.RightControl, -- default key that shows / hides the UI
	LoadTimeout = 40, -- seconds, the UI opens after this even if something fails to load
	PC = { W = 760, H = 520, Side = 148, MinW = 600, MinH = 420 },
	Mobile = { W = 440, H = 440, Side = 84, MinW = 340, MinH = 380 },
}

-- Optional manual overrides: if a decal does not show, put its real IMAGE id here.
-- Format: ["<decal id>"] = "<image id>"
local IMAGE_OVERRIDES = {
	-- ["116199675212405"] = "000000000000",
}

-- Star pattern scattered over the empty parts of the UI (they twinkle slowly).
-- Upload a WHITE star image, put its id here ("" = no stars). Color comes from each preset ("star").
local STAR_ID = ""
local STAR_TINT = true -- false = keep the original colors of your star image

local FONT = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamMedium

-- Load screen image
local LOAD_IMAGES = { "103653080170339" }

-- 6 presets: each preset = 2 decals (logo = next to the title, deco = bottom-right corner)
local PRESETS = {
	Blue = {
		logo = "98775126532594", deco = "97603113899216", -- blue bear (top) + pot blue (bottom right)
		c = { bg = "F4F9FE", hd = "E3F0FB", ac = "4DA3EE", tx = "3D7DB5", bd = "A9D2F0", pn = "FFFFFF", ti = "1D4A75", lb = "8FB3D3", st = "C8DFF0", star = "8EC3F2" },
	},
	Pink = {
		logo = "94850602572956", deco = "138403741265339", -- pink 1 + pink 2
		c = { bg = "FFF5F8", hd = "FDE4EC", ac = "EE8FB2", tx = "A85577", bd = "F4BFD1", pn = "FFFFFF", ti = "6E2C46", lb = "D79BB2", st = "F6D4E0", star = "F4A9C4" },
	},
	Lavender = {
		logo = "133196220406065", deco = "122704870005827", -- lavender 1 + lavender 2
		c = { bg = "F8F6FE", hd = "EBE6FA", ac = "9D89DD", tx = "6A5AA3", bd = "CFC4EF", pn = "FFFFFF", ti = "3F3270", lb = "A99BD6", st = "DDD5F3", star = "BBA9EA" },
	},
	Mint = {
		logo = "77406503298938", deco = "98543739479633", -- mint 1 + mint 2
		c = { bg = "F3FCF9", hd = "DFF5EE", ac = "5CC4A2", tx = "3A8570", bd = "A8E0CF", pn = "FFFFFF", ti = "1D5242", lb = "82C6B0", st = "CDEEE3", star = "86D5B8" },
	},
	Cream = {
		logo = "113924268625686", deco = "111712866810602", -- cream 1 + cream 2
		c = { bg = "FFFAF2", hd = "F7ECD9", ac = "D4AA6A", tx = "96763F", bd = "E8D3AE", pn = "FFFFFF", ti = "5E4622", lb = "C9AD80", st = "EFE2C8", star = "E3C48A" },
	},
	Navy = {
		logo = "129597276731969", deco = "81102994640350", -- dark navy 1 + dark navy 2
		c = { bg = "1B2742", hd = "24345A", ac = "5F86D6", tx = "B9CBEF", bd = "3A4D7C", pn = "202D4D", ti = "E3EBFB", lb = "7E95C4", st = "121A2E", star = "6F8FD8" },
	},
}
local ORDER = { "Blue", "Pink", "Lavender", "Mint", "Cream", "Navy" }

for _, p in pairs(PRESETS) do
	for k, v in pairs(p.c) do
		p.c[k] = Color3.fromHex(v)
	end
end

----------------------------------------------------------------
-- STATE / UTILS
----------------------------------------------------------------
local State = { Animations = true }
local conns = {}

local function merge(a, b)
	local r = {}
	for k, v in pairs(a) do r[k] = v end
	if b then
		for k, v in pairs(b) do r[k] = v end
	end
	return r
end

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do
		i[k] = v
	end
	if parent then i.Parent = parent end
	return i
end

-- Tween helper (applies instantly when animations are off)
local function tw(inst, props, t, style, dir)
	if not State.Animations then
		for k, v in pairs(props) do inst[k] = v end
		return
	end
	TweenService:Create(inst, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
end

-- Custom animation driver (used when a property needs maths, e.g. size + position together).
-- fn(alpha) is called every frame with the eased value 0 -> 1. Returns a cancel function.
-- When animations are off the end state is applied immediately.
local function animate(dur, style, dir, fn, done)
	if not State.Animations then
		fn(1)
		if done then done() end
		return function() end
	end
	local t0 = os.clock()
	local alive = true
	local con
	con = RunService.RenderStepped:Connect(function()
		if not alive then
			con:Disconnect()
			return
		end
		local a = math.clamp((os.clock() - t0) / dur, 0, 1)
		fn(TweenService:GetValue(a, style, dir))
		if a >= 1 then
			alive = false
			con:Disconnect()
			if done then done() end
		end
	end)
	return function()
		alive = false
		con:Disconnect()
	end
end

local function mount(gui)
	local getters = {}
	if gethui then table.insert(getters, function() return gethui() end) end
	table.insert(getters, function() return game:GetService("CoreGui") end)
	table.insert(getters, function() return LocalPlayer:WaitForChild("PlayerGui") end)
	for _, get in ipairs(getters) do
		local ok = pcall(function() gui.Parent = get() end)
		if ok and gui.Parent then return end
	end
end

local function round(n, d)
	local m = 10 ^ (d or 0)
	return math.floor(n * m + 0.5) / m
end

local ROOT_DIR = "Bumps"
local CFG_DIR = "Bumps/Configs"

-- creates workspace/Bumps and workspace/Bumps/Configs when they do not exist yet
local function ensureFolders()
	if not (makefolder and isfolder) then return false end
	pcall(function()
		if not isfolder(ROOT_DIR) then makefolder(ROOT_DIR) end
		if not isfolder(CFG_DIR) then makefolder(CFG_DIR) end
	end)
	local ok, exists = pcall(isfolder, CFG_DIR)
	return (ok and exists) and true or false
end

local function cleanName(n)
	n = tostring(n or ""):gsub("[^%w _%-%.]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	return n:sub(1, 32)
end

local function cfgPath(name)
	return CFG_DIR .. "/" .. name .. ".json"
end

local function listConfigs()
	local out = {}
	if not ensureFolders() then return out end
	local ok, files = pcall(listfiles, CFG_DIR)
	if ok and type(files) == "table" then
		for _, f in ipairs(files) do
			local file = tostring(f):match("([^/\\]+)$")
			local name = file and file:match("^(.+)%.json$")
			if name then table.insert(out, name) end
		end
	end
	table.sort(out, function(a, b) return a:lower() < b:lower() end)
	return out
end

local function readConfig()
	local data = {}
	ensureFolders()
	pcall(function()
		if readfile and isfile then
			local path
			if isfile(CONFIG.ConfigFile) then path = CONFIG.ConfigFile
			elseif isfile(CONFIG.LegacyFile) then path = CONFIG.LegacyFile end
			if path then
				local d = HttpService:JSONDecode(readfile(path))
				if type(d) == "table" then data = d end
			end
		end
	end)
	return data
end

local function writeConfig(data)
	pcall(function()
		if writefile then
			ensureFolders()
			writefile(CONFIG.ConfigFile, HttpService:JSONEncode(data))
		end
	end)
end

----------------------------------------------------------------
-- IMAGES
-- IDs from the Creator Dashboard are often DECAL ids, but an ImageLabel needs the
-- IMAGE id that sits behind the decal. For every ID the script:
--   1) checks the asset type (Image -> use it directly)
--   2) for Decals, finds the real image id with several methods
--   3) prints which method worked, so problems are easy to see in the console
-- If nothing works, that image is hidden (no broken-image icon).
----------------------------------------------------------------
local resolved = {} -- id -> url to use
local failed = {}   -- id -> true when nothing could load it

local function extractTexture(obj)
	if not obj then return nil end
	if obj:IsA("Decal") or obj:IsA("Texture") then return obj.Texture end
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then return obj.Image end
	local d = obj:FindFirstChildWhichIsA("Decal", true) or obj:FindFirstChildWhichIsA("Texture", true)
	return d and d.Texture or nil
end

local function productInfo(id)
	local ok, r = pcall(function() return MarketplaceService:GetProductInfo(tonumber(id)) end)
	if ok and type(r) == "table" then return r end
	return nil
end

-- true unless Roblox reports that the asset failed to load
local function urlOk(url)
	local ok = true
	pcall(function()
		ContentProvider:PreloadAsync({ url }, function(_, status)
			if status == Enum.AssetFetchStatus.Failure then ok = false end
		end)
	end)
	return ok
end

-- Method A: read the texture of the decal through GetObjects / LoadAsset
local function imageIdFromObjects(id)
	local tex
	pcall(function()
		local objs = game:GetObjects("rbxassetid://" .. id)
		tex = extractTexture(objs[1])
		for _, o in ipairs(objs) do o:Destroy() end
	end)
	if not tex or tex == "" then
		pcall(function()
			local m = InsertService:LoadAsset(tonumber(id))
			tex = extractTexture(m)
			m:Destroy()
		end)
	end
	return tex and tex:match("(%d+)%s*$") or nil
end

-- Method B: download the decal file from the asset delivery and read the image id inside
local function imageIdFromDelivery(id)
	local ok, body = pcall(function() return game:HttpGet("https://assetdelivery.roblox.com/v1/asset/?id=" .. id) end)
	if ok and type(body) == "string" then
		return body:match("<url>[^<]-id=(%d+)") or body:match("rbxassetid://(%d+)")
	end
	return nil
end

-- Method C: decals are uploaded together with an image that has the same name and
-- a nearby id. Only accepted when type, name and creator all match.
local function imageIdFromNeighbours(id, info)
	if not info then return nil end
	for _, d in ipairs({ -1, 1, -2, 2, -3, 3 }) do
		local cand = tostring(tonumber(id) + d)
		local ci = productInfo(cand)
		if ci and ci.AssetTypeId == 1 and ci.Name == info.Name
			and ci.Creator and info.Creator and ci.Creator.TargetId == info.Creator.TargetId then
			return cand
		end
	end
	return nil
end

-- Method D: download the thumbnail and load it as a custom asset (executor feature)
local function urlFromThumbnail(id)
	if not (getcustomasset and writefile and isfile) then return nil end
	local path = "BumpUI_" .. id .. ".png"
	if not isfile(path) then
		local ok = pcall(function()
			local body = game:HttpGet("https://thumbnails.roblox.com/v1/assets?assetIds=" .. id .. "&size=420x420&format=Png&isCircular=false")
			local url = HttpService:JSONDecode(body).data[1].imageUrl
			writefile(path, game:HttpGet(url))
		end)
		if not ok or not isfile(path) then return nil end
	end
	local ok, asset = pcall(getcustomasset, path)
	if ok then return asset end
	return nil
end

local function resolveImage(id)
	local direct = "rbxassetid://" .. id

	if IMAGE_OVERRIDES[id] then
		return "rbxassetid://" .. IMAGE_OVERRIDES[id], true, "override"
	end

	local info = productInfo(id)
	local typeId = info and info.AssetTypeId

	-- already an Image asset
	if typeId == 1 and urlOk(direct) then return direct, true, "direct (Image)" end

	-- Decal (or unknown): find the image behind it
	local methods = {
		{ "GetObjects", function() return imageIdFromObjects(id) end },
		{ "asset delivery", function() return imageIdFromDelivery(id) end },
		{ "neighbour id", function() return imageIdFromNeighbours(id, info) end },
	}
	for _, m in ipairs(methods) do
		local ok, imageId = pcall(m[2])
		if ok and imageId then
			local url = "rbxassetid://" .. imageId
			if urlOk(url) then return url, true, m[1] .. " -> " .. imageId end
		end
	end

	local thumb = urlFromThumbnail(id)
	if thumb then return thumb, true, "thumbnail" end

	-- unknown type: last try with the raw id
	if typeId == nil and urlOk(direct) then return direct, true, "direct" end

	return direct, false, "type " .. tostring(typeId)
end

local function img(id)
	return resolved[id] or ("rbxassetid://" .. id)
end


----------------------------------------------------------------
-- LOAD SCREEN
-- card fades + pops in, the image floats and sways, the progress bar eases toward its
-- target, pulses in color and has a moving shine, the status text animates its dots.
----------------------------------------------------------------
local function showLoader()
	local c = PRESETS.Blue.c
	local gui = new("ScreenGui", { Name = "BumpLoader", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	mount(gui)
	local alive = true

	local function loop(inst, props, t, style)
		TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), props):Play()
	end

	local dim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = c.st, BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)
	TweenService:Create(dim, TweenInfo.new(0.4), { BackgroundTransparency = 0.2 }):Play()

	local card = new("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 260), BackgroundColor3 = c.pn, BorderColor3 = c.bd, BorderSizePixel = 1, GroupTransparency = 1 }, gui)
	local scale = new("UIScale", { Scale = 0.88 }, card)
	TweenService:Create(card, TweenInfo.new(0.35), { GroupTransparency = 0 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	-- floating + swaying image
	local image = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(120, 120), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Rotation = -3 }, card)
	loop(image, { Position = UDim2.new(0.5, 0, 0, 8) }, 1.4)
	loop(image, { Rotation = 3 }, 1.9)

	new("TextLabel", { Position = UDim2.new(0, 0, 0, 140), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = CONFIG.Title, Font = FONT_BOLD, TextSize = 17, TextColor3 = c.ti }, card)
	local status = new("TextLabel", { Position = UDim2.new(0, 0, 0, 164), Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = "Starting", Font = FONT, TextSize = 12, TextColor3 = c.tx }, card)

	-- progress bar
	local back = new("Frame", { Position = UDim2.new(0, 30, 0, 196), Size = UDim2.new(1, -60, 0, 8), BackgroundColor3 = c.hd, BorderColor3 = c.bd, BorderSizePixel = 1, ClipsDescendants = true }, card)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = c.ac, BorderSizePixel = 0, ClipsDescendants = true }, back)
	loop(fill, { BackgroundColor3 = c.star }, 0.8) -- color pulse
	local shine = new("Frame", { Size = UDim2.fromScale(0.4, 1), Position = UDim2.fromScale(-0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, fill)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1) }) }, shine)
	TweenService:Create(shine, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 0.1), { Position = UDim2.fromScale(1.1, 0) }):Play()

	local percent = new("TextLabel", { Position = UDim2.new(0, 0, 0, 212), Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = "0%", Font = FONT, TextSize = 11, TextColor3 = c.lb }, card)

	-- smooth progress + animated dots
	local target, shown = 0, 0
	local base, dots = "Starting", true
	task.spawn(function()
		local t = 0
		while alive and gui.Parent do
			local dt = task.wait()
			shown = shown + (target - shown) * math.min(1, dt * 8)
			if math.abs(target - shown) < 0.002 then shown = target end
			fill.Size = UDim2.fromScale(shown, 1)
			percent.Text = math.floor(shown * 100 + 0.5) .. "%"
			t = t + dt
			if dots then status.Text = base .. string.rep(".", math.floor(t * 2.5) % 4) end
		end
	end)

	local api = { holder = card }
	function api.set(p, msg)
		target = math.clamp(p, 0, 1)
		if msg then
			base = msg
			if target >= 1 then
				dots = false
				status.Text = msg
			end
		end
	end
	function api.setImage(url) image.Image = url end
	-- fades out smoothly, the UI shows up behind it at the same time
	function api.destroy()
		alive = false
		TweenService:Create(dim, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(card, TweenInfo.new(0.35), { GroupTransparency = 1 }):Play()
		TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Scale = 1.1 }):Play()
		task.delay(0.5, function() gui:Destroy() end)
	end
	return api
end

----------------------------------------------------------------
-- THEME
----------------------------------------------------------------
local Theme = {}
for k, v in pairs(PRESETS.Blue.c) do Theme[k] = v end
local themed = {}
local themeHooks = {}

local function bind(inst, prop, key)
	table.insert(themed, { inst, prop, key })
	inst[prop] = Theme[key]
end

local function onTheme(fn)
	table.insert(themeHooks, fn)
	fn()
end

-- Full preset change (tweened)
local function applyColors(name, accent)
	local t = {}
	for k, v in pairs(PRESETS[name].c) do t[k] = v end
	if accent then t.ac = accent end
	Theme = t
	for _, b in ipairs(themed) do
		if b[1].Parent then tw(b[1], { [b[2]] = Theme[b[3]] }, 0.25) end
	end
	for _, fn in ipairs(themeHooks) do pcall(fn) end
end

-- Accent only (instant, used while dragging the color picker)
local function applyAccent(c)
	Theme.ac = c
	for _, b in ipairs(themed) do
		if b[3] == "ac" then pcall(function() b[1][b[2]] = c end) end
	end
	for _, fn in ipairs(themeHooks) do pcall(fn) end
end

local function text(parent, str, key, props)
	local t = new("TextLabel", merge({
		BackgroundTransparency = 1, Text = str, Font = FONT, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, props), parent)
	bind(t, "TextColor3", key or "tx")
	return t
end

-- text boxes light up their border with the accent color while they are focused
local function focusFx(box, target)
	target = target or box
	box.Focused:Connect(function() tw(target, { BorderColor3 = Theme.ac }, 0.15) end)
	box.FocusLost:Connect(function() tw(target, { BorderColor3 = Theme.bd }, 0.2) end)
end

----------------------------------------------------------------
-- DECALS (2 per preset: logo = header, deco = bottom-right corner)
----------------------------------------------------------------
local function decal(parent, props)
	local image = new("ImageLabel", merge({ BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit }, props), parent)
	return { img = image }
end

local function setDecal(d, id)
	d.failed = failed[id] and true or false
	d.img.Image = img(id)
	d.img.Visible = not d.failed
end

-- STAR PATTERN: { x, y (scale 0-1), size (px), rotation, image transparency }
local starImgs = {}
local STAR_MAIN = {
	{ 0.06, 0.20, 14, 12, 0.35 }, { 0.18, 0.10, 9, -10, 0.5 }, { 0.32, 0.28, 12, 20, 0.45 },
	{ 0.47, 0.14, 10, 0, 0.4 }, { 0.62, 0.24, 15, -15, 0.4 }, { 0.78, 0.12, 9, 8, 0.5 },
	{ 0.92, 0.30, 13, 18, 0.4 }, { 0.12, 0.48, 10, -8, 0.5 }, { 0.28, 0.62, 16, 10, 0.35 },
	{ 0.42, 0.45, 9, 0, 0.55 }, { 0.56, 0.58, 12, -20, 0.4 }, { 0.72, 0.50, 10, 12, 0.5 },
	{ 0.90, 0.58, 15, -10, 0.35 }, { 0.08, 0.80, 13, 15, 0.4 }, { 0.22, 0.92, 9, -12, 0.5 },
	{ 0.38, 0.84, 14, 6, 0.4 }, { 0.52, 0.94, 10, -6, 0.5 }, { 0.66, 0.80, 12, 22, 0.4 },
}
local STAR_SIDE = {
	{ 0.30, 0.60, 12, 10, 0.4 }, { 0.72, 0.66, 9, -14, 0.5 }, { 0.22, 0.74, 8, 0, 0.55 },
	{ 0.62, 0.78, 13, 18, 0.4 }, { 0.40, 0.70, 7, -8, 0.6 },
}
local STAR_SUB = {
	{ 0.05, 0.50, 11, 12, 0.4 }, { 0.14, 0.30, 7, -10, 0.55 }, { 0.24, 0.62, 9, 6, 0.5 },
	{ 0.76, 0.38, 9, -6, 0.5 }, { 0.86, 0.66, 7, 14, 0.55 }, { 0.95, 0.46, 11, -12, 0.4 },
}

-- a transparent layer with stars; create it BEFORE the content so the stars stay behind it
local function starLayer(parent, spots)
	local layer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, parent)
	for _, s in ipairs(spots) do
		local star = new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(s[1], s[2]),
			Size = UDim2.fromOffset(s[3], s[3]), Rotation = s[4], ImageTransparency = s[5],
			BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Visible = false,
		}, layer)
		if STAR_TINT then bind(star, "ImageColor3", "star") end
		table.insert(starImgs, star)
	end
	return layer
end

-- stars twinkle (fade + tiny rotation) with a random speed / delay each
local starTweens = {}
local function starAnim(on)
	for _, st in ipairs(starTweens) do
		st.tween:Cancel()
		st.inst.ImageTransparency = st.tr
		st.inst.Rotation = st.rot
	end
	starTweens = {}
	if not on then return end
	for _, s in ipairs(starImgs) do
		if s.Visible then
			local tr, rot = s.ImageTransparency, s.Rotation
			local tween = TweenService:Create(s, TweenInfo.new(1.3 + math.random() * 1.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, math.random() * 1.5), {
				ImageTransparency = math.min(tr + 0.35, 0.95), Rotation = rot + 14,
			})
			tween:Play()
			table.insert(starTweens, { inst = s, tween = tween, tr = tr, rot = rot })
		end
	end
end

local function setStars()
	local ok = STAR_ID ~= "" and not failed[STAR_ID]
	for _, s in ipairs(starImgs) do
		s.Image = ok and img(STAR_ID) or ""
		s.Visible = ok
	end
	starAnim(State.Animations)
end

----------------------------------------------------------------
-- GLOBAL INPUT (dragging, keybinds)
----------------------------------------------------------------
local dragFn
local dragEnd
local listening
local openDrop -- the dropdown that is currently open (only one at a time)
local keybinds = {}
local ActiveWindow

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

table.insert(conns, UIS.InputChanged:Connect(function(i)
	if dragFn and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		dragFn(i)
	end
end))

table.insert(conns, UIS.InputEnded:Connect(function(i)
	if isPress(i) then
		dragFn = nil
		if dragEnd then
			local f = dragEnd
			dragEnd = nil
			f()
		end
	end
	if i.UserInputType == Enum.UserInputType.Keyboard then
		for _, kb in ipairs(keybinds) do
			if kb.key and kb.key == i.KeyCode then kb.release() end
		end
	end
end))

table.insert(conns, UIS.InputBegan:Connect(function(i, gp)
	if listening then
		if i.UserInputType == Enum.UserInputType.Keyboard then
			local f = listening
			listening = nil
			f(i.KeyCode)
		end
		return
	end
	if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if ActiveWindow and ActiveWindow.menuKey and i.KeyCode == ActiveWindow.menuKey then
		ActiveWindow:Toggle()
		return
	end
	for _, kb in ipairs(keybinds) do
		if kb.key and kb.key == i.KeyCode then kb.press() end
	end
end))

-- click outside of the open dropdown closes it
table.insert(conns, UIS.InputBegan:Connect(function(i)
	if not openDrop or not isPress(i) then return end
	local row = openDrop.row
	if not row.Parent then openDrop = nil return end
	local p, s = row.AbsolutePosition, row.AbsoluteSize
	local x, y = i.Position.X, i.Position.Y
	local inset = GuiService:GetGuiInset().Y
	local inX = x >= p.X and x <= p.X + s.X
	local inY = (y >= p.Y and y <= p.Y + s.Y) or (y + inset >= p.Y and y + inset <= p.Y + s.Y)
	if not (inX and inY) then openDrop.close() end
end))

----------------------------------------------------------------
-- COLOR HELPERS
----------------------------------------------------------------
local function pct(x) return math.floor(x * 100 + 0.5) .. "%" end

local function describeColor(c)
	local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
	local h, s, v = c:ToHSV()
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	local l = (mx + mn) / 2
	local sl = (mx == mn) and 0 or (mx - mn) / (1 - math.abs(2 * l - 1))
	local k = 1 - mx
	local C, M, Y = 0, 0, 0
	if k < 1 then
		C, M, Y = (1 - c.R - k) / (1 - k), (1 - c.G - k) / (1 - k), (1 - c.B - k) / (1 - k)
	end
	local deg = math.floor(h * 360 + 0.5) .. "\u{B0}"
	return {
		rgb = r .. ", " .. g .. ", " .. b,
		cmyk = pct(C) .. ", " .. pct(M) .. ", " .. pct(Y) .. ", " .. pct(k),
		hsv = deg .. ", " .. pct(s) .. ", " .. pct(v),
		hsl = deg .. ", " .. pct(math.clamp(sl, 0, 1)) .. ", " .. pct(l),
	}
end

local KEY_SHORT = {
	RightControl = "RCtrl", LeftControl = "LCtrl", RightShift = "RShift", LeftShift = "LShift",
	RightAlt = "RAlt", LeftAlt = "LAlt", Return = "Enter", Backspace = "Bksp", Escape = "Esc",
}
local function keyName(k)
	if not k then return "None" end
	return KEY_SHORT[k.Name] or k.Name
end
local MODES = { "Press", "Toggle", "Hold" }

----------------------------------------------------------------
-- SMALL SHARED WIDGETS
----------------------------------------------------------------
local function smallButton(parent, label, props, cb)
	local b = new("TextButton", merge({ BorderSizePixel = 1, AutoButtonColor = false, Text = label, Font = FONT, TextSize = 12 }, props), parent)
	bind(b, "BackgroundColor3", "hd") bind(b, "BorderColor3", "bd") bind(b, "TextColor3", "ti")
	b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = Theme.bd }, 0.1) end)
	b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = Theme.hd }, 0.15) end)
	b.MouseButton1Down:Connect(function() tw(b, { BackgroundColor3 = Theme.ac }, 0.06) end)
	b.MouseButton1Up:Connect(function() tw(b, { BackgroundColor3 = Theme.bd }, 0.18) end)
	b.MouseButton1Click:Connect(function() if cb then task.spawn(cb) end end)
	return b
end

-- list of the config files in workspace/Bumps/Configs (click = select)
local function buildConfigList(win, parent, props)
	local scroll = new("ScrollingFrame", merge({
		BorderSizePixel = 1, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, props), parent)
	bind(scroll, "BackgroundColor3", "hd") bind(scroll, "BorderColor3", "bd") bind(scroll, "ScrollBarImageColor3", "bd")
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, scroll)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, scroll)
	local api = { selected = nil, count = 0 }
	local items, bars = {}, {}
	local function mark()
		for name, bar in pairs(bars) do
			tw(bar, { Size = UDim2.new(0, 3, name == api.selected and 1 or 0, 0) }, 0.18, Enum.EasingStyle.Quint)
		end
	end
	function api.select(name)
		api.selected = name
		mark()
	end
	function api.refresh()
		if not scroll.Parent then return end
		for _, it in ipairs(items) do it:Destroy() end
		items, bars = {}, {}
		local list = listConfigs()
		api.count = #list
		local stillThere = false
		for idx, name in ipairs(list) do
			if name == api.selected then stillThere = true end
			local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 26), BorderSizePixel = 1, AutoButtonColor = false, Text = "", LayoutOrder = idx }, scroll)
			bind(b, "BackgroundColor3", "pn") bind(b, "BorderColor3", "bd")
			local bar = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 3, 0, 0), BorderSizePixel = 0 }, b)
			bind(bar, "BackgroundColor3", "ac")
			text(b, name, "ti", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -16, 1, 0), TextSize = 12 })
			b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = Theme.hd }, 0.1) end)
			b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = Theme.pn }, 0.15) end)
			b.MouseButton1Click:Connect(function() api.select(name) end)
			items[#items + 1] = b
			bars[name] = bar
		end
		if #list == 0 then
			items[1] = text(scroll, "No configs yet", "lb", { Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12 })
		end
		if not stillThere then api.selected = nil end
		mark()
	end
	table.insert(win.browsers, api)
	return api
end

----------------------------------------------------------------
-- CLASSES
----------------------------------------------------------------
local Window, Page, Tab, Section = {}, {}, {}, {}
Window.__index, Page.__index, Tab.__index, Section.__index = Window, Page, Tab, Section

-- SECTION ELEMENTS -------------------------------------------
function Section:_row(h)
	self._n = self._n + 1
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = self._n }, self.body)
	table.insert(self.rows, f)
	return f
end

-- every element is registered so a config can save / restore its value
function Section:_reg(label, get, set)
	if self.noSave then return end
	local win = self.tab.win
	local base = table.concat({ self.tab.page.name, self.tab.name, self.title, label }, "/")
	local id, n = base, 1
	while win.flagIds[id] do
		n = n + 1
		id = base .. " #" .. n
	end
	win.flagIds[id] = true
	table.insert(win.flagList, { id = id, get = get, set = set })
end

-- every element is searchable from the sidebar search bar
function Section:_index(label)
	table.insert(self.tab.win.index, { label = tostring(label), page = self.tab.page, tab = self.tab, section = self.title, sectionObj = self })
end

-- collapse / expand: the body slides open or closed and the arrow rotates
function Section:SetCollapsed(v, instant)
	v = v and true or false
	if v == self.collapsed then return end
	self.collapsed = v
	local body, layout = self.body, self.bodyLayout
	if self._cancel then
		self._cancel()
		self._cancel = nil
	end
	tw(self.arrow, { Rotation = v and -90 or 0 }, 0.22, Enum.EasingStyle.Quint)
	local from = body.AbsoluteSize.Y
	local to = v and 0 or layout.AbsoluteContentSize.Y
	if instant or not State.Animations or (not v and to <= 0) then
		if v then
			body.AutomaticSize = Enum.AutomaticSize.None
			body.Size = UDim2.new(1, 0, 0, 0)
		else
			body.AutomaticSize = Enum.AutomaticSize.Y
			body.Size = UDim2.new(1, 0, 0, 0)
		end
		return
	end
	body.AutomaticSize = Enum.AutomaticSize.None
	body.Size = UDim2.new(1, 0, 0, from)
	self._cancel = animate(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, function(a)
		body.Size = UDim2.new(1, 0, 0, from + (to - from) * a)
	end, function()
		self._cancel = nil
		if not self.collapsed then
			body.AutomaticSize = Enum.AutomaticSize.Y
			body.Size = UDim2.new(1, 0, 0, 0)
		end
	end)
end

function Section:Label(str)
	local row = self:_row(24)
	text(row, str, "tx", { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -20, 1, 0), TextSize = 12 })
end

function Section:Toggle(label, default, cb)
	local row = self:_row(30)
	self:_index(label)
	text(row, label, "tx", { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -60, 1, 0) })
	local track = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(32, 16), BorderSizePixel = 0 }, row)
	local knob = new("Frame", { Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, track)
	local btn = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, row)
	-- soft highlight behind the row while hovering
	bind(row, "BackgroundColor3", "hd")
	row.BackgroundTransparency = 1
	btn.MouseEnter:Connect(function() tw(row, { BackgroundTransparency = 0.55 }, 0.15) end)
	btn.MouseLeave:Connect(function() tw(row, { BackgroundTransparency = 1 }, 0.2) end)
	local state = default and true or false
	local first = true
	local function render()
		local goal = { BackgroundColor3 = state and Theme.ac or Theme.bd }
		local kpos = state and UDim2.new(1, -14, 0, 2) or UDim2.new(0, 2, 0, 2)
		if first then
			first = false
			track.BackgroundColor3 = goal.BackgroundColor3
			knob.Position = kpos
		else
			tw(track, goal, 0.18)
			tw(knob, { Position = kpos }, 0.22, Enum.EasingStyle.Back)
		end
	end
	onTheme(render)
	btn.MouseButton1Click:Connect(function()
		state = not state
		render()
		if cb then task.spawn(cb, state) end
	end)
	self:_reg(label, function() return state end, function(v)
		state = v and true or false
		render()
		if cb then task.spawn(cb, state) end
	end)
	return { Set = function(_, v) state = v and true or false render() end, Get = function() return state end }
end

function Section:Slider(label, min, max, default, decimals, cb)
	decimals = decimals or 0
	local row = self:_row(30)
	self:_index(label)
	text(row, label, "tx", { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0, 70, 1, 0) })
	local box = new("TextBox", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(46, 20), BorderSizePixel = 1, Font = FONT, TextSize = 12, ClearTextOnFocus = false }, row)
	bind(box, "BackgroundColor3", "hd") bind(box, "BorderColor3", "bd") bind(box, "TextColor3", "ti")
	focusFx(box)
	local track = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 82, 0.5, 0), Size = UDim2.new(1, -82 - 10 - 46 - 10, 0, 4), BorderSizePixel = 0 }, row)
	bind(track, "BackgroundColor3", "bd")
	local fillBar = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
	bind(fillBar, "BackgroundColor3", "ac")
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BorderSizePixel = 1, BorderColor3 = Color3.new(1, 1, 1) }, track)
	bind(knob, "BackgroundColor3", "ac")
	local hit = new("TextButton", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "" }, track)

	local value = default
	-- the knob and the fill glide to the new value (instant only for the first draw)
	local function set(v, fire, instant)
		value = round(math.clamp(v, min, max), decimals)
		local a = (value - min) / (max - min)
		if instant then
			knob.Position = UDim2.new(a, 0, 0.5, 0)
			fillBar.Size = UDim2.fromScale(a, 1)
		else
			tw(knob, { Position = UDim2.new(a, 0, 0.5, 0) }, 0.08)
			tw(fillBar, { Size = UDim2.fromScale(a, 1) }, 0.08)
		end
		box.Text = string.format("%." .. decimals .. "f", value)
		if fire and cb then task.spawn(cb, value) end
	end
	set(default, false, true)
	local function fromInput(i)
		local a = math.clamp((i.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		set(min + (max - min) * a, true)
	end
	hit.InputBegan:Connect(function(i)
		if isPress(i) then
			fromInput(i)
			dragFn = fromInput
			tw(knob, { Size = UDim2.fromOffset(17, 17) }, 0.15, Enum.EasingStyle.Back)
			dragEnd = function() tw(knob, { Size = UDim2.fromOffset(12, 12) }, 0.18) end
		end
	end)
	box.FocusLost:Connect(function()
		set(tonumber(box.Text) or value, true)
	end)
	self:_reg(label, function() return value end, function(v)
		if tonumber(v) then set(tonumber(v), true) end
	end)
	return { Set = function(_, v) set(v, false) end, Get = function() return value end }
end

-- opts: { multi = true } for multi select, { search = true/false } to force the search box
-- (search is shown automatically when there are more than 6 options)
function Section:Dropdown(label, options, default, cb, opts)
	opts = opts or {}
	local multi = opts.multi and true or false
	local searchable = opts.search
	if searchable == nil then searchable = #options > 6 end
	self._n = self._n + 1
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = self._n }, self.body)
	table.insert(self.rows, row)
	self:_index(label)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 1 }, row)
	text(head, label, "tx", { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -120, 1, 0) })
	local box = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(96, 22), BorderSizePixel = 1, AutoButtonColor = false, Text = "" }, head)
	bind(box, "BackgroundColor3", "hd") bind(box, "BorderColor3", "bd")
	box.MouseEnter:Connect(function() tw(box, { BackgroundColor3 = Theme.st }, 0.12) end)
	box.MouseLeave:Connect(function() tw(box, { BackgroundColor3 = Theme.hd }, 0.15) end)
	local cur = text(box, "", "ti", { Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -24, 1, 0), TextSize = 12 })
	local arrow = text(box, "v", "tx", { Position = UDim2.new(1, -16, 0, 0), Size = UDim2.fromOffset(12, 22), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center })

	-- the list stays "visible" but clipped to height 0 while closed, it slides open / closed
	local list = new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = 2 }, row)
	local listLayout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, list)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 6) }, list)
	local search
	if searchable then
		search = new("TextBox", { Size = UDim2.new(1, 0, 0, 22), BorderSizePixel = 1, Font = FONT, TextSize = 12, ClearTextOnFocus = false, Text = "", PlaceholderText = "Search...", TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 }, list)
		bind(search, "BackgroundColor3", "hd") bind(search, "BorderColor3", "bd") bind(search, "TextColor3", "ti") bind(search, "PlaceholderColor3", "lb")
		focusFx(search)
		new("UIPadding", { PaddingLeft = UDim.new(0, 6) }, search)
	end
	-- the option list scrolls when it is taller than 150px
	local scroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, list)
	bind(scroll, "ScrollBarImageColor3", "bd")
	local layout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, scroll)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.Size = UDim2.new(1, 0, 0, math.clamp(layout.AbsoluteContentSize.Y, 0, 150))
	end)

	local dd = { row = row, open = false }
	local cancelAnim
	local function setOpen(o)
		if dd.open == o then return end
		dd.open = o
		if cancelAnim then
			cancelAnim()
			cancelAnim = nil
		end
		tw(arrow, { Rotation = o and 180 or 0 }, 0.22, Enum.EasingStyle.Quint)
		local from = list.AbsoluteSize.Y
		list.AutomaticSize = Enum.AutomaticSize.None
		list.Size = UDim2.new(1, 0, 0, from)
		local to = o and (listLayout.AbsoluteContentSize.Y + 6) or 0
		cancelAnim = animate(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, function(a)
			list.Size = UDim2.new(1, 0, 0, from + (to - from) * a)
		end, function()
			cancelAnim = nil
			if dd.open then
				list.AutomaticSize = Enum.AutomaticSize.Y
				list.Size = UDim2.new(1, 0, 0, 0)
			end
		end)
	end
	local function close()
		setOpen(false)
		if openDrop == dd then openDrop = nil end
	end
	dd.close = close

	local names = {}
	for _, o in ipairs(options) do names[#names + 1] = tostring(o) end
	local selected, single = {}, nil
	local buttons = {}

	local function getValue()
		if multi then
			local out = {}
			for _, n in ipairs(names) do
				if selected[n] then out[#out + 1] = n end
			end
			return out
		end
		return single
	end
	local function render()
		for n, b in pairs(buttons) do
			local on
			if multi then on = selected[n] == true else on = (single == n) end
			tw(b.mark, { Size = on and UDim2.fromOffset(8, 8) or UDim2.fromOffset(0, 0) }, 0.2, Enum.EasingStyle.Back)
		end
		if multi then
			local v = getValue()
			if #v == 0 then cur.Text = "None"
			elseif #v <= 2 then cur.Text = table.concat(v, ", ")
			else cur.Text = #v .. " selected" end
		else
			cur.Text = tostring(single)
		end
	end
	local function setValue(v, fire)
		if multi then
			selected = {}
			if type(v) == "table" then
				for _, n in ipairs(v) do
					n = tostring(n)
					if buttons[n] then selected[n] = true end
				end
			end
		else
			local n = tostring(v)
			if buttons[n] then single = n else return end
		end
		render()
		if fire and cb then task.spawn(cb, getValue()) end
	end
	local function pick(n)
		if multi then
			selected[n] = (not selected[n]) or nil
			render()
			if cb then task.spawn(cb, getValue()) end
		else
			setValue(n, true)
			close()
		end
	end

	for idx, name in ipairs(names) do
		local b = new("TextButton", { Size = UDim2.new(1, -4, 0, 24), BorderSizePixel = 1, AutoButtonColor = false, Text = "", LayoutOrder = idx }, scroll)
		bind(b, "BackgroundColor3", "hd") bind(b, "BorderColor3", "bd")
		text(b, name, "ti", { Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -30, 1, 0), TextSize = 12 })
		local mark = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(0, 0), BorderSizePixel = 0 }, b)
		bind(mark, "BackgroundColor3", "ac")
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, mark)
		buttons[name] = { btn = b, mark = mark }
		b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = Theme.bd }, 0.1) end)
		b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = Theme.hd }, 0.15) end)
		b.MouseButton1Click:Connect(function() pick(name) end)
	end

	if search then
		search:GetPropertyChangedSignal("Text"):Connect(function()
			local q = search.Text:lower()
			for n, b in pairs(buttons) do
				b.btn.Visible = (q == "") or (n:lower():find(q, 1, true) ~= nil)
			end
		end)
	end

	box.MouseButton1Click:Connect(function()
		if dd.open then
			close()
		else
			if openDrop and openDrop ~= dd then openDrop.close() end
			setOpen(true)
			openDrop = dd
		end
	end)

	if multi then
		setValue(type(default) == "table" and default or {}, false)
	else
		setValue(default or names[1], false)
		if single == nil and names[1] then
			single = names[1]
			render()
		end
	end

	self:_reg(label, getValue, function(v) setValue(v, true) end)
	return { Set = function(_, v) setValue(v, false) end, Get = function() return getValue() end }
end

-- confirm = true: the first click asks "Click again to confirm" (for dangerous buttons)
function Section:Button(label, cb, confirm)
	local row = self:_row(34)
	self:_index(label)
	local b = new("TextButton", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.new(1, -20, 0, 24), BorderSizePixel = 1, AutoButtonColor = false, Text = label, Font = FONT, TextSize = 12 }, row)
	bind(b, "BackgroundColor3", "hd") bind(b, "BorderColor3", "bd") bind(b, "TextColor3", "ti")
	b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = Theme.bd }, 0.1) end)
	b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = Theme.hd }, 0.15) end)
	b.MouseButton1Down:Connect(function() tw(b, { BackgroundColor3 = Theme.ac }, 0.06) end)
	b.MouseButton1Up:Connect(function() tw(b, { BackgroundColor3 = Theme.bd }, 0.18) end)
	local armed, tok = false, 0
	b.MouseButton1Click:Connect(function()
		tok = tok + 1
		if confirm and not armed then
			armed = true
			local mine = tok
			b.Text = "Click again to confirm"
			task.delay(2.5, function()
				if tok == mine and armed then
					armed = false
					b.Text = label
				end
			end)
			return
		end
		armed = false
		b.Text = label
		if cb then task.spawn(cb) end
	end)
end

-- list of the saved configs (select one, then use Load / Overwrite / Delete buttons)
function Section:ConfigBrowser(height)
	local win = self.tab.win
	local row = self:_row(height + 10)
	local api = buildConfigList(win, row, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, height) })
	win.cfgBrowser = api
	api.refresh()
	return api
end

function Section:Textbox(label, default, placeholder, cb)
	local row = self:_row(30)
	self:_index(label)
	text(row, label, "tx", { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -140, 1, 0) })
	local box = new("TextBox", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 22), BorderSizePixel = 1, Font = FONT, TextSize = 12, ClearTextOnFocus = false, Text = default or "", PlaceholderText = placeholder or "" }, row)
	bind(box, "BackgroundColor3", "hd") bind(box, "BorderColor3", "bd") bind(box, "TextColor3", "ti") bind(box, "PlaceholderColor3", "lb")
	focusFx(box)
	box.FocusLost:Connect(function(enter)
		if enter and cb then task.spawn(cb, box.Text) end
	end)
	self:_reg(label, function() return box.Text end, function(v)
		box.Text = tostring(v)
		if cb then task.spawn(cb, box.Text) end
	end)
	return { Set = function(_, v) box.Text = v end, Get = function() return box.Text end }
end

-- Keybind: left click = rebind, right click = cycle mode (Press / Toggle / Hold)
-- Escape or Backspace while binding clears the key.
function Section:Keybind(label, default, cb, mode, changed)
	local row = self:_row(30)
	local kb = { key = default, mode = mode or "Press", state = false }
	self:_index(label)
	text(row, label, "tx", { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -170, 1, 0) })
	local modeLbl = text(row, kb.mode, "lb", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -100, 0, 0), Size = UDim2.fromOffset(52, 30), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right })
	local box = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(84, 22), BorderSizePixel = 1, AutoButtonColor = false, Font = FONT, TextSize = 12, Text = keyName(default) }, row)
	bind(box, "BackgroundColor3", "hd") bind(box, "BorderColor3", "bd") bind(box, "TextColor3", "ti")
	box.MouseEnter:Connect(function() if not listening then tw(box, { BackgroundColor3 = Theme.st }, 0.12) end end)
	box.MouseLeave:Connect(function() if not listening then tw(box, { BackgroundColor3 = Theme.hd }, 0.15) end end)

	function kb.press()
		if kb.mode == "Toggle" then
			kb.state = not kb.state
			if cb then task.spawn(cb, kb.state) end
		elseif kb.mode == "Hold" then
			kb.state = true
			if cb then task.spawn(cb, true) end
		else
			if cb then task.spawn(cb, true) end
		end
	end
	function kb.release()
		if kb.mode == "Hold" and kb.state then
			kb.state = false
			if cb then task.spawn(cb, false) end
		end
	end

	box.MouseButton1Click:Connect(function()
		box.Text = "..."
		tw(box, { BackgroundColor3 = Theme.bd, BorderColor3 = Theme.ac }, 0.12)
		listening = function(key)
			if key == Enum.KeyCode.Escape or key == Enum.KeyCode.Backspace then key = nil end
			kb.key = key
			if changed then
				local replace = changed(key)
				if replace then kb.key = replace end
			end
			box.Text = keyName(kb.key)
			tw(box, { BackgroundColor3 = Theme.hd, BorderColor3 = Theme.bd }, 0.18)
		end
	end)
	box.MouseButton2Click:Connect(function()
		local idx = table.find(MODES, kb.mode) or 1
		kb.mode = MODES[idx % #MODES + 1]
		kb.state = false
		modeLbl.Text = kb.mode
		-- little flash so the mode change is noticeable
		modeLbl.TextColor3 = Theme.ac
		tw(modeLbl, { TextColor3 = Theme.lb }, 0.4)
	end)

	table.insert(keybinds, kb)
	self:_reg(label, function()
		return { key = kb.key and kb.key.Name or "", mode = kb.mode }
	end, function(v)
		if type(v) ~= "table" then return end
		if v.key == nil or v.key == "" then
			kb.key = nil
		else
			local ok, k = pcall(function() return Enum.KeyCode[v.key] end)
			if ok and k then kb.key = k end
		end
		if table.find(MODES, v.mode) then
			kb.mode = v.mode
			modeLbl.Text = v.mode
		end
		kb.state = false
		box.Text = keyName(kb.key)
	end)
	return {
		Set = function(_, key) kb.key = key box.Text = keyName(key) end,
		Get = function() return kb.key end,
	}
end

-- Color picker (SV square + hue slider + HEX + RGB / CMYK / HSV / HSL)
function Section:ColorPicker(label, default, cb)
	local row = self:_row(290)
	self:_index(label)
	local tabWin = self.tab.win
	text(row, label, "ti", { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -20, 0, 22), Font = FONT_BOLD, TextSize = 12 })

	local h, s, v = default:ToHSV()
	local color = default

	-- preview swatch + SV square
	local area = new("Frame", { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 120), BackgroundTransparency = 1 }, row)
	local swatch = new("Frame", { Size = UDim2.new(0.28, -4, 1, 0), BorderSizePixel = 1 }, area)
	bind(swatch, "BorderColor3", "bd")
	local sv = new("Frame", { Position = UDim2.fromScale(0.28, 0), Size = UDim2.fromScale(0.72, 1), BorderSizePixel = 1 }, area)
	bind(sv, "BorderColor3", "bd")
	local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, sv)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, white)
	local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, sv)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, black)
	local cursor = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, BorderSizePixel = 0 }, sv)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, cursor)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, cursor)
	local svHit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, sv)

	-- hue slider
	local hue = new("Frame", { Position = UDim2.fromOffset(10, 154), Size = UDim2.new(1, -20, 0, 10), BorderSizePixel = 0 }, row)
	new("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
		ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)), ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
		ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)), ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
	}) }, hue)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, hue)
	local hueKnob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0 }, hue)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, hueKnob)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, hueKnob)
	local hueHit = new("TextButton", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "" }, hue)

	-- HEX row
	local hexFrame = new("Frame", { Position = UDim2.fromOffset(10, 176), Size = UDim2.new(1, -20, 0, 28), BorderSizePixel = 1 }, row)
	bind(hexFrame, "BackgroundColor3", "hd") bind(hexFrame, "BorderColor3", "bd")
	text(hexFrame, "HEX", "lb", { Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(30, 28), TextSize = 10 })
	local hexBox = new("TextBox", { Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -96, 1, 0), BackgroundTransparency = 1, Font = FONT, TextSize = 12, ClearTextOnFocus = false, Text = "" }, hexFrame)
	bind(hexBox, "TextColor3", "ti")
	focusFx(hexBox, hexFrame)
	local copy = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(46, 20), BorderSizePixel = 1, AutoButtonColor = false, Text = "Copy", Font = FONT, TextSize = 11 }, hexFrame)
	bind(copy, "BackgroundColor3", "pn") bind(copy, "BorderColor3", "bd") bind(copy, "TextColor3", "tx")
	copy.MouseEnter:Connect(function() tw(copy, { BackgroundColor3 = Theme.hd }, 0.1) end)
	copy.MouseLeave:Connect(function() tw(copy, { BackgroundColor3 = Theme.pn }, 0.15) end)

	-- RGB / CMYK / HSV / HSL
	local infoLabels = {}
	local defs = { { "rgb", "RGB", 0, 0 }, { "cmyk", "CMYK", 1, 0 }, { "hsv", "HSV", 0, 1 }, { "hsl", "HSL", 1, 1 } }
	for _, d in ipairs(defs) do
		local box = new("Frame", { Position = UDim2.new(d[3] * 0.5, 10 + d[3] * 3, 0, 212 + d[4] * 38), Size = UDim2.new(0.5, -13, 0, 34), BorderSizePixel = 1 }, row)
		bind(box, "BackgroundColor3", "pn") bind(box, "BorderColor3", "bd")
		text(box, d[2], "lb", { Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 14), TextSize = 10 })
		infoLabels[d[1]] = text(box, "", "ti", { Position = UDim2.fromOffset(8, 16), Size = UDim2.new(1, -16, 0, 16), TextSize = 11 })
	end

	local function apply(fire)
		color = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		swatch.BackgroundColor3 = color
		cursor.Position = UDim2.fromScale(s, 1 - v)
		hueKnob.Position = UDim2.fromScale(h, 0.5)
		hueKnob.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		hexBox.Text = "#" .. color:ToHex():upper()
		local info = describeColor(color)
		for k, lbl in pairs(infoLabels) do lbl.Text = info[k] end
		if fire and cb then task.spawn(cb, color) end
	end
	apply(false)

	local function svInput(i)
		s = math.clamp((i.Position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - math.clamp((i.Position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		apply(true)
	end
	local function hueInput(i)
		h = math.clamp((i.Position.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 0.999)
		apply(true)
	end
	-- the cursors grow a little while they are dragged
	svHit.InputBegan:Connect(function(i)
		if isPress(i) then
			svInput(i)
			dragFn = svInput
			tw(cursor, { Size = UDim2.fromOffset(16, 16) }, 0.12, Enum.EasingStyle.Back)
			dragEnd = function() tw(cursor, { Size = UDim2.fromOffset(12, 12) }, 0.15) end
		end
	end)
	hueHit.InputBegan:Connect(function(i)
		if isPress(i) then
			hueInput(i)
			dragFn = hueInput
			tw(hueKnob, { Size = UDim2.fromOffset(18, 18) }, 0.12, Enum.EasingStyle.Back)
			dragEnd = function() tw(hueKnob, { Size = UDim2.fromOffset(14, 14) }, 0.15) end
		end
	end)
	hexBox.FocusLost:Connect(function()
		local ok, c = pcall(Color3.fromHex, hexBox.Text)
		if ok and c then
			h, s, v = c:ToHSV()
		end
		apply(ok)
	end)
	copy.MouseButton1Click:Connect(function()
		local clip = setclipboard or toclipboard
		if clip then
			pcall(clip, "#" .. color:ToHex():upper())
			tabWin:Notify("Color picker", "Copied #" .. color:ToHex():upper(), 2, "success")
		else
			tabWin:Notify("Color picker", "Clipboard is not supported here.", 2, "warning")
		end
	end)

	self:_reg(label, function() return color:ToHex() end, function(hex)
		local ok, c = pcall(Color3.fromHex, tostring(hex))
		if ok and c then
			h, s, v = c:ToHSV()
			apply(true)
		end
	end)
	return {
		Set = function(_, c) h, s, v = c:ToHSV() apply(false) end,
		Get = function() return color end,
	}
end

-- TAB ---------------------------------------------------------
function Tab:Section(title, side)
	local col = (side == "right") and self.Right or self.Left
	local card = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 1, LayoutOrder = #col:GetChildren() }, col)
	bind(card, "BackgroundColor3", "pn") bind(card, "BorderColor3", "bd")
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, card)
	-- the header is a button: click it to collapse / expand the section
	local header = new("TextButton", { Size = UDim2.new(1, 0, 0, 22), BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = 0 }, card)
	bind(header, "BackgroundColor3", "hd")
	header.MouseEnter:Connect(function() tw(header, { BackgroundColor3 = Theme.st }, 0.12) end)
	header.MouseLeave:Connect(function() tw(header, { BackgroundColor3 = Theme.hd }, 0.18) end)
	text(header, string.upper(title), "lb", { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -34, 1, 0), TextSize = 10, Font = FONT_BOLD })
	local arrow = text(header, "v", "lb", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(14, 22), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center })
	new("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 1, LayoutOrder = 1 }, card)
	-- all the rows live inside this body, so the whole section can slide open / closed
	local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = 2 }, card)
	local bodyLayout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, body)
	local sec = setmetatable({ card = card, body = body, bodyLayout = bodyLayout, _n = 1, tab = self, title = title, rows = {}, noSave = self.noSave, arrow = arrow, collapsed = false }, Section)
	header.MouseButton1Click:Connect(function() sec:SetCollapsed(not sec.collapsed) end)
	return sec
end

-- PAGE --------------------------------------------------------
function Page:Tab(name)
	local win = self.win
	local tab = setmetatable({ win = win, page = self, name = name, noSave = self.noSave }, Tab)

	tab.btn = new("TextButton", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BorderSizePixel = 0, AutoButtonColor = false, Text = name, Font = FONT, TextSize = 12, LayoutOrder = #self.tabs + 1 }, self.tabBar)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, tab.btn)
	tab.line = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(0, 0, 0, 2), BorderSizePixel = 0 }, tab.btn)

	tab.scroll = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false }, win.content)
	bind(tab.scroll, "ScrollBarImageColor3", "bd")
	tab.holder = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, tab.scroll)
	new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, tab.holder)
	tab.layout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12), FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Top }, tab.holder)
	for idx, key in ipairs({ "Left", "Right" }) do
		local col = new("Frame", { Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = idx }, tab.holder)
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }, col)
		tab[key] = col
	end

	tab.btn.MouseEnter:Connect(function()
		if self.activeTab ~= tab then tw(tab.btn, { TextColor3 = Theme.ti }, 0.12) end
	end)
	tab.btn.MouseLeave:Connect(function()
		if self.activeTab ~= tab then tw(tab.btn, { TextColor3 = Theme.tx }, 0.15) end
	end)
	tab.btn.MouseButton1Click:Connect(function()
		self.activeTab = tab
		win:_refresh()
	end)
	table.insert(self.tabs, tab)
	table.insert(win.allTabs, tab)
	if not self.activeTab then self.activeTab = tab end
	win:_applyColumns()
	win:_refresh()
	return tab
end

-- WINDOW ------------------------------------------------------
function Window:_refresh()
	for _, page in ipairs(self.pages) do
		local on = page == self.activePage
		page.tabBar.Visible = on
		tw(page.btn, { BackgroundColor3 = on and Theme.hd or Theme.pn, TextColor3 = on and Theme.ti or Theme.tx }, 0.15)
		-- accent bar of the selected page grows / shrinks
		tw(page.bar, { Size = UDim2.fromOffset(3, on and 20 or 0) }, 0.24, Enum.EasingStyle.Quint)
		for _, tab in ipairs(page.tabs) do
			local sel = page.activeTab == tab
			tab.scroll.Visible = on and sel
			tab.line.BackgroundColor3 = Theme.ac
			tab.btn.BackgroundColor3 = Theme.pn
			tw(tab.line, { Size = UDim2.new(sel and 1 or 0, 0, 0, 2) }, 0.2, Enum.EasingStyle.Quint)
			tw(tab.btn, { TextColor3 = sel and Theme.ti or Theme.tx }, 0.15)
		end
	end
	-- slide-in animation when the visible tab changes (position only, no relayout)
	local cur = self.activePage and self.activePage.activeTab
	if cur and cur ~= self._cur then
		self._cur = cur
		cur.scroll.Position = UDim2.fromOffset(0, 16)
		tw(cur.scroll, { Position = UDim2.new() }, 0.3, Enum.EasingStyle.Quint)
	end
end

function Window:_applyColumns()
	local m = self.mode == "Mobile" or (self.W - CONFIG[self.mode].Side) < 480
	for _, tab in ipairs(self.allTabs) do
		tab.layout.FillDirection = m and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
		tab.Left.Size = m and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -6, 0, 0)
		tab.Right.Size = tab.Left.Size
	end
end

function Window:_applyMode()
	local m = CONFIG[self.mode]
	local sz = self.sizes[self.mode]
	self.W, self.H = sz[1], sz[2]
	self.win.Size = UDim2.fromOffset(self.W, self.H)
	self.side.Size = UDim2.new(0, m.Side, 1, 0)
	self.main.Position = UDim2.new(0, m.Side, 0, 0)
	self.main.Size = UDim2.new(1, -m.Side, 1, 0)
	local mobile = self.mode == "Mobile"
	self.userText.Visible = not mobile
	for _, p in ipairs(self.pages) do p.btn.TextSize = mobile and 11 or 13 end
	for _, l in ipairs(self.navLabels) do l.TextSize = mobile and 9 or 10 end
	self:_applyColumns()
end

-- noSave = true: the elements of this page are NOT stored in configs (used for the Settings page)
function Window:Page(name, category, noSave)
	if category and category ~= self._cat then
		if self._cat then
			local sep = new("Frame", { Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, LayoutOrder = self._order }, self.nav)
			bind(sep, "BackgroundColor3", "bd")
			self._order = self._order + 1
		end
		local l = text(self.nav, category, "lb", { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = self._order, TextSize = 10, Font = FONT_BOLD })
		new("UIPadding", { PaddingLeft = UDim.new(0, 14) }, l)
		table.insert(self.navLabels, l)
		self._order = self._order + 1
		self._cat = category
	end
	local page = setmetatable({ win = self, name = name, tabs = {}, noSave = noSave }, Page)
	page.btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, AutoButtonColor = false, Text = name, Font = FONT, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = self._order }, self.nav)
	new("UIPadding", { PaddingLeft = UDim.new(0, 14) }, page.btn)
	-- selected indicator (the button has 14px padding, so x = -14 is the real left edge)
	page.bar = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -14, 0.5, 0), Size = UDim2.fromOffset(3, 0), BorderSizePixel = 0 }, page.btn)
	bind(page.bar, "BackgroundColor3", "ac")
	self._order = self._order + 1
	page.tabBar = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BorderSizePixel = 0, Visible = false }, self.main)
	bind(page.tabBar, "BackgroundColor3", "pn")
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, page.tabBar)
	page.btn.MouseEnter:Connect(function()
		if self.activePage ~= page then tw(page.btn, { BackgroundColor3 = Theme.hd }, 0.12) end
	end)
	page.btn.MouseLeave:Connect(function()
		if self.activePage ~= page then tw(page.btn, { BackgroundColor3 = Theme.pn }, 0.15) end
	end)
	page.btn.MouseButton1Click:Connect(function()
		self.activePage = page
		self:_refresh()
	end)
	table.insert(self.pages, page)
	if not self.activePage then self.activePage = page end
	self:_applyMode()
	self:_refresh()
	return page
end

function Window:_save()
	local p = self._basePos or self.win.Position
	writeConfig({
		preset = self.preset, mode = self.mode, size = self.sizes,
		accent = self.accent and self.accent:ToHex() or nil,
		menuKey = self.menuKey and self.menuKey.Name or nil,
		animations = State.Animations,
		pos = { p.X.Offset, p.Y.Offset },
	})
end

function Window:_saveSoon()
	self._saveTok = (self._saveTok or 0) + 1
	local tok = self._saveTok
	task.delay(0.6, function()
		if tok == self._saveTok then self:_save() end
	end)
end

function Window:SetPreset(name)
	if not PRESETS[name] then return end
	self.preset = name
	self.accent = nil
	applyColors(name)
	local p = PRESETS[name]
	setDecal(self.logo, p.logo)
	setDecal(self.deco, p.deco)
	setDecal(self.miniDecal, p.logo)
	-- the decals pop in when the preset changes
	if State.Animations and self.win.Visible then
		for _, d in ipairs({ self.logo, self.deco, self.miniDecal }) do
			local full = d.base or d.img.Size
			d.base = full
			d.img.Size = UDim2.fromOffset(full.X.Offset * 0.55, full.Y.Offset * 0.55)
			tw(d.img, { Size = full }, 0.45, Enum.EasingStyle.Back)
		end
	end
	if self.onPreset then self.onPreset(name, Theme.ac) end
	self:_saveSoon()
end

function Window:SetAccent(color)
	self.accent = color
	applyAccent(color)
	self:_saveSoon()
end

function Window:GetAccent()
	return Theme.ac
end

function Window:SetMode(mode)
	if mode ~= "PC" and mode ~= "Mobile" then return end
	local ow, oh = self.W, self.H
	self.mode = mode
	self:_applyMode()
	-- the window glides to its new size
	if State.Animations and self.win.Visible and (ow ~= self.W or oh ~= self.H) then
		local nw, nh = self.W, self.H
		if self._sizeAnim then self._sizeAnim() end
		self.win.Size = UDim2.fromOffset(ow, oh)
		self._sizeAnim = animate(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, function(a)
			self.win.Size = UDim2.fromOffset(ow + (nw - ow) * a, oh + (nh - oh) * a)
		end, function()
			self._sizeAnim = nil
			self.win.Size = UDim2.fromOffset(self.W, self.H)
		end)
	end
	self:_saveSoon()
end

-- Free resize: width and height are independent
function Window:SetSize(w, h)
	if self._sizeAnim then
		self._sizeAnim()
		self._sizeAnim = nil
	end
	local m = CONFIG[self.mode]
	local vp = Camera.ViewportSize
	w = math.clamp(w, m.MinW, math.max(m.MinW, vp.X - 20))
	h = math.clamp(h, m.MinH, math.max(m.MinH, vp.Y - 20))
	self.W, self.H = w, h
	self.sizes[self.mode] = { w, h }
	self.win.Size = UDim2.fromOffset(w, h)
	self:_applyColumns()
	if self.onSize then self.onSize(w, h) end
end

function Window:ResetSize()
	local m = CONFIG[self.mode]
	local ow, oh = self.W, self.H
	self:SetSize(m.W, m.H)
	-- animate back to the default size
	if State.Animations and self.win.Visible and (ow ~= self.W or oh ~= self.H) then
		local nw, nh = self.W, self.H
		self.win.Size = UDim2.fromOffset(ow, oh)
		self._sizeAnim = animate(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, function(a)
			self.win.Size = UDim2.fromOffset(ow + (nw - ow) * a, oh + (nh - oh) * a)
		end, function()
			self._sizeAnim = nil
			self.win.Size = UDim2.fromOffset(self.W, self.H)
		end)
	end
	self:_saveSoon()
end

function Window:GetAnimations()
	return State.Animations
end

function Window:SetAnimations(on)
	State.Animations = on and true or false
	for _, f in ipairs(self.floaters or {}) do
		if State.Animations then f.play() else f.stop() end
	end
	starAnim(State.Animations)
	self:_saveSoon()
end

-- Show / hide: the window scales + slides a little (centered), no heavy relayout.
local SHOW_SCALE = 0.93

function Window:_stopWinAnim()
	if self._winAnim then
		self._winAnim()
		self._winAnim = nil
	end
end

function Window:Show()
	if not self.hidden then return end
	self.hidden = false
	self._tok = (self._tok or 0) + 1
	local tok = self._tok
	self:_stopWinAnim()
	local win, scale = self.win, self.scale
	local base = self._basePos or win.Position
	-- the mini button (mobile) pops away
	if self.mini.Visible then
		tw(self.miniScale, { Scale = 0 }, 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.15, function()
			if tok == self._tok and not self.hidden then self.mini.Visible = false end
		end)
	end
	win.Visible = true
	if State.Animations then
		self._basePos = base
		self._winAnim = animate(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, function(a)
			local s = SHOW_SCALE + (1 - SHOW_SCALE) * a
			scale.Scale = s
			win.Position = base + UDim2.fromOffset(self.W * (1 - s) / 2, self.H * (1 - s) / 2 + 14 * (1 - a))
		end, function()
			scale.Scale = 1
			win.Position = base
			self._basePos = nil
			self._winAnim = nil
		end)
	else
		scale.Scale = 1
		win.Position = base
		self._basePos = nil
	end
end

-- PC: hides everything (use the menu key to show again)
-- Mobile: shows the small draggable square button (it pops in)
function Window:Hide()
	if self.hidden then return end
	self.hidden = true
	self._tok = (self._tok or 0) + 1
	local tok = self._tok
	self:_stopWinAnim()
	local win, scale = self.win, self.scale
	local base = self._basePos or win.Position
	self._basePos = base
	if self.mode == "Mobile" then
		self.mini.Visible = true
		self.miniScale.Scale = 0
		tw(self.miniScale, { Scale = 1 }, 0.38, Enum.EasingStyle.Back)
	else
		self.mini.Visible = false
	end
	local function finish()
		if tok == self._tok and self.hidden then
			win.Visible = false
			scale.Scale = 1
			win.Position = base
			self._basePos = nil
			self._winAnim = nil
		end
	end
	if State.Animations then
		local s0 = scale.Scale
		self._winAnim = animate(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In, function(a)
			local s = s0 - (s0 - SHOW_SCALE) * a
			scale.Scale = s
			win.Position = base + UDim2.fromOffset(self.W * (1 - s) / 2, self.H * (1 - s) / 2 + 10 * a)
		end, finish)
	else
		finish()
	end
end

function Window:Toggle()
	if self.hidden then self:Show() else self:Hide() end
end

local TOAST_COLORS = {
	success = Color3.fromRGB(92, 196, 110),
	warning = Color3.fromRGB(232, 184, 74),
	error = Color3.fromRGB(232, 106, 106),
}

-- kind: nil / "info" (accent color), "success", "warning", "error". Max 5 toasts at once.
function Window:Notify(title, message, duration, kind)
	duration = duration or 3
	self._toastList = self._toastList or {}
	while #self._toastList >= 5 do
		local old = table.remove(self._toastList, 1)
		pcall(old.kill)
	end

	local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1 }, self.toasts)
	local card = new("Frame", { Position = UDim2.new(1.15, 0, 0, 0), Size = UDim2.fromScale(1, 1), BorderSizePixel = 1, BackgroundTransparency = 1 }, wrap)
	bind(card, "BackgroundColor3", "pn") bind(card, "BorderColor3", "bd")
	local bar = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 3, 0, 0), BorderSizePixel = 0 }, card)
	local t1 = text(card, title, "ti", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -20, 0, 16), Font = FONT_BOLD, TextSize = 12, TextTransparency = 1 })
	local t2 = text(card, message, "tx", { Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -20, 0, 24), TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTransparency = 1 })
	local timer = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0 }, card)
	local col = TOAST_COLORS[kind]
	if col then
		bar.BackgroundColor3 = col
		timer.BackgroundColor3 = col
	else
		bind(bar, "BackgroundColor3", "ac")
		bind(timer, "BackgroundColor3", "ac")
	end

	local entry = {}
	entry.kill = function() if wrap.Parent then wrap:Destroy() end end
	table.insert(self._toastList, entry)

	-- in: slide with a small overshoot + fade, accent bar grows, text fades in
	tw(card, { Position = UDim2.new() }, 0.4, Enum.EasingStyle.Back)
	tw(card, { BackgroundTransparency = 0 }, 0.2)
	tw(bar, { Size = UDim2.new(0, 3, 1, 0) }, 0.35, Enum.EasingStyle.Quint)
	tw(t1, { TextTransparency = 0 }, 0.3)
	tw(t2, { TextTransparency = 0 }, 0.4)
	-- countdown line shrinks while the toast is visible
	if State.Animations then
		TweenService:Create(timer, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
	else
		timer.Visible = false
	end

	task.delay(duration, function()
		local i = table.find(self._toastList, entry)
		if i then table.remove(self._toastList, i) end
		if not wrap.Parent then return end
		-- out: slide + fade, then the stack closes the gap smoothly
		tw(card, { Position = UDim2.new(1.15, 0, 0, 0) }, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tw(card, { BackgroundTransparency = 1 }, 0.25)
		tw(t1, { TextTransparency = 1 }, 0.2)
		tw(t2, { TextTransparency = 1 }, 0.2)
		tw(bar, { Size = UDim2.new(0, 3, 0, 0) }, 0.2)
		timer.Visible = false
		task.delay(0.28, function()
			if wrap.Parent then
				tw(wrap, { Size = UDim2.new(1, 0, 0, 0) }, 0.2, Enum.EasingStyle.Quint)
				task.delay(0.22, function() if wrap.Parent then wrap:Destroy() end end)
			end
		end)
	end)
end

-- keeps at least part of the window (and the header) on screen
function Window:_clampPos(x, y)
	local vp = Camera.ViewportSize
	x = math.clamp(x, -(self.W - 120), math.max(0, vp.X - 120))
	y = math.clamp(y, 0, math.max(0, vp.Y - 48))
	return x, y
end

-- SEARCH ------------------------------------------------------
function Window:_search(q)
	q = tostring(q or ""):lower():gsub("^%s+", "")
	for _, r in ipairs(self.resultRows) do r:Destroy() end
	self.resultRows = {}
	if q == "" then
		self.results.Visible = false
		return
	end
	-- the results panel slides up when it appears
	if not self.results.Visible then
		self.results.Visible = true
		self.results.Position = UDim2.fromOffset(0, 40)
		tw(self.results, { Position = UDim2.fromOffset(0, 28) }, 0.25, Enum.EasingStyle.Quint)
	end
	local n = 0
	for _, e in ipairs(self.index) do
		if n >= 40 then break end
		if (e.label .. " " .. e.section):lower():find(q, 1, true) then
			n = n + 1
			local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 38), BorderSizePixel = 1, AutoButtonColor = false, Text = "", LayoutOrder = n, ZIndex = 7 }, self.results)
			bind(b, "BackgroundColor3", "pn") bind(b, "BorderColor3", "bd")
			text(b, e.label, "ti", { Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -20, 0, 16), TextSize = 12 })
			text(b, e.page.name .. " > " .. e.tab.name .. " > " .. e.section, "lb", { Position = UDim2.fromOffset(10, 21), Size = UDim2.new(1, -20, 0, 14), TextSize = 10 })
			b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = Theme.hd }, 0.1) end)
			b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = Theme.pn }, 0.15) end)
			b.MouseButton1Click:Connect(function() self:_goto(e) end)
			table.insert(self.resultRows, b)
		end
	end
	if n == 0 then
		table.insert(self.resultRows, text(self.results, "No results", "lb", { Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12 }))
	end
end

function Window:_goto(e)
	self.search.Text = ""
	if e.sectionObj and e.sectionObj.collapsed then e.sectionObj:SetCollapsed(false, true) end
	self.activePage = e.page
	e.page.activeTab = e.tab
	self:_refresh()
end

-- CONFIGS -----------------------------------------------------
-- A config stores everything the UI shows: the window settings (preset, accent, mode, size,
-- position, animations, menu key) + the value of every element that is not on a noSave page.
-- Manage them inside the UI: Settings > configs.
function Window:_collectUI()
	local p = self._basePos or self.win.Position
	return {
		preset = self.preset, mode = self.mode, sizes = self.sizes,
		accent = self.accent and self.accent:ToHex() or nil,
		menuKey = self.menuKey and self.menuKey.Name or nil,
		animations = State.Animations,
		pos = { p.X.Offset, p.Y.Offset },
	}
end

function Window:_collectFlags()
	local out = {}
	for _, e in ipairs(self.flagList) do
		local ok, v = pcall(e.get)
		if ok and v ~= nil then out[e.id] = v end
	end
	return out
end

function Window:_applyUI(ui)
	if type(ui.sizes) == "table" then
		for _, k in ipairs({ "PC", "Mobile" }) do
			local v = ui.sizes[k]
			if type(v) == "table" and tonumber(v[1]) and tonumber(v[2]) then
				self.sizes[k] = { math.max(CONFIG[k].MinW, tonumber(v[1])), math.max(CONFIG[k].MinH, tonumber(v[2])) }
			end
		end
	end
	if ui.mode == "PC" or ui.mode == "Mobile" then self:SetMode(ui.mode) end
	local sz = self.sizes[self.mode]
	self:SetSize(sz[1], sz[2])
	if type(ui.preset) == "string" and PRESETS[ui.preset] then self:SetPreset(ui.preset) end
	if type(ui.accent) == "string" then
		local ok, c = pcall(Color3.fromHex, ui.accent)
		if ok and c then
			self:SetAccent(c)
			if self.onPreset then self.onPreset(self.preset, c) end
		end
	end
	if type(ui.animations) == "boolean" then self:SetAnimations(ui.animations) end
	if type(ui.menuKey) == "string" then
		local ok, k = pcall(function() return Enum.KeyCode[ui.menuKey] end)
		if ok and k then self.menuKey = k end
	end
	if type(ui.pos) == "table" and tonumber(ui.pos[1]) and tonumber(ui.pos[2]) then
		local x, y = self:_clampPos(tonumber(ui.pos[1]), tonumber(ui.pos[2]))
		local p = UDim2.fromOffset(x, y)
		if self._basePos then
			self._basePos = p
		else
			-- glide to the saved position
			local from = self.win.Position
			if State.Animations and self.win.Visible then
				tw(self.win, { Position = p }, 0.35, Enum.EasingStyle.Quint)
			else
				self.win.Position = p
			end
		end
	end
	if self.onUIApplied then self.onUIApplied() end
end

function Window:RefreshConfigs()
	for _, b in ipairs(self.browsers) do b.refresh() end
end

function Window:SaveConfig(name)
	name = cleanName(name)
	if name == "" then
		self:Notify("Configs", "Type a valid name first.", 3, "warning")
		return false
	end
	if not (writefile and ensureFolders()) then
		self:Notify("Configs", "Your executor can't write files.", 3, "error")
		return false
	end
	local data = { version = 1, name = name, savedAt = os.time(), ui = self:_collectUI(), flags = self:_collectFlags() }
	local ok = pcall(function() writefile(cfgPath(name), HttpService:JSONEncode(data)) end)
	if ok then
		self:Notify("Configs", "Saved '" .. name .. "'", 2.5, "success")
		self:RefreshConfigs()
	else
		self:Notify("Configs", "Could not save '" .. name .. "'", 3, "error")
	end
	return ok
end

function Window:LoadConfig(name)
	name = tostring(name or "")
	local path = cfgPath(name)
	local okRead, raw = pcall(function()
		if not (isfile and isfile(path)) then error("missing") end
		return readfile(path)
	end)
	if not okRead then
		self:Notify("Configs", "Can't find '" .. name .. "'. Try Refresh.", 3, "error")
		return false
	end
	local okJson, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not okJson or type(data) ~= "table" then
		self:Notify("Configs", "'" .. name .. "' is not a valid config.", 3, "error")
		return false
	end
	if type(data.ui) == "table" then pcall(function() self:_applyUI(data.ui) end) end
	local applied = 0
	if type(data.flags) == "table" then
		for _, e in ipairs(self.flagList) do
			local v = data.flags[e.id]
			if v ~= nil and pcall(e.set, v) then applied = applied + 1 end
		end
	end
	self:Notify("Configs", "Loaded '" .. name .. "' (" .. applied .. " values)", 3, "success")
	return true
end

function Window:DeleteConfig(name)
	if not delfile then
		self:Notify("Configs", "Your executor has no delfile.", 3, "warning")
		return false
	end
	local ok = pcall(delfile, cfgPath(name))
	if ok then
		self:Notify("Configs", "Deleted '" .. name .. "'", 2.5, "success")
		self:RefreshConfigs()
	else
		self:Notify("Configs", "Could not delete '" .. name .. "'", 3, "error")
	end
	return ok
end

function Window:Destroy()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	table.clear(keybinds)
	ActiveWindow = nil
	self.gui:Destroy()
end

----------------------------------------------------------------
-- BUILD WINDOW
----------------------------------------------------------------
local function buildWindow(cfg)
	local self = setmetatable({
		pages = {}, allTabs = {}, navLabels = {}, _order = 1, mode = cfg.mode or "PC", preset = cfg.preset or "Blue", hidden = true,
		flagList = {}, flagIds = {}, index = {}, browsers = {}, resultRows = {}, floaters = {},
	}, Window)
	if not PRESETS[self.preset] then self.preset = "Blue" end
	if self.mode ~= "PC" and self.mode ~= "Mobile" then self.mode = "PC" end
	self.menuKey = CONFIG.MenuKey
	if cfg.menuKey then
		local ok, k = pcall(function() return Enum.KeyCode[cfg.menuKey] end)
		if ok and k then self.menuKey = k end
	end
	if cfg.animations ~= nil then State.Animations = cfg.animations end
	if cfg.accent then
		local ok, c = pcall(Color3.fromHex, cfg.accent)
		if ok then self.accent = c end
	end

	self.gui = new("ScreenGui", { Name = "BumpUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	mount(self.gui)
	applyColors(self.preset, self.accent)

	local m = CONFIG[self.mode]
	self.sizes = { PC = { CONFIG.PC.W, CONFIG.PC.H }, Mobile = { CONFIG.Mobile.W, CONFIG.Mobile.H } }
	if type(cfg.size) == "table" then
		for _, k in ipairs({ "PC", "Mobile" }) do
			local v = cfg.size[k]
			if type(v) == "table" and tonumber(v[1]) and tonumber(v[2]) then
				self.sizes[k] = { math.max(CONFIG[k].MinW, tonumber(v[1])), math.max(CONFIG[k].MinH, tonumber(v[2])) }
			end
		end
	end
	local sz = self.sizes[self.mode]
	self.W, self.H = sz[1], sz[2]
	local win = new("Frame", { Size = UDim2.fromOffset(sz[1], sz[2]), BorderSizePixel = 1, ClipsDescendants = true, Visible = false }, self.gui)
	bind(win, "BackgroundColor3", "bg") bind(win, "BorderColor3", "bd")
	self.win = win
	self.scale = new("UIScale", { Scale = 1 }, win)

	-- header
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 48), BorderSizePixel = 0 }, win)
	bind(top, "BackgroundColor3", "pn")
	local topLine = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0 }, top)
	bind(topLine, "BackgroundColor3", "bd")
	text(top, CONFIG.Title, "ti", { Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(60, 48), TextSize = 17, Font = FONT_BOLD })
	-- ICON 1: next to the title, centered vertically in the header (floats gently)
	self.logo = decal(top, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 80, 0.5, 0), Size = UDim2.fromOffset(38, 38) })
	text(top, os.date("%a, %b %d, %Y"), "tx", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -52, 0, 0), Size = UDim2.fromOffset(140, 48), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12 })
	local minBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(24, 24), BorderSizePixel = 1, AutoButtonColor = false, Text = "-", Font = FONT_BOLD, TextSize = 14 }, top)
	bind(minBtn, "BackgroundColor3", "hd") bind(minBtn, "BorderColor3", "bd") bind(minBtn, "TextColor3", "ti")
	minBtn.MouseEnter:Connect(function() tw(minBtn, { BackgroundColor3 = Theme.bd }, 0.1) end)
	minBtn.MouseLeave:Connect(function() tw(minBtn, { BackgroundColor3 = Theme.hd }, 0.15) end)
	minBtn.MouseButton1Down:Connect(function() tw(minBtn, { BackgroundColor3 = Theme.ac }, 0.06) end)

	-- subtitle bar
	local sub = new("Frame", { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0 }, win)
	bind(sub, "BackgroundColor3", "hd")
	starLayer(sub, STAR_SUB)
	local spaced = table.concat(string.split(CONFIG.Subtitle, ""), " ")
	text(sub, spaced, "ti", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11 })

	-- body
	local body = new("Frame", { Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 1, -88), BackgroundTransparency = 1 }, win)
	self.side = new("Frame", { Size = UDim2.new(0, m.Side, 1, 0), BorderSizePixel = 0 }, body)
	bind(self.side, "BackgroundColor3", "pn")
	starLayer(self.side, STAR_SIDE)
	local sideLine = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0), BorderSizePixel = 0 }, self.side)
	bind(sideLine, "BackgroundColor3", "bd")
	self.nav = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, -1, 1, -84), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, self.side)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, self.nav)
	new("UIPadding", { PaddingTop = UDim.new(0, 6) }, self.nav)

	-- search bar: finds any feature on any page
	self.search = new("TextBox", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -13, 0, 24), BorderSizePixel = 1, Font = FONT, TextSize = 11, ClearTextOnFocus = false, Text = "", PlaceholderText = "Search...", TextXAlignment = Enum.TextXAlignment.Left }, self.side)
	bind(self.search, "BackgroundColor3", "hd") bind(self.search, "BorderColor3", "bd") bind(self.search, "TextColor3", "ti") bind(self.search, "PlaceholderColor3", "lb")
	focusFx(self.search)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6) }, self.search)
	self.search:GetPropertyChangedSignal("Text"):Connect(function() self:_search(self.search.Text) end)

	-- user box
	local user = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, -1, 0, 48), BorderSizePixel = 0 }, self.side)
	bind(user, "BackgroundColor3", "pn")
	local uLine = new("Frame", { Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0 }, user)
	bind(uLine, "BackgroundColor3", "bd")
	local av = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(28, 28), BorderSizePixel = 1 }, user)
	bind(av, "BackgroundColor3", "hd") bind(av, "BorderColor3", "bd")
	text(av, string.lower(string.sub(LocalPlayer.Name, 1, 2)), "ti", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, Font = FONT_BOLD })
	self.userText = new("Frame", { Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1 }, user)
	text(self.userText, LocalPlayer.DisplayName, "ti", { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 16), TextSize = 10 })
	text(self.userText, "ID: " .. tostring(LocalPlayer.UserId), "lb", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 14), TextSize = 10 })

	-- main
	self.main = new("Frame", { Position = UDim2.new(0, m.Side, 0, 0), Size = UDim2.new(1, -m.Side, 1, 0), BackgroundTransparency = 1 }, body)
	starLayer(self.main, STAR_MAIN)
	self.content = new("Frame", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -42), BackgroundTransparency = 1, ClipsDescendants = true }, self.main)
	local tabLine = new("Frame", { Position = UDim2.fromOffset(0, 27), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, ZIndex = 2 }, self.main)
	bind(tabLine, "BackgroundColor3", "bd")
	local strip = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, -12, 0, 14), BorderSizePixel = 0, ZIndex = 2 }, self.main)
	bind(strip, "BackgroundColor3", "bd")
	-- ICON 2: bottom of the content area, a bit away from the resize handle (floats gently)
	self.deco = decal(self.main, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -90, 1, -8), Size = UDim2.fromOffset(38, 38), ZIndex = 3 })

	-- idle float of the two decals (a looping tween, stopped when animations are off)
	local function floater(inst, dy, t)
		local base = inst.Position
		local tween = TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = base + UDim2.fromOffset(0, dy) })
		return {
			play = function() tween:Play() end,
			stop = function()
				tween:Cancel()
				inst.Position = base
			end,
		}
	end
	table.insert(self.floaters, floater(self.logo.img, -3, 2.2))
	table.insert(self.floaters, floater(self.deco.img, -4, 2.6))
	if State.Animations then
		for _, f in ipairs(self.floaters) do f.play() end
	end

	-- search results (covers the content while the search bar has text)
	self.results = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -42), BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 6 }, self.main)
	bind(self.results, "BackgroundColor3", "bg") bind(self.results, "ScrollBarImageColor3", "bd")
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, self.results)
	new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, self.results)

	-- cute resize handle: drag to resize width AND height
	local grip = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -5, 1, -5), Size = UDim2.fromOffset(24, 24), BorderSizePixel = 0, Text = "", ZIndex = 10, AutoButtonColor = false }, win)
	new("UICorner", { CornerRadius = UDim.new(0.42, 0) }, grip)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, grip)
	bind(grip, "BackgroundColor3", "ac")
	local eyeColor = Color3.fromRGB(45, 50, 80)
	local eyes = {}
	for _, x in ipairs({ 8, 16 }) do
		local e = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, 9), Size = UDim2.fromOffset(3, 5), BackgroundColor3 = eyeColor, BorderSizePixel = 0 }, grip)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, e)
		table.insert(eyes, e)
	end
	for _, x in ipairs({ 5, 16 }) do -- blush
		local b = new("Frame", { Position = UDim2.fromOffset(x, 13), Size = UDim2.fromOffset(4, 3), BackgroundColor3 = Color3.fromRGB(255, 150, 175), BackgroundTransparency = 0.25, BorderSizePixel = 0 }, grip)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	end
	local mouth = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(12, 15), Size = UDim2.fromOffset(4, 3), BackgroundColor3 = eyeColor, BorderSizePixel = 0 }, grip)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, mouth)

	local gripBusy = false
	local function squint(on) -- eyes close (^ ^) while dragging
		for _, e in ipairs(eyes) do
			tw(e, { Size = on and UDim2.fromOffset(6, 2) or UDim2.fromOffset(3, 5) }, 0.1)
		end
		tw(mouth, { Size = on and UDim2.fromOffset(6, 4) or UDim2.fromOffset(4, 3) }, 0.1)
	end
	grip.MouseEnter:Connect(function() tw(grip, { Size = UDim2.fromOffset(28, 28), Rotation = -8 }, 0.2, Enum.EasingStyle.Back) end)
	grip.MouseLeave:Connect(function() tw(grip, { Size = UDim2.fromOffset(24, 24), Rotation = 0 }, 0.18) end)
	grip.InputBegan:Connect(function(i)
		if isPress(i) then
			local start, w0, h0 = i.Position, self.W, self.H
			gripBusy = true
			squint(true)
			dragEnd = function()
				gripBusy = false
				squint(false)
				self:_saveSoon()
			end
			dragFn = function(inp)
				local d = inp.Position - start
				self:SetSize(w0 + d.X, h0 + d.Y)
			end
		end
	end)

	-- the handle blinks from time to time
	task.spawn(function()
		while self.gui.Parent do
			task.wait(2.5 + math.random() * 2.5)
			if State.Animations and not gripBusy and win.Visible then
				for _, e in ipairs(eyes) do tw(e, { Size = UDim2.fromOffset(3, 1) }, 0.07) end
				task.wait(0.14)
				if not gripBusy then
					for _, e in ipairs(eyes) do tw(e, { Size = UDim2.fromOffset(3, 5) }, 0.1) end
				end
			end
		end
	end)

	-- drag window by header
	top.InputBegan:Connect(function(i)
		if isPress(i) then
			local start, startPos = i.Position, win.Position
			dragEnd = function() self:_saveSoon() end
			dragFn = function(inp)
				local d = inp.Position - start
				local x, y = self:_clampPos(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
				win.Position = UDim2.fromOffset(x, y)
			end
		end
	end)

	-- mini button (Mobile only, draggable). Anchored at its center so it pops from the middle.
	self.mini = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(39, 39), Size = UDim2.fromOffset(46, 46), BorderSizePixel = 1, Visible = false, Text = "", AutoButtonColor = false, ZIndex = 20 }, self.gui)
	bind(self.mini, "BackgroundColor3", "pn") bind(self.mini, "BorderColor3", "bd")
	self.miniScale = new("UIScale", { Scale = 1 }, self.mini)
	self.miniDecal = decal(self.mini, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(32, 32) })
	local miniMoved = 0
	self.mini.InputBegan:Connect(function(i)
		if isPress(i) then
			local start, startPos = i.Position, self.mini.Position
			miniMoved = 0
			dragFn = function(inp)
				local d = inp.Position - start
				miniMoved = d.Magnitude
				local vp = Camera.ViewportSize
				self.mini.Position = UDim2.fromOffset(
					math.clamp(startPos.X.Offset + d.X, 23, math.max(23, vp.X - 23)),
					math.clamp(startPos.Y.Offset + d.Y, 23, math.max(23, vp.Y - 23)))
			end
		end
	end)
	self.mini.InputEnded:Connect(function(i)
		if isPress(i) and miniMoved < 8 then self:Show() end
		miniMoved = 0
	end)
	minBtn.MouseButton1Click:Connect(function()
		self:Hide()
		if self.mode == "PC" then
			self:Notify("UI hidden", "Default keybind to hide/unhide script is Right Ctrl", 4)
		end
	end)

	-- toast holder
	self.toasts = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(250, 400), BackgroundTransparency = 1, ZIndex = 100 }, self.gui)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6) }, self.toasts)

	-- clamp the saved size to the screen, then center the window
	self:SetSize(self.W, self.H)
	local vp = Camera.ViewportSize
	if type(cfg.pos) == "table" and tonumber(cfg.pos[1]) and tonumber(cfg.pos[2]) then
		local x, y = self:_clampPos(tonumber(cfg.pos[1]), tonumber(cfg.pos[2]))
		win.Position = UDim2.fromOffset(x, y)
	else
		win.Position = UDim2.fromOffset(math.max(0, (vp.X - self.W) / 2), math.max(0, (vp.Y - self.H) / 2))
	end

	setStars()
	onTheme(function() self:_refresh() end)
	ActiveWindow = self
	self:SetPreset(self.preset)
	if self.accent then applyAccent(self.accent) end
	return self
end

----------------------------------------------------------------
-- BOOT: load screen -> build UI
----------------------------------------------------------------
local cfg = readConfig()
local loader = showLoader()

local ids = {}
for _, id in ipairs(LOAD_IMAGES) do table.insert(ids, id) end
if STAR_ID ~= "" then table.insert(ids, STAR_ID) end
for _, name in ipairs(ORDER) do
	table.insert(ids, PRESETS[name].logo)
	table.insert(ids, PRESETS[name].deco)
end

local total = #ids + 1
local progress = 0
local function tick(msg)
	progress = progress + 1
	loader.set(progress / total, msg)
end

local finished = false
task.spawn(function()
	-- 1) load every decal (in parallel)
	local pending = #ids
	for _, id in ipairs(ids) do
		task.spawn(function()
			local url, ok, how = resolveImage(id)
			resolved[id] = url
			if ok then
				print("[BumpUI] " .. id .. " OK via " .. how)
			else
				failed[id] = true
				warn("[BumpUI] Could not find an image for " .. id .. " (" .. how .. "). It will be hidden. Put its Image id in IMAGE_OVERRIDES.")
			end
			if id == LOAD_IMAGES[1] and ok then loader.setImage(url) end
			tick("Loading decals")
			pending = pending - 1
		end)
	end
	while pending > 0 do task.wait() end

	-- 2) fonts (Gotham is built into Roblox; preloading avoids font pop-in)
	pcall(function()
		local holder = new("ScreenGui", { Enabled = false })
		local labels = {}
		for _, f in ipairs({ FONT, FONT_BOLD }) do
			table.insert(labels, new("TextLabel", { Text = "Aa", Font = f }, holder))
		end
		ContentProvider:PreloadAsync(labels)
		holder:Destroy()
	end)
	tick("Loading fonts")
	finished = true
end)

local t0 = os.clock()
while not finished and os.clock() - t0 < CONFIG.LoadTimeout do task.wait(0.05) end
loader.set(1, "Ready")
task.wait(0.6) -- lets the progress bar finish its smooth fill

local Library = buildWindow(cfg)
loader.destroy() -- fades out while the UI animates in

-- exposed for the example / your own scripts
Library.PresetOrder = ORDER

pcall(function()
	if getgenv then getgenv().BumpUI = Library end
end)

return Library
