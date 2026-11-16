-- Baggy: the bag and bank windows

local S = Baggy

local SLOT = 37          -- item button size
local BAGSLOT = 30       -- bag bar button size
local PAD = 8
local TITLE_H = 30
local SEARCH_H = 24
local BAGBAR_H = BAGSLOT + 8
local BOTTOM_H = 26
local GROUP_GAP = 6
local MIN_W = 230

local EMPTY_SLOT = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
local EMPTY_BAG = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local BACKPACK_ICON = "Interface\\Buttons\\Button-Backpack-Up"
local BANK_ICON = "Interface\\Icons\\INV_Box_01"
local KEY_ICON = "Interface\\Icons\\INV_Misc_Key_04"

S.frames = {}
local itemCount = 0

local INFO = {
  inventory = { name = "BaggyInventoryFrame", title = "%s's Bags" },
  bank      = { name = "BaggyBankFrame",      title = "%s's Bank" },
}

----------------------------------------------------------------------
-- where the data comes from: the live game, or what we saved
----------------------------------------------------------------------
function S:FrameBags(f)
  if f.kind == "inventory" then
    local t = { 0, 1, 2, 3, 4 }
    if self.db.showKeyring then table.insert(t, S.KEYRING) end
    return t
  end
  return { -1, 5, 6, 7, 8, 9, 10 }
end

function S:IsLive(f)
  if f.viewing ~= self.player then return false end
  if f.kind == "bank" then return self.atBank and true or false end
  return true
end

local function CachedBag(f, bag)
  local d = S:CharData(f.viewing)
  return d and d.bags and d.bags[bag]
end

function S:BagSize(f, bag)
  if f.live then return self:NumSlots(bag) end
  local b = CachedBag(f, bag)
  return b and b.size or 0
end

-- texture, count, locked, link
function S:SlotInfo(f, bag, slot)
  if f.live then
    local tex, count, locked = GetContainerItemInfo(bag, slot)
    return tex, count, locked, GetContainerItemLink(bag, slot)
  end
  local b = CachedBag(f, bag)
  local it = b and b[slot]
  if not it then return nil end
  local tex = it.t
  if not tex then
    local is = S.ItemString(it.l)
    if is then
      local _, _, _, _, _, _, _, _, t = GetItemInfo(is)
      tex = t
    end
  end
  return tex or "Interface\\Icons\\INV_Misc_QuestionMark", it.c, nil, it.l
end

-- the bag item in a bag slot: texture, link, kind
function S:BagItem(f, bag)
  local inv = self:BagInvSlot(bag)
  if not inv then return nil end
  if f.live then
    local link = GetInventoryItemLink("player", inv)
    return GetInventoryItemTexture("player", inv), link, self:BagKind(link)
  end
  local b = CachedBag(f, bag)
  if b then return b.tex, b.link, b.kind end
  return nil
end

function S:NumBankSlots(f)
  if f.live then return GetNumBankSlots() or 0 end
  local d = self:CharData(f.viewing)
  return d and d.bankSlots or 0
end

function S.ClassColored(name, class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if not c then return name end
  return string.format("|cff%02x%02x%02x%s|r",
    math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), name)
end

----------------------------------------------------------------------
-- search
----------------------------------------------------------------------
function S:Matches(link, text)
  if not text or text == "" then return true end
  if not link then return false end
  local name = string.lower(S.ItemName(link) or "")
  if string.find(name, text, 1, true) then return true end
  local is = S.ItemString(link)
  if is then
    local _, _, _, _, itype, sub = GetItemInfo(is)
    if itype and string.find(string.lower(itype), text, 1, true) then return true end
    if sub and string.find(string.lower(sub), text, 1, true) then return true end
  end
  return false
end

function S:UpdateSearch(f)
  local text = f.searchText
  local list = f.shown or {}
  for i = 1, table.getn(list) do
    local b = list[i]
    if text and text ~= "" and not self:Matches(b.link, text) then
      b:SetAlpha(0.2)
    else
      b:SetAlpha(1)
    end
  end
end

function S:HighlightBag(f, bag)
  local list = f.shown or {}
  for i = 1, table.getn(list) do
    local b = list[i]
    if bag and b.bag == bag then b:LockHighlight() else b:UnlockHighlight() end
  end
