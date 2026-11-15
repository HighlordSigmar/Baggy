-- Baggy: search every character's bags, bank and equipped items

local S = Baggy

local ROWS = 10
local ROW_H = 36
local WIDTH = 400

local win
local results = {}

-- every item on the realm that matches, merged by name
function S:FindItems(text)
  local found, byName = {}, {}
  if not text or text == "" then return found end
  local function add(char, link, count)
    if not link or not self:Matches(link, text) then return end
    local name = S.ItemName(link) or link
    local r = byName[name]
    if not r then
      r = { name = name, link = link, total = 0, chars = {} }
      byName[name] = r
      table.insert(found, r)
    end
    r.total = r.total + (count or 1)
    r.chars[char] = (r.chars[char] or 0) + (count or 1)
  end
  for char, d in pairs(self:Realm()) do
    for _, b in pairs(d.bags or {}) do
      for slot = 1, (b.size or 0) do
        local it = b[slot]
        if it then add(char, it.l, it.c) end
      end
    end
    for _, it in pairs(d.equip or {}) do add(char, it.l, 1) end
  end
  table.sort(found, function(a, b) return a.name < b.name end)
  return found
end

local function Detail(r)
  local names = S:CharNames()
  local parts = {}
  for i = 1, table.getn(names) do
    local n = r.chars[names[i]]
    if n then
      local d = S:CharData(names[i])
      table.insert(parts, S.ClassColored(names[i], d and d.class) .. " " .. n)
    end
  end
  return "|cffffd100" .. r.total .. "|r  " .. table.concat(parts, ", ")
end

local function UpdateRows()
  local n = table.getn(results)
  FauxScrollFrame_Update(win.scroll, n, ROWS, ROW_H)
  local offset = FauxScrollFrame_GetOffset(win.scroll) or 0
  for i = 1, ROWS do
    local row = win.rows[i]
    local r = results[i + offset]
    if r then
      row.result = r
      local is = S.ItemString(r.link)
      local tex
      if is then
        local _, _, _, _, _, _, _, _, t = GetItemInfo(is)
        tex = t
      end
      row.icon:SetTexture(tex or S:FindTexture(r.link) or "Interface\\Icons\\INV_Misc_QuestionMark")
      local q = S.ItemQuality(r.link)
      local c = q and S.QUALITY_COLORS[q] or S.QUALITY_COLORS[1]
      row.name:SetText(r.name)
      row.name:SetTextColor(c[1], c[2], c[3])
      row.detail:SetText(Detail(r))
      row:Show()
    else
      row.result = nil
      row:Hide()
    end
  end
  local text = win.search:GetText() or ""
  if text == "" then
    win.status:SetText("Type to search every character's bags, bank and equipped items on " .. S.realm .. ".")
  elseif n == 0 then
    win.status:SetText("Nothing found.")
  elseif n == 1 then
    win.status:SetText("1 item")
  else
    win.status:SetText(n .. " items")
  end
end

-- the icon we saved with the item, for items the game hasn't cached
function S:FindTexture(link)
  for _, d in pairs(self:Realm()) do
    for _, b in pairs(d.bags or {}) do
      for slot = 1, (b.size or 0) do
        local it = b[slot]
        if it and it.l == link and it.t then return it.t end
      end
    end
  end
  return nil
end

local function RunSearch()
  results = S:FindItems(string.lower(win.search:GetText() or ""))
  win.scroll.offset = 0
  getglobal(win.scroll:GetName() .. "ScrollBar"):SetValue(0)
  UpdateRows()
end

local function RowOnEnter()
  local r = this.result
  if not r then return end
  GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
  local is = S.ItemString(r.link)
  if is and GetItemInfo(is) then
    GameTooltip:SetHyperlink(is)
  else
    GameTooltip:SetText(r.name)
    GameTooltip:AddLine(Detail(r), 1, 1, 1)
  end
  GameTooltip:Show()
end

local function RowOnClick()
  local r = this.result
  if not r then return end
  if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
    ChatFrameEditBox:Insert(r.link)
  elseif IsControlKeyDown() then
    DressUpItemLink(r.link)
  end
end

local function Build()
  win = CreateFrame("Frame", "BaggyFindFrame", UIParent)
  win:SetWidth(WIDTH)
  win:SetHeight(92 + ROWS * ROW_H)
  win:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  win:SetFrameStrata("HIGH")
  win:SetToplevel(true)
  win:EnableMouse(true)
  win:SetMovable(true)
  win:SetClampedToScreen(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", function() this:StartMoving() end)
  win:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  win:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  table.insert(UISpecialFrames, "BaggyFindFrame")

  local title = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -10)
  title:SetText("Search all characters")

  local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
  close:SetWidth(26); close:SetHeight(26)
  close:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function() this:GetParent():Hide() end)

  local search = CreateFrame("EditBox", "BaggyFindSearch", win, "InputBoxTemplate")
  search:SetHeight(18)
  search:SetAutoFocus(false)
  search:SetPoint("TOPLEFT", win, "TOPLEFT", 18, -30)
  search:SetPoint("TOPRIGHT", win, "TOPRIGHT", -14, -30)
  search:SetScript("OnTextChanged", RunSearch)
  search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  search:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  win.search = search

  local scroll = CreateFrame("ScrollFrame", "BaggyFindScroll", win, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -56)
  scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -30, 30)
  scroll:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(ROW_H, UpdateRows)
  end)
  win.scroll = scroll

  win.rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Button", nil, win)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -56 - (i - 1) * ROW_H)
    row:SetPoint("RIGHT", win, "RIGHT", -32, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(30); icon:SetHeight(30)
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon = icon
    local name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
    name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    name:SetJustifyH("LEFT")
    name:SetHeight(14)
    row.name = name
    local detail = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 2)
    detail:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    detail:SetJustifyH("LEFT")
    detail:SetHeight(12)
    row.detail = detail
    row:SetScript("OnEnter", RowOnEnter)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", RowOnClick)
    row:Hide()
    win.rows[i] = row
  end

  local status = win:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  status:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 12, 12)
  status:SetPoint("RIGHT", win, "RIGHT", -12, 0)
  status:SetJustifyH("LEFT")
  win.status = status

  win:SetScript("OnShow", function()
    local c = S.db.colors
    this:SetBackdropColor(c.bg[1], c.bg[2], c.bg[3], math.max(c.bg[4], 0.9))
    this:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], c.border[4])
    RunSearch()
  end)
  win:Hide()
end

-- open the search window, optionally with some text already typed
function S:OpenFind(text)
  if not win then Build() end
  if text then win.search:SetText(text) end
  if win:IsShown() then RunSearch() else win:Show() end
  win.search:SetFocus()
end

function S:ToggleFind()
  if win and win:IsShown() then win:Hide() else self:OpenFind() end
end

-- keep results fresh when bags change while the window is open
function S:RefreshFind()
  if win and win:IsShown() then
    results = S:FindItems(string.lower(win.search:GetText() or ""))
    UpdateRows()
  end
end
