SbTransmog = SbTransmog or {}

local Addon = SbTransmog
local PREFIX = "AC_TRANSMOG"
local VERSION = 6

Addon.connected = false
Addon.sessionId = nil
Addon.requestId = 0
Addon.pendingLists = {}
Addon.transmogSlots = {}
Addon.savedSets = {}
Addon.pendingSets = {}
Addon.protocolVersion = VERSION
Addon.lastProtocolMessage = "none"

local function Split(message)
    local values = {}
    local start = 1
    while true do
        local position = string.find(message, "\t", start, true)
        if not position then
            table.insert(values, string.sub(message, start))
            break
        end
        table.insert(values, string.sub(message, start, position - 1))
        start = position + 1
    end
    return values
end

function Addon:Send(command)
    if not UnitName("player") then
        return
    end
    SendAddonMessage(PREFIX, command, "WHISPER", UnitName("player"))
end

function Addon:NextRequestId()
    self.requestId = self.requestId + 1
    if self.requestId > 999999 then
        self.requestId = 1
    end
    return self.requestId
end

function Addon:Hello()
    self.lastProtocolMessage = "HELLO sent"
    self:Send("HELLO\t" .. VERSION)
end

function Addon:RequestOpen(keepDraft)
    if self.pendingOperation then return end
    self.queuedList = nil
    self.pendingLists, self.pendingSets = {}, {}
    self.UI:Create()
    self.UI.frame:Show()
    self.UI:SetLoading(true)
    self.openRequested = "hello"
    self.openElapsed = 0
    self.keepDraftOnOpen = keepDraft or (self.GetDraftCount and self:GetDraftCount() > 0)
    self.openRequestId = self:NextRequestId()
    self.quoteReady = false
    self.stateElapsed = nil
    self:Hello()
end

function Addon:RequestState()
    self.quoteReady = false
    self.stateElapsed = 0
    if self.sessionId then self:Send("STATE\t" .. self.sessionId) end
end

function Addon:RequestList(slot, page, search, quality)
    if self.pendingOperation then return end
    if not self.sessionId then self:RequestOpen(true) return end
    search = string.gsub(search or "", "[\t\r\n]", " ")
    if string.len(search) > 100 then
        self.UI:SetLoading(false)
        self.UI:SetStatus(SbTransmogLocale.ERROR_SEARCH, 1, 0.3, 0.3)
        return
    end
    self.queuedList = { slot, page or 0, search, quality or 255 }
    self.listDelay = 0.2
    self.UI:SetLoading(true)
end

function Addon:BeginOperation(requestId)
    if self.pendingOperation then return false end
    self.pendingOperation = { id = requestId, elapsed = 0 }
    self.UI:SetBusy(true)
    return true
end

function Addon:UpdateProtocol(elapsed)
    if self.openRequested then
        self.openElapsed = (self.openElapsed or 0) + elapsed
        if self.openElapsed >= 10 then
            self.openRequested, self.openRequestId = nil, nil
            self.UI:SetLoading(false)
            self.UI:SetStatus(SbTransmogLocale.ERROR_NO_RESPONSE, 1, 0.3, 0.3)
        end
    end
    if self.pendingOperation then
        self.pendingOperation.elapsed = self.pendingOperation.elapsed + elapsed
        if self.pendingOperation.elapsed >= 15 then
            self.pendingOperation = nil
            self.UI:SetBusy(false)
            self:RequestOpen(true)
        end
    end
    if self.stateElapsed then
        self.stateElapsed = self.stateElapsed + elapsed
        if self.stateElapsed >= 10 then
            self.stateElapsed = nil
            self:RequestOpen(true)
        end
    end
    for id, pending in pairs(self.pendingLists) do
        pending.elapsed = (pending.elapsed or 0) + elapsed
        if pending.elapsed >= 10 then
            self.pendingLists[id] = nil
            if self.latestListRequestId == id and not self.queuedList then
                self.UI:SetLoading(false)
                self.UI:SetStatus(SbTransmogLocale.ERROR_NO_RESPONSE, 1, 0.3, 0.3)
            end
        end
    end
    for id, pending in pairs(self.pendingSets) do
        pending.elapsed = (pending.elapsed or 0) + elapsed
        if pending.elapsed >= 10 then
            self.pendingSets[id] = nil
            self.UI:SetStatus(SbTransmogLocale.ERROR_NO_RESPONSE, 1, 0.3, 0.3)
        end
    end
    if self.queuedList and not self.pendingOperation then
        self.listDelay = self.listDelay - elapsed
        if self.listDelay <= 0 and self.sessionId then
            local query = self.queuedList
            self.queuedList = nil
            local id = self:NextRequestId()
            self.pendingLists = { [id] = { items = {}, received = {}, query = query, elapsed = 0 } }
            self.latestListRequestId = id
            self:Send(string.format("LIST\t%d\t%d\t%d\t%d\t%s\t%d", id, self.sessionId, unpack(query)))
        end
    end
