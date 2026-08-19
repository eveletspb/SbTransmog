local calls = {}

SbTransmog = {
    draftSlots = { [16] = 19019 },
    transmogSlots = { [15] = 32837 },
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

local triedOn = {}
for _, call in ipairs(calls) do
    if call.name == "TryOn" then
        table.insert(triedOn, call.value)
    end
end

assert(#triedOn == 2, "main-hand should be applied before an off-hand preview")
assert(triedOn[1] == "item:32837", "current main-hand appearance should keep the first weapon slot")
assert(triedOn[2] == "item:19019", "selected off-hand appearance should use the second weapon slot")

print("model_preview_test: ok")
