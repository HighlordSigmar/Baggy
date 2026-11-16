-- Baggy: all your bags in one window, plus your bank and your alts' items.
-- In the spirit of Bagnon. Written for the 1.12 client (OctoWoW), Lua 5.0.

Baggy = {}
local S = Baggy
local ADDON = "Baggy"

S.KEYRING = KEYRING_CONTAINER or -2

S.defaults = {
  replaceBags = true,       -- our window instead of Blizzard's bags
  replaceBank = true,       -- our window instead of Blizzard's bank
  openMail = true,
  openAH = true,
  openTrade = true,
  openMerchant = true,
  showKeyring = false,
  tooltipCounts = true,     -- "Juan: 12 (Bags 5, Bank 7)" lines on item tooltips
  tooltipTotal = true,
  locked = false,
  spacing = 2,
  qualityGlow = true,       -- colored border on green and better
  glowPoor = false,         -- grey border on junk too
  questGlow = true,         -- yellow border on quest items
  bagColors = true,         -- tint empty slots of soul / herb / ammo bags
  reverse = false,
  showSearch = true,
  enterSearchAll = true,    -- Enter in a bag search box searches every character
  moneyAllChars = true,     -- money tooltip with every character on the realm
  bagBarPos = "top",        -- top | bottom
  keyringPos = "bottom",    -- keyring rows above or below the bag slots
  slotStyle = "blizzard",   -- blizzard | flat | flatclean
  colors = {
    bg      = { 0.05, 0.05, 0.05, 0.85 },
    border  = { 0.55, 0.55, 0.55, 1 },
    slot    = { 0.12, 0.12, 0.12, 0.9 },   -- empty slots in the flat styles
    keyring = { 1, 0.78, 0.3, 1 },         -- frame around keyring slots
  },
  frames = {
    inventory = { cols = 10, scale = 1, showBags = false, hidden = {} },
    bank      = { cols = 14, scale = 1, showBags = false, hidden = {} },
  },
}

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------
local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffd9a066Baggy:|r " .. msg)
end
S.Print = Print

local function CopyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function S.ItemString(link)
  if not link then return nil end
  local _, _, s = string.find(link, "(item:%d+:%d+:%d+:%d+)")
  return s
end

-- id:enchant:suffix, the part that decides whether two items stack
function S.ItemKey(link)
  if not link then return nil end
  local _, _, id, ench, suffix = string.find(link, "item:(%d+):(%d+):(%d+)")
  if not id then return nil end
  return id .. ":" .. ench .. ":" .. suffix
end

function S.ItemID(link)
  if not link then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  return id and tonumber(id)
end

function S.ItemName(link)
  if not link then return nil end
  local _, _, name = string.find(link, "%[(.-)%]")
  return name
end

local HEX_QUALITY = {
  ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3,
  ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6,
}

function S.ItemQuality(link)
  if not link then return nil end
  local is = S.ItemString(link)
  if is then
    local _, _, q = GetItemInfo(is)
    if q then return q end
  end
  local _, _, hex = string.find(link, "|c%x%x(%x%x%x%x%x%x)")
  return hex and HEX_QUALITY[string.lower(hex)]
end

