-- WoW Controller Labels
--
-- Changes which glyph set (Xbox letters, PlayStation shapes, Switch "reverse"
-- letters, or generic numbers) the game draws on controller prompts.
--
-- How: every controller has a gamepad config in the engine (the same data as
-- WTF/GamePadConfig_Default.json). One field of that config, labelStyle, is
-- what Blizzard's UI reads to pick glyph art. This addon copies the connected
-- controller's existing config unchanged, sets only labelStyle, and hands it
-- back through the public C_GamePad API. Button and axis mappings are copied
-- verbatim, so nothing about how the controller behaves changes.
--
-- The addon never hooks or calls Blizzard UI code, so it cannot taint the
-- secure gamepad UI.

local VALID_STYLES = {
	Letters = true,  -- Xbox: A B X Y
	Shapes  = true,  -- PlayStation: cross circle square triangle
	Reverse = true,  -- Nintendo Switch: B A Y X
	Generic = true,  -- numbered buttons
}

local STYLE_ALIASES = {
	xbox = "Letters", letters = "Letters", abxy = "Letters", xb = "Letters",
	playstation = "Shapes", ps = "Shapes", ps4 = "Shapes", ps5 = "Shapes", shapes = "Shapes", sony = "Shapes", dualsense = "Shapes",
	switch = "Reverse", nintendo = "Reverse", reverse = "Reverse",
	generic = "Generic", numbers = "Generic",
	auto = false, default = false, off = false, reset = false,
}

local STYLE_LABELS = {
	Letters = "Xbox (A B X Y)",
	Shapes  = "PlayStation (shapes)",
	Reverse = "Switch (B A Y X)",
	Generic = "Generic (numbers)",
}

local PREFIX = "|cff33ccffControllerLabels|r: "
local function Print(msg)
	print(PREFIX .. msg)
end

WowControllerLabelsDB = WowControllerLabelsDB or {}

local function DeviceKey(vendorID, productID)
	return tostring(vendorID or 0) .. ":" .. tostring(productID or 0)
end

-- Returns a list of { id, name, vendorID, productID } for every physical controller.
local function GetConnectedDevices()
	local devices = {}
	if not C_GamePad or not C_GamePad.GetAllDeviceIDs then
		return devices
	end
	for _, id in ipairs(C_GamePad.GetAllDeviceIDs() or {}) do
		local raw = C_GamePad.GetDeviceRawState(id)
		if raw and raw.vendorID and raw.vendorID ~= 0 then
			table.insert(devices, { id = id, name = raw.name, vendorID = raw.vendorID, productID = raw.productID })
		end
	end
	return devices
end

-- Deep copy so we never hand the engine a table it gave us.
local function CopyTable(t)
	local out = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			out[k] = CopyTable(v)
		else
			out[k] = v
		end
	end
	return out
end

-- Find the config the engine uses for this device: exact vendor+product first,
-- then vendor-only.
local function FindDeviceConfig(device)
	local config = C_GamePad.GetConfig({ vendorID = device.vendorID, productID = device.productID })
	if config then
		return config
	end
	config = C_GamePad.GetConfig({ vendorID = device.vendorID })
	return config
end

-- Push a labelStyle to the engine for one device. style == nil restores
-- whatever the controller had before this addon first touched it.
local function ApplyToDevice(device, style)
	WowControllerLabelsDB.originals = WowControllerLabelsDB.originals or {}
	WowControllerLabelsDB.overlays = WowControllerLabelsDB.overlays or {}
	local key = DeviceKey(device.vendorID, device.productID)
	local configID = { vendorID = device.vendorID, productID = device.productID }

	local config = FindDeviceConfig(device)

	if not config then
		-- The engine does not expose this device's built-in config through
		-- GetConfig. Configs layer by device ID, so submit an overlay that
		-- carries only labelStyle; the mappings stay with the built-in config.
		if style == nil then
			if WowControllerLabelsDB.overlays[key] then
				C_GamePad.DeleteConfig(configID)
				WowControllerLabelsDB.overlays[key] = nil
			end
			return true
		end
		C_GamePad.SetConfig({
			configID = configID,
			name = device.name,
			comment = "WowControllerLabels: labelStyle overlay only; mappings come from the game default.",
			labelStyle = style,
			rawButtonMappings = {},
			rawAxisMappings = {},
			axisConfigs = {},
			stickConfigs = {},
		})
		WowControllerLabelsDB.overlays[key] = true
		return true
	end

	if WowControllerLabelsDB.originals[key] == nil then
		-- Remember what the game chose on its own, so "auto" can put it back.
		WowControllerLabelsDB.originals[key] = config.labelStyle or "Generic"
	end

	local target = style or WowControllerLabelsDB.originals[key]
	if config.labelStyle == target then
		return true
	end

	local newConfig = CopyTable(config)
	newConfig.configID = configID
	newConfig.labelStyle = target
	newConfig.comment = "WowControllerLabels: only labelStyle differs from the game default."
	C_GamePad.SetConfig(newConfig)
	return true
end

local function ApplyAll(quiet)
	local style = WowControllerLabelsDB.style
	if style and not VALID_STYLES[style] then
		style = nil
	end
	local devices = GetConnectedDevices()
	if #devices == 0 then
		if not quiet then
			Print("no controller connected. The style will apply the next time you log in with one plugged in.")
		end
		return
	end
	local changed = false
	for _, device in ipairs(devices) do
		if ApplyToDevice(device, style) then
			changed = true
		end
	end
	if changed then
		C_GamePad.ApplyConfigs()
	end
end

