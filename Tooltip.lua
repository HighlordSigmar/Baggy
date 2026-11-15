-- Baggy: "how many do my characters have" lines on item tooltips

local S = Baggy

local index
local dirty = true

function S:MarkIndexDirty()
  dirty = true
end

local function Add(name, char, where, count)
  if not name then return end
  local e = index[name]
  if not e then e = {}; index[name] = e end
  local c = e[char]
  if not c then c = { bags = 0, bank = 0, equip = 0 }; e[char] = c end
  c[where] = c[where] + (count or 1)
end

local function BuildIndex()
  index = {}
  local realm = S:Realm()
  for char, d in pairs(realm) do
    for bag, b in pairs(d.bags or {}) do
      local where = S:IsBankBag(bag) and "bank" or "bags"
      for slot = 1, (b.size or 0) do
        local it = b[slot]
        if it then Add(S.ItemName(it.l), char, where, it.c) end
      end
    end
    for _, it in pairs(d.equip or {}) do
      Add(S.ItemName(it.l), char, "equip", 1)
    end
  end
  dirty = false
end

function S:AddTooltipCounts(tt)
  if not self.db or not self.db.tooltipCounts or not self.me then return end
  local first = getglobal(tt:GetName() .. "TextLeft1")
  local name = first and first:GetText()
  if not name then return end
  -- already added to this exact tooltip
  if tt.baggyName == name and tt.baggyLines == tt:NumLines() then return end
  if dirty then BuildIndex() end
  local e = index[name]
  if not e then return end

  local names = self:CharNames()
  local total, chars = 0, 0
  for i = 1, table.getn(names) do
    local char = names[i]
    local c = e[char]
    if c then
      local sum = c.bags + c.bank + c.equip
      if sum > 0 then
        local parts = {}
        if c.bags > 0 then table.insert(parts, "Bags " .. c.bags) end
        if c.bank > 0 then table.insert(parts, "Bank " .. c.bank) end
        if c.equip > 0 then table.insert(parts, "Equipped " .. c.equip) end
        local d = self:CharData(char)
        tt:AddDoubleLine(self.ClassColored(char, d and d.class),
          sum .. "  |cffaaaaaa(" .. table.concat(parts, ", ") .. ")|r",
          1, 1, 1, 1, 1, 1)
        total = total + sum
        chars = chars + 1
      end
    end
  end
  if chars > 1 and self.db.tooltipTotal then
    tt:AddDoubleLine("Total", tostring(total), 1, 0.82, 0, 1, 1, 1)
  end
  if chars > 0 then
    tt.baggyName = name
    tt.baggyLines = tt:NumLines()
    tt:Show()
  end
end

local METHODS = {
  "SetBagItem", "SetInventoryItem", "SetHyperlink", "SetLootItem", "SetLootRollItem",
  "SetMerchantItem", "SetBuybackItem", "SetQuestItem", "SetQuestLogItem",
  "SetTradeSkillItem", "SetCraftItem", "SetAuctionItem", "SetAuctionSellItem",
  "SetTradePlayerItem", "SetTradeTargetItem", "SetInboxItem", "SetSendMailItem",
}

local function Wrap(tt, method)
  local orig = tt[method]
  if not orig then return end
  tt[method] = function(self, a1, a2, a3, a4)
    local r1, r2, r3, r4 = orig(self, a1, a2, a3, a4)
    S:AddTooltipCounts(self)
    return r1, r2, r3, r4
  end
end

function S:InstallTooltipHooks()
  if self.tooltipHooked then return end
  self.tooltipHooked = true
  for i = 1, table.getn(METHODS) do Wrap(GameTooltip, METHODS[i]) end
  if ItemRefTooltip then Wrap(ItemRefTooltip, "SetHyperlink") end
end