end

function Addon:Apply(slot, itemEntry)
    if not self.sessionId or not itemEntry then
        return
    end
    local requestId = self:NextRequestId()
    if not self:BeginOperation(requestId) then return end
    self.UI:SetStatus(SbTransmogLocale.APPLYING, 1, 0.82, 0)
    self:Send(string.format("APPLY\t%d\t%d\t%d\t%d\t%d", requestId, self.sessionId, slot, itemEntry, self.quoteId or 0))
end

function Addon:ApplyOutfit()
    if self:GetDraftCount() == 0 then return end
    if not self.sessionId then self:RequestOpen(true) return end
    if not self.quoteReady then self:RequestState() return end

    local slots = {}
    for slot in pairs(self.draftSlots) do
        table.insert(slots, slot)
    end
    table.sort(slots)

    local changes = {}
    for _, slot in ipairs(slots) do
        table.insert(changes, slot .. ":" .. self.draftSlots[slot])
    end

    local requestId = self:NextRequestId()
    if not self:BeginOperation(requestId) then return end
    self.UI:SetStatus(SbTransmogLocale.APPLYING_OUTFIT, 1, 0.82, 0)
    self:Send(string.format("APPLY_OUTFIT\t%d\t%d\t%s\t%d", requestId, self.sessionId, table.concat(changes, ","), self.quoteId or 0))
end

function Addon:Remove(slot)
    if not self.sessionId then
        return
    end
    local requestId = self:NextRequestId()
    if not self:BeginOperation(requestId) then return end
    self:Send(string.format("REMOVE\t%d\t%d\t%d\t%d", requestId, self.sessionId, slot, self.quoteId or 0))
end

function Addon:RemoveAll()
    if not self.sessionId then
        return
    end
    local requestId = self:NextRequestId()
    if not self:BeginOperation(requestId) then return end
    self.UI:SetStatus(SbTransmogLocale.REMOVING_ALL, 1, 0.82, 0)
    self:Send(string.format("REMOVE_ALL\t%d\t%d\t%d", requestId, self.sessionId, self.quoteId or 0))
end

local function NormalizeSetName(name)
    name = string.gsub(name or "", "[\t\r\n]", " ")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    if name == "" or string.len(name) > 64 then return nil end
    return name
end

function Addon:RequestSets()
    if not self.sessionId then return end
    local requestId = self:NextRequestId()
    self.pendingSets[requestId] = { sets = {}, received = {}, remaining = nil, maxSets = 0 }
    self.latestSetsRequestId = requestId
    self:Send(string.format("LIST_SETS\t%d\t%d", requestId, self.sessionId))
end

function Addon:GetEffectiveOutfit()
    local entries = {}
    for slot, itemEntry in pairs(self.transmogSlots or {}) do
        if itemEntry and itemEntry > 0 then entries[slot] = itemEntry end
    end
    for slot, itemEntry in pairs(self.draftSlots or {}) do
        if itemEntry and itemEntry > 0 then
            entries[slot] = itemEntry
        else
            entries[slot] = nil
        end
    end
    return entries
end

local function EncodeEntries(entries)
    local slots = {}
    for slot in pairs(entries) do table.insert(slots, slot) end
    table.sort(slots)
    local encoded = {}
    for _, slot in ipairs(slots) do
        table.insert(encoded, slot .. ":" .. entries[slot])
    end
    return table.concat(encoded, ",")
end

function Addon:SaveSet(name)
    if not self.sessionId then return end
    if not self.quoteReady then self:RequestState() return end
    name = NormalizeSetName(name)
    if not name then
        self.UI:SetStatus(SbTransmogLocale.ERROR_SET_NAME, 1, 0.3, 0.3)
        return
    end
    local encoded = EncodeEntries(self:GetEffectiveOutfit())
    if encoded == "" then
        self.UI:SetStatus(SbTransmogLocale.ERROR_EMPTY_SET, 1, 0.3, 0.3)
        return
    end
    local requestId = self:NextRequestId()
    local command = string.format("SAVE_SET\t%d\t%d\t%s\t%s", requestId, self.sessionId, name, encoded)
    if string.len(command) > 240 then
        self.UI:SetStatus(SbTransmogLocale.ERROR_SET_TOO_LARGE, 1, 0.3, 0.3)
        return
    end
    if not self:BeginOperation(requestId) then return end
    self:Send(command)
