function GetLocale() return "ruRU" end
function UnitName() return "Tester" end
local sent = {}
function SendAddonMessage(prefix, message, channel, target)
    assert(prefix == "AC_TRANSMOG" and channel == "WHISPER" and target == "Tester")
    table.insert(sent, message)
end
local events = {}
function CreateFrame()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, event, callback) events[event] = callback end,
    }
end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
dofile("Localization.lua")
dofile("Protocol.lua")
local Addon = SbTransmog
local shown, loading, status, keepDraft, opened, pageItems
Addon.draftSlots = { [0] = 42 }
Addon.GetDraftCount = function() return 1 end
Addon.UI = {
    frame = { Show = function() shown = true end },
    Create = function() end,
    SetLoading = function(_, value) loading = value end,
    SetStatus = function(_, text) status = text end,
    SetBusy = function() end,
    Open = function(_, keep)
        keepDraft = keep
        opened = (opened or 0) + 1
    end,
    ShowPage = function(_, meta, items)
        assert(meta.total == 2 and meta.page == 0)
        pageItems = items
    end,
}
dofile("Core.lua")

-- Login only negotiates; the slash command opens a remote session.
events.OnEvent(nil, "PLAYER_LOGIN")
events.OnUpdate(nil, 1)
assert(sent[#sent] == "HELLO\t5")
Addon:HandleProtocolMessage("HELLO_OK\t5")
assert(sent[#sent] == "HELLO\t5", "login must not open the window")
SlashCmdList.SBTRANSMOG("")
assert(shown and loading and sent[#sent] == "HELLO\t5")
Addon:HandleProtocolMessage("HELLO_OK\t5")
assert(sent[#sent] == "OPEN", "opening must not require gossip or an NPC")
local sentBeforeDuplicateHello = #sent
Addon:HandleProtocolMessage("HELLO_OK\t5")
assert(#sent == sentBeforeDuplicateHello, "duplicate hello replies must not open extra sessions")
Addon:HandleProtocolMessage("OPEN\t123")
assert(Addon.sessionId == 123 and opened == 1 and not keepDraft)
assert(sent[#sent]:match("^LIST_SETS\t%d+\t123$"))

-- Both filters travel with every page; quality zero must not become 'all'.
Addon:RequestList(0, 2, "МЕЧ\tЛьда", 4)
assert(sent[#sent]:match("^LIST\t%d+\t123\t0\t2\tМЕЧ Льда\t4$"))
Addon:RequestList(0, 0, "", 0)
assert(sent[#sent]:match("\t0\t0\t\t0$"))
Addon:RequestList(0, 0, "")
assert(sent[#sent]:match("\t0\t0\t\t255$"))
local count = #sent
Addon:RequestList(0, 0, string.rep("я", 51), 4)
assert(#sent == count and status == SbTransmogLocale.ERROR_SEARCH)

-- Rendering preserves the global quality ordering supplied by the server.
Addon:RequestList(0, 0, "", 4)
local id = Addon.latestListRequestId
Addon:HandleProtocolMessage("PAGE\t" .. id .. "\t0\t0\t1\t2\t0\t0\t1")
Addon:HandleProtocolMessage("ITEMS\t" .. id .. "\t0\t1\t200,100")
assert(pageItems[1] == 200 and pageItems[2] == 100)

-- A read can reopen an expired session while retaining the draft.
Addon:RequestList(0, 0, "", 4)
id = Addon.latestListRequestId
Addon:HandleProtocolMessage("RESULT\t" .. id .. "\tERROR\tSESSION")
assert(Addon.openRequested and not Addon.sessionId)
Addon:HandleProtocolMessage("HELLO_OK\t5")
Addon:HandleProtocolMessage("OPEN\t124")
assert(keepDraft and Addon.draftSlots[0] == 42)

-- Failed writes are never automatically repeated.
Addon:Apply(0, 42)
id = Addon.requestId
count = #sent
Addon:HandleProtocolMessage("RESULT\t" .. id .. "\tERROR\tSESSION")
assert(#sent == count and not Addon.openRequested and status == SbTransmogLocale.ERROR_SESSION)

Addon:RequestOpen()
Addon:HandleProtocolMessage("HELLO_ERROR\t4")
assert(not Addon.openRequested and not loading and status == SbTransmogLocale.INCOMPATIBLE)
Addon:RequestOpen()
Addon:HandleProtocolMessage("HELLO_OK\t5")
Addon:HandleProtocolMessage("RESULT\t0\tERROR\tUNAVAILABLE")
assert(not Addon.openRequested and not loading and status == SbTransmogLocale.ERROR_UNAVAILABLE)
Addon:RequestOpen()
events.OnUpdate(nil, 10)
assert(not Addon.openRequested and not loading and status == SbTransmogLocale.ERROR_NO_RESPONSE)

Addon.sessionId = 125
Addon:CloseSession()
assert(sent[#sent] == "CLOSE\t125" and not Addon.sessionId)
assert(next(Addon.pendingLists) == nil and next(Addon.pendingSets) == nil)
print("protocol_test: ok")
