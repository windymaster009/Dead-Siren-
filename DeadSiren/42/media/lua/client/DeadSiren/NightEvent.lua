--[[
    Dead Siren - client NightEvent
    Keeps UI feedback client-side.
]]

DeadSiren = DeadSiren or {}
DeadSiren.Config = DeadSiren.Config or {}

print("[DeadSiren] Client NightEvent.lua loaded.")

local function showWarningMessage(playerObj, text)
    if not playerObj then
        DeadSiren.Log("Client warning failed: local player not found.")
        return
    end

    DeadSiren.Log("Client warning message: " .. tostring(text))

    -- HaloTextHelper API can differ between versions/mod stacks.
    if HaloTextHelper then
        local ok = pcall(function()
            if HaloTextHelper.addText then
                HaloTextHelper.addText(playerObj, text)
            elseif HaloTextHelper.addTextWithArrow and HaloTextHelper.getColorWhite then
                HaloTextHelper.addTextWithArrow(playerObj, text, true, HaloTextHelper.getColorWhite())
            end
        end)

        if ok then
            DeadSiren.Log("Client warning displayed via HaloTextHelper.")
            return
        end
    end

    playerObj:Say(text)
    DeadSiren.Log("Client warning displayed via player:Say fallback.")
end

function DeadSiren.OnServerCommand(module, command, args)
    DeadSiren.Log("Client OnServerCommand received: module=" .. tostring(module)
        .. " command=" .. tostring(command))

    if module ~= DeadSiren.Config.ServerCommandModule then return end
    if command ~= DeadSiren.Config.ServerCommandWarning then return end

    local playerObj = getSpecificPlayer(0)
    local text = args and args.text or DeadSiren.Config.WarningMessage or "I feel something watching me..."
    showWarningMessage(playerObj, text)
end

Events.OnServerCommand.Add(DeadSiren.OnServerCommand)
