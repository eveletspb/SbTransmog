SbTransmog = {
    draftSlots = {},
    transmogSlots = {},
    GetDraftCount = function()
        return 0
    end,
}

SbTransmogLocale = {
    PAGE = "%d %d %d",
}
StaticPopupDialogs = {}
YES = "Yes"
NO = "No"

local iconTexture
local requestedLink

function GetItemInfo()
    return nil
end

function GetItemIcon(itemEntry)
    assert(itemEntry == 934, "icon lookup should use the item entry")
    return "Interface\\Icons\\INV_Axe_04"
end

dofile("UI.lua")

local function CreateButtonStub()
    return {
        Enable = function() end,
        Disable = function() end,
    }
end

local marker = {
    Show = function() end,
    Hide = function() end,
}

local itemButton = {
    icon = {
        SetTexture = function(_, texture)
            iconTexture = texture
        end,
    },
    qualityOutline = {
        { SetTexture = function() end },
    },
    selectionOutline = {},
    currentMarker = marker,
    Show = function() end,
    Hide = function() end,
}

local UI = SbTransmog.UI
UI.itemButtons = { itemButton }
UI.previous = CreateButtonStub()
UI.next = CreateButtonStub()
UI.apply = CreateButtonStub()
UI.remove = CreateButtonStub()
UI.pageText = { SetText = function() end }
UI.itemInfoTooltip = {
    ClearLines = function() end,
    SetHyperlink = function(_, link)
        requestedLink = link
    end,
    Hide = function() end,
}

UI:ShowPage({
    page = 0,
    pageCount = 1,
    total = 1,
    current = 0,
    price = 0,
    slot = 16,
}, { 934 })

assert(iconTexture == "Interface\\Icons\\INV_Axe_04", "item icon should not depend on GetItemInfo cache")
assert(requestedLink == "item:934", "missing item info should be requested without mouse hover")
assert(UI.hasMissingItemInfo, "missing item info should keep automatic refresh active")

print("item_info_test: ok")