end

----------------------------------------------------------------------
-- item buttons
----------------------------------------------------------------------
local function ItemOnEnter()
  local bag, slot = this.bag, this.slot
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  if this.offline then
    if this.link then
      local is = S.ItemString(this.link)
      if is and GetItemInfo(is) then
        GameTooltip:SetHyperlink(is)
      else
        GameTooltip:SetText(S.ItemName(this.link) or UNKNOWN or "Unknown")
      end
      GameTooltip:Show()
    else
      GameTooltip:Hide()
    end
    return
  end
  if not this.link then
    GameTooltip:Hide()
    ResetCursor()
    return
  end
  if bag == -1 then
    GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(slot))
  else
    local _, repairCost = GameTooltip:SetBagItem(bag, slot)
    if InRepairMode() and repairCost and repairCost > 0 then
      GameTooltip:AddLine(REPAIR_COST, 1, 1, 1)
      SetTooltipMoney(GameTooltip, repairCost)
      GameTooltip:Show()
    end
  end
  if IsControlKeyDown() then
    ShowInspectCursor()
  elseif MerchantFrame:IsVisible() and MerchantFrame.selectedTab == 1 and ShowContainerSellCursor then
    ShowContainerSellCursor(bag, slot)
  else
    ResetCursor()
  end
end

local function ItemOnLeave()
  GameTooltip:Hide()
  ResetCursor()
end

local function ItemOnClick()
  if this.offline then
    if not this.link then return end
    if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
      ChatFrameEditBox:Insert(this.link)
    elseif IsControlKeyDown() then
      DressUpItemLink(this.link)
    end
    return
  end
  ContainerFrameItemButton_OnClick(arg1)
end

local function ItemOnDrag()
  if this.offline then return end
  ContainerFrameItemButton_OnClick("LeftButton", 1)
end

local function CreateItemButton(f, parent)
  itemCount = itemCount + 1
  local name = "BaggyItem" .. itemCount
  local b = CreateFrame("Button", name, parent, "ContainerFrameItemButtonTemplate")
  b:SetWidth(SLOT); b:SetHeight(SLOT)
  b.frame = f
  b.icon = getglobal(name .. "IconTexture")
  b.cooldown = getglobal(name .. "Cooldown")
  b.normal = getglobal(name .. "NormalTexture")

  local glow = b:CreateTexture(nil, "OVERLAY")
  glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  glow:SetBlendMode("ADD")
  glow:SetWidth(67); glow:SetHeight(67)
  glow:SetPoint("CENTER", b, "CENTER", 0, 1)
  glow:Hide()
  b.glow = glow

  b:SetScript("OnUpdate", nil)
  b:SetScript("OnEnter", ItemOnEnter)
  b:SetScript("OnLeave", ItemOnLeave)
  b:SetScript("OnClick", ItemOnClick)
  b:SetScript("OnDragStart", ItemOnDrag)
  b:SetScript("OnReceiveDrag", ItemOnDrag)
  return b
end

local FLAT_BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  edgeSize = 1,
  insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

-- switch a button between the Blizzard look and the flat looks
local function ApplySlotStyle(b, style)
  if b.style == style then return end
  b.style = style
  b.icon:ClearAllPoints()
  if style == "blizzard" then
    b:SetBackdrop(nil)
    b.icon:SetAllPoints(b)
    b.icon:SetTexCoord(0, 1, 0, 1)
    if b.normal then b.normal:SetAlpha(1) end
  else
    b:SetBackdrop(FLAT_BACKDROP)
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if b.normal then b.normal:SetAlpha(0) end
  end
end

