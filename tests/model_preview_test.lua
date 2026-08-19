local calls = {}

SbTransmog = {
    draftSlots = { [16] = 19019 },
    transmogSlots = {},
    UI = {
        model = {
            SetUnit = function(_, unit)
                table.insert(calls, { name = "SetUnit", value = unit })
            end,
            Show = function()
                table.insert(calls, { name = "Show" })
            end,
            TryOn = function(_, link)
                table.insert(calls, { name = "TryOn", value = link })
            end,
        },
        SetStatus = function() end,
    },
}

SbTransmogLocale = {
    PREVIEW_LOADING = "loading",
    DRAFT_READY = "%d ready",
}

function GetItemInfo(item)
    return "Test weapon", item
end

function GetInventoryItemLink()
    return nil
end

dofile("ModelPreview.lua")

local success, previewed = pcall(function()
    return SbTransmog:PreviewDraft()
end)

assert(success, "off-hand preview should work when UndressSlot is unavailable")
assert(previewed, "off-hand draft should be previewed")

local tryOnCall
for index, call in ipairs(calls) do
    if call.name == "TryOn" then tryOnCall = index end
end

assert(tryOnCall, "off-hand appearance should be passed to TryOn")
assert(calls[tryOnCall].value == "item:19019", "selected off-hand appearance should be previewed")

print("model_preview_test: ok")
