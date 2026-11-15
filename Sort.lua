-- Baggy: stack and sort. One move at a time, waiting for the server to
-- confirm each one, which is the only safe way to do it on the 1.12 client.

local S = Baggy

local TYPE_ORDER = {
  ["Weapon"] = 1, ["Armor"] = 2, ["Consumable"] = 3, ["Trade Goods"] = 4,
  ["Reagent"] = 5, ["Recipe"] = 6, ["Projectile"] = 7, ["Quiver"] = 8,
  ["Container"] = 9, ["Key"] = 10, ["Miscellaneous"] = 11, ["Quest"] = 12,
}
local HEARTHSTONE = 6948

local job
local runner = CreateFrame("Frame")
runner:Hide()

local function Stop(msg)
  job = nil
  runner:Hide()
  if msg then S.Print(msg) end
end

-- normal bags only: special bags only take certain items
local function SortableBags(kind)
  local list = (kind == "bank") and { -1, 5, 6, 7, 8, 9, 10 } or { 0, 1, 2, 3, 4 }
  local bags = {}
  for i = 1, table.getn(list) do
    local bag = list[i]
    local inv = S:BagInvSlot(bag)
    local special = inv and S:BagKind(GetInventoryItemLink("player", inv))
    if not special and S:NumSlots(bag) > 0 then table.insert(bags, bag) end
  end
  return bags
end

local function Describe(link, count)
  local is = S.ItemString(link)
  local name, _, q, _, itype, sub, stack, equipLoc = GetItemInfo(is or "")
  local id = S.ItemID(link)
  local group = 1
  if id == HEARTHSTONE then group = 0 elseif q == 0 then group = 2 end
  return {
    key = S.ItemKey(link) or link,
    count = count or 1,
    group = group,
    t = TYPE_ORDER[itype or ""] or 50,
    sub = sub or "",
    equip = equipLoc or "",
    q = q or 1,
    name = name or S.ItemName(link) or "",
    stack = stack or 1,
  }
end

local function Before(a, b)
  if a.group ~= b.group then return a.group < b.group end
  if a.t ~= b.t then return a.t < b.t end
  if a.sub ~= b.sub then return a.sub < b.sub end
  if a.equip ~= b.equip then return a.equip < b.equip end
  if a.q ~= b.q then return a.q > b.q end
  if a.name ~= b.name then return a.name < b.name end
  if a.key ~= b.key then return a.key < b.key end
  return a.count > b.count
end

local function Same(a, b)
  if not a and not b then return true end
  if not a or not b then return false end
  return a.key == b.key and a.count == b.count
end

-- one move; returns "wait", "moved" or "done"
local function Step()
  local slots = job.slots
  local n = table.getn(slots)
  local items = {}
  for i = 1, n do
    local bag, slot = slots[i][1], slots[i][2]
    local _, count, locked = GetContainerItemInfo(bag, slot)
    if locked then return "wait" end
    local link = GetContainerItemLink(bag, slot)
    if link then items[i] = Describe(link, count) end
  end
  if CursorHasItem() then return "busy" end

  -- 1) merge partial stacks
  for i = 1, n do
    local a = items[i]
    if a and a.stack > 1 and a.count < a.stack then
      for j = i + 1, n do
        local b = items[j]
        if b and b.key == a.key and b.count < b.stack then
          local amount = a.stack - a.count
          if amount >= b.count then
            PickupContainerItem(slots[j][1], slots[j][2])
          else
            SplitContainerItem(slots[j][1], slots[j][2], amount)
          end
          PickupContainerItem(slots[i][1], slots[i][2])
          return "moved"
        end
      end
    end
  end

  -- 2) put things in order
  local want = {}
  for i = 1, n do
    if items[i] then table.insert(want, items[i]) end
  end
  table.sort(want, Before)
  for i = 1, n do
    if not Same(want[i], items[i]) then
      local target = want[i]
      if not target then return "done" end
      for j = i + 1, n do
        if Same(target, items[j]) then
          local src, dst = slots[j], slots[i]
          local here = items[i]
          -- same item in both slots: always drop the smaller stack onto the
          -- full one so the game swaps them instead of merging
          if here and here.key == target.key and here.count < target.count then
            src, dst = slots[i], slots[j]
          end
          PickupContainerItem(src[1], src[2])
          PickupContainerItem(dst[1], dst[2])
          return "moved"
        end
      end
      return "done"
    end
  end
  return "done"
end

runner:SetScript("OnUpdate", function()
  if not job then this:Hide(); return end
  job.elapsed = job.elapsed + arg1
  if job.elapsed < 0.05 then return end
  job.elapsed = 0
  if job.kind == "bank" and not S.atBank then return Stop("bank closed, sorting stopped.") end
  local result = Step()
  if result == "wait" or result == "busy" then
    job.waited = job.waited + 1
    if job.waited > 100 then
      if result == "busy" then return Stop("sorting stopped: put down the item on your cursor first.") end
      return Stop("sorting stopped: items stayed locked too long.")
    end
  elseif result == "moved" then
    job.waited = 0
    job.moves = job.moves + 1
    if job.moves > 600 then return Stop("sorting stopped after too many moves.") end
  else
    Stop()
    S:RefreshShown()
  end
end)

function S:Sort(kind)
  if job then return end
  if kind == "bank" and not self.atBank then
    self.Print("you need to be at a banker to sort your bank.")
    return
  end
  if CursorHasItem() then
    self.Print("put down the item on your cursor first.")
    return
  end
  local bags = SortableBags(kind)
  local slots = {}
  for i = 1, table.getn(bags) do
    for slot = 1, self:NumSlots(bags[i]) do
      table.insert(slots, { bags[i], slot })
    end
  end
  job = { kind = kind, slots = slots, elapsed = 0, waited = 0, moves = 0 }
  runner:Show()
end
