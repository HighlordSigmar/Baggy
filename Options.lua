-- Baggy options window (/baggy)

local S = Baggy
local panel
local refreshers = {}
local count = 0
local refreshing = false

-- settings are addressed by path, e.g. "frames.bank.cols"
local function Get(path)
  local t = S.db
  local last
  for part in string.gfind(path, "[^%.]+") do
    if last then t = t[last] end
    last = part
  end
  return t[last]
end

local function Set(path, value)
  local t = S.db
  local last
  for part in string.gfind(path, "[^%.]+") do
    if last then t = t[last] end
    last = part
  end
  t[last] = value
end

local function NextName(kind)
  count = count + 1
  return "BaggyOpt" .. kind .. count
end

local function Header(parent, label, x, y)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetText(label)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetTexture(1, 0.82, 0, 0.25)
  line:SetHeight(1)
  line:SetWidth(260)
  line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
  return fs
end

local function Check(parent, label, key, x, y)
  local name = NextName("Check")
  local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
  cb:SetWidth(24); cb:SetHeight(24)
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  getglobal(name .. "Text"):SetText(label)
  cb:SetScript("OnClick", function()
    Set(key, this:GetChecked() and true or false)
    S:ApplyAll()
  end)
  table.insert(refreshers, function() cb:SetChecked(Get(key) and 1 or nil) end)
  return cb
end

local function Slider(parent, label, key, minv, maxv, step, x, y)
  local name = NextName("Slider")
  local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
  s:SetWidth(250)
  s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  s:SetMinMaxValues(minv, maxv)
  s:SetValueStep(step)
  getglobal(name .. "Low"):SetText(minv)
  getglobal(name .. "High"):SetText(maxv)
  local title = getglobal(name .. "Text")
  local function show(v)
    if step < 1 then
      title:SetText(label .. ": " .. string.format("%.2f", v))
    else
      title:SetText(label .. ": " .. v)
    end
  end
  s:SetScript("OnValueChanged", function()
    if refreshing then show(Get(key)); return end
    local v = math.floor(this:GetValue() / step + 0.5) * step
    if step >= 1 then v = math.floor(v + 0.5) end
    show(v)
    if Get(key) ~= v then
      Set(key, v)
      S:ApplyAll()
    end
  end)
  table.insert(refreshers, function() s:SetValue(Get(key)); show(Get(key)) end)
  return s
end

local function Button(parent, label, x, y, width, onClick)
  local b = CreateFrame("Button", NextName("Button"), parent, "UIPanelButtonTemplate")
  b:SetWidth(width or 120); b:SetHeight(22)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  b:SetText(label)
  b:SetScript("OnClick", onClick)
  return b
end

local function OpenColorPicker(c, onChange)
  local pr, pg, pb, pa = c[1], c[2], c[3], c[4] or 1
  ColorPickerFrame:Hide()
  ColorPickerFrame.func = nil
  ColorPickerFrame.opacityFunc = nil
  ColorPickerFrame.cancelFunc = nil
  ColorPickerFrame.hasOpacity = true
  ColorPickerFrame.opacity = 1 - pa
  ColorPickerFrame:SetColorRGB(pr, pg, pb)
  local function apply()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    c[1], c[2], c[3] = r, g, b
    c[4] = 1 - OpacitySliderFrame:GetValue()
    onChange()
  end
  ColorPickerFrame.func = apply
  ColorPickerFrame.opacityFunc = apply
  ColorPickerFrame.cancelFunc = function()
    c[1], c[2], c[3], c[4] = pr, pg, pb, pa
    onChange()
  end
  ColorPickerFrame:Show()
end

local function Swatch(parent, label, ckey, x, y)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(120); b:SetHeight(18)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local edge = b:CreateTexture(nil, "BACKGROUND")
  edge:SetWidth(18); edge:SetHeight(18)
  edge:SetPoint("LEFT", b, "LEFT", 0, 0)
  edge:SetTexture(0.8, 0.8, 0.8, 1)
  local back = b:CreateTexture(nil, "BORDER")
  back:SetWidth(16); back:SetHeight(16)
  back:SetPoint("LEFT", b, "LEFT", 1, 0)
  back:SetTexture(0.1, 0.1, 0.1, 1)
  local sw = b:CreateTexture(nil, "ARTWORK")
  sw:SetWidth(16); sw:SetHeight(16)
  sw:SetPoint("LEFT", b, "LEFT", 1, 0)
  local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  fs:SetPoint("LEFT", b, "LEFT", 24, 0)
  fs:SetText(label)
  local function refresh()
    local c = S.db.colors[ckey]
    sw:SetTexture(c[1], c[2], c[3], c[4] or 1)
  end
  b:SetScript("OnClick", function()
    OpenColorPicker(S.db.colors[ckey], function() refresh(); S:ApplyAll() end)
  end)
  b:SetScript("OnEnter", function() fs:SetTextColor(1, 0.82, 0) end)
  b:SetScript("OnLeave", function() fs:SetTextColor(1, 1, 1) end)
  table.insert(refreshers, refresh)
  return b