end

function Addon:RenameSet(presetId, name)
    name = NormalizeSetName(name)
    if not self.sessionId or presetId == nil or not name then
        self.UI:SetStatus(SbTransmogLocale.ERROR_SET_NAME, 1, 0.3, 0.3)
        return
    end
    local requestId = self:NextRequestId()
    if not self:BeginOperation(requestId) then return end
    self:Send(string.format("RENAME_SET\t%d\t%d\t%d\t%s", requestId, self.sessionId, presetId, name))
end

function Addon:DeleteSet(presetId)
    if not self.sessionId or presetId == nil then return end
    local requestId = self:NextRequestId()
    if not self:BeginOperation(requestId) then return end
    self:Send(string.format("DELETE_SET\t%d\t%d\t%d", requestId, self.sessionId, presetId))
end

function Addon:CloseSession()
    self.openRequested, self.openRequestId = nil, nil
    self.keepDraftOnOpen = nil
    self.queuedList, self.pendingOperation = nil, nil
    self.quoteReady, self.stateSnapshot, self.stateElapsed = false, nil, nil
    self.UI:SetBusy(false)
    self.pendingLists = {}
    self.pendingSets = {}
    if self.sessionId then
        self:Send("CLOSE\t" .. self.sessionId)
    end
    self.sessionId = nil
end

local function ErrorText(code)
    local L = SbTransmogLocale
    local errors = {
        SESSION = L.ERROR_SESSION,
        EQUIPMENT_CHANGED = L.ERROR_EQUIPMENT_CHANGED,
        THROTTLED = L.ERROR_THROTTLED,
        DUPLICATE = L.ERROR_DUPLICATE,
        SEARCH = L.ERROR_SEARCH,
        QUALITY = L.ERROR_QUALITY,
        UNAVAILABLE = L.ERROR_UNAVAILABLE,
        SLOT = L.ERROR_SLOT,
        EMPTY_SLOT = L.ERROR_EMPTY_SLOT,
        COLLECTION_DISABLED = L.ERROR_COLLECTION_DISABLED,
        NOT_COLLECTED = L.ERROR_NOT_COLLECTED,
        NOT_TRANSMOGRIFIED = L.ERROR_NOT_TRANSMOGRIFIED,
        TRANSMOG_2 = L.ERROR_SLOT,
        TRANSMOG_3 = L.ERROR_INVALID_ITEMS,
        TRANSMOG_4 = L.ERROR_INVALID_ITEMS,
        TRANSMOG_5 = L.ERROR_EMPTY_SLOT,
        TRANSMOG_6 = L.ERROR_INVALID_ITEMS,
        TRANSMOG_7 = L.ERROR_MONEY,
        TRANSMOG_8 = L.ERROR_TOKENS,
        SETS_DISABLED = L.ERROR_SETS_DISABLED,
        SET_NAME = L.ERROR_SET_NAME,
        SET_NAME_EXISTS = L.ERROR_SET_NAME_EXISTS,
        SET_LIMIT = L.ERROR_SET_LIMIT,
        SET_NOT_FOUND = L.ERROR_SET_NOT_FOUND,
        EMPTY_SET = L.ERROR_EMPTY_SET,
    }
    return errors[code] or L.ERROR_GENERIC
end

