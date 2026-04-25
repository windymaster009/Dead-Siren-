--[[
    Dead Siren - server ScreamerBehavior

    Responsibilities:
    - Trigger Screamer scream when near players.
    - Emit loud world sound to attract zombies.
    - Enforce scream cooldown.
]]

DeadSiren = DeadSiren or {}
DeadSiren.Config = DeadSiren.Config or {}
DeadSiren.State = DeadSiren.State or {}

print("[DeadSiren] Server ScreamerBehavior.lua loaded.")

local function getCurrentWorldMinute()
    local gt = getGameTime()
    return (gt:getNightsSurvived() * 24 * 60) + (gt:getHour() * 60) + gt:getMinutes()
end

local function isScreamer(zombie)
    if not zombie then return false end
    if zombie:isDead() then return false end

    local md = zombie:getModData()
    return md and md.DeadSiren_IsScreamer == true
end

local function distanceSqToPlayer(zombie, playerObj)
    local dx = zombie:getX() - playerObj:getX()
    local dy = zombie:getY() - playerObj:getY()
    return (dx * dx) + (dy * dy)
end

local function isNearAnyPlayer(zombie)
    local players = getOnlinePlayers()
    if not players then
        DeadSiren.Log("ScreamerBehavior: no online players list.")
        return false
    end

    local triggerSq = DeadSiren.Config.ScreamRange * DeadSiren.Config.ScreamRange
    for i = 0, players:size() - 1 do
        local playerObj = players:get(i)
        if playerObj and not playerObj:isDead() then
            if distanceSqToPlayer(zombie, playerObj) <= triggerSq then
                DeadSiren.Log("ScreamerBehavior: player in range username=" .. tostring(playerObj:getUsername()))
                return true
            end
        end
    end

    DeadSiren.Log("ScreamerBehavior: no players within scream range.")
    return false
end

local function playScream(zombie)
    local x, y, z = zombie:getX(), zombie:getY(), zombie:getZ()

    local emitter = getWorld():getFreeEmitter(x, y, z)
    if emitter then
        emitter:playSound("FemaleZombieAttack")
        DeadSiren.Log("ScreamerBehavior: played scream emitter sound.")
    else
        DeadSiren.Log("ScreamerBehavior: emitter unavailable.")
    end

    addSound(zombie, x, y, z, DeadSiren.Config.ScreamRadius, DeadSiren.Config.ScreamVolume)
    DeadSiren.Log("ScreamerBehavior: addSound emitted radius=" .. tostring(DeadSiren.Config.ScreamRadius)
        .. " volume=" .. tostring(DeadSiren.Config.ScreamVolume))
end

function DeadSiren.UpdateScreamerBehaviorServer()
    DeadSiren.Log("EveryOneMinute: UpdateScreamerBehaviorServer tick")

    local hour = getGameTime():getHour()
    DeadSiren.Log("ScreamerBehavior current game hour=" .. tostring(hour))

    local zombie = DeadSiren.State and DeadSiren.State.activeScreamer or nil
    if not isScreamer(zombie) then
        DeadSiren.Log("ScreamerBehavior: no active Screamer.")
        return
    end

    if not isNearAnyPlayer(zombie) then
        return
    end

    local md = zombie:getModData()
    local nowMinute = getCurrentWorldMinute()
    local nextMinute = md.DeadSiren_NextScreamMinute or 0
    if nowMinute < nextMinute then
        DeadSiren.Log("ScreamerBehavior: cooldown active now=" .. tostring(nowMinute)
            .. " next=" .. tostring(nextMinute))
        return
    end

    playScream(zombie)
    md.DeadSiren_NextScreamMinute = nowMinute + DeadSiren.Config.ScreamCooldownMinutes
    DeadSiren.Log("ScreamerBehavior: cooldown reset to " .. tostring(md.DeadSiren_NextScreamMinute))
end

Events.EveryOneMinute.Add(DeadSiren.UpdateScreamerBehaviorServer)
