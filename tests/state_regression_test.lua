function GetLocale() return "enUS" end
function UnitName() return "Tester" end
local sent, events = {}, {}
function SendAddonMessage(_, message) sent[#sent + 1] = message end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function(_, event, callback) events[event] = callback end }
end
function GetItemInfo(item) return "Item", item end
function GetInventoryItemLink(_, slot) return "item:" .. slot end
function GetCoinTextureString(amount) return tostring(amount) end
SlashCmdList, StaticPopupDialogs = {}, {}
YES, NO = "Yes", "No"
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
dofile("Localization.lua")
dofile("Protocol.lua")
dofile("ModelPreview.lua")
dofile("UI.lua")
local A, U = SbTransmog, SbTransmog.UI
local shown, price, opened = true, "", 0
local function button()
    return { Enable = function(self) self.enabled = true end, Disable = function(self) self.enabled = false end }
end
U.apply, U.remove, U.resetAll, U.cancelDraft = button(), button(), button(), button()
U.slotButtons, U.itemButtons = {}, {}
U.priceText = { SetText = function(_, value) price = value end }
U.frame = { Show = function() shown = true end, IsShown = function() return shown end }
U.gridOverlay = { Show = function() end, Hide = function() end }
U.status = { SetText = function() end, SetTextColor = function() end }
function U:Create() end
function U:Open(keep)
    opened = opened + 1
    shown = true
    self.busy = false
    if not keep then A:ClearDraft() end
end
function U:RefreshCurrentPage() end
function U:ShowPage(meta, items) self.rendered = items end
function U:ShowSavedSets() end
dofile("Core.lua")

local function snapshot(session)
    A:HandleProtocolMessage("STATE_BEGIN\t" .. session .. "\t1\t49426\t2")
    for slot = 0, 18 do
        A:HandleProtocolMessage("EQUIP\t" .. session .. "\t" .. slot .. "\t100\t0\t2000\t0")
    end
    A:HandleProtocolMessage("STATE_END\t" .. session)
end
local function reopen(session)
    A:RequestOpen(true)
    A:HandleProtocolMessage("HELLO_OK\t6")
    A:HandleProtocolMessage("OPEN\t" .. session .. "\t" .. A.openRequestId)
    snapshot(session)
end

reopen(123)
A.draftSlots = { [0] = 1001, [2] = 1002 }
U:UpdateDraftState()
assert(price == "2 changes, total: 200 + 4 x Item", "a saved outfit must quote unvisited slots and tokens")
assert(U.apply.enabled)
A.quoteReady = false
U:UpdateDraftState()
assert(not U.apply.enabled and price:find("Loading"), "unknown prices must never be shown as zero")
snapshot(123)

-- Incomplete snapshots remain unquoted; reconciliation removes already-applied changes.
A:HandleProtocolMessage("STATE_BEGIN\t123\t2\t49426\t2")
A:HandleProtocolMessage("EQUIP\t123\t0\t100\t1001\t2000\t0")
A:HandleProtocolMessage("STATE_END\t123")
assert(not A.quoteReady)
for slot = 1, 18 do A:HandleProtocolMessage("EQUIP\t123\t" .. slot .. "\t100\t0\t2000\t0") end
A:HandleProtocolMessage("STATE_END\t123")
assert(A.quoteReady and A.draftSlots[0] == nil and A.draftSlots[2] == 1002)
A.draftSlots[0] = 1001
snapshot(123)

-- Only the result matching the write can release its busy state.
A:RequestList(0, 0, "")
A:UpdateProtocol(0.2)
local read = A.latestListRequestId
A:ApplyOutfit()
local write = A.pendingOperation.id
assert(U.busy)
A:HandleProtocolMessage("RESULT\t" .. read .. "\tERROR\tEMPTY_SLOT")
assert(U.busy and A.pendingOperation.id == write)
A:HandleProtocolMessage("SET_RESULT\t" .. A.latestSetsRequestId .. "\tERROR\tSETS_DISABLED")
assert(U.busy)
local count = #sent
A:ApplyOutfit()
assert(#sent == count, "a second write must not be sent while one is pending")
A:HandleProtocolMessage("RESULT\t" .. write .. "\tERROR\tTRANSMOG_7")
assert(not U.busy and A:GetDraftCount() == 2)

-- Coalesce quick input, and recover a throttled read without repeating writes.
A:RequestList(0, 0, "one")
A:RequestList(2, 1, "two", 4)
count = #sent
A:UpdateProtocol(0.1)
assert(#sent == count)
A:UpdateProtocol(0.1)
assert(#sent == count + 1 and sent[#sent]:find("\t2\t1\ttwo\t4", 1, true))
read = A.latestListRequestId
A:HandleProtocolMessage("RESULT\t" .. read .. "\tERROR\tTHROTTLED")
A:UpdateProtocol(0.2)
read = A.latestListRequestId
A:HandleProtocolMessage("PAGE\t" .. read .. "\t2\t1\t2\t2\t100\t0\t2000")
A:HandleProtocolMessage("ITEMS\t" .. read .. "\t0\t1\t1002,1001")
assert(U.rendered[1] == 1002 and U.rendered[2] == 1001)

-- Expired writes reopen for a new snapshot but do not submit payment again.
A:ApplyOutfit()
write = A.pendingOperation.id
count = #sent
A:HandleProtocolMessage("RESULT\t" .. write .. "\tERROR\tSESSION")
assert(#sent == count + 1 and sent[#sent] == "HELLO\t6" and A:GetDraftCount() == 2)
A:HandleProtocolMessage("HELLO_OK\t6")
A:HandleProtocolMessage("OPEN\t124\t" .. A.openRequestId)
snapshot(124)
assert(A:GetDraftCount() == 2)

-- Closing cancels the exact open request; delayed replies cannot resurrect it.
A:RequestOpen(true)
A:HandleProtocolMessage("HELLO_OK\t6")
local opening, before = A.openRequestId, opened
shown = false
A:CloseSession()
A:HandleProtocolMessage("OPEN\t125\t" .. opening)
assert(not shown and opened == before and not A.sessionId)
assert(sent[#sent] == "CLOSE\t125")

-- Missing write replies release the UI and reconcile; late replies are ignored.
reopen(126)
A:ApplyOutfit()
write = A.pendingOperation.id
A:UpdateProtocol(15)
assert(not A.pendingOperation and not U.busy and A.openRequested)
A:HandleProtocolMessage("RESULT\t" .. write .. "\tOK\tOUTFIT\t2\t100")
assert(A:GetDraftCount() == 2, "an obsolete write reply must not erase the retained draft")
A:HandleProtocolMessage("HELLO_OK\t6")
A:HandleProtocolMessage("OPEN\t127\t" .. A.openRequestId)
snapshot(127)

-- A legacy hidden slot survives SET decoding, loading, quoting and saving.
A.pendingSets[900] = { sets = {}, received = {}, remaining = 1, maxSets = 10 }
A.latestSetsRequestId = 900
A:HandleProtocolMessage("SET\t900\t0\tHidden outfit\t0:1,4:1002")
assert(A:LoadSavedSet(0) and A.draftSlots[0] == 1)
assert(A:GetEffectiveOutfit()[0] == 1)
U:UpdateDraftState()
assert(price == "2 changes, total: 100 + 2 x Item")

-- Equipment changes invalidate just the affected draft slot and request fresh prices.
U.selectedSlot = 0
A.draftSlots = { [0] = 1001, [2] = 1002 }
events.OnEvent(nil, "PLAYER_EQUIPMENT_CHANGED", 1)
assert(not A.draftSlots[0] and A.draftSlots[2] == 1002 and not A.quoteReady)
assert(sent[#sent] == "STATE\t127")

-- Reads have bounded lifetimes and do not leave pending tables growing.
A:RequestList(0, 0, "")
A:UpdateProtocol(0.2)
A.stateElapsed = nil
A:UpdateProtocol(10)
assert(next(A.pendingLists) == nil and next(A.pendingSets) == nil)
print("state_regression_test: ok")