local function CurrentEngineStyle()
	local devices = GetConnectedDevices()
	local device = devices[1]
	if device then
		local mapped = C_GamePad.GetDeviceMappedState(device.id)
		if mapped and mapped.labelStyle then
			return mapped.labelStyle, device.name
		end
	end
	return nil
end

local function SetStyle(style, quiet)
	WowControllerLabelsDB.style = style or nil
	ApplyAll(quiet)
	if quiet then
		return
	end
	if style then
		Print("controller glyphs set to " .. STYLE_LABELS[style] .. ". Press any controller button to redraw the prompts.")
	else
		Print("restored the game's own glyph style for your controller. Press any controller button to redraw the prompts.")
	end
end

local function PrintStatus()
	local chosen = WowControllerLabelsDB.style
	local engineStyle, deviceName = CurrentEngineStyle()
	if chosen and VALID_STYLES[chosen] then
		Print("preference: " .. STYLE_LABELS[chosen] .. ".")
	else
		Print("preference: auto (whatever the game picks).")
	end
	if engineStyle then
		Print("controller '" .. tostring(deviceName) .. "' is currently using " .. (STYLE_LABELS[engineStyle] or engineStyle) .. " glyphs.")
	else
		Print("no controller detected right now.")
	end
	Print("usage: /padlabels xbox | playstation | switch | generic | auto | debug")
end

local function DescribeConfig(config)
	if not config then
		return "nil"
	end
	return string.format("name=%s labelStyle=%s buttons=%d axes=%d",
		tostring(config.name), tostring(config.labelStyle),
		#(config.rawButtonMappings or {}), #(config.rawAxisMappings or {}))
end

local function PrintDebug()
	Print("active device id: " .. tostring(C_GamePad.GetActiveDeviceID()))
	for _, id in ipairs(C_GamePad.GetAllDeviceIDs() or {}) do
		local raw = C_GamePad.GetDeviceRawState(id)
		local mapped = C_GamePad.GetDeviceMappedState(id)
		Print(string.format("device %s: raw name=%s vendor=%s product=%s | mapped labelStyle=%s",
			tostring(id), raw and tostring(raw.name) or "nil",
			raw and tostring(raw.vendorID) or "nil", raw and tostring(raw.productID) or "nil",
			mapped and tostring(mapped.labelStyle) or "nil"))
	end
	local ids = C_GamePad.GetAllConfigIDs() or {}
	Print("config ids known to the engine: " .. #ids)
	for _, cid in ipairs(ids) do
		local config = C_GamePad.GetConfig(cid)
		Print(string.format("  vendor=%s product=%s -> %s", tostring(cid.vendorID), tostring(cid.productID), DescribeConfig(config)))
	end
	for _, device in ipairs(GetConnectedDevices()) do
		Print(string.format("lookup exact %d:%d -> %s", device.vendorID, device.productID,
			DescribeConfig(C_GamePad.GetConfig({ vendorID = device.vendorID, productID = device.productID }))))
		Print(string.format("lookup vendor %d -> %s", device.vendorID,
			DescribeConfig(C_GamePad.GetConfig({ vendorID = device.vendorID }))))
	end
	Print("lookup global -> " .. DescribeConfig(C_GamePad.GetConfig({})))
end

-- Optional Settings panel (Options > AddOns). Guarded so the slash command
-- keeps working even if this client's Settings API differs.
local function RegisterSettingsPanel()
	if not Settings or not Settings.RegisterVerticalLayoutCategory then
		return
	end
	pcall(function()
		local category = Settings.RegisterVerticalLayoutCategory("Controller Labels")
		local function GetValue()
			return WowControllerLabelsDB.style or "Auto"
		end
		local function SetValue(value)
			SetStyle(value ~= "Auto" and value or nil, true)
		end
		local setting = Settings.RegisterProxySetting(category, "WowControllerLabels_Style", Settings.VarType.String, "Button glyph style", "Auto", GetValue, SetValue)
		local function GetOptions()
			local container = Settings.CreateControlTextContainer()
			container:Add("Auto", "Auto (match controller)")
			container:Add("Letters", STYLE_LABELS.Letters)
			container:Add("Shapes", STYLE_LABELS.Shapes)
			container:Add("Reverse", STYLE_LABELS.Reverse)
			container:Add("Generic", STYLE_LABELS.Generic)
			return container:GetData()
		end
		Settings.CreateDropdown(category, setting, GetOptions, "Which button glyphs to draw on controller prompts. Binds are never changed. Press a controller button after changing this to redraw.")
		Settings.RegisterAddOnCategory(category)
	end)
end

SLASH_WOWCONTROLLERLABELS1 = "/padlabels"
SLASH_WOWCONTROLLERLABELS2 = "/controllerlabels"
SlashCmdList.WOWCONTROLLERLABELS = function(msg)
	local arg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if arg == "" or arg == "status" or arg == "help" then
		PrintStatus()
		return
	end
	if arg == "debug" then
		PrintDebug()
		return
	end
	local style = STYLE_ALIASES[arg]
	if style == nil then
		Print("unknown style '" .. arg .. "'.")
		PrintStatus()
		return
	end
	SetStyle(style or nil)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GAME_PAD_CONNECTED")
frame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		WowControllerLabelsDB = WowControllerLabelsDB or {}
		if not C_GamePad then
			Print("C_GamePad API not available; this client is not supported.")
			return
		end
		RegisterSettingsPanel()
	end
	-- Re-apply on login and whenever a controller is plugged in, so the chosen
	-- style follows the device. Silent unless a style is actually set.
	if WowControllerLabelsDB.style then
		ApplyAll(true)
	end
end)
