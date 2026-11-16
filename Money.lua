-- Baggy: money shown with coin icons, like Blizzard's money frames.
-- The 1.12 client can't put pictures inside text, so each amount is a
-- small row of number + coin texture pairs.

local S = Baggy

local COINS = {
  "Interface\\MoneyFrame\\UI-GoldIcon",
  "Interface\\MoneyFrame\\UI-SilverIcon",
  "Interface\\MoneyFrame\\UI-CopperIcon",
}
local ICON = 13

-- a right-aligned coin display inside `parent`
function S:CreateCoins(parent, font)
  local c = CreateFrame("Frame", nil, parent)
  c:SetHeight(ICON)
  c:SetWidth(1)
  c.parts = {}
  for i = 1, 3 do
    local fs = c:CreateFontString(nil, "ARTWORK", font or "NumberFontNormal")
    fs:SetJustifyH("RIGHT")
    local tex = c:CreateTexture(nil, "ARTWORK")
    tex:SetWidth(ICON); tex:SetHeight(ICON)
    tex:SetTexture(COINS[i])
    c.parts[i] = { text = fs, icon = tex }
  end
  return c
end

-- fill a coin display; returns its width. Gold and silver are left out
-- while they're zero, copper is always shown.
function S:SetCoins(c, copper)
  copper = copper or 0
  local values = {
    math.floor(copper / 10000),
    math.floor(math.mod(copper, 10000) / 100),
    math.mod(copper, 100),
  }
  local anchor
  local width = 0
  for i = 3, 1, -1 do
    local p = c.parts[i]
    local show = (i == 3) or values[i] > 0 or (i == 2 and values[1] > 0)
    if show then
      p.icon:ClearAllPoints()
      if anchor then
        p.icon:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
        width = width + 4
      else
        p.icon:SetPoint("RIGHT", c, "RIGHT", 0, 0)
      end
      p.text:ClearAllPoints()
      p.text:SetPoint("RIGHT", p.icon, "LEFT", -1, 0)
      p.text:SetText(values[i])
      p.icon:Show(); p.text:Show()
      width = width + ICON + 1 + p.text:GetStringWidth()
      anchor = p.text
    else
      p.icon:Hide(); p.text:Hide()
    end
  end
  c:SetWidth(width > 0 and width or 1)
  return width
end

----------------------------------------------------------------------
-- tooltip with every character's money
----------------------------------------------------------------------
local tip
local ROW_H = 16

local function BuildTip()
  tip = CreateFrame("Frame", "BaggyMoneyTip", UIParent)
  tip:SetFrameStrata("TOOLTIP")
  tip:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  tip:SetBackdropColor(0.09, 0.09, 0.19, 0.95)
  tip:SetBackdropBorderColor(1, 1, 1, 1)
  tip.title = tip:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  tip.title:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, -10)
  tip.rows = {}
  tip:Hide()
end

local function Row(i)
  local r = tip.rows[i]
  if not r then
    r = {}
    r.name = tip:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    r.name:SetJustifyH("LEFT")
    r.coins = S:CreateCoins(tip, "GameFontHighlightSmall")
    tip.rows[i] = r
  end
  return r
end

function S:ShowMoneyTip(owner)
  if not tip then BuildTip() end
  tip.title:SetText("Money on " .. (self.realm or ""))
  local names = self:CharNames()
  local list = {}
  local total = 0
  for i = 1, table.getn(names) do
    local d = self:CharData(names[i])
    local m = d and d.money or 0
    total = total + m
    table.insert(list, { self.ClassColored(names[i], d and d.class), m })
  end
  if table.getn(list) > 1 then
    table.insert(list, { "|cffffd100Total|r", total, true })
  end

  local nameW, coinW = 0, 0
  local y = -30
  for i = 1, table.getn(list) do
    local r = Row(i)
    if list[i][3] then y = y - 6 end   -- small gap before the total
    r.name:ClearAllPoints()
    r.name:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, y)
    r.name:SetText(list[i][1])
    r.name:Show()
    r.coins:ClearAllPoints()
    r.coins:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -10, y)
    local w = self:SetCoins(r.coins, list[i][2])
    r.coins:Show()
    if r.name:GetStringWidth() > nameW then nameW = r.name:GetStringWidth() end
    if w > coinW then coinW = w end
    y = y - ROW_H
  end
  for i = table.getn(list) + 1, table.getn(tip.rows) do
    tip.rows[i].name:Hide()
    tip.rows[i].coins:Hide()
  end

  local width = nameW + coinW + 40
  local tw = tip.title:GetStringWidth() + 20
  if tw > width then width = tw end
  tip:SetWidth(width)
  tip:SetHeight(-y + 8)
  tip:ClearAllPoints()
  tip:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", 0, 4)
  tip:Show()
end

function S:HideMoneyTip()
  if tip then tip:Hide() end
end
