--[[
    Dead Siren - client NightEvent
    Keeps UI feedback client-side.
]]

DeadSiren = DeadSiren or {}
DeadSiren.Config = DeadSiren.Config or {}

local function showWarningMessage(playerObj, text)
    if not playerObj then return end

    -- HaloTextHelper API can differ between versions/mod stacks.
    if HaloTextHelper then
        local ok = pcall(function()
            if HaloTextHelper.addText then
                HaloTextHelper.addText(playerObj, text)
            elseif HaloTextHelper.addTextWithArrow and HaloTextHelper.getColorWhite then
                HaloTextHelper.addTextWithArrow(playerObj, text, true, HaloTextHelper.getColorWhite())
            end
        end)
        if ok then return end
    end

    -- Fallback feedback.
    playerObj:Say(text)
end

function DeadSiren.OnServerCommand(module, command, args)
    if module ~= DeadSiren.Config.ServerCommandModule then return end
    if command ~= DeadSiren.Config.ServerCommandWarning then return end

    local playerObj = getSpecificPlayer(0)
    local text = args and args.text or DeadSiren.Config.WarningMessage or "I feel something watching me..."

    showWarningMessage(playerObj, text)

    DeadSiren.Log("Received warning command from server.")
end

Events.OnServerCommand.Add(DeadSiren.OnServerCommand)