function S:UpdateItemButton(f, b, kind)
  local bag, slot = b.bag, b.slot
  local tex, count, locked, link = self:SlotInfo(f, bag, slot)
  b.link = link
  b.offline = not f.live
  local db = self.db
  local style = db.slotStyle or "blizzard"
  local flat = style ~= "blizzard"
  local isKey = (kind == "keyring")
  local kc = db.colors.keyring
  ApplySlotStyle(b, style)

  b.icon:SetAlpha(1)
  if tex then
    SetItemButtonTexture(b, tex)
    SetItemButtonCount(b, count or 1)
    if locked then
      SetItemButtonDesaturated(b, 1, 0.5, 0.5, 0.5)
    else
      SetItemButtonDesaturated(b, nil)
      b.icon:SetVertexColor(1, 1, 1)
    end
  elseif isKey then
    -- empty keyring slot: a faded key
    SetItemButtonTexture(b, KEY_ICON)
    SetItemButtonCount(b, 0)
    SetItemButtonDesaturated(b, 1, 0.5, 0.5, 0.5)
    b.icon:SetVertexColor(kc[1], kc[2], kc[3])
    b.icon:SetAlpha(0.35)
  else
    SetItemButtonCount(b, 0)
    SetItemButtonDesaturated(b, nil)
    local c = db.bagColors and kind and S.BAG_KIND_COLORS[kind]
    if flat then
      SetItemButtonTexture(b, nil)
    else
      SetItemButtonTexture(b, EMPTY_SLOT)
      if c then b.icon:SetVertexColor(c[1], c[2], c[3]) else b.icon:SetVertexColor(1, 1, 1) end
    end
  end

  -- slot frame and background
  if flat then
    local sc = db.colors.slot
    local c = db.bagColors and kind and not isKey and S.BAG_KIND_COLORS[kind]
    if isKey then
      b:SetBackdropColor(kc[1] * 0.25, kc[2] * 0.25, kc[3] * 0.25, sc[4])
    elseif c then
      b:SetBackdropColor(c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, sc[4])
    else
      b:SetBackdropColor(sc[1], sc[2], sc[3], sc[4])
    end
    if isKey then
      b:SetBackdropBorderColor(kc[1], kc[2], kc[3], kc[4])
    elseif style == "flatclean" then
      b:SetBackdropBorderColor(0, 0, 0, 0)
    else
      b:SetBackdropBorderColor(0, 0, 0, 1)
    end
  elseif b.normal then
    if isKey then
      b.normal:SetVertexColor(kc[1], kc[2], kc[3])
    else
      b.normal:SetVertexColor(1, 1, 1)
    end
  end

  -- border by quality, or yellow for quest items
  local glow
  if link then
    local is = S.ItemString(link)
    local itype
    if is then
      local _
      _, _, _, _, itype = GetItemInfo(is)
    end
    if db.questGlow and itype == "Quest" then
      glow = { 1, 1, 0 }
    elseif db.qualityGlow then
      local q = S.ItemQuality(link)
      if q and (q >= 2 or (q == 0 and db.glowPoor)) then glow = S.QUALITY_COLORS[q] end
    end
  end
  if glow then
    b.glow:SetVertexColor(glow[1], glow[2], glow[3])
    b.glow:SetAlpha(0.8)
    b.glow:Show()
  else
    b.glow:Hide()
  end

  if b.cooldown then
    if f.live and tex and bag ~= -1 then
      local start, duration, enable = GetContainerItemCooldown(bag, slot)
      CooldownFrame_SetTimer(b.cooldown, start, duration, enable)
    else
      b.cooldown:Hide()
    end
  end

  return tex ~= nil
end

local function GetBagFrame(f, bag)
  local bf = f.bagFrames[bag]
  if not bf then
    bf = CreateFrame("Frame", nil, f)
    bf:SetID(bag)
    bf:SetWidth(1); bf:SetHeight(1)
    bf:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    bf.buttons = {}
    f.bagFrames[bag] = bf
  end
  return bf
end

----------------------------------------------------------------------
-- bag bar
----------------------------------------------------------------------
StaticPopupDialogs["BAGGY_BUY_BANK_SLOT"] = {
  text = "Buy a new bank bag slot?",
  button1 = YES or "Yes",
  button2 = NO or "No",
  OnAccept = function() PurchaseSlot() end,
  OnShow = function()
    MoneyFrame_Update(this:GetName() .. "MoneyFrame", GetBankSlotCost(GetNumBankSlots()))
  end,
  hasMoneyFrame = 1,
  timeout = 0,
  hideOnEscape = 1,
}

