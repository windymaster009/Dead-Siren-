--[[
    Dead Siren - server NightEvent

    Responsibilities:
    - Rare night-time spawn roll.
    - Spawn one Screamer near a selected player.
    - Keep Screamer lifecycle server-authoritative.
]]

DeadSiren = DeadSiren or {}
DeadSiren.Config = DeadSiren.Config or {}
DeadSiren.State = DeadSiren.State or {
    activeScreamer = nil,
    activeSinceMinute = nil,
    ownerUsername = nil,
}

local function getCurrentWorldMinute()
    local gt = getGameTime()
    return (gt:getNightsSurvived() * 24 * 60) + (gt:getHour() * 60) + gt:getMinutes()
end

local function isNightHour(hour)
    if DeadSiren.Config.NightStartHour <= DeadSiren.Config.NightEndHour then
        return hour >= DeadSiren.Config.NightStartHour and hour < DeadSiren.Config.NightEndHour
    end

    return hour >= DeadSiren.Config.NightStartHour or hour < DeadSiren.Config.NightEndHour
end

local function getSpawnChance()
    if DeadSiren.Debug then
        return DeadSiren.Config.SpawnChancePerMinuteDebug
    end
    return DeadSiren.Config.SpawnChancePerMinute
end

local function clearScreamerState()
    DeadSiren.State.activeScreamer = nil
    DeadSiren.State.activeSinceMinute = nil
    DeadSiren.State.ownerUsername = nil
end

local function isScreamerStillValid(zombie)
    if not zombie then return false end
    if zombie:isDead() then return false end
    if zombie:getCurrentSquare() == nil then return false end

    local md = zombie:getModData()
    return md and md.DeadSiren_IsScreamer == true
end

local function getOnlinePlayersList()
    local list = getOnlinePlayers()
    if not list then return nil end
    if list:size() <= 0 then return nil end
    return list
end

local function pickTargetPlayer()
    local players = getOnlinePlayersList()
    if not players then return nil end

    local index = ZombRand(0, players:size())
    return players:get(index)
end

local function getRandomSpawnPoint(playerObj)
    local px = playerObj:getX()
    local py = playerObj:getY()
    local pz = playerObj:getZ()

    for _ = 1, 24 do
        local angle = ZombRandFloat(0.0, math.pi * 2)
        local dist = ZombRand(DeadSiren.Config.MinSpawnDistance, DeadSiren.Config.MaxSpawnDistance + 1)

        local x = math.floor(px + math.cos(angle) * dist)
        local y = math.floor(py + math.sin(angle) * dist)
        local square = getCell():getGridSquare(x, y, pz)

        if square and not square:isSolid() then
            return x, y, pz
        end
    end

    return nil
end

local function setScreamerVisualData(zombie)
    local md = zombie:getModData()
    md.DeadSiren_Texture = "media/textures/DeadSiren_Screamer_Eyes.png"

    -- Keep vanilla model and tag this zombie for future custom visual pipeline.
    pcall(function()
        local hv = zombie:getHumanVisual()
        if hv and hv.setSkinTextureIndex then
            hv:setSkinTextureIndex(0)
        end
    end)
end

local function applyScreamerTraits(zombie)
    local md = zombie:getModData()
    md.DeadSiren_IsScreamer = true
    md.DeadSiren_NextScreamMinute = 0

    if zombie.setRunning then
        zombie:setRunning(true)
    end

    zombie:setHealth(0.45)
    setScreamerVisualData(zombie)
end

local function spawnScreamerNearPlayer(playerObj)
    local x, y, z = getRandomSpawnPoint(playerObj)
    if not x then return nil end

    local zombie = addZombie(x, y, z, 0, nil, nil)
    if not zombie then return nil end

    applyScreamerTraits(zombie)
    return zombie
end

local function sendWarningToPlayer(playerObj)
    if not playerObj then return end

    sendServerCommand(
        playerObj,
        DeadSiren.Config.ServerCommandModule,
        DeadSiren.Config.ServerCommandWarning,
        { text = DeadSiren.Config.WarningMessage }
    )
end

local function despawnScreamerIfExpired()
    local active = DeadSiren.State.activeScreamer
    if not isScreamerStillValid(active) then
        clearScreamerState()
        return
    end

    local elapsed = getCurrentWorldMinute() - (DeadSiren.State.activeSinceMinute or 0)
    if elapsed < DeadSiren.Config.MaxLifetimeMinutes then
        return
    end

    DeadSiren.Log("Despawning expired Screamer.")
    active:setHealth(0.0)
    clearScreamerState()
end

function DeadSiren.TryNightSpawnServer()
    despawnScreamerIfExpired()

    if isScreamerStillValid(DeadSiren.State.activeScreamer) then
        return
    end

    local hour = getGameTime():getHour()
    if not isNightHour(hour) then
        return
    end

    local chance = getSpawnChance()
    local roll = ZombRandFloat(0.0, 1.0)
    if roll > chance then
        DeadSiren.Log(string.format("No spawn this minute. roll=%.3f chance=%.3f", roll, chance))
        return
    end

    local playerObj = pickTargetPlayer()
    if not playerObj then
        DeadSiren.Log("No valid player found for spawn roll.")
        return
    end

    local spawned = spawnScreamerNearPlayer(playerObj)
    if not spawned then
        DeadSiren.Log("Spawn roll succeeded but valid location was not found.")
        return
    end

    DeadSiren.State.activeScreamer = spawned
    DeadSiren.State.activeSinceMinute = getCurrentWorldMinute()
    DeadSiren.State.ownerUsername = playerObj:getUsername()

    DeadSiren.Log("Spawned Screamer near " .. tostring(DeadSiren.State.ownerUsername))
    sendWarningToPlayer(playerObj)
end

Events.EveryOneMinute.Add(DeadSiren.TryNightSpawnServer)