S.QUALITY_COLORS = {
  [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 },       [2] = { 0.12, 1, 0 },
  [3] = { 0, 0.44, 0.87 },    [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
  [6] = { 0.9, 0.8, 0.5 },
}

function S.FormatMoney(copper)
  copper = copper or 0
  local g = math.floor(copper / 10000)
  local s = math.floor(math.mod(copper, 10000) / 100)
  local c = math.mod(copper, 100)
  local t = ""
  if g > 0 then t = g .. "|cffffd700g|r " end
  if g > 0 or s > 0 then t = t .. s .. "|cffc7c7cfs|r " end
  return t .. c .. "|cffeda55fc|r"
end

function S:IsInventoryBag(bag)
  return bag and ((bag >= 0 and bag <= 4) or bag == S.KEYRING)
end

function S:IsBankBag(bag)
  return bag and (bag == -1 or (bag >= 5 and bag <= 10))
end

-- inventory slot holding the bag itself (nil for backpack, bank, keyring)
function S:BagInvSlot(bag)
  if bag >= 1 and bag <= 4 then return ContainerIDToInventoryID(bag) end
  if bag >= 5 and bag <= 10 then return BankButtonIDToInvSlotID(bag - 4, 1) end
  return nil
end

function S:NumSlots(bag)
  if bag == S.KEYRING and GetKeyRingSize then return GetKeyRingSize() or 0 end
  return GetContainerNumSlots(bag) or 0
end

-- what kind of bag an item link is: nil for a normal bag
function S:BagKind(link)
  if not link then return nil end
  local is = S.ItemString(link)
  if not is then return nil end
  local _, _, _, _, itype, sub = GetItemInfo(is)
  if not itype then return nil end
  if itype == "Quiver" then
    if sub == "Ammo Pouch" then return "ammo" end
    return "quiver"
  end
  if itype == "Container" or itype == "Bag" then
    if sub == "Soul Bag" then return "soul" end
    if sub == "Herb Bag" then return "herb" end
    if sub == "Enchanting Bag" then return "enchant" end
    if sub and sub ~= "Bag" then return "special" end
  end
  return nil
end

S.BAG_KIND_COLORS = {
  ammo    = { 1, 0.85, 0.4 },
  quiver  = { 1, 0.85, 0.4 },
  soul    = { 0.75, 0.45, 1 },
  herb    = { 0.45, 1, 0.45 },
  enchant = { 0.5, 0.7, 1 },
  special = { 0.6, 1, 1 },
}

----------------------------------------------------------------------
-- saved character data
----------------------------------------------------------------------
function S:Realm()
  return BaggyDB.realms[self.realm]
end

function S:CharData(name)
  local r = BaggyDB.realms[self.realm]
  return r and r[name or self.player]
end

function S:CharNames()
  local t = {}
  for name in pairs(self:Realm()) do table.insert(t, name) end
  table.sort(t, function(a, b)
    if a == S.player then return true end
    if b == S.player then return false end
    return a < b
  end)
  return t
end

function S:ScanBag(bag)
  if not self.me then return end
  local size = self:NumSlots(bag)
  local b = { size = size }
  local inv = self:BagInvSlot(bag)
  if inv then
    b.link = GetInventoryItemLink("player", inv)
    b.tex = GetInventoryItemTexture("player", inv)
    b.kind = self:BagKind(b.link)
  end
  for slot = 1, size do
    local link = GetContainerItemLink(bag, slot)
    if link then
      local tex, count = GetContainerItemInfo(bag, slot)
      b[slot] = { l = link, c = count or 1, t = tex }
    end
  end
  self.me.bags[bag] = b
  if self.MarkIndexDirty then self:MarkIndexDirty() end
end

function S:ScanEquipment()
  if not self.me then return end
  local e = {}
  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    if link then e[slot] = { l = link } end
  end
  self.me.equip = e
  if self.MarkIndexDirty then self:MarkIndexDirty() end
end

function S:ScanInventory()
  for bag = 0, 4 do self:ScanBag(bag) end
  self:ScanBag(S.KEYRING)
end

function S:ScanBank()
  self.me.bankSlots = GetNumBankSlots()
  self:ScanBag(-1)
  for bag = 5, 10 do self:ScanBag(bag) end
  self.me.bankSeen = true
end

function S:ForgetCharacter(name)
  local r = self:Realm()
  if name == self.player then
    Print("you can't forget the character you're playing.")
    return
  end
  for n in pairs(r) do
    if string.lower(n) == string.lower(name or "") then
      r[n] = nil
      for _, f in pairs(self.frames) do
        if f.viewing == n then f.viewing = self.player end
      end
      if self.MarkIndexDirty then self:MarkIndexDirty() end
      Print("forgot " .. n .. ".")
      self:RefreshShown()
      return
    end
  end
  Print("no saved character called " .. (name or "?") .. " on this realm.")
end

----------------------------------------------------------------------
-- opening and closing
----------------------------------------------------------------------
function S:Open(kind, auto)
  local f = self:GetFrame(kind)
  if f:IsShown() then return end
  f.autoShown = auto and true or nil
  f:Show()
end

-- autoOnly: only close it if something else opened it (a mailbox, a vendor...)
function S:Close(kind, autoOnly)
  local f = self.frames[kind]
  if not f or not f:IsShown() then return end
  if autoOnly and not f.autoShown then return end
  f:Hide()
end

function S:Toggle(kind)
  local f = self:GetFrame(kind)
  if f:IsShown() then
    f:Hide()
  else
    f.autoShown = nil
    f:Show()
  end
end

function S:ToggleKeyring()
  local f = self:GetFrame("inventory")
  if f:IsShown() and self.db.showKeyring then
    self.db.showKeyring = false
  else
    self.db.showKeyring = true
    if not f:IsShown() then f.autoShown = nil; f:Show() end
  end
  self:RefreshShown()
end

-- a vendor / bank window is open and the player turned auto-open off for it
local function Suppressed()
  if MerchantFrame and MerchantFrame:IsVisible() and not S.db.openMerchant then return true end
  return false
end

----------------------------------------------------------------------
-- replace the Blizzard bag functions
----------------------------------------------------------------------
local orig = {}
local function Replace(name, fn)
  if not getglobal(name) then return end
  orig[name] = getglobal(name)
  setglobal(name, fn)
end

function S:InstallHooks()
  Replace("ToggleBackpack", function()
    if S.db.replaceBags then S:Toggle("inventory") else orig.ToggleBackpack() end
  end)
  Replace("OpenBackpack", function()
    if S.db.replaceBags then
      if not Suppressed() then S:Open("inventory", true) end
    else orig.OpenBackpack() end
  end)
  Replace("CloseBackpack", function()
    if S.db.replaceBags then S:Close("inventory", true) else orig.CloseBackpack() end
  end)
  Replace("ToggleBag", function(id)
    if S.db.replaceBags and S:IsInventoryBag(id) then S:Toggle("inventory")
    elseif S.db.replaceBank and S:IsBankBag(id) then S:Toggle("bank")
    else orig.ToggleBag(id) end
  end)
  Replace("OpenBag", function(id)
    if S.db.replaceBags and S:IsInventoryBag(id) then
      if not Suppressed() then S:Open("inventory", true) end
    elseif S.db.replaceBank and S:IsBankBag(id) then S:Open("bank", true)
    else orig.OpenBag(id) end
  end)
  Replace("CloseBag", function(id)
    if S.db.replaceBags and S:IsInventoryBag(id) then S:Close("inventory", true)
    elseif S.db.replaceBank and S:IsBankBag(id) then -- the bank closes with the banker
    else orig.CloseBag(id) end
  end)
  Replace("OpenAllBags", function(force)
    if S.db.replaceBags then
      if force then
        if not Suppressed() then S:Open("inventory", true) end
      else
        S:Toggle("inventory")
      end
    else orig.OpenAllBags(force) end
  end)
  Replace("CloseAllBags", function()
    if S.db.replaceBags then S:Close("inventory", true) else orig.CloseAllBags() end
  end)
  Replace("ToggleKeyRing", function()
    if S.db.replaceBags then S:ToggleKeyring() else orig.ToggleKeyRing() end
  end)
  self:UpdateBankHook()
end

-- stop the Blizzard bank window from opening while ours is in charge
function S:UpdateBankHook()
  if not BankFrame then return end
  if self.db.replaceBank then
    BankFrame:UnregisterEvent("BANKFRAME_OPENED")
  else
    BankFrame:RegisterEvent("BANKFRAME_OPENED")
  end
end

----------------------------------------------------------------------
-- bank
----------------------------------------------------------------------
function S:BankOpened()
  self.atBank = true
  self:ScanBank()
  if self.db.replaceBank then
    local f = self:GetFrame("bank")
    f.viewing = self.player
    if f:IsShown() then self:Refresh(f) else f.autoShown = true; f:Show() end
    OpenAllBags(1)
  end
  self:RefreshShown()
end

function S:BankClosed()
  if not self.atBank then return end
  self.atBank = false
  if self.db.replaceBank then
    self:Close("bank")
    CloseAllBags()
  end
  self:RefreshShown()
end

----------------------------------------------------------------------
-- batched updates: many BAG_UPDATEs in one frame become one redraw
----------------------------------------------------------------------
local pendingBags = {}
local pendingOpen = false
local updater = CreateFrame("Frame")
updater:Hide()
updater:SetScript("OnUpdate", function()
  this:Hide()
  for bag in pairs(pendingBags) do
    S:ScanBag(bag)
    pendingBags[bag] = nil
  end
  if pendingOpen then
    pendingOpen = false
    if S.db.replaceBags then S:Open("inventory", true) end
  end
  S:RefreshShown()
end)

function S:Queue(bag)
  if bag then pendingBags[bag] = true end
  updater:Show()
end

function S:QueueOpen()
  pendingOpen = true
  updater:Show()
end

----------------------------------------------------------------------
-- events
----------------------------------------------------------------------
function S:InitDB()
  BaggyDB = BaggyDB or {}
  BaggyDB.settings = BaggyDB.settings or {}
  CopyDefaults(self.defaults, BaggyDB.settings)
  BaggyDB.realms = BaggyDB.realms or {}
  self.db = BaggyDB.settings
end

function S:ResetSettings()
  BaggyDB.settings = {}
  CopyDefaults(self.defaults, BaggyDB.settings)
  self.db = BaggyDB.settings
  self:UpdateBankHook()
  self:ApplyAll()
  if self.RefreshOptions then self:RefreshOptions() end
end

function S:Login()
  self.player = UnitName("player")
  self.realm = (GetRealmName and GetRealmName()) or GetCVar("realmName") or "Realm"
  BaggyDB.realms[self.realm] = BaggyDB.realms[self.realm] or {}
  local r = BaggyDB.realms[self.realm]
  r[self.player] = r[self.player] or {}
  self.me = r[self.player]
  self.me.bags = self.me.bags or {}
  local _, class = UnitClass("player")
  self.me.class = class
  self.me.faction = UnitFactionGroup("player")
  self.me.money = GetMoney()
  self:ScanInventory()
  self:ScanEquipment()
  self:InstallHooks()
  if self.InstallTooltipHooks then self:InstallTooltipHooks() end
end

local ev = CreateFrame("Frame")
local EVENTS = {
  "ADDON_LOADED", "PLAYER_LOGIN", "BAG_UPDATE", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN",
  "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
  "PLAYER_MONEY", "UNIT_INVENTORY_CHANGED",
  "MAIL_SHOW", "MAIL_CLOSED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
  "TRADE_SHOW", "TRADE_CLOSED", "MERCHANT_SHOW", "MERCHANT_CLOSED",
}
for i = 1, table.getn(EVENTS) do ev:RegisterEvent(EVENTS[i]) end

ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then S:InitDB() end
    return
  end
  if event == "PLAYER_LOGIN" then S:Login(); return end
  if not S.me then return end

  if event == "BAG_UPDATE" then
    if S:IsInventoryBag(arg1) or (S.atBank and S:IsBankBag(arg1)) then S:Queue(arg1) end
  elseif event == "ITEM_LOCK_CHANGED" or event == "BAG_UPDATE_COOLDOWN" then
    S:Queue()
  elseif event == "PLAYERBANKSLOTS_CHANGED" then
    if S.atBank then S:Queue(-1) end
  elseif event == "PLAYERBANKBAGSLOTS_CHANGED" then
    if S.atBank then
      S.me.bankSlots = GetNumBankSlots()
      for bag = 5, 10 do S:Queue(bag) end
    end
  elseif event == "BANKFRAME_OPENED" then
    S:BankOpened()
  elseif event == "BANKFRAME_CLOSED" then
    S:BankClosed()
  elseif event == "PLAYER_MONEY" then
    S.me.money = GetMoney()
    S:Queue()
  elseif event == "UNIT_INVENTORY_CHANGED" then
    if arg1 == "player" then
      S:ScanEquipment()
      for bag = 1, 4 do S:Queue(bag) end
    end
  elseif event == "MAIL_SHOW" then
    if S.db.openMail then S:QueueOpen() end
  elseif event == "AUCTION_HOUSE_SHOW" then
    if S.db.openAH then S:QueueOpen() end
  elseif event == "TRADE_SHOW" then
    if S.db.openTrade then S:QueueOpen() end
  elseif event == "MERCHANT_SHOW" then
    if S.db.openMerchant then S:QueueOpen() end
  elseif event == "MAIL_CLOSED" or event == "AUCTION_HOUSE_CLOSED"
      or event == "TRADE_CLOSED" or event == "MERCHANT_CLOSED" then
    S:Close("inventory", true)
  end
end)

