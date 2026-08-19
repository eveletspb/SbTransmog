SbTransmog = SbTransmog or {}

local Addon = SbTransmog
local MAIN_HAND_SLOT = 15
local OFF_HAND_SLOT = 16

Addon.draftSlots = Addon.draftSlots or {}

local function TryOnItem(addon, slot, itemEntry)
    local link
    if itemEntry == 0 then
        link = GetInventoryItemLink("player", slot + 1)
    else
        local _, itemLink = GetItemInfo("item:" .. itemEntry)
        link = itemLink
    end

    if not link then
        return false
    end
    if slot == OFF_HAND_SLOT and addon.UI.model.UndressSlot then
        addon.UI.model:UndressSlot(slot + 1)
    end
    addon.UI.model:TryOn(link)
    return true
end

function Addon:ResetPreview()
    if not self.UI or not self.UI.model then
        return
    end
    self.UI.model:SetUnit("player")
end

function Addon:GetDraftCount()
    local count = 0
    for _ in pairs(self.draftSlots) do
        count = count + 1
    end
    return count
end

function Addon:PreviewDraft()
    if not self.UI or not self.UI.model then return false end

    self:ResetPreview()
    self.UI.model:Show()
    self.pendingDraftPreview = false

    for slot, itemEntry in pairs(self.draftSlots) do
        if slot ~= MAIN_HAND_SLOT and slot ~= OFF_HAND_SLOT and not TryOnItem(self, slot, itemEntry) then
            self.pendingDraftPreview = true
        end
    end

    local mainHandDraft = self.draftSlots[MAIN_HAND_SLOT]
    local offHandDraft = self.draftSlots[OFF_HAND_SLOT]
    if mainHandDraft ~= nil then
        if not TryOnItem(self, MAIN_HAND_SLOT, mainHandDraft) then
            self.pendingDraftPreview = true
        end
    elseif offHandDraft ~= nil then
        local currentMainHand = (self.transmogSlots or {})[MAIN_HAND_SLOT]
        if not TryOnItem(self, MAIN_HAND_SLOT, currentMainHand or 0) and currentMainHand then
            self.pendingDraftPreview = true
        end
    end
    if offHandDraft ~= nil and not TryOnItem(self, OFF_HAND_SLOT, offHandDraft) then
        self.pendingDraftPreview = true
    end

    if self.pendingDraftPreview then
        self.UI:SetStatus(SbTransmogLocale.PREVIEW_LOADING, 1, 0.82, 0)
        return false
    end

    local count = self:GetDraftCount()
    if count > 0 then
        self.UI:SetStatus(string.format(SbTransmogLocale.DRAFT_READY, count), 0.35, 0.8, 1)
    end
    return count > 0
end

function Addon:SetDraftAppearance(slot, itemEntry)
    if slot == nil or not itemEntry then return end

    if self.transmogSlots[slot] == itemEntry then
        self.draftSlots[slot] = nil
    else
        self.draftSlots[slot] = itemEntry
    end
    self:PreviewDraft()
    if self.UI then self.UI:UpdateDraftState() end
end

function Addon:SetDraftRemoval(slot)
    if slot == nil then return end

    if self.draftSlots[slot] == 0 then
        self.draftSlots[slot] = nil
    elseif self.transmogSlots[slot] then
        self.draftSlots[slot] = 0
    else
        self.draftSlots[slot] = nil
    end
    self:PreviewDraft()
    if self.UI then
        self.UI.selectedEntry = nil
        self.UI:UpdateDraftState()
        self.UI:UpdateSelection()
        self.UI:UpdateSelectedItemText()
    end
end

function Addon:LoadSavedSet(presetId)
    local savedSet = self.savedSets and self.savedSets[presetId]
    if not savedSet then return false end

    local draft = {}
    for slot, currentEntry in pairs(self.transmogSlots or {}) do
        if currentEntry and not savedSet.entries[slot] then draft[slot] = 0 end
    end
    for slot, itemEntry in pairs(savedSet.entries) do
        if self.transmogSlots[slot] ~= itemEntry then draft[slot] = itemEntry end
    end

    self.draftSlots = draft
    if self.UI then
        self.UI.selectedEntry = self.UI.selectedSlot and draft[self.UI.selectedSlot] or nil
    end
    self:PreviewDraft()
    if self.UI then
        self.UI:UpdateDraftState()
        self.UI:UpdateSelection()
        self.UI:UpdateSelectedItemText()
        self.UI:SetStatus(string.format(SbTransmogLocale.SET_LOADED, savedSet.name), 0.35, 0.8, 1)
    end
    return true
end

function Addon:ClearDraft()
    self.draftSlots = {}
    self.pendingDraftPreview = false
    self:ResetPreview()
    if self.UI then
        self.UI.selectedEntry = nil
        self.UI:UpdateDraftState()
        self.UI:UpdateSelection()
        self.UI:UpdateSelectedItemText()
    end
end