local function BagSlotOnClick()
  local f, bag = this.frame, this.bag
  local inv = S:BagInvSlot(bag)
  if f.live and CursorHasItem() then
    if bag == 0 then PutItemInBackpack() elseif inv then PutItemInBag(inv) end
    return
  end
  if this.locked then
    if this.purchasable and f.live then
      StaticPopup_Show("BAGGY_BUY_BANK_SLOT")
    end
    return
  end
  local hidden = S.db.frames[f.kind].hidden
  if hidden[bag] then hidden[bag] = nil else hidden[bag] = true end
  S:Refresh(f)
end

local function BagSlotOnDragStart()
  local f = this.frame
  local inv = S:BagInvSlot(this.bag)
  if f.live and inv then PickupBagFromSlot(inv) end
end

local function BagSlotOnReceiveDrag()
  local f, bag = this.frame, this.bag
  if not f.live then return end
  local inv = S:BagInvSlot(bag)
  if bag == 0 then PutItemInBackpack() elseif inv then PutItemInBag(inv) end
end

local function BagSlotOnEnter()
  local f, bag = this.frame, this.bag
  local inv = S:BagInvSlot(bag)
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  if bag == 0 then
    GameTooltip:SetText(BACKPACK_TOOLTIP or "Backpack")
  elseif bag == -1 then
    GameTooltip:SetText("Bank")
  elseif bag == S.KEYRING then
    GameTooltip:SetText(KEYRING or "Keyring")
  elseif this.locked then
    GameTooltip:SetText(BANK_BAG_PURCHASE or "Purchasable bag slot")
    if this.purchasable and f.live then
      GameTooltip:AddLine("Click to buy", 0.6, 0.6, 0.6)
      SetTooltipMoney(GameTooltip, GetBankSlotCost(GetNumBankSlots()))
    elseif this.purchasable then
      GameTooltip:AddLine("Visit a banker to buy it", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
    return
  else
    local shown = false
    if f.live and inv then shown = GameTooltip:SetInventoryItem("player", inv) end
    if not shown then
      local _, link = S:BagItem(f, bag)
      if link then
        local is = S.ItemString(link)
        if is and GetItemInfo(is) then GameTooltip:SetHyperlink(is)
        else GameTooltip:SetText(S.ItemName(link) or "Bag") end
      else
        GameTooltip:SetText(EQUIP_CONTAINER or "Equip Container")
      end
    end
  end
  if S.db.frames[f.kind].hidden[bag] then
    GameTooltip:AddLine("Click to show this bag", 0.6, 0.6, 0.6)
  else
    GameTooltip:AddLine("Click to hide this bag", 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
  S:HighlightBag(f, bag)
end

local function BagSlotOnLeave()
  GameTooltip:Hide()
  S:HighlightBag(this.frame, nil)
end

local function CreateBagSlot(f, i)
  local name = f:GetName() .. "BagSlot" .. i
  local b = CreateFrame("Button", name, f.bagBar, "ItemButtonTemplate")
  b:SetWidth(BAGSLOT); b:SetHeight(BAGSLOT)
  local nt = getglobal(name .. "NormalTexture")
  if nt then nt:SetWidth(BAGSLOT * 64 / 37); nt:SetHeight(BAGSLOT * 64 / 37) end
  b.icon = getglobal(name .. "IconTexture")
  b.frame = f
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnClick", BagSlotOnClick)
  b:SetScript("OnDragStart", BagSlotOnDragStart)
  b:SetScript("OnReceiveDrag", BagSlotOnReceiveDrag)
  b:SetScript("OnEnter", BagSlotOnEnter)
  b:SetScript("OnLeave", BagSlotOnLeave)
  f.bagSlots[i] = b
  return b
end

function S:UpdateBagBar(f)
  local hidden = self.db.frames[f.kind].hidden
  local bags = self:FrameBags(f)
  local n = table.getn(bags)
  local numBank = (f.kind == "bank") and self:NumBankSlots(f) or 0
  for i = 1, n do
    local bag = bags[i]
    local b = f.bagSlots[i] or CreateBagSlot(f, i)
    b.bag = bag
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f.bagBar, "TOPLEFT", (i - 1) * (BAGSLOT + 4), 0)
    local tex
    if bag == 0 then tex = BACKPACK_ICON
    elseif bag == -1 then tex = BANK_ICON
    elseif bag == S.KEYRING then tex = KEY_ICON
    else tex = self:BagItem(f, bag) end
    b.locked, b.purchasable = nil, nil
    if bag >= 5 and bag - 4 > numBank then
      b.locked = true
      b.purchasable = (bag - 4 == numBank + 1)
    end
    SetItemButtonTexture(b, tex or EMPTY_BAG)
    SetItemButtonCount(b, 0)
    if b.locked then b.icon:SetVertexColor(1, 0.1, 0.1) else b.icon:SetVertexColor(1, 1, 1) end
    if hidden[bag] then b:SetAlpha(0.35) else b:SetAlpha(1) end
    b:Show()
  end
  for i = n + 1, table.getn(f.bagSlots) do f.bagSlots[i]:Hide() end
  return n * (BAGSLOT + 4) - 4
end

----------------------------------------------------------------------
-- character menu (view another character's bags or bank)
----------------------------------------------------------------------
local menu
function S:ToggleCharMenu(f)
  if not menu then
    menu = CreateFrame("Frame", "BaggyCharMenu", UIParent)
    menu:SetFrameStrata("DIALOG")
    menu:EnableMouse(true)
    menu:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    menu:SetBackdropColor(0, 0, 0, 0.95)
    menu.buttons = {}
    menu:Hide()
    table.insert(UISpecialFrames, "BaggyCharMenu")
  end
  if menu:IsShown() and menu.owner == f then menu:Hide(); return end
  menu.owner = f

  local names = self:CharNames()
  local width = 100
  for i = 1, table.getn(names) do
    local b = menu.buttons[i]
    if not b then
      b = CreateFrame("Button", nil, menu)
      b:SetHeight(16)
      b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      b.text:SetPoint("LEFT", b, "LEFT", 4, 0)
      b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
      b:SetScript("OnClick", function()
        local owner = menu.owner
        menu:Hide()
        owner.viewing = this.charName
        S:Refresh(owner)
      end)
      menu.buttons[i] = b
    end
    local name = names[i]
    local d = self:CharData(name)
    b.charName = name
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -8 - (i - 1) * 16)
    b:SetPoint("RIGHT", menu, "RIGHT", -8, 0)
    local mark = (name == f.viewing) and "|cffffd100>|r " or "   "
    b.text:SetText(mark .. S.ClassColored(name, d and d.class))
    local w = b.text:GetStringWidth() + 28
    if w > width then width = w end
    b:Show()
  end
  for i = table.getn(names) + 1, table.getn(menu.buttons) do menu.buttons[i]:Hide() end
  menu:SetWidth(width)
  menu:SetHeight(16 + table.getn(names) * 16)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", -6, -2)
  menu:Show()
end

----------------------------------------------------------------------
-- the window
----------------------------------------------------------------------
local function IconButton(f, texture, onClick, onEnter)
  local b = CreateFrame("Button", nil, f)
  b:SetWidth(18); b:SetHeight(18)
  local t = b:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints(b)
  t:SetTexture(texture)
  t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.icon = t
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    onEnter()
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local function CreateWindow(kind)
  local info = INFO[kind]
  local f = CreateFrame("Frame", info.name, UIParent)
  f:Hide()
  f.kind = kind
  f.bagFrames = {}
  f.bagSlots = {}
  f.shown = {}
  f.viewing = S.player
  f:SetFrameStrata("MEDIUM")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:SetWidth(MIN_W); f:SetHeight(200)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() if not S.db.locked then this:StartMoving() end end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing(); S:SavePosition(this) end)
  table.insert(UISpecialFrames, info.name)

  -- title (click to pick a character)
  local title = CreateFrame("Button", info.name .. "Title", f)
  title:SetHeight(18)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 2, -8)
  title:RegisterForDrag("LeftButton")
  title:SetScript("OnDragStart", function()
    if not S.db.locked then this:GetParent():StartMoving() end
  end)
  title:SetScript("OnDragStop", function()
    local p = this:GetParent()
    p:StopMovingOrSizing(); S:SavePosition(p)
  end)
  local tfs = title:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  tfs:SetPoint("LEFT", title, "LEFT", 0, 0)
  tfs:SetHeight(14)
  tfs:SetJustifyH("LEFT")
  title.text = tfs
  title:SetScript("OnClick", function() S:ToggleCharMenu(this:GetParent()) end)
  title:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(this.text:GetText())
    GameTooltip:AddLine("Click to view another character", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Drag to move", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  title:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.title = title

  -- top-right buttons
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetWidth(26); close:SetHeight(26)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function() this:GetParent():Hide() end)

  f.icons = {}
  local last = close
  local function add(b, gap)
    b:SetPoint("RIGHT", last, "LEFT", gap or -3, 0)
    last = b
    table.insert(f.icons, b)
  end

  add(IconButton(f, "Interface\\Icons\\INV_Misc_Gear_01",
    function() S:ToggleOptions() end,
    function() GameTooltip:SetText("Options") end), 0)

  if kind == "inventory" then
    add(IconButton(f, "Interface\\Icons\\INV_Misc_Spyglass_02",
      function() S:ToggleFind() end,
      function()
        GameTooltip:SetText("Search all characters")
        GameTooltip:AddLine("Find an item in every character's bags, bank and gear", 0.6, 0.6, 0.6)
      end))
    add(IconButton(f, BANK_ICON,
      function() S:Toggle("bank") end,
      function()
        GameTooltip:SetText("Bank")
        GameTooltip:AddLine("Show your bank, even away from a banker", 0.6, 0.6, 0.6)
      end))
  end

  f.sortButton = IconButton(f, "Interface\\Icons\\INV_Misc_Bag_10",
    function() S:Sort(this:GetParent().kind) end,
    function()
      GameTooltip:SetText("Sort")
      GameTooltip:AddLine("Stacks and sorts the items in your normal bags.", 0.6, 0.6, 0.6)
      GameTooltip:AddLine("Soul, herb, ammo and other special bags are left alone.", 0.6, 0.6, 0.6)
    end)
  add(f.sortButton)

  add(IconButton(f, "Interface\\Icons\\INV_Misc_Bag_08",
    function()
      local fdb = S.db.frames[this:GetParent().kind]
      fdb.showBags = not fdb.showBags
      S:Refresh(this:GetParent())
    end,
    function()
      GameTooltip:SetText("Bags")
      GameTooltip:AddLine("Show or hide the bag bar", 0.6, 0.6, 0.6)
    end))
  f.firstIcon = last

  -- search
  local search = CreateFrame("EditBox", info.name .. "Search", f, "InputBoxTemplate")
  search:SetHeight(18)
  search:SetAutoFocus(false)
  search:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 6, -TITLE_H + 2)
  search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD - 2, -TITLE_H + 2)
  local hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("LEFT", search, "LEFT", 2, 0)
  hint:SetText("Search")
  search:SetScript("OnTextChanged", function()
    local fr = this:GetParent()
    local text = this:GetText() or ""
    if text == "" then hint:Show() else hint:Hide() end
    fr.searchText = string.lower(text)
    S:UpdateSearch(fr)
  end)
  search:SetScript("OnEscapePressed", function() this:SetText(""); this:ClearFocus() end)
  search:SetScript("OnEnterPressed", function()
    this:ClearFocus()
    local text = this:GetText() or ""
    if S.db.enterSearchAll and text ~= "" then S:OpenFind(text) end
  end)
  f.search = search

  -- bag bar
  f.bagBar = CreateFrame("Frame", nil, f)
  f.bagBar:SetWidth(1); f.bagBar:SetHeight(BAGSLOT)

  -- bottom: free slots and money
  local free = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  free:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD + 2, 11)
  f.freeText = free

  local money = CreateFrame("Button", nil, f)
  money:SetHeight(16); money:SetWidth(150)
  money:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 2, 8)
  money.coins = S:CreateCoins(money)
  money.coins:SetPoint("RIGHT", money, "RIGHT", 0, 0)
  money:SetScript("OnEnter", function()
    if S.db.moneyAllChars then S:ShowMoneyTip(this) end
  end)
  money:SetScript("OnLeave", function() S:HideMoneyTip() end)
  f.money = money

  local empty = f:CreateFontString(nil, "ARTWORK", "GameFontDisable")
  empty:SetJustifyH("CENTER")
  f.emptyText = empty

  f:SetScript("OnShow", function()
    PlaySound("igBackPackOpen")
    S:ApplyPosition(this)
    S:Refresh(this)
  end)
  f:SetScript("OnHide", function()
    PlaySound("igBackPackClose")
    if menu and menu.owner == this then menu:Hide() end
    this.search:SetText("")
    this.search:ClearFocus()
    this.viewing = S.player
    this.autoShown = nil
    if this.kind == "bank" and S.atBank and S.db.replaceBank then
      S.atBank = false
      CloseBankFrame()
      CloseAllBags()
    end
  end)
  return f