----------------------------------------------------------------------
-- slash command
----------------------------------------------------------------------
SLASH_BAGGY1 = "/baggy"
SlashCmdList["BAGGY"] = function(msg)
  msg = msg or ""
  local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")
  if cmd == "" or cmd == "options" or cmd == "config" then
    S:ToggleOptions()
  elseif cmd == "bags" then
    S:Toggle("inventory")
  elseif cmd == "bank" then
    S:Toggle("bank")
  elseif cmd == "sort" then
    S:Sort("inventory")
  elseif cmd == "sortbank" then
    S:Sort("bank")
  elseif cmd == "find" or cmd == "search" then
    if rest ~= "" then S:OpenFind(rest) else S:ToggleFind() end
  elseif cmd == "keyring" then
    S:ToggleKeyring()
  elseif cmd == "lock" then
    S.db.locked = true; Print("windows locked.")
  elseif cmd == "unlock" then
    S.db.locked = false; Print("windows unlocked.")
  elseif cmd == "forget" then
    S:ForgetCharacter(rest)
  elseif cmd == "resetpos" then
    S.db.frames.inventory.pos = nil
    S.db.frames.bank.pos = nil
    S:ApplyAll()
    Print("window positions reset.")
  elseif cmd == "reset" then
    S:ResetSettings()
    Print("all settings reset to defaults.")
  else
    Print("commands:")
    Print("/baggy - options    /baggy bags - toggle bags    /baggy bank - toggle bank")
    Print("/baggy sort - sort bags    /baggy sortbank - sort bank (at a banker)")
    Print("/baggy find <text> - search every character's bags, bank and gear")
    Print("/baggy keyring    /baggy lock | unlock    /baggy resetpos")
    Print("/baggy forget <name> - delete a character's saved items    /baggy reset")
  end
end