function Addon:HandleProtocolMessage(message)
    local parts = Split(message)
    local command = parts[1]
    self.lastProtocolMessage = command or "unknown"

    if command == "HELLO_OK" then
        self.connected = tonumber(parts[2]) == VERSION
        self.helloAcknowledged = self.connected
        if self.openRequested == "hello" then
            if self.connected then
                self.openRequested = "open"
                self:Send("OPEN\t" .. self.openRequestId)
            else
                self.openRequested = nil
                self.UI:SetLoading(false)
                self.UI:SetStatus(SbTransmogLocale.INCOMPATIBLE, 1, 0.3, 0.3)
            end
        end
        return
    end

    if command == "HELLO_ERROR" then
        self.connected = false
        self.openRequested = nil
        if self.UI then
            self.UI:SetLoading(false)
            self.UI:SetStatus(SbTransmogLocale.INCOMPATIBLE, 1, 0.3, 0.3)
        end
        return
    end

    if command == "OPEN" then
        local opening = tonumber(parts[3])
        if opening ~= 0 and (self.openRequested ~= "open" or opening ~= self.openRequestId) then
            self:Send("CLOSE\t" .. (parts[2] or "0"))
            return
        end
        self.sessionId = tonumber(parts[2])
        self.openRequestId = nil
        self.openRequested = nil
        self.pendingLists = {}
        self.pendingSets = {}
        local keepDraft = self.keepDraftOnOpen
        self.keepDraftOnOpen = nil
        local opened, errorMessage = pcall(function() self.UI:Open(keepDraft) end)
        if not opened then
            self.lastProtocolMessage = "UI_ERROR"
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4040SbTransmog UI error:|r " .. tostring(errorMessage))
        end
        if opened then self:RequestSets() end
        return
    end

    if command == "SETS" then
        local requestId = tonumber(parts[2])
        local pending = requestId and self.pendingSets[requestId]
        if not pending then return end
        pending.remaining = tonumber(parts[3]) or 0
        pending.maxSets = tonumber(parts[4]) or 0
        if pending.remaining == 0 and self.latestSetsRequestId == requestId then
            self.savedSets = {}
            self.UI:ShowSavedSets(self.savedSets, pending.maxSets)
            self.pendingSets[requestId] = nil
        end
        return
    end

    if command == "SET" then
        local requestId = tonumber(parts[2])
        local presetId = tonumber(parts[3])
        local pending = requestId and self.pendingSets[requestId]
        if not pending or presetId == nil or pending.received[presetId] then return end

        local entries = {}
        for value in string.gmatch(parts[5] or "", "[^,]+") do
            local separator = string.find(value, ":", 1, true)
            if separator then
                local slot = tonumber(string.sub(value, 1, separator - 1))
                local itemEntry = tonumber(string.sub(value, separator + 1))
                if slot and itemEntry then entries[slot] = itemEntry end
            end
        end
        pending.received[presetId] = true
        pending.sets[presetId] = { id = presetId, name = parts[4] or ("#" .. presetId), entries = entries }
        pending.remaining = math.max(0, (pending.remaining or 1) - 1)
        if pending.remaining == 0 then
            if self.latestSetsRequestId == requestId then
                self.savedSets = pending.sets
                self.UI:ShowSavedSets(self.savedSets, pending.maxSets)
            end
            self.pendingSets[requestId] = nil
        end
        return
    end

    if command == "SET_RESULT" then
        local requestId = tonumber(parts[2])
        local wasRead = requestId and self.pendingSets[requestId] ~= nil
        local wasWrite = self.pendingOperation and self.pendingOperation.id == requestId
        if not wasRead and not wasWrite then return end
        self.pendingSets[requestId] = nil
        if wasWrite then
            self.pendingOperation = nil
            self.UI:SetBusy(false)
        end
        if parts[3] == "OK" then
            local messages = { SAVED = SbTransmogLocale.SET_SAVED, RENAMED = SbTransmogLocale.SET_RENAMED, DELETED = SbTransmogLocale.SET_DELETED }
            self.UI:SetStatus(messages[parts[4]] or SbTransmogLocale.SET_UPDATED, 0.3, 1, 0.3)
            self:RequestSets()
        else
            self.UI:SetStatus(ErrorText(parts[4]), 1, 0.3, 0.3)
            if parts[4] == "SESSION" then self.sessionId = nil self:RequestOpen(true) end
        end
        return
    end

    if command == "STATE_BEGIN" and tonumber(parts[2]) == self.sessionId then
        self.stateElapsed = 0
        self.stateSnapshot = { slots = {}, prices = {}, hiddenPrices = {}, quoteId = tonumber(parts[3]), tokenEntry = tonumber(parts[4]), tokenAmount = tonumber(parts[5]) }
        self.quoteReady = false
        return
    end
    if command == "EQUIP" and tonumber(parts[2]) == self.sessionId and self.stateSnapshot then
        local slot, price, current = tonumber(parts[3]), tonumber(parts[4]), tonumber(parts[5])
        if slot and price and current then
            self.stateSnapshot.prices[slot] = price
            self.stateSnapshot.hiddenPrices[slot] = tonumber(parts[7])
            self.stateSnapshot.slots[slot] = current ~= 0 and current or nil
        end
        return
    end
    if command == "STATE_END" and tonumber(parts[2]) == self.sessionId and self.stateSnapshot then
        local state = self.stateSnapshot
        for slot = 0, 18 do
            if state.prices[slot] == nil or state.hiddenPrices[slot] == nil then return end
        end
        self.stateSnapshot, self.stateElapsed = nil, nil
        self.transmogSlots = state.slots
        self.UI.slotPrices, self.UI.hiddenPrices = state.prices, state.hiddenPrices
        self.tokenEntry, self.tokenAmount, self.quoteId = state.tokenEntry, state.tokenAmount, state.quoteId
        for slot, entry in pairs(self.draftSlots or {}) do
            if entry == state.slots[slot] or (entry == 0 and not state.slots[slot]) then self.draftSlots[slot] = nil end
        end
        self.quoteReady = true
        self.UI:UpdateTransmogSlotMarkers()
        self.UI:UpdateDraftState()
        return
    end

    if command == "PAGE" then
        local requestId = tonumber(parts[2])
        local pending = self.pendingLists[requestId]
        if not pending then
            return
        end
        pending.meta = {
            requestId = requestId,
            slot = tonumber(parts[3]),
            page = tonumber(parts[4]),
            pageCount = tonumber(parts[5]),
            total = tonumber(parts[6]),
            price = tonumber(parts[7]),
            current = tonumber(parts[8]),
            target = tonumber(parts[9]),
        }
        return
    end

    if command == "ITEMS" then
        local requestId = tonumber(parts[2])
        local chunk = tonumber(parts[3])
        local chunks = tonumber(parts[4])
        local pending = self.pendingLists[requestId]
        if not pending then
            return
        end

        pending.chunks = chunks
        if not pending.received[chunk] then
            pending.received[chunk] = true
            if parts[5] and parts[5] ~= "" then
                for value in string.gmatch(parts[5], "[^,]+") do
                    table.insert(pending.items, tonumber(value))
                end
            end
        end

        local complete = pending.meta ~= nil
        for index = 0, chunks - 1 do
            if not pending.received[index] then
                complete = false
                break
            end
        end
        if complete then
            if self.latestListRequestId == requestId and not self.queuedList then
                self.UI:ShowPage(pending.meta, pending.items)
            end
            self.pendingLists[requestId] = nil
        end
        return
    end

    if command == "RESULT" then
        local requestId = tonumber(parts[2])
        local pending = requestId and self.pendingLists[requestId]
        local wasList = pending ~= nil
        local wasSetRead = requestId and self.pendingSets[requestId] ~= nil
        local wasWrite = self.pendingOperation and self.pendingOperation.id == requestId
        if requestId ~= 0 and not wasList and not wasSetRead and not wasWrite then return end
        if requestId == 0 then
            self.openRequested, self.openRequestId = nil, nil
            self.UI:SetLoading(false)
        end
        if requestId then
            self.pendingLists[requestId], self.pendingSets[requestId] = nil, nil
        end
        if wasList and not self.queuedList then self.UI:SetLoading(false) end
        if wasWrite then
            self.pendingOperation = nil
            self.UI:SetBusy(false)
        end
        if parts[3] == "OK" then
            local slot = tonumber(parts[4])
            local itemEntry = tonumber(parts[5]) or 0
            if parts[4] == "OUTFIT" then
                self.UI.pendingResultStatus = string.format(SbTransmogLocale.OUTFIT_APPLIED, itemEntry)
                self:ClearDraft()
            elseif slot == 255 then
                self.transmogSlots = {}
                self.UI.pendingResultStatus = SbTransmogLocale.RESET_ALL_SUCCESS
                self:ClearDraft()
            elseif slot then
                self.transmogSlots[slot] = itemEntry ~= 0 and itemEntry or nil
                self.UI.pendingResultStatus = itemEntry == 0 and SbTransmogLocale.REMOVED or SbTransmogLocale.APPLIED
            end
            self.UI:UpdateTransmogSlotMarkers()
            self.UI:RefreshCurrentPage()
        else
            local errorCode = parts[4]
            if errorCode == "THROTTLED" and wasList and not self.queuedList then
                self:RequestList(unpack(pending.query))
                return
            end
            if errorCode == "EQUIPMENT_CHANGED" then self:ClearDraft() end
            self.UI:SetStatus(ErrorText(errorCode), 1, 0.3, 0.3)
            if errorCode == "SESSION" then
                self.sessionId = nil
                self:RequestOpen(true)
            end
        end
    end
end

function Addon:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX or channel ~= "WHISPER" then
        return
    end

    local shortSender = sender and string.match(sender, "^[^-]+")
    if shortSender and shortSender ~= UnitName("player") then
        return
    end
    self:HandleProtocolMessage(message)
end

Addon.PREFIX = PREFIX