end

local function Build()
  panel = CreateFrame("Frame", "BaggyOptions", UIParent)
  panel:SetWidth(600); panel:SetHeight(500)
  panel:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
  panel:SetFrameStrata("HIGH")
  panel:SetToplevel(true)
  panel:EnableMouse(true)
  panel:SetMovable(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", function() this:StartMoving() end)
  panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  table.insert(UISpecialFrames, "BaggyOptions")

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", panel, "TOP", 0, -18)
  title:SetText("Baggy")

  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)

  -- left column: behavior
  local L, R = 24, 316
  Header(panel, "Behavior", L, -46)
  Check(panel, "Use Baggy for your bags", "replaceBags", L, -66)
  Check(panel, "Use Baggy for your bank", "replaceBank", L, -88)
  Check(panel, "Open bags at a vendor", "openMerchant", L, -110)
  Check(panel, "Open bags at the mailbox", "openMail", L, -132)
  Check(panel, "Open bags at the auction house", "openAH", L, -154)
  Check(panel, "Open bags when trading", "openTrade", L, -176)
  Check(panel, "Show the keyring in your bags", "showKeyring", L, -198)
  Check(panel, "Lock window positions", "locked", L, -220)

  Header(panel, "Tooltips", L, -254)
  Check(panel, "Item counts for all your characters", "tooltipCounts", L, -274)
  Check(panel, "Total line when more than one has it", "tooltipTotal", L, -296)

  Header(panel, "Reset", L, -330)
  Button(panel, "Reset positions", L, -352, 125, function()
    S.db.frames.inventory.pos = nil
    S.db.frames.bank.pos = nil
    S:ApplyAll()
  end)
  Button(panel, "Reset everything", L + 135, -352, 125, function()
    S:ResetSettings()
    S.Print("all settings reset to defaults.")
  end)

  local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", panel, "TOPLEFT", L, -388)
  help:SetWidth(262)
  help:SetJustifyH("LEFT")
  help:SetText("Click a window's title to see another character's bags or bank. " ..
    "Each character is saved when you log in on it, and its bank when you visit a banker.\n\n" ..
    "|cffffd100/baggy forget Name|r deletes a character you no longer play.")

  -- right column: look
  Header(panel, "Layout", R, -46)
  Slider(panel, "Bag columns", "frames.inventory.cols", 4, 24, 1, R + 6, -80)
  Slider(panel, "Bank columns", "frames.bank.cols", 4, 36, 1, R + 6, -118)
  Slider(panel, "Bag scale", "frames.inventory.scale", 0.5, 1.5, 0.05, R + 6, -156)
  Slider(panel, "Bank scale", "frames.bank.scale", 0.5, 1.5, 0.05, R + 6, -194)
  Slider(panel, "Slot spacing", "spacing", 0, 10, 1, R + 6, -232)

  Header(panel, "Look", R, -264)
  Check(panel, "Search box", "showSearch", R, -284)
  Check(panel, "Quality borders (green and better)", "qualityGlow", R, -306)
  Check(panel, "Grey border on junk", "glowPoor", R, -328)
  Check(panel, "Yellow border on quest items", "questGlow", R, -350)
  Check(panel, "Tint soul, herb and ammo bag slots", "bagColors", R, -372)
  Check(panel, "Reverse slot order", "reverse", R, -394)

  Header(panel, "Colors", R, -428)
  Swatch(panel, "Background", "bg", R, -450)
  Swatch(panel, "Border", "border", R + 130, -450)

  panel:SetScript("OnShow", function() S:RefreshOptions() end)
  panel:Hide()
end

function S:RefreshOptions()
  if not panel then return end
  refreshing = true
  for i = 1, table.getn(refreshers) do refreshers[i]() end
  refreshing = false
end

function S:ToggleOptions()
  if not panel then Build() end
  if panel:IsShown() then panel:Hide() else panel:Show() end
end