end

function S:GetFrame(kind)
  local f = self.frames[kind]
  if not f then
    f = CreateWindow(kind)
    self.frames[kind] = f
    f:SetScale(self.db.frames[kind].scale)
    self:ApplyLook(f)
    self:ApplyPosition(f)
  end
  return f
end

----------------------------------------------------------------------
-- look and position
----------------------------------------------------------------------
function S:ApplyLook(f)
  local c = self.db.colors
  f:SetBackdropColor(c.bg[1], c.bg[2], c.bg[3], c.bg[4])
  f:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], c.border[4])
end

function S:ApplyPosition(f)
  local fdb = self.db.frames[f.kind]
  local old = f:GetScale()
  if fdb.pos and old and old > 0 and math.abs(old - fdb.scale) > 0.001 then
    -- keep the window where it is on screen when the scale changes
    fdb.pos[2] = fdb.pos[2] * old / fdb.scale
    fdb.pos[3] = fdb.pos[3] * old / fdb.scale
  end
  f:SetScale(fdb.scale)
  f:ClearAllPoints()
  local p = fdb.pos
  if p then
    f:SetPoint(p[1], UIParent, "BOTTOMLEFT", p[2], p[3])
  elseif f.kind == "inventory" then
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60 / fdb.scale, 110 / fdb.scale)
  else
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30 / fdb.scale, -110 / fdb.scale)
  end
