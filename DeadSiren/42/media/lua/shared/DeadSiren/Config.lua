-- Dead Siren shared configuration.

DeadSiren = DeadSiren or {}
DeadSiren.Config = DeadSiren.Config or {}

-- Force debug for troubleshooting.
DeadSiren.Debug = true

-- Request-specific debug override value.
DeadSiren.SpawnChancePerMinuteDebug = 100

DeadSiren.Config.NightStartHour = 22
DeadSiren.Config.NightEndHour = 4

DeadSiren.Config.SpawnChancePerMinute = 0.004
DeadSiren.Config.SpawnChancePerMinuteDebug = DeadSiren.SpawnChancePerMinuteDebug

DeadSiren.Config.MinSpawnDistance = 10
DeadSiren.Config.MaxSpawnDistance = 20
DeadSiren.Config.MaxLifetimeMinutes = 20

DeadSiren.Config.ScreamRange = 10
DeadSiren.Config.ScreamCooldownMinutes = 3
DeadSiren.Config.ScreamRadius = 80
DeadSiren.Config.ScreamVolume = 100

DeadSiren.Config.WarningMessage = "I feel something watching me..."
DeadSiren.Config.ServerCommandModule = "DeadSiren"
DeadSiren.Config.ServerCommandWarning = "ShowScreamerWarning"

function DeadSiren.Log(message)
    if DeadSiren.Debug then
        print("[DeadSiren] " .. tostring(message))
    end
end

print("[DeadSiren] Config.lua loaded. Debug=" .. tostring(DeadSiren.Debug)
    .. ", DebugSpawnChance=" .. tostring(DeadSiren.SpawnChancePerMinuteDebug))

return DeadSiren
