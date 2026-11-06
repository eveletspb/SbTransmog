function GetLocale() return "ruRU" end
dofile("Localization.lua")
function UnitName() return "Tester" end
local sent
function SendAddonMessage(_, message) sent = message end
SlashCmdList = {}
dofile("Protocol.lua")
StaticPopupDialogs = {}
UISpecialFrames = {}
YES, NO = "Yes", "No"
local frames = {}
local function Frame()
    return setmetatable({ scripts = {} }, { __index = function(self, key)
        if key == "SetScript" then return function(_, name, callback) self.scripts[name] = callback end end
        if key == "GetFrameLevel" then return function() return 1 end end
        if key == "CreateTexture" or key == "CreateFontString" or key == "GetFontString" then return Frame end
        if key == "GetText" then return function() return self.text or "" end end
        if key == "SetText" then return function(_, text) self.text = text end end
        return function() end
    end })
end
function CreateFrame(_, name)
    local frame = Frame()
    if name then frames[name] = frame end
    return frame
end
function UIDropDownMenu_SetWidth(frame, width)
    assert(type(frame) == "table" and type(width) == "number", "WoW 3.3.5 expects SetWidth(frame, width)")
    frame.width = width
end
function UIDropDownMenu_SetText(frame, text)
    assert(type(frame) == "table" and type(text) == "string", "WoW 3.3.5 expects SetText(frame, text)")
    frame.text = text
end
function UIDropDownMenu_Initialize(frame, callback)
    frame.initialize = callback
    callback(frame)
end
function UIDropDownMenu_CreateInfo() return {} end
local entries = {}
function UIDropDownMenu_AddButton(info) table.insert(entries, info) end
for quality = 0, 7 do _G["ITEM_QUALITY" .. quality .. "_DESC"] = "Quality " .. quality end

dofile("UI.lua")
dofile("Core.lua")
local UI = SbTransmog.UI
assert(SLASH_SBTRANSMOG1 == "/transmog")
SlashCmdList.SBTRANSMOG("")
assert(sent == "HELLO\t6" and SbTransmog.openRequested == "hello", "the slash command must create the UI and start the handshake")
UI.selectedSlot = 15
UI.search:SetText("Меч")
local requested
function SbTransmog:RequestList(slot, page, search, quality)
    requested = { slot, page, search, quality }
end
local filter = frames.SbTransmogQualityFilter
assert(filter.width == 130 and filter.text == SbTransmogLocale.ALL_QUALITIES)
local function OpenDropdown()
    entries = {}
    filter.initialize()
    assert(#entries == 9)
end
OpenDropdown()
assert(entries[1].checked and entries[1].text == SbTransmogLocale.ALL_QUALITIES)
entries[6].func() -- Epic (4), after All and qualities 0..3.
assert(UI.selectedQuality == 4 and filter.text == "Quality 4")
assert(requested[1] == 15 and requested[2] == 0 and requested[3] == "Меч" and requested[4] == 4)
OpenDropdown()
assert(entries[6].checked and not entries[1].checked)
entries[2].func()
assert(UI.selectedQuality == 0 and requested[4] == 0)
UI:RequestPage(2)
assert(requested[2] == 2 and requested[4] == 0, "pagination must retain both filters")
entries[1].func()
assert(UI.selectedQuality == 255 and requested[2] == 0 and requested[4] == 255)
frames.SbTransmogSearch.scripts.OnEnterPressed(frames.SbTransmogSearch)
assert(requested[2] == 0 and requested[3] == "Меч")
print("quality_filter_test: ok")