end

-- bags grow up and left from the bottom-right corner, the bank grows down
-- and right from the top-left corner, like Blizzard's windows
function S:SavePosition(f)
  local fdb = self.db.frames[f.kind]
  if f.kind == "inventory" then
    fdb.pos = { "BOTTOMRIGHT", f:GetRight(), f:GetBottom() }
  else
    fdb.pos = { "TOPLEFT", f:GetLeft(), f:GetTop() }
  end
  self:ApplyPosition(f)
end

----------------------------------------------------------------------
-- draw everything
----------------------------------------------------------------------
function S:Refresh(f)
  if not f:IsShown() then return end
  local db = self.db
  local fdb = db.frames[f.kind]
  local cols = fdb.cols
  local spacing = db.spacing
  f.live = self:IsLive(f)

  -- title
  local d = self:CharData(f.viewing)
  local t = string.format(INFO[f.kind].title, f.viewing)
  if not f.live then t = t .. " |cff909090(saved)|r" end
  f.title.text:SetText(t)
  if f.live then f.sortButton:Show() else f.sortButton:Hide() end

  local top = TITLE_H
  if db.showSearch then
    f.search:Show()
    top = top + SEARCH_H
  else
    f.search:Hide()
  end

  local barW = 0
  local barBottom = (db.bagBarPos == "bottom")
  if fdb.showBags then
    barW = self:UpdateBagBar(f)
    f.bagBar:Show()
    if not barBottom then
      f.bagBar:ClearAllPoints()
      f.bagBar:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -top + 2)
      top = top + BAGBAR_H
    end
  else
    f.bagBar:Hide()
  end

  -- collect the slots to show: normal bags, then the keyring on its own rows
  local bags = self:FrameBags(f)
  local groups = { {}, {} }
  local total, used = 0, 0
  for i = 1, table.getn(bags) do
    local bag = bags[i]
    local size = self:BagSize(f, bag)
    local bf = GetBagFrame(f, bag)
    local kind
    if bag == S.KEYRING then
      kind = "keyring"
    elseif bag >= 1 then
      local _, _, k = self:BagItem(f, bag)
      kind = k
    end
    local hide = fdb.hidden[bag]
    local group = (bag == S.KEYRING) and groups[2] or groups[1]
    for slot = 1, size do
      local b = bf.buttons[slot]
      if not b then
        b = CreateItemButton(f, bf)
        b:SetID(slot)
        bf.buttons[slot] = b
      end
      b.bag, b.slot = bag, slot
      local has = self:UpdateItemButton(f, b, kind)
      if bag ~= S.KEYRING then
        total = total + 1
        if has then used = used + 1 end
      end
      if hide then
        b:Hide()
      else
        table.insert(group, b)
      end
    end
    for slot = size + 1, table.getn(bf.buttons) do bf.buttons[slot]:Hide() end
  end
  -- hide buttons of bags that aren't in this window any more (keyring turned off)
  for bag, bf in pairs(f.bagFrames) do
    local inList = false
    for i = 1, table.getn(bags) do if bags[i] == bag then inList = true end end
    if not inList then
      for slot = 1, table.getn(bf.buttons) do bf.buttons[slot]:Hide() end
    end
  end

  -- put the groups in order: keyring above or below the bags,
  -- slots inside each group reversed if asked
  local order = {}
  local groupOrder = (db.keyringPos == "top") and { 2, 1 } or { 1, 2 }
  for k = 1, 2 do
    local src = groups[groupOrder[k]]
    local seq = src
    if db.reverse then
      seq = {}
      for i = table.getn(src), 1, -1 do table.insert(seq, src[i]) end
    end
    if table.getn(seq) > 0 then table.insert(order, seq) end
  end

  -- lay them out, each group starting on a new row
  local list = {}
  local gy = 0
  for gi = 1, table.getn(order) do
    local seq = order[gi]
    local count = table.getn(seq)
    for i = 1, count do
      local b = seq[i]
      local col = math.mod(i - 1, cols)
      local row = math.floor((i - 1) / cols)
      local x = PAD + col * (SLOT + spacing)
      local y = -(top + gy + row * (SLOT + spacing))
      if b.px ~= x or b.py ~= y then
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        b.px, b.py = x, y
      end
      b:Show()
      table.insert(list, b)
    end
    local rows = math.ceil(count / cols)
    gy = gy + rows * SLOT + (rows - 1) * spacing
    if gi < table.getn(order) then gy = gy + GROUP_GAP end
  end
  f.shown = list
  local n = table.getn(list)

  local gridH = gy
  local width = PAD * 2 + cols * SLOT + (cols - 1) * spacing
  if width < MIN_W then width = MIN_W end
  if barW + PAD * 2 > width then width = barW + PAD * 2 end

  if n == 0 then
    gridH = 40
    f.emptyText:ClearAllPoints()
    f.emptyText:SetPoint("TOP", f, "TOP", 0, -top - 12)
    f.emptyText:SetWidth(width - PAD * 2)
    if f.kind == "bank" and not f.live and not (d and d.bankSeen) then
      f.emptyText:SetText("Visit a banker on " .. f.viewing .. " to save this bank.")
    else
      f.emptyText:SetText("Nothing to show.")
    end
    f.emptyText:Show()
  else
    f.emptyText:Hide()
  end

  local height = top + gridH + BOTTOM_H
  if fdb.showBags and barBottom then
    f.bagBar:ClearAllPoints()
    f.bagBar:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(top + gridH + 6))
    height = height + BAGBAR_H
  end
  f:SetWidth(width)
  f:SetHeight(height)

  -- title width: up to the first icon button
  local titleW = width - PAD - 2 - 26 - table.getn(f.icons) * 21 - 6
  if titleW < 40 then titleW = 40 end
  f.title:SetWidth(titleW)
  f.title.text:SetWidth(titleW)

  f.freeText:SetText(string.format("%d/%d", used, total))
  S:SetCoins(f.money.coins, d and d.money or 0)

  self:UpdateSearch(f)
end

function S:RefreshShown()
  for _, f in pairs(self.frames) do
    if f:IsShown() then self:Refresh(f) end
  end
  if self.RefreshFind then self:RefreshFind() end
end

function S:ApplyAll()
  self:UpdateBankHook()
  for _, f in pairs(self.frames) do
    self:ApplyLook(f)
    self:ApplyPosition(f)
    for _, bf in pairs(f.bagFrames) do
      for slot = 1, table.getn(bf.buttons) do bf.buttons[slot].px = nil end
    end
    if f:IsShown() then self:Refresh(f) end
  end
end
