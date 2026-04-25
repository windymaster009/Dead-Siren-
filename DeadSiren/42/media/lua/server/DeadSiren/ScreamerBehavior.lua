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
    if not players then return false end

    local triggerSq = DeadSiren.Config.ScreamRange * DeadSiren.Config.ScreamRange
    for i = 0, players:size() - 1 do
        local playerObj = players:get(i)
        if playerObj and not playerObj:isDead() then
            if distanceSqToPlayer(zombie, playerObj) <= triggerSq then
                return true
            end
        end
    end

    return false
end

local function playScream(zombie)
    local x, y, z = zombie:getX(), zombie:getY(), zombie:getZ()

    local emitter = getWorld():getFreeEmitter(x, y, z)
    if emitter then
        emitter:playSound("FemaleZombieAttack")
    end

    -- Server-side world noise: attracts nearby zombies.
    addSound(zombie, x, y, z, DeadSiren.Config.ScreamRadius, DeadSiren.Config.ScreamVolume)
end

function DeadSiren.UpdateScreamerBehaviorServer()
    local zombie = DeadSiren.State and DeadSiren.State.activeScreamer or nil
    if not isScreamer(zombie) then return end

    if not isNearAnyPlayer(zombie) then
        return
    end

    local md = zombie:getModData()
    local nowMinute = getCurrentWorldMinute()
    local nextMinute = md.DeadSiren_NextScreamMinute or 0
    if nowMinute < nextMinute then
        return
    end

    playScream(zombie)
    md.DeadSiren_NextScreamMinute = nowMinute + DeadSiren.Config.ScreamCooldownMinutes

    DeadSiren.Log("Screamer used scream ability.")
end

Events.EveryOneMinute.Add(DeadSiren.UpdateScreamerBehaviorServer)
