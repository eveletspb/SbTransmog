SbTransmog = SbTransmog or {}

local Addon = SbTransmog
local eventFrame = CreateFrame("Frame")
local helloDelay = nil
local helloAttempts = 0

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(Addon.PREFIX)
        end
        helloDelay = 1
        helloAttempts = 0
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not Addon.connected then
            helloDelay = 1
        end
    elseif event == "CHAT_MSG_ADDON" then
        Addon:OnAddonMessage(...)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if Addon.UI and Addon.UI.frame and Addon.UI.frame:IsShown() then
            local slot = ...
            Addon.draftSlots[slot - 1] = nil
            Addon.pendingLists, Addon.queuedList = {}, nil
            Addon:RequestState()
            Addon.UI:RefreshCurrentPage()
            Addon.UI:UpdateDraftState()
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if Addon.UI and Addon.UI.frame and Addon.UI.frame:IsShown() and Addon.UI.page ~= nil then
            Addon.UI:RefreshItemInfo()
        end
    end
end)

eventFrame:SetScript("OnUpdate", function(self, elapsed)
    Addon:UpdateProtocol(elapsed)
    if not helloDelay then
        return
    end
    if Addon.connected then
        helloDelay = nil
        return
    end
    helloDelay = helloDelay - elapsed
    if helloDelay <= 0 then
        helloAttempts = helloAttempts + 1
        Addon:Hello()
        if Addon.connected or helloAttempts >= 5 then
            helloDelay = nil
        else
            helloDelay = 3
        end
    end
end)

SLASH_SBTRANSMOG1 = "/transmog"
local function PrintDebug()
    local connected = Addon.connected and "yes" or "no"
    local session = Addon.sessionId and tostring(Addon.sessionId) or "none"
    DEFAULT_CHAT_FRAME:AddMessage("|cffffb52eSbTransmog|r loaded=yes protocol=" ..
        tostring(Addon.protocolVersion) .. " connected=" .. connected .. " session=" .. session ..
        " last=" .. tostring(Addon.lastProtocolMessage))
    if not Addon.connected then
        DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaaSending a new HELLO request...|r")
        helloAttempts = 0
        helloDelay = 0
    end
end

SlashCmdList.SBTRANSMOG = function(message)
    message = string.lower(message or "")
    if message == "debug" then
        PrintDebug()
        return
    end

    Addon:RequestOpen()
end
