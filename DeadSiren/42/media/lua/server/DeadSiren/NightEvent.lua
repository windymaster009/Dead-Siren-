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

print("[DeadSiren] Server NightEvent.lua loaded.")

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
    local chance = DeadSiren.Config.SpawnChancePerMinute

    if DeadSiren.Debug then
        chance = DeadSiren.SpawnChancePerMinuteDebug or DeadSiren.Config.SpawnChancePerMinuteDebug
    end

    -- Accept either 0..1 or percentage form (e.g. 100 for guaranteed in debug).
    if chance > 1 then
        chance = chance / 100
    end

    if chance < 0 then chance = 0 end
    if chance > 1 then chance = 1 end

    return chance
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
    if not list then
        DeadSiren.Log("No online players list returned.")
        return nil
    end

    if list:size() <= 0 then
        DeadSiren.Log("Online players list is empty.")
        return nil
    end

    return list
end

local function pickTargetPlayer()
    local players = getOnlinePlayersList()
    if not players then return nil end

    local index = ZombRand(0, players:size())
    local playerObj = players:get(index)

    DeadSiren.Log("Selected player index=" .. tostring(index)
        .. " username=" .. tostring(playerObj and playerObj:getUsername()))

    return playerObj
end

local function getRandomSpawnPoint(playerObj)
    local px = playerObj:getX()
    local py = playerObj:getY()
    local pz = playerObj:getZ()

    for attempt = 1, 24 do
        local angle = ZombRandFloat(0.0, math.pi * 2)
        local dist = ZombRand(DeadSiren.Config.MinSpawnDistance, DeadSiren.Config.MaxSpawnDistance + 1)

        local x = math.floor(px + math.cos(angle) * dist)
        local y = math.floor(py + math.sin(angle) * dist)
        local square = getCell():getGridSquare(x, y, pz)

        if square and not square:isSolid() then
            DeadSiren.Log("Found spawn square on attempt " .. tostring(attempt)
                .. " at " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(pz))
            return x, y, pz
        end
    end

    DeadSiren.Log("Failed to find spawn square near player.")
    return nil
end

local function setScreamerVisualData(zombie)
    local md = zombie:getModData()
    md.DeadSiren_Texture = "media/textures/DeadSiren_Screamer_Eyes.png"

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

    DeadSiren.Log("Applied Screamer traits.")
end

local function spawnScreamerNearPlayer(playerObj)
    DeadSiren.Log("Trying to spawn Screamer near player " .. tostring(playerObj and playerObj:getUsername()))

    local x, y, z = getRandomSpawnPoint(playerObj)
    if not x then
        DeadSiren.Log("Spawn failure: no valid spawn coordinates.")
        return nil
    end

    local zombie = addZombie(x, y, z, 0, nil, nil)
    if not zombie then
        DeadSiren.Log("Spawn failure: addZombie returned nil.")
        return nil
    end

    applyScreamerTraits(zombie)
    DeadSiren.Log("Spawn success: Screamer created at " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))

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

    DeadSiren.Log("Sent warning command to player " .. tostring(playerObj:getUsername()))
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
    DeadSiren.Log("EveryOneMinute: TryNightSpawnServer tick")

    despawnScreamerIfExpired()

    if isScreamerStillValid(DeadSiren.State.activeScreamer) then
        DeadSiren.Log("Existing Screamer is still active. Skipping spawn roll.")
        return
    end

    local hour = getGameTime():getHour()
    DeadSiren.Log("Current game hour=" .. tostring(hour))

    local passesNightCheck = isNightHour(hour)
    if DeadSiren.Debug then
        passesNightCheck = true
        DeadSiren.Log("Debug mode: night check bypassed.")
    end

    DeadSiren.Log("Night check passes=" .. tostring(passesNightCheck))
    if not passesNightCheck then
        return
    end

    local chance = getSpawnChance()
    local roll = ZombRandFloat(0.0, 1.0)
    DeadSiren.Log(string.format("Spawn roll result: roll=%.4f chance=%.4f", roll, chance))

    if roll > chance then
        DeadSiren.Log("Spawn roll failed.")
        return
    end

    local playerObj = pickTargetPlayer()
    if not playerObj then
        DeadSiren.Log("Spawn failed: no valid player selected.")
        return
    end

    local spawned = spawnScreamerNearPlayer(playerObj)
    if not spawned then
        DeadSiren.Log("Spawn failed after spawn attempt.")
        return
    end

    DeadSiren.State.activeScreamer = spawned
    DeadSiren.State.activeSinceMinute = getCurrentWorldMinute()
    DeadSiren.State.ownerUsername = playerObj:getUsername()

    DeadSiren.Log("Screamer active for owner=" .. tostring(DeadSiren.State.ownerUsername))
    sendWarningToPlayer(playerObj)
end

Events.EveryOneMinute.Add(DeadSiren.TryNightSpawnServer)
