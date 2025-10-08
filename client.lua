local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local currentGarage = nil
local inGarageStation = false
local isMenuOpen = false
local currentVehicleData = nil
local isPlayerLoaded = false
local sharedGaragesData = {}
local pendingJoinRequests = {}
local isHoveringVehicle = false
local hoveredVehicle = nil
local lastHoveredVehicle = nil
local vehicleHoverInfo = nil
local hoveredNetId = nil
local isGarageMenuOpen = false
local isVehicleFaded = false
local fadedVehicle = nil
local parkingPromptShown = false
local canStoreVehicle = false
local isStorageInProgress = false
local vehicleOwnershipCache = {}
local optimalParkingDistance = 12.0
local isTransferringVehicle = false
local currentTransferVehicle = nil
local isAtImpoundLot = false
local currentImpoundLot = nil
local impoundBlips = {}
local lastGarageCheckTime = nil
local lastGarageId = nil
local lastGarageType = nil
local lastGarageCoords = nil
local lastGarageDist = nil
local activeConfirmation = nil
local activeAnimations = {}
local parkedJobVehicles = {}

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    Wait(1000)

    if LocalPlayer.state.isLoggedIn then
        PlayerData = QBCore.Functions.GetPlayerData()
        isPlayerLoaded = true
    end
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    PlayerData = data
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(GangInfo)
    PlayerData.gang = GangInfo
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    isPlayerLoaded = true
end)

CreateThread(function()
    if Config.GarageBlip.Enable then
        -- Garajes públicos
        for k, v in pairs(Config.Garages) do
            local blip = AddBlipForCoord(v.coords.x, v.coords.y, v.coords.z)
            SetBlipSprite(blip, Config.GarageBlip.Sprite)
            SetBlipDisplay(blip, Config.GarageBlip.Display)
            SetBlipScale(blip, Config.GarageBlip.Scale)
            SetBlipAsShortRange(blip, Config.GarageBlip.ShortRange)
            SetBlipColour(blip, Config.GarageBlip.Color)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(v.label)
            EndTextCommandSetBlipName(blip)
        end

        -- Garajes de trabajo
        -- for k, v in pairs(Config.JobGarages) do
        --     local blip = AddBlipForCoord(v.coords.x, v.coords.y, v.coords.z)
        --     SetBlipSprite(blip, Config.GarageBlip.Sprite)
        --     SetBlipDisplay(blip, Config.GarageBlip.Display)
        --     SetBlipScale(blip, Config.GarageBlip.Scale)
        --     SetBlipAsShortRange(blip, Config.GarageBlip.ShortRange)
        --     SetBlipColour(blip, 38)
        --     BeginTextCommandSetBlipName("STRING")
        --     AddTextComponentSubstringPlayerName(v.label)
        --     EndTextCommandSetBlipName(blip)
        -- end

        -- Garajes de bandas
        -- for k, v in pairs(Config.GangGarages) do
        --     local blip = AddBlipForCoord(v.coords.x, v.coords.y, v.coords.z)
        --     SetBlipSprite(blip, Config.GarageBlip.Sprite)
        --     SetBlipDisplay(blip, Config.GarageBlip.Display)
        --     SetBlipScale(blip, Config.GarageBlip.Scale)
        --     SetBlipAsShortRange(blip, Config.GarageBlip.ShortRange)
        --     SetBlipColour(blip, 59)
        --     BeginTextCommandSetBlipName("STRING")
        --     AddTextComponentSubstringPlayerName(v.label)
        --     EndTextCommandSetBlipName(blip)
        -- end
    end

    -- Depósito
    if Config.EnableImpound then
        for k, v in pairs(Config.ImpoundLots) do
            local blip = AddBlipForCoord(v.coords.x, v.coords.y, v.coords.z)
            SetBlipSprite(blip, v.blip.sprite)
            SetBlipDisplay(blip, v.blip.display)
            SetBlipScale(blip, v.blip.scale)
            SetBlipAsShortRange(blip, v.blip.shortRange)
            SetBlipColour(blip, v.blip.color)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(v.label)
            EndTextCommandSetBlipName(blip)

            table.insert(impoundBlips, blip)
        end
    end
end)

function AddVisualDamageToProps(vehicle, props)
    -- Puertas
    props.doors = {}
    for i = 0, 5 do
        props.doors[i] = IsVehicleDoorDamaged(vehicle, i)
    end
    -- Ventanas
    props.windows = {}
    for i = 0, 7 do
        props.windows[i] = IsVehicleWindowIntact(vehicle, i)
    end
    -- Ruedas
    props.tyres = {}
    for i = 0, 7 do
        props.tyres[i] = IsVehicleTyreBurst(vehicle, i, false)
    end
    -- Capó y maletero
    props.bonnet = GetVehicleDoorAngleRatio(vehicle, 4) > 0.1
    props.trunk = GetVehicleDoorAngleRatio(vehicle, 5) > 0.1
    -- Faros
    props.headlights = {}
    props.taillights = {}
    for i = 0, 1 do
        props.headlights[i] = not IsVehicleHeadlightBroken(vehicle, i)
        props.taillights[i] = not IsVehicleTailLightBroken(vehicle, i)
    end
    -- Extras (retrovisores, etc.)
    props.extras = {}
    for i = 0, 20 do
        if DoesExtraExist(vehicle, i) then
            props.extras[i] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end
    -- Sirenas
    props.siren = IsVehicleSirenOn(vehicle)
    return props
end

function Lerp(a, b, t)
    return a + (b - a) * t
end

function GetClosestRoad(x, y, z, radius, oneSideOfRoad, allowJunctions)
    local outPosition = vector3(0.0, 0.0, 0.0)
    local outHeading = 0.0

    if GetClosestVehicleNode(x, y, z, outPosition, outHeading, 1, 3.0, 0) then
        return outPosition
    end

    return nil
end

function ShowConfirmDialog(title, message, onYes, onNo)
    activeConfirmation = {
        yesCallback = onYes,
        noCallback = onNo
    }

    local scaleform = RequestScaleformMovie("mp_big_message_freemode")
    while not HasScaleformMovieLoaded(scaleform) do
        Wait(0)
    end

    BeginScaleformMovieMethod(scaleform, "SHOW_SHARD_WASTED_MP_MESSAGE")
    ScaleformMovieMethodAddParamTextureNameString(title)
    ScaleformMovieMethodAddParamTextureNameString(message)
    ScaleformMovieMethodAddParamInt(5)
    EndScaleformMovieMethod()

    local key_Y = 246
    local key_N = 306

    CreateThread(function()
        local startTime = GetGameTimer()
        local showing = true

        while showing do
            Wait(0)

            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)

            BeginTextCommandDisplayHelp("STRING")
            AddTextComponentSubstringPlayerName(
                "Presione ~INPUT_REPLAY_START_STOP_RECORDING~ para SÍ o ~INPUT_REPLAY_SCREENSHOT~ para NO")
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustPressed(0, key_Y) then
                showing = false
                if activeConfirmation and activeConfirmation.yesCallback then
                    activeConfirmation.yesCallback()
                end
            elseif IsControlJustPressed(0, key_N) then
                showing = false
                if activeConfirmation and activeConfirmation.noCallback then
                    activeConfirmation.noCallback()
                end
            end

            if GetGameTimer() - startTime > 15000 then
                showing = false
                if activeConfirmation and activeConfirmation.noCallback then
                    activeConfirmation.noCallback()
                end
            end
        end

        SetScaleformMovieAsNoLongerNeeded(scaleform)
        activeConfirmation = nil
    end)
end

RegisterNetEvent('DP-Garages:client:DeleteGarage')
AddEventHandler('DP-Garages:client:DeleteGarage', function(garageId)
    TriggerServerEvent('DP-Garages:server:DeleteSharedGarage', garageId)
end)

RegisterNUICallback('confirmRemoveVehicle', function(data, cb)
    local plate = data.plate

    SetNuiFocus(false, false)

    Wait(100)

    local removeMenu = {{
        header = "Quitar vehículo",
        isMenuHeader = true
    }, {
        header = "Estas seguro",
        txt = "¿Retirar este vehículo del garaje compartido?",
        isMenuHeader = true
    }, {
        header = "Sí, retirar el vehículo.",
        txt = "El vehículo será devuelto a su garaje principal.",
        params = {
            isServer = true,
            event = "DP-Garages:server:RemoveVehicleFromSharedGarage",
            args = {
                plate = plate
            }
        }
    }, {
        header = "No, cancelar",
        txt = "Mantener el vehículo en garaje compartido",
        params = {
            event = ""
        }
    }}

    exports['qb-menu']:openMenu(removeMenu)

    cb({
        status = "success"
    })
end)

RegisterNetEvent('DP-Garages:client:ConfirmDeleteGarage', function(data)
    TriggerServerEvent('DP-Garages:server:DeleteSharedGarage', data.garageId)

    if callbackRegistry[data.callback] then
        callbackRegistry[data.callback](true)
        callbackRegistry[data.callback] = nil
    end

    SetNuiFocus(false, false)
end)

RegisterNetEvent('DP-Garages:client:CancelDeleteGarage')
AddEventHandler('DP-Garages:client:CancelDeleteGarage', function()
end)

RegisterNetEvent('DP-Garages:client:ConfirmRemoveVehicle', function(data)
    TriggerServerEvent('DP-Garages:server:RemoveVehicleFromSharedGarage', data.plate)

    if callbackRegistry[data.callback] then
        callbackRegistry[data.callback](true)
        callbackRegistry[data.callback] = nil
    end

    SetNuiFocus(false, false)
end)

RegisterNetEvent('DP-Garages:client:CancelRemoveVehicle', function(data)
    if callbackRegistry[data.callback] then
        callbackRegistry[data.callback](false)
        callbackRegistry[data.callback] = nil
    end

    SetNuiFocus(false, false)
end)

callbackRegistry = {}

RegisterNUICallback('confirmDeleteGarage', function(data, cb)
    local garageId = data.garageId

    exports['qb-menu']:openMenu({{
        header = "Confirmar eliminación",
        isMenuHeader = true
    }, {
        header = "Eliminar garaje",
        txt = "Todos los vehículos serán devueltos a sus propietarios.",
        params = {
            event = "DP-Garages:client:ConfirmDeleteSharedGarage",
            args = {
                garageId = garageId
            }
        }
    }, {
        header = "Cancelar",
        txt = "Mantenga este garaje",
        params = {
            event = "DP-Garages:client:CancelDeleteGarage"
        }
    }})

    cb({
        status = "success"
    })
end)

RegisterNetEvent('DP-Garages:client:ConfirmDeleteSharedGarage')
AddEventHandler('DP-Garages:client:ConfirmDeleteSharedGarage', function(data)
    local garageId = data.garageId

    TriggerServerEvent('DP-Garages:server:DeleteSharedGarage', garageId)

    SendNUIMessage({
        action = "garageDeleted",
        garageId = garageId
    })
end)

RegisterNUICallback('closeSharedGarageMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb({
        status = "success"
    })
end)

function AnimateVehicleMove(vehicle, toCoords, toHeading, duration, callback)
    if not DoesEntityExist(vehicle) then
        if callback then
            callback()
        end
        return
    end

    local startCoords = GetEntityCoords(vehicle)
    local startHeading = GetEntityHeading(vehicle)
    local startTime = GetGameTimer()
    local endTime = startTime + duration
    local animationId = math.random(1, 100000)
    activeAnimations[vehicle] = animationId
    NetworkRequestControlOfEntity(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetEntityInvincible(vehicle, true)
    SetVehicleDoorsLocked(vehicle, 4)
    FreezeEntityPosition(vehicle, false)

    CreateThread(function()
        while GetGameTimer() < endTime and DoesEntityExist(vehicle) and activeAnimations[vehicle] == animationId do
            local progress = (GetGameTimer() - startTime) / duration
            local currentX = startCoords.x + (toCoords.x - startCoords.x) * progress
            local currentY = startCoords.y + (toCoords.y - startCoords.y) * progress
            local currentZ = startCoords.z + (toCoords.z - startCoords.z) * progress
            local currentHeading = startHeading + (toHeading - startHeading) * progress

            SetEntityCoordsNoOffset(vehicle, currentX, currentY, currentZ, false, false, false)
            SetEntityHeading(vehicle, currentHeading)

            Wait(0)
        end

        if DoesEntityExist(vehicle) and activeAnimations[vehicle] == animationId then
            SetEntityCoordsNoOffset(vehicle, toCoords.x, toCoords.y, toCoords.z, false, false, false)
            SetEntityHeading(vehicle, toHeading)

            activeAnimations[vehicle] = nil

            SetEntityInvincible(vehicle, false)
            SetVehicleDoorsLocked(vehicle, 1)

            if callback then
                callback()
            end
        end
    end)
end

function IsJobVehicle(vehicle)
    if not DoesEntityExist(vehicle) then
        return false
    end

    local plate = QBCore.Functions.GetPlate(vehicle)
    if not plate then
        return false
    end

    if string.sub(plate, 1, 3) == "JOB" then
        return true
    end

    local model = GetEntityModel(vehicle)
    local modelName = string.lower(GetDisplayNameFromVehicleModel(model))

    for jobName, jobGarage in pairs(Config.JobGarages) do
        if jobGarage.vehicles then
            for vehicleModel, vehicleInfo in pairs(jobGarage.vehicles) do
                if string.lower(vehicleModel) == modelName then
                    return true, jobName
                end
            end
        end
    end

    return false
end

function DoesPlayerJobMatchVehicleJob(vehicle)
    if not DoesEntityExist(vehicle) then
        return false
    end
    if not PlayerData.job then
        return false
    end

    local jobName = PlayerData.job.name
    if not jobName then
        return false
    end

    local isJobVehicle, vehicleJobName = IsJobVehicle(vehicle)
    if not isJobVehicle then
        return false
    end

    if not vehicleJobName then
        local model = GetEntityModel(vehicle)
        local modelName = string.lower(GetDisplayNameFromVehicleModel(model))

        for k, v in pairs(Config.JobGarages) do
            if v.job == jobName and v.vehicles then
                for vehModel, _ in pairs(v.vehicles) do
                    if string.lower(vehModel) == modelName then
                        return true
                    end
                end
            end
        end
        return false
    end

    return vehicleJobName == jobName
end

RegisterNUICallback('getJobVehicles', function(data, cb)
    local job = data.job
    if not job then
        cb({
            jobVehicles = {}
        })
        return
    end

    local jobVehicles = {}

    for k, garage in pairs(Config.JobGarages) do
        if garage.job == job then
            local i = 1
            for model, vehicle in pairs(garage.vehicles) do
                table.insert(jobVehicles, {
                    id = i,
                    model = model,
                    name = vehicle.label,
                    fuel = 100,
                    engine = 100,
                    body = 100,
                    state = 1,
                    stored = true,
                    isJobVehicle = true,
                    icon = vehicle.icon or "🚗"
                })
                i = i + 1
            end
            break
        end
    end

    cb({
        jobVehicles = jobVehicles
    })
end)

RegisterNUICallback('takeOutJobVehicle', function(data, cb)
    local model = data.model

    if not model then
        cb({
            status = "error",
            message = "Modelo no válido"
        })
        return
    end

    local job = PlayerData.job.name
    if not job then
        cb({
            status = "error",
            message = "No se encontró trabajo"
        })
        return
    end

    local garageInfo = nil
    for k, v in pairs(Config.JobGarages) do
        if v.job == job then
            garageInfo = v
            break
        end
    end

    if not garageInfo then
        cb({
            status = "error",
            message = "Garaje de trabajo no encontrado"
        })
        return
    end

    local spawnPoints = nil
    if garageInfo.spawnPoints then
        spawnPoints = garageInfo.spawnPoints
    else
        spawnPoints = {garageInfo.spawnPoint}
    end

    local clearPoint = FindClearSpawnPoint(spawnPoints)
    if not clearPoint then
        cb({
            status = "error",
            message = "¡Todos los lugares de aparición están bloqueados!"
        })
        return
    end

    local spawnCoords = vector3(clearPoint.x, clearPoint.y, clearPoint.z)
    QBCore.Functions.SpawnVehicle(model, function(veh)
        if not veh or veh == 0 then
            QBCore.Functions.Notify("Error al crear el vehículo de trabajo. Inténtalo de nuevo.", "error")
            cb({
                status = "error",
                message = "No se pudo generar el vehículo"
            })
            return
        end

        SetEntityHeading(veh, clearPoint.w)
        exports['LegacyFuel']:SetFuel(veh, 100)

        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehicleDirtLevel(veh, 0.0)
        SetVehicleUndriveable(veh, false)
        SetVehicleEngineOn(veh, true, true, false)
        FixEngineSmoke(veh)

        -- 1. OBTENER MATRÍCULA (¡FUNCIÓN CORREGIDA!)
        local plate = QBCore.Functions.GetPlate(veh)

        -- 2. AÑADIR LA LLAVE AL JUGADOR (Evento de Server verificado)
        TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)

        -- 3. DESBLOQUEAR PUERTAS
        SetVehicleDoorsLocked(veh, 0)

        -- 4. SUBIR AL JUGADOR (Último paso, después de la llave y desbloqueo)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    end, spawnCoords, true)

    SetNuiFocus(false, false)
    isMenuOpen = false
end)

RegisterNUICallback('refreshVehicles', function(data, cb)
    local garageId = data.garageId
    local garageType = data.garageType

    if garageType == "public" then
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetPersonalVehicles', function(vehicles)
            if vehicles then
                SendNUIMessage({
                    action = "refreshVehicles",
                    vehicles = FormatVehiclesForNUI(vehicles)
                })
            end
        end, garageId)
    elseif garageType == "gang" then
        local gang = PlayerData.gang.name
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetGangVehicles', function(vehicles)
            if vehicles then
                SendNUIMessage({
                    action = "refreshVehicles",
                    vehicles = FormatVehiclesForNUI(vehicles)
                })
            end
        end, gang, garageId)
    elseif garageType == "shared" then
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetSharedGarageVehicles', function(vehicles)
            if vehicles then
                SendNUIMessage({
                    action = "refreshVehicles",
                    vehicles = FormatVehiclesForNUI(vehicles)
                })
            end
        end, garageId)
    elseif garageType == "impound" then
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetImpoundedVehicles', function(vehicles)
            if vehicles then
                SendNUIMessage({
                    action = "refreshVehicles",
                    vehicles = FormatVehiclesForNUI(vehicles)
                })
            end
        end)
    end

    cb({
        status = "refreshing"
    })
end)

function FormatVehiclesForNUI(vehicles)
    local formattedVehicles = {}
    local currentGarageId = currentGarage and currentGarage.id or nil
    for i, vehicle in ipairs(vehicles) do
        local vehicleInfo = QBCore.Shared.Vehicles[vehicle.vehicle]
        if vehicleInfo then
            local enginePercent = round(vehicle.engine / 10, 1)
            local bodyPercent = round(vehicle.body / 10, 1)
            local fuelPercent = vehicle.fuel or 100

            local displayName = vehicleInfo.name
            if vehicle.custom_name and vehicle.custom_name ~= "" then
                displayName = vehicle.custom_name
            end

            local isInCurrentGarage = false
            if currentGarage and currentGarage.type == "job" then
                isInCurrentGarage = true
            else
                if vehicle.garage and currentGarageId then
                    isInCurrentGarage = (vehicle.garage == currentGarageId)
                end
            end

            local impoundFee = nil
            local impoundReason = nil
            local impoundedBy = nil
            local daysImpounded = nil

            if vehicle.state == 2 then
                impoundFee = Config.ImpoundFee

                if vehicle.impoundfee ~= nil then
                    local customFee = tonumber(vehicle.impoundfee)
                    if customFee and customFee > 0 then
                        impoundFee = customFee
                    end
                end

                impoundReason = vehicle.impoundreason or "No se especifica ningún motivo"
                impoundedBy = vehicle.impoundedby or "Oficial desconocido"
                daysImpounded = 1
            end

            local isStored = vehicle.state == 1
            local isOut = vehicle.state == 0

            local icon = nil
            if QBCore.Shared.Vehicles[vehicle.vehicle] and QBCore.Shared.Vehicles[vehicle.vehicle].image then
                -- Vanilla: usa la imagen vanilla (o deja nil para que el NUI la resuelva solo)
                icon = nil
            else
                -- Add-on: usa la imagen custom si existe
                icon = "images/" .. vehicle.vehicle .. ".png"
            end

            table.insert(formattedVehicles, {
                id = i,
                plate = vehicle.plate,
                model = vehicle.vehicle,
                name = displayName,
                fuel = fuelPercent,
                engine = enginePercent,
                body = bodyPercent,
                state = vehicle.state,
                garage = vehicle.garage or "Desconocido",
                stored = isStored,
                isOut = isOut,
                inCurrentGarage = isInCurrentGarage,
                isFavorite = vehicle.is_favorite == 1,
                owner = vehicle.citizenid,
                ownerName = vehicle.owner_name,
                storedInGang = vehicle.stored_in_gang,
                storedInShared = vehicle.shared_garage_id ~= nil,
                sharedGarageId = vehicle.shared_garage_id,
                currentGarage = currentGarageId,
                impoundFee = impoundFee,
                impoundReason = impoundReason,
                impoundedBy = impoundedBy,
                daysImpounded = daysImpounded,
                impoundType = vehicle.impoundtype,
                icon = icon
            })
        end
    end

    return formattedVehicles
end

Citizen.CreateThread(function()
    while QBCore == nil do
        Wait(0)
    end

    local originalDeleteVehicle = QBCore.Functions.DeleteVehicle

    QBCore.Functions.DeleteVehicle = function(vehicle)
        if DoesEntityExist(vehicle) then
            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            TriggerServerEvent('QBCore:Server:DeleteVehicle', netId)
            return originalDeleteVehicle(vehicle)
        end
    end
end)

Citizen.CreateThread(function()
    local trackedVehicles = {}
    while true do
        Wait(1000)
        local vehicles = GetGamePool('CVehicle')
        local currentVehicles = {}
        for _, vehicle in pairs(vehicles) do
            if DoesEntityExist(vehicle) then
                local plate = QBCore.Functions.GetPlate(vehicle)
                if plate then
                    currentVehicles[plate] = true
                end
            end
        end
        for plate, _ in pairs(trackedVehicles) do
            if not currentVehicles[plate] then
                TriggerServerEvent('DP-Garages:server:HandleDeletedVehicle', plate)
                trackedVehicles[plate] = nil
            end
        end
        trackedVehicles = currentVehicles
    end
end)

RegisterNetEvent('QBCore:Command:DeleteVehicle', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 then
        local plate = QBCore.Functions.GetPlate(veh)
        if plate then
            TriggerServerEvent('DP-Garages:server:HandleDeletedVehicle', plate)
        end
    else
        local coords = GetEntityCoords(ped)
        local vehicles = GetGamePool('CVehicle')
        for _, v in pairs(vehicles) do
            if #(coords - GetEntityCoords(v)) <= 5.0 then
                local plate = QBCore.Functions.GetPlate(v)
                if plate then
                    TriggerServerEvent('DP-Garages:server:HandleDeletedVehicle', plate)
                end
            end
        end
    end
end)

RegisterNUICallback('checkVehicleState', function(data, cb)
    local plate = data.plate

    if not plate then
        cb({
            state = 1
        })
        return
    end
    QBCore.Functions.TriggerCallback('DP-Garages:server:CheckVehicleStatus', function(isStored)
        if isStored then
            cb({
                state = 1
            })
        else
            cb({
                state = 0
            })
        end
    end, plate)
end)

RegisterNUICallback('refreshImpoundVehicles', function(data, cb)

    QBCore.Functions.TriggerCallback('DP-Garages:server:GetImpoundedVehicles', function(vehicles)
        if vehicles then
            for i, vehicle in ipairs(vehicles) do
                Wait(100)
            end

            local formattedVehicles = FormatVehiclesForNUI(vehicles)
            SendNUIMessage({
                action = "refreshVehicles",
                vehicles = formattedVehicles
            })
        else
            SendNUIMessage({
                action = "refreshVehicles",
                vehicles = {}
            })
        end
    end)

    cb({
        status = "refreshing"
    })
end)

RegisterCommand('debuggarage', function(source, args)
    local garageId = args[1] or (currentGarage and currentGarage.id or "Desconocido")

    QBCore.Functions.TriggerCallback('DP-Garages:server:GetJobGarageVehicles', function(vehicles)
        for i, v in ipairs(vehicles) do
            Wait(100)
        end
        local formatted = FormatVehiclesForNUI(vehicles)

        local currentGarageTest = currentGarage
        currentGarage = {
            id = garageId,
            type = "job"
        }
        QBCore.Functions.Notify("Se encontraron " .. #vehicles.. " vehículos en el garaje ".. garageId, "primary", 5000)

        currentGarage = currentGarageTest
    end, garageId)
end, false)

function GetClosestVehicleInGarage(garageCoords, maxDistance)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local vehicles = GetGamePool('CVehicle')
    local closestVehicle = 0
    local closestDistance = maxDistance

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        local vehicleCoords = GetEntityCoords(vehicle)

        local distToGarage = #(vehicleCoords - garageCoords)

        if distToGarage <= maxDistance then
            local distToPlayer = #(vehicleCoords - pedCoords)

            if distToPlayer < closestDistance then
                closestVehicle = vehicle
                closestDistance = distToPlayer
            end
        end
    end

    if DoesEntityExist(closestVehicle) then
        Wait(100)
    end

    return closestVehicle
end

function FadeOutVehicle(vehicle, callback)
    CreateThread(function()
        QBCore.Functions.DeleteVehicle(vehicle)

        if callback then
            callback()
        end
    end)
end

function GetAllAttachedEntities(entity)
    local entities = {}

    if IsEntityAVehicle(entity) and IsVehicleAttachedToTrailer(entity) then
        local trailer = GetVehicleTrailerVehicle(entity)
        if trailer and trailer > 0 then
            table.insert(entities, trailer)
        end
    end

    return entities
end

function GetClosestGaragePoint()
    local playerPos = GetEntityCoords(PlayerPedId())
    local closestDist = 1000.0
    local closestGarage = nil
    local closestCoords = nil
    local closestGarageType = nil

    for k, v in pairs(Config.Garages) do
        local garageCoords = vector3(v.coords.x, v.coords.y, v.coords.z)
        local dist = #(playerPos - garageCoords)
        if dist < closestDist then
            closestDist = dist
            closestGarage = k
            closestCoords = garageCoords
            closestGarageType = "public"
        end
    end

    if PlayerData.job then
        for k, v in pairs(Config.JobGarages) do
            if v.job == PlayerData.job.name then
                local garageCoords = vector3(v.coords.x, v.coords.y, v.coords.z)
                local dist = #(playerPos - garageCoords)
                if dist < closestDist then
                    closestDist = dist
                    closestGarage = k
                    closestCoords = garageCoords
                    closestGarageType = "job"
                end
            end
        end
    end

    if PlayerData.gang and PlayerData.gang.name ~= "none" then
        for k, v in pairs(Config.GangGarages) do
            if v.gang == PlayerData.gang.name then
                local garageCoords = vector3(v.coords.x, v.coords.y, v.coords.z)
                local dist = #(playerPos - garageCoords)
                if dist < closestDist then
                    closestDist = dist
                    closestGarage = k
                    closestCoords = garageCoords
                    closestGarageType = "gang"
                end
            end
        end
    end

    if closestDist <= optimalParkingDistance then
        return closestGarage, closestGarageType, closestCoords, closestDist
    end

    return nil, nil, nil, nil
end

function FindClearSpawnPoint(spawnPoints)
    for i, point in ipairs(spawnPoints) do
        local coords = vector3(point.x, point.y, point.z)
        local clear = true

        local vehicles = GetGamePool('CVehicle')
        for j = 1, #vehicles do
            local vehicleCoords = GetEntityCoords(vehicles[j])
            if #(vehicleCoords - coords) <= 3.0 then
                clear = false
                break
            end
        end

        if clear then
            return point
        end
    end

    return nil
end

function IsVehicleOwned(vehicle)
    local plate = QBCore.Functions.GetPlate(vehicle)
    if not plate then
        return false
    end

    if vehicleOwnershipCache[plate] ~= nil then
        return vehicleOwnershipCache[plate]
    end

    vehicleOwnershipCache[plate] = false

    QBCore.Functions.TriggerCallback('DP-Garages:server:CheckIfVehicleOwned', function(owned)
        vehicleOwnershipCache[plate] = owned
    end, plate)

    return vehicleOwnershipCache[plate]
end

CreateThread(function()
    while true do
        Wait(60000)
        vehicleOwnershipCache = {}
    end
end)

function FixEngineSmoke(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)

    SetVehicleEngineHealth(vehicle, 1000.0)
    Wait(50)

    if engineHealth < 300.0 then
        engineHealth = 300.0
    end

    SetVehicleEngineHealth(vehicle, engineHealth)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleDamage(vehicle, 0.0, 0.0, 0.3, 0.0, 0.0, false)

    SetEntityProofs(vehicle, false, true, false, false, false, false, false, false)
    Wait(100)
    SetEntityProofs(vehicle, false, false, false, false, false, false, false, false)
end

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)

    if onScreen then
        local dist = #(GetGameplayCamCoords() - vector3(x, y, z))
        local scale = (1 / dist) * 2.5
        local fov = (1 / GetGameplayCamFov()) * 100
        scale = scale * fov * 0.7

        SetTextScale(0.0, 0.40 * scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropShadow(0, 0, 0, 55)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)

        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.017 + factor, 0.03 * scale, 0, 0, 0, 75)

        local highlight = math.abs(math.sin(GetGameTimer() / 500)) * 50
        DrawRect(_x, _y + 0.0125 - 0.01 * scale, 0.017 + factor, 0.002 * scale, 255, 255, 255, highlight)
    end
end

CreateThread(function()
    local activeTextId = nil -- Variable para controlar el TextUI activo

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local isInVehicle = IsPedInAnyVehicle(ped, false)
        local vehicle = GetVehiclePedIsIn(ped, true)

        if not DoesEntityExist(vehicle) then
            isVehicleFaded = false
            fadedVehicle = nil
            parkingPromptShown = false
            canStoreVehicle = false
            isStorageInProgress = false
            
            -- Ocultar TextUI si no hay vehículo
            if activeTextId then
                exports['DP-TextUI']:OcultarUI(activeTextId)
                activeTextId = nil
            end
            
            Wait(sleep)
        else
            -- Obtener información del garaje más cercano
            local garageId, garageType, garageCoords, garageDist = GetClosestGaragePoint()

            if garageId and garageDist <= optimalParkingDistance then
                local vehicleCoords = GetEntityCoords(vehicle)
                local speed = GetEntitySpeed(vehicle)
                local isStationary = speed < 0.1
                local plate = QBCore.Functions.GetPlate(vehicle)

                if plate then
                    -- Verificar si el jugador está en el asiento del conductor
                    local pedInDriverSeat = (GetPedInVehicleSeat(vehicle, -1) == ped)

                    -- SOLO mostrar mensaje si está DENTRO del vehículo como conductor
                    if isInVehicle and pedInDriverSeat and isStationary then
                        
                        -- Lógica para vehículos de trabajo
                        local skipToEnd = false
                        if garageType == "job" and PlayerData.job then
                            local jobName = PlayerData.job.name
                            local jobGarage = Config.JobGarages[garageId]

                            if jobGarage and jobGarage.job == jobName then
                                local isJobVehicle = false
                                local model = GetEntityModel(vehicle)
                                local modelName = string.lower(GetDisplayNameFromVehicleModel(model))

                                if jobGarage.vehicles then
                                    for jobVehModel, _ in pairs(jobGarage.vehicles) do
                                        if string.lower(jobVehModel) == modelName then
                                            isJobVehicle = true
                                            break
                                        end
                                    end
                                end

                                if isJobVehicle then
                                    if not isVehicleFaded or fadedVehicle ~= vehicle then
                                        isVehicleFaded = true
                                        fadedVehicle = vehicle
                                        canStoreVehicle = true
                                    end

                                    if not isStorageInProgress then
                                        sleep = 0
                                        parkingPromptShown = true
                                    end
                                    skipToEnd = true
                                end
                            end
                        end

                        if not skipToEnd then
                            -- Lógica para vehículos personales
                            local isOwned = vehicleOwnershipCache[plate]
                            if isOwned == nil then
                                QBCore.Functions.TriggerCallback('DP-Garages:server:CheckIfVehicleOwned', function(owned)
                                    vehicleOwnershipCache[plate] = owned
                                end, plate)
                                isOwned = false
                            end

                            if isOwned then
                                if not isVehicleFaded or fadedVehicle ~= vehicle then
                                    isVehicleFaded = true
                                    fadedVehicle = vehicle
                                    canStoreVehicle = true
                                end

                                if not isStorageInProgress then
                                    sleep = 0
                                    parkingPromptShown = true
                                    
                                    -- Mostrar TextUI para vehículos personales (REEMPLAZO DEL DrawText3D)
                                    local textId = "personal_vehicle_store_" .. plate
                                    if activeTextId ~= textId then
                                        if activeTextId then
                                            exports['DP-TextUI']:OcultarUI(activeTextId)
                                        end
                                        exports['DP-TextUI']:MostrarUI(textId, 'Para guardar vehículo', 'G', false)
                                        activeTextId = textId
                                    end

                                    if IsControlJustPressed(0, 47) and canStoreVehicle then
                                        TriggerEvent('DP-Garages:client:StoreVehicle', {
                                            garageId = garageId,
                                            garageType = garageType
                                        })
                                        
                                        -- Ocultar TextUI después de guardar
                                        if activeTextId then
                                            exports['DP-TextUI']:OcultarUI(activeTextId)
                                            activeTextId = nil
                                        end
                                    end
                                end
                            else
                                if isVehicleFaded and fadedVehicle == vehicle then
                                    isVehicleFaded = false
                                    fadedVehicle = nil
                                    parkingPromptShown = false
                                    canStoreVehicle = false
                                    
                                    -- Ocultar TextUI si el vehículo no es propiedad
                                    if activeTextId then
                                        exports['DP-TextUI']:OcultarUI(activeTextId)
                                        activeTextId = nil
                                    end
                                end
                            end
                        end
                    else
                        -- Si no está dentro del vehículo como conductor, limpiar estados
                        if isVehicleFaded and fadedVehicle == vehicle then
                            isVehicleFaded = false
                            fadedVehicle = nil
                            parkingPromptShown = false
                            canStoreVehicle = false
                            
                            -- Ocultar TextUI
                            if activeTextId then
                                exports['DP-TextUI']:OcultarUI(activeTextId)
                                activeTextId = nil
                            end
                        end
                    end
                else
                    -- Ocultar TextUI si no hay matrícula
                    if activeTextId then
                        exports['DP-TextUI']:OcultarUI(activeTextId)
                        activeTextId = nil
                    end
                end
            else
                -- Si no está cerca de un garaje, limpiar estados
                if isVehicleFaded and fadedVehicle == vehicle then
                    isVehicleFaded = false
                    fadedVehicle = nil
                    parkingPromptShown = false
                    canStoreVehicle = false
                    
                    -- Ocultar TextUI
                    if activeTextId then
                        exports['DP-TextUI']:OcultarUI(activeTextId)
                        activeTextId = nil
                    end
                end
            end

            -- Lógica adicional para verificar acceso a vehículos de trabajo cuando estás dentro
            if isInVehicle then
                local currentVehicle = GetVehiclePedIsIn(ped, false)

                if currentVehicle > 0 and DoesEntityExist(currentVehicle) then
                    local plate = QBCore.Functions.GetPlate(currentVehicle)
                    if plate then
                        QBCore.Functions.TriggerCallback('DP-Garages:server:CheckJobAccess', function(hasAccess)
                            if not hasAccess then
                                local isJobVehicle = false
                                local jobName = nil

                                for k, v in pairs(Config.JobGarages) do
                                    local model = GetEntityModel(currentVehicle)
                                    local modelName = string.lower(GetDisplayNameFromVehicleModel(model))

                                    if v.vehicles then
                                        for jobVehModel, _ in pairs(v.vehicles) do
                                            if string.lower(jobVehModel) == modelName then
                                                isJobVehicle = true
                                                jobName = v.job
                                                break
                                            end
                                        end
                                    end

                                    if isJobVehicle then
                                        break
                                    end
                                end

                                if isJobVehicle and jobName ~= PlayerData.job.name then
                                    TaskLeaveVehicle(ped, currentVehicle, 0)
                                    QBCore.Functions.Notify("No tienes acceso a este vehículo de trabajo", "error")
                                    
                                    -- Ocultar TextUI si pierdes acceso
                                    if activeTextId then
                                        exports['DP-TextUI']:OcultarUI(activeTextId)
                                        activeTextId = nil
                                    end
                                end
                            end
                        end, plate)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

function CreateGarageAttendant(coords, heading, model)
    RequestModel(GetHashKey(model))
    while not HasModelLoaded(GetHashKey(model)) do
        Wait(1)
    end

    local ped = CreatePed(4, GetHashKey(model), coords.x, coords.y, coords.z - 1.0, heading, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CLIPBOARD", 0, true)

    return ped
end

CreateThread(function()
    while not isPlayerLoaded do
        Wait(500)
    end

    local attendantModels = {"s_m_m_security_01", "s_m_y_valet_01", "s_m_m_gentransport", "s_m_m_autoshop_01",
                             "s_m_m_autoshop_02"}

    local garageAttendants = {}

    for k, v in pairs(Config.Garages) do
        local model = attendantModels[math.random(1, #attendantModels)]
        local ped = CreateGarageAttendant(v.coords, v.coords.w, model)
        table.insert(garageAttendants, {
            ped = ped,
            garageId = k,
            garageType = "public"
        })
    end

    for k, v in pairs(Config.JobGarages) do
        local model = attendantModels[math.random(1, #attendantModels)]
        local ped = CreateGarageAttendant(v.coords, v.coords.w, model)
        table.insert(garageAttendants, {
            ped = ped,
            garageId = k,
            garageType = "job",
            jobName = v.job
        })
    end

    for k, v in pairs(Config.GangGarages) do
        local model = attendantModels[math.random(1, #attendantModels)]
        local ped = CreateGarageAttendant(v.coords, v.coords.w, model)
        table.insert(garageAttendants, {
            ped = ped,
            garageId = k,
            garageType = "gang",
            gangName = v.gang
        })
    end

    for k, v in pairs(Config.ImpoundLots) do
        local model = "s_m_y_cop_01"
        if k == "paleto" then
            model = "s_m_y_sheriff_01"
        elseif k == "sandy" then
            model = "s_m_y_ranger_01"
        end

        local ped = CreateGarageAttendant(v.coords, v.coords.w, model)
        table.insert(garageAttendants, {
            ped = ped,
            garageId = k,
            garageType = "impound"
        })
    end

    if Config.UseTarget then
        -- Lógica para qb-target
        for _, data in pairs(garageAttendants) do
            if data.garageType == "public" then
                exports['qb-target']:AddTargetEntity(data.ped, {
                    options = {{
                        type = "client",
                        event = "DP-Garages:client:OpenGarage",
                        icon = "fas fa-car",
                        label = "Abrir Garaje",
                        garageId = data.garageId,
                        garageType = data.garageType
                    }},
                    distance = 2.5
                })
            elseif data.garageType == "job" then
                exports['qb-target']:AddTargetEntity(data.ped, {
                    options = {{
                        type = "client",
                        event = "DP-Garages:client:OpenGarage",
                        icon = "fas fa-car",
                        label = "Abrir Garaje de trabajo",
                        garageId = data.garageId,
                        garageType = data.garageType
                    }},
                    distance = 2.5,
                    job = data.jobName
                })
            elseif data.garageType == "gang" then
                exports['qb-target']:AddTargetEntity(data.ped, {
                    options = {{
                        type = "client",
                        event = "DP-Garages:client:OpenGarage",
                        icon = "fas fa-car",
                        label = "Abrir Garake de bandas",
                        garageId = data.garageId,
                        garageType = data.garageType
                    }},
                    distance = 2.5,
                    gang = data.gangName
                })
            elseif data.garageType == "impound" then
                exports['qb-target']:AddTargetEntity(data.ped, {
                    options = {{
                        type = "client",
                        event = "DP-Garages:client:OpenImpoundLot",
                        icon = "fas fa-car",
                        label = "Comprobar lote incautado",
                        impoundId = data.garageId
                    }},
                    distance = 2.5
                })
            end
        end
    else
        -- Lógica unificada para DP-TextUI o DrawText3D
        local activeTextId = nil -- Variable para saber qué TextUI está activo

        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local currentGarage = nil
            local isPlayerInVehicle = IsPedInAnyVehicle(ped)

            if not isPlayerInVehicle then
                for k, v in pairs(Config.Garages) do
                    local dist = #(pos - vector3(v.coords.x, v.coords.y, v.coords.z))
                    if dist <= 3.0 then
                        currentGarage = {
                            id = k,
                            type = "public",
                            label = "Hablar con Gregor"
                        }
                        break
                    end
                end

                if not currentGarage then
                    for k, v in pairs(Config.JobGarages) do
                        if PlayerData.job and PlayerData.job.name == v.job then
                            local dist = #(pos - vector3(v.coords.x, v.coords.y, v.coords.z))
                            if dist <= 3.0 then
                                currentGarage = {
                                    id = k,
                                    type = "job",
                                    label = "Hablar con Smith"
                                }
                                break
                            end
                        end
                    end
                end

                if not currentGarage then
                    for k, v in pairs(Config.GangGarages) do
                        if PlayerData.gang and PlayerData.gang.name == v.gang then
                            local dist = #(pos - vector3(v.coords.x, v.coords.y, v.coords.z))
                            if dist <= 3.0 then
                                currentGarage = {
                                    id = k,
                                    type = "gang",
                                    label = "Hablar con Michael"
                                }
                                break
                            end
                        end
                    end
                end

                if not currentGarage then
                    for k, v in pairs(Config.ImpoundLots) do
                        local dist = #(pos - vector3(v.coords.x, v.coords.y, v.coords.z))
                        if dist <= 3.0 then
                            currentGarage = {
                                id = k,
                                type = "impound",
                                label = "Hablar con Mr.Williams"
                            }
                            break
                        end
                    end
                end
            end

            -- Lógica para mostrar/ocultar el TextUI o DrawText3D
            if currentGarage then
                sleep = 0
                if Config.UseDPTextUI then
                    -- Solo mostrar si no hay un TextUI activo o si es una zona diferente
                    if activeTextId ~= currentGarage.id then
                        exports['DP-TextUI']:OcultarUI()
                        exports['DP-TextUI']:MostrarUI(currentGarage.id, currentGarage.label, 'E', false)
                        activeTextId = currentGarage.id
                    end
                else
                    -- DrawText3D se dibuja en cada tick para ser visible
                    DrawText3D(pos.x, pos.y, pos.z, currentGarage.label)
                end

                if IsControlJustReleased(0, 38) then
                    if currentGarage.type == "impound" then
                        TriggerEvent("DP-Garages:client:OpenImpoundLot", {
                            impoundId = currentGarage.id
                        })
                    else
                        TriggerEvent("DP-Garages:client:OpenGarage", {
                            garageId = currentGarage.id,
                            garageType = currentGarage.type
                        })
                    end
                end
            else
                -- Si el jugador no está en una zona, oculta el TextUI
                if Config.UseDPTextUI and activeTextId then
                    exports['DP-TextUI']:OcultarUI(activeTextId)
                    activeTextId = nil
                end
            end

            Wait(sleep)
        end
    end
end)

function OpenGarageUI(vehicles, garageInfo, garageType)

    table.sort(vehicles, function(a, b)
        if a.is_favorite and not b.is_favorite then
            return true
        elseif not a.is_favorite and b.is_favorite then
            return false
        else
            return a.vehicle < b.vehicle
        end
    end)

    local vehicleData = FormatVehiclesForNUI(vehicles)

    local hasGang = false
    if PlayerData.gang and PlayerData.gang.name and PlayerData.gang.name ~= "none" then
        hasGang = true
    end

    local hasJobAccess = false

    local isInJobGarage = false
    if garageType == "job" then
        if garageInfo.job == PlayerData.job.name then
            isInJobGarage = true
            hasJobAccess = true
        end
    end

    QBCore.Functions.TriggerCallback('DP-Garages:server:GetAllGarages', function(allGarages)
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "openGarage",
            vehicles = vehicleData,
            garage = {
                name = garageInfo.label,
                type = garageType,
                location = garageInfo.label,
                hasGang = hasGang,
                hasJobAccess = isInJobGarage,
                hasSharedAccess = Config.EnableSharedGarages,
                showJobVehiclesTab = true,
                gangName = PlayerData.gang and PlayerData.gang.name or nil,
                jobName = PlayerData.job and PlayerData.job.name or nil,
                isJobGarage = garageType == "job",
                isSharedGarage = garageType == "shared",
                isImpound = garageType == "impound",
                id = garageInfo.id
            },
            allGarages = allGarages,
            transferCost = Config.TransferCost or 500
        })
    end)

end

RegisterNetEvent('DP-Garages:client:OpenGarage', function(data)
    if isMenuOpen then
        return
    end
    isMenuOpen = true

    local garageId = data.garageId
    local garageType = data.garageType
    local garageInfo = {}
    currentGarage = {
        id = garageId,
        type = garageType
    }

    if garageType == "public" then
        garageInfo = Config.Garages[garageId]
    elseif garageType == "job" then
        garageInfo = Config.JobGarages[garageId]
    elseif garageType == "gang" then
        garageInfo = Config.GangGarages[garageId]
    elseif garageType == "shared" then
        garageInfo = data.garageInfo
    elseif garageType == "impound" then
        garageInfo = Config.ImpoundLots[garageId]
    end

    local isImpoundLot = (garageType == "impound")

    if garageType == "public" then
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetPersonalVehicles', function(vehicles)
            OpenGarageUI(vehicles or {}, garageInfo, garageType, isImpoundLot)
        end)
    elseif garageType == "job" then
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetJobGarageVehicles', function(vehicles)
            OpenGarageUI(vehicles or {}, garageInfo, garageType, isImpoundLot)
        end, garageId)
    elseif garageType == "gang" then
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetGangVehicles', function(vehicles)
            OpenGarageUI(vehicles or {}, garageInfo, garageType, isImpoundLot)
        end, garageInfo.gang, garageId)
    elseif garageType == "shared" then
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetSharedGarageVehicles', function(vehicles)
            OpenGarageUI(vehicles or {}, garageInfo, garageType, isImpoundLot)
        end, garageId)
    elseif garageType == "impound" then
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetImpoundedVehicles', function(vehicles)
            OpenGarageUI(vehicles or {}, garageInfo, garageType, isImpoundLot)
        end)
    end
end)

function DebugJobGarage(garageId)
    local jobGarageInfo = Config.JobGarages[garageId]
    if not jobGarageInfo then
        Wait(100)
        return
    end

    QBCore.Functions.TriggerCallback('DP-Garages:server:GetPersonalVehicles', function(vehicles)

        local count = 0
        for i, vehicle in ipairs(vehicles) do
            if vehicle.garage == garageId then
                count = count + 1
            end
        end

        if count == 0 then
            Wait(100)
        end
    end)
end

function OpenJobGarageUI(garageInfo, isImpoundLot)
    local jobVehicles = {}
    local i = 1

    for k, v in pairs(garageInfo.vehicles) do

        table.insert(jobVehicles, {
            id = i,
            model = v.model,
            name = v.label,
            fuel = 100,
            engine = 100,
            body = 100,
            state = 1,
            stored = true,
            isFavorite = false,
            isJobVehicle = true,
            icon = v.icon or "🚗"
        })
        i = i + 1
    end
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openGarage",
        vehicles = jobVehicles,
        garage = {
            name = garageInfo.label,
            type = "job",
            location = garageInfo.label,
            isJobGarage = true,
            jobName = PlayerData.job and PlayerData.job.name or nil,
            hasJobAccess = true,
            isImpound = isImpoundLot
        }
    })
end

RegisterNetEvent('DP-Garages:client:CloseGarage')
AddEventHandler('DP-Garages:client:CloseGarage', function()
    SetNuiFocus(false, false)
end)

RegisterNUICallback('closeGarage', function(data, cb)
    SetNuiFocus(false, false)
    isMenuOpen = false
    cb({
        status = "success"
    })
end)

-- Fix for takeOutVehicle NUI callback
RegisterNUICallback('takeOutVehicle', function(data, cb)
    local plate = data.plate
    local model = data.model

    SetNuiFocus(false, false)
    isMenuOpen = false

    if data.state == 0 then
        QBCore.Functions.Notify("Este vehículo ya está fuera del garaje.", "error")
        cb({
            status = "error",
            message = "Vehículo ya salido"
        })
        return
    end

    QBCore.Functions.TriggerCallback('DP-Garages:server:GetVehicleByPlate', function(vehData, isOut)
        if isOut then
            QBCore.Functions.Notify("Este vehículo ya está afuera.", "error")
            cb({
                status = "error",
                message = "Vehículo ya salido"
            })
            return
        end

        local garageInfo = {}
        if currentGarage.type == "public" then
            garageInfo = Config.Garages[currentGarage.id]
        elseif currentGarage.type == "job" then
            garageInfo = Config.JobGarages[currentGarage.id]
        elseif currentGarage.type == "gang" then
            garageInfo = Config.GangGarages[currentGarage.id]
        elseif currentGarage.type == "shared" then
            garageInfo = sharedGaragesData[currentGarage.id]
        end

        local spawnPoints = nil
        if garageInfo.spawnPoints then
            spawnPoints = garageInfo.spawnPoints
        else
            spawnPoints = {garageInfo.spawnPoint}
        end

        local clearPoint = FindClearSpawnPoint(spawnPoints)
        if not clearPoint then
            QBCore.Functions.Notify("¡Todos los lugares de aparición están bloqueados!", "error")
            cb({
                status = "error",
                message = "Ubicaciones de generación bloqueadas"
            })
            return
        end

        if currentGarage.type == "shared" then
            QBCore.Functions.TriggerCallback('DP-Garages:server:CheckSharedAccess', function(hasAccess)
                if hasAccess then
                    TriggerServerEvent('DP-Garages:server:TakeOutSharedVehicle', plate, currentGarage.id)
                    cb({
                        status = "success"
                    })
                else
                    QBCore.Functions.Notify("No tienes acceso a este vehículo", "error")
                    cb({
                        status = "error",
                        message = "Sin acceso"
                    })
                end
            end, plate, currentGarage.id)
            return
        end

        local spawnCoords = vector3(clearPoint.x, clearPoint.y, clearPoint.z)

        QBCore.Functions.SpawnVehicle(model, function(veh)
            if not veh or veh == 0 then
                QBCore.Functions.Notify("No se pudo generar el vehículo", "error")
                cb({
                    status = "error",
                    message = "No se pudo generar"
                })
                return
            end

            SetEntityHeading(veh, clearPoint.w)
            exports['LegacyFuel']:SetFuel(veh, data.fuel)
            SetVehicleNumberPlateText(veh, plate)

            if currentGarage.type == "public" or currentGarage.type == "gang" then
                QBCore.Functions.TriggerCallback('DP-Garages:server:GetVehicleProperties', function(properties)
                    if properties then
                        QBCore.Functions.SetVehicleProperties(veh, properties)

                        SetVehicleDirtLevel(veh, 0.0)
                        FixEngineSmoke(veh)
                        SetVehicleUndriveable(veh, false)
                        SetVehicleEngineOn(veh, true, true, false)
                        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)

                        TriggerServerEvent('DP-Garages:server:UpdateVehicleState', plate, 0)

                        if currentGarage.type == "gang" and data.storedInGang then
                            TriggerServerEvent('DP-Garages:server:UpdateGangVehicleState', plate, 0)
                        end

                        QBCore.Functions.Notify("Vehículo sacado", "success")
                        cb({
                            status = "success"
                        })
                    else
                        cb({
                            status = "error",
                            message = "No se pudieron cargar las propiedades"
                        })
                    end
                end, plate)
            else
                SetVehicleEngineHealth(veh, 1000.0)
                SetVehicleBodyHealth(veh, 1000.0)
                SetVehicleDirtLevel(veh, 0.0)
                SetVehicleUndriveable(veh, false)
                SetVehicleEngineOn(veh, true, true, false)
                FixEngineSmoke(veh)
                TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
            end
        end, spawnCoords, true)
    end, plate)
end)

RegisterNetEvent('DP-Garages:client:TakeOutSharedVehicle', function(plate, vehicleData)
    local garageId = currentGarage.id
    local garageType = currentGarage.type

    if not garageId or not garageType then
        QBCore.Functions.Notify("Falta información del garaje", "error")
        return
    end

    if not sharedGaragesData[garageId] then
        QBCore.Functions.Notify("No se encontraron datos del garaje compartido", "error")
        return
    end

    if not plate or not vehicleData then
        QBCore.Functions.Notify("Los datos del vehículo están incompletos.", "error")
        return
    end

    local garageInfo = sharedGaragesData[garageId]

    local spawnPoints = nil
    if garageInfo.spawnPoints then
        spawnPoints = garageInfo.spawnPoints
    else
        spawnPoints = {garageInfo.spawnPoint}
    end

    local clearPoint = FindClearSpawnPoint(spawnPoints)
    if not clearPoint then
        QBCore.Functions.Notify("¡Todos los lugares de aparición están bloqueados!", "error")
        return
    end

    local spawnCoords = vector3(clearPoint.x, clearPoint.y, clearPoint.z)
    QBCore.Functions.SpawnVehicle(vehicleData.vehicle, function(veh)
        if not veh or veh == 0 then
            QBCore.Functions.Notify("Error al crear el vehículo compartido. Inténtalo de nuevo.", "error")
            return
        end

        SetEntityHeading(veh, clearPoint.w)
        exports['LegacyFuel']:SetFuel(veh, vehicleData.fuel)
        SetVehicleNumberPlateText(veh, plate)

        QBCore.Functions.TriggerCallback('DP-Garages:server:GetVehicleProperties', function(properties)
            if properties then
                QBCore.Functions.SetVehicleProperties(veh, properties)

                local engineHealth = math.max(vehicleData.engine, 900.0)
                local bodyHealth = math.max(vehicleData.body, 900.0)

                SetVehicleEngineHealth(veh, engineHealth)
                SetVehicleBodyHealth(veh, bodyHealth)
                SetVehicleDirtLevel(veh, 0.0)
                FixEngineSmoke(veh)
                SetVehicleUndriveable(veh, false)
                SetVehicleEngineOn(veh, true, true, false)
                TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)

                QBCore.Functions.Notify("Vehículo sacado del garaje compartido", "success")
            else
                QBCore.Functions.Notify("No se pudieron cargar las propiedades del vehículo", "error")
            end
        end, plate)
    end, spawnCoords, true)
end)

function normalize(vec)
    local length = math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
    if length > 0 then
        return vector3(vec.x / length, vec.y / length, vec.z / length)
    else
        return vector3(0, 0, 0)
    end
end

function normalize(vec)
    local length = math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
    if length > 0 then
        return vector3(vec.x / length, vec.y / length, vec.z / length)
    else
        return vector3(0, 0, 0)
    end
end

RegisterNUICallback('directTransferVehicle', function(data, cb)
    local plate = data.plate
    local newGarageId = data.newGarageId
    local cost = data.cost or Config.TransferCost or 500

    cb({
        status = "success"
    })

    TriggerServerEvent('DP-Garages:server:TransferVehicleToGarage', plate, newGarageId, cost)

    Citizen.SetTimeout(1000, function()
        TriggerEvent('DP-Garages:client:RefreshVehicleList')
    end)
end)

RegisterNUICallback('transferVehicle', function(data, cb)
    local plate = data.plate
    local newGarageId = data.newGarageId
    local cost = data.cost or Config.TransferCost or 500

    if not plate or not newGarageId then
        cb({
            status = "error",
            message = "Datos no válidos"
        })
        return
    end

    if isTransferringVehicle then
        cb({
            status = "error",
            message = "Transferencia ya en curso"
        })
        return
    end

    isTransferringVehicle = true
    currentTransferVehicle = {
        plate = plate,
        garage = newGarageId
    }

    SetNuiFocus(false, false)
    TriggerServerEvent('DP-Garages:server:TransferVehicleToGarage', plate, newGarageId, cost)

    Citizen.SetTimeout(2000, function()
        isTransferringVehicle = false
        currentTransferVehicle = nil
    end)
    cb({
        status = "success"
    })
end)

RegisterNetEvent('DP-Garages:client:TransferComplete', function(newGarageId, plate)
    QBCore.Functions.Notify("Vehículo transferido al taller " .. newGarageId, "success")

    if currentGarage and isMenuOpen then
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetPersonalVehicles', function(vehicles)
            if vehicles then
                SendNUIMessage({
                    action = "refreshVehicles",
                    vehicles = FormatVehiclesForNUI(vehicles)
                })
            end
        end)
    end
end)

RegisterNUICallback('updateVehicleName', function(data, cb)
    local plate = data.plate
    local newName = data.name

    if plate and newName then
        TriggerServerEvent('DP-Garages:server:UpdateVehicleName', plate, newName)
        cb({
            status = "success"
        })
    else
        cb({
            status = "error",
            message = "Invalid data"
        })
    end
end)

RegisterNUICallback('toggleFavorite', function(data, cb)
    local plate = data.plate
    local isFavorite = data.isFavorite

    if plate then
        TriggerServerEvent('DP-Garages:server:ToggleFavorite', plate, isFavorite)
        cb({
            status = "success"
        })
    else
        cb({
            status = "error",
            message = "Matrícula no válida"
        })
    end
end)

RegisterNUICallback('storeInGang', function(data, cb)
    local plate = data.plate
    local gangName = PlayerData.gang.name

    if plate and gangName then
        TriggerServerEvent('DP-Garages:server:StoreVehicleInGang', plate, gangName)
        cb({
            status = "success"
        })
    else
        cb({
            status = "error",
            message = "Datos no válidos"
        })
    end
end)

RegisterNUICallback('storeInShared', function(data, cb)
    local plate = data.plate

    if plate then
        OpenSharedGarageSelectionUI(plate)
        cb({
            status = "success"
        })
    else
        cb({
            status = "error",
            message = "Datos no válidos"
        })
    end
end)

RegisterNUICallback('removeFromShared', function(data, cb)
    local plate = data.plate

    if plate then
        TriggerServerEvent('DP-Garages:server:RemoveVehicleFromSharedGarage', plate)
        cb({
            status = "success"
        })
    else
        cb({
            status = "error",
            message = "Matrícula no válida"
        })
    end
end)

function OpenSharedGarageSelectionUI(plate)
    QBCore.Functions.TriggerCallback('DP-Garages:server:GetSharedGarages', function(garages)
        if #garages == 0 then
            QBCore.Functions.Notify("No tienes acceso a ningún garaje compartido.", "error")
            return
        end

        local formattedGarages = {}
        for _, garage in ipairs(garages) do
            table.insert(formattedGarages, {
                id = garage.id,
                name = garage.name,
                owner = garage.isOwner
            })
        end

        SendNUIMessage({
            action = "openSharedGarageSelection",
            garages = formattedGarages,
            plate = plate
        })
    end)
end

RegisterNUICallback('storeInSelectedSharedGarage', function(data, cb)
    local plate = data.plate
    local garageId = data.garageId

    if not plate or not garageId then
        cb({
            status = "error",
            message = "Datos no válidos"
        })
        return
    end

    TriggerServerEvent('DP-Garages:server:TransferVehicleToSharedGarage', plate, garageId)

    cb({
        status = "success"
    })
end)

function IsSpawnPointClear(coords, radius)
    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        local vehicleCoords = GetEntityCoords(vehicles[i])
        if #(vehicleCoords - coords) <= radius then
            return false
        end
    end
    return true
end

RegisterNetEvent('DP-Garages:client:StoreVehicle', function(data)
    local ped = PlayerPedId()
    local garageId = nil
    local garageType = nil
    local garageInfo = nil

    if data and data.garageId and data.garageType then
        garageId = data.garageId
        garageType = data.garageType
    elseif currentGarage and currentGarage.id and currentGarage.type then
        garageId = currentGarage.id
        garageType = currentGarage.type
    else
        local pos = GetEntityCoords(PlayerPedId())
        local closestDist = 999999
        local closestGarage = nil
        local closestType = nil

        for k, v in pairs(Config.Garages) do
            local dist = #(pos - vector3(v.coords.x, v.coords.y, v.coords.z))
            if dist < closestDist and dist < 10.0 then
                closestDist = dist
                closestGarage = k
                closestType = "public"
            end
        end

        if PlayerData.job then
            for k, v in pairs(Config.JobGarages) do
                if PlayerData.job.name == v.job then
                    local dist = #(pos - vector3(v.coords.x, v.coords.y, v.coords.z))
                    if dist < closestDist and dist < 10.0 then
                        closestDist = dist
                        closestGarage = k
                        closestType = "job"
                    end
                end
            end
        end

        if PlayerData.gang and PlayerData.gang.name ~= "none" then
            for k, v in pairs(Config.GangGarages) do
                if PlayerData.gang.name == v.gang then
                    local dist = #(pos - vector3(v.coords.x, v.coords.y, v.coords.z))
                    if dist < closestDist and dist < 10.0 then
                        closestDist = dist
                        closestGarage = k
                        closestType = "gang"
                    end
                end
            end
        end

        garageId = closestGarage
        garageType = closestType

        if garageId then
            Wait(100)
        end
    end

    if not garageId or not garageType then
        QBCore.Functions.Notify("No está en una zona de estacionamiento válida", "error")
        return
    end

    if garageType == "public" then
        garageInfo = Config.Garages[garageId]
    elseif garageType == "job" then
        garageInfo = Config.JobGarages[garageId]
    elseif garageType == "gang" then
        garageInfo = Config.GangGarages[garageId]
    end

    if not garageInfo then
        QBCore.Functions.Notify("Garaje no válido", "error")
        return
    end

    local garageCoords = vector3(garageInfo.coords.x, garageInfo.coords.y, garageInfo.coords.z)

    local curVeh = GetVehiclePedIsIn(ped, false)

    if curVeh == 0 then
        curVeh = GetClosestVehicleInGarage(garageCoords, 15.0)

        if curVeh == 0 or not DoesEntityExist(curVeh) then
            QBCore.Functions.Notify("No se encontró ningún vehículo cerca para estacionar", "error")
            return
        end

        if GetVehicleNumberOfPassengers(curVeh) > 0 or not IsVehicleSeatFree(curVeh, -1) then
            QBCore.Functions.Notify("El vehículo no se puede almacenar mientras esté ocupado.", "error")
            return
        end
    end

    currentGarage = {
        id = garageId,
        type = garageType
    }

    local plate = QBCore.Functions.GetPlate(curVeh)
    local props = QBCore.Functions.GetVehicleProperties(curVeh)
    local fuel = exports['LegacyFuel']:GetFuel(curVeh)
    local engineHealth = GetVehicleEngineHealth(curVeh)
    local bodyHealth = GetVehicleBodyHealth(curVeh)

    QBCore.Functions.TriggerCallback('DP-Garages:server:CheckOwnership', function(isOwner, isInGarage)
        if isOwner or (garageType == "gang" and isInGarage) then
            FadeOutVehicle(curVeh, function()
                TriggerServerEvent('DP-Garages:server:StoreVehicle', plate, garageId, props, fuel, engineHealth,
                    bodyHealth, garageType)
                QBCore.Functions.Notify("Vehículo guardado en garaje.", "success")

                if isMenuOpen then
                    QBCore.Functions.TriggerCallback('DP-Garages:server:GetPersonalVehicles', function(vehicles)
                        if vehicles then
                            SendNUIMessage({
                                action = "refreshVehicles",
                                vehicles = FormatVehiclesForNUI(vehicles)
                            })
                        end
                    end, garageId)
                end
            end)
        else
            QBCore.Functions.Notify("No dueño de este vehículo", "error")
        end
    end, plate, garageType)
end)

function round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

RegisterNetEvent('DP-Garages:client:ManageSharedGarages')
AddEventHandler('DP-Garages:client:ManageSharedGarages', function()

    if not Config.EnableSharedGarages then
        SendNUIMessage({
            action = "openSharedGarageManager",
            garages = {},
            error = "La función de garajes compartidos está deshabilitada"
        })
        SetNuiFocus(true, true)
        return
    end

    QBCore.Functions.TriggerCallback('DP-Garages:server:CheckSharedGaragesTables', function(tablesExist)
        if not tablesExist then
            TriggerServerEvent('DP-Garages:server:CreateSharedGaragesTables')

            SendNUIMessage({
                action = "openSharedGarageManager",
                garages = {},
                error = "Inicializando la función de garajes compartidos..."
            })
            SetNuiFocus(true, true)
            return
        end

        QBCore.Functions.TriggerCallback('DP-Garages:server:GetSharedGarages', function(garages)
            sharedGaragesData = {}

            local formattedGarages = {}

            for _, garage in ipairs(garages) do
                sharedGaragesData[garage.id] = {
                    id = garage.id,
                    name = garage.name,
                    label = garage.name,
                    isOwner = garage.isOwner,
                    accessCode = garage.access_code,
                    spawnPoint = Config.Garages["Pillbox Hill"].spawnPoint,
                    spawnPoints = Config.Garages["Pillbox Hill"].spawnPoints
                }

                table.insert(formattedGarages, {
                    id = garage.id,
                    name = garage.name,
                    isOwner = garage.isOwner,
                    accessCode = garage.access_code
                })
            end

            SendNUIMessage({
                action = "openSharedGarageManager",
                garages = formattedGarages
            })
            SetNuiFocus(true, true)
        end)
    end)
end)

RegisterNUICallback('manageSharedGarages', function(data, cb)
    TriggerEvent('DP-Garages:client:ManageSharedGarages')
    cb({
        status = "success"
    })
end)

RegisterNUICallback('createSharedGarage', function(data, cb)
    local garageName = data.name

    if not garageName or garageName == "" then
        cb({
            status = "error",
            message = "Nombre de garaje no válido"
        })
        return
    end

    QBCore.Functions.TriggerCallback('DP-Garages:server:CreateSharedGarage', function(success, result)
        if success then
            QBCore.Functions.Notify("Garaje compartido creado correctamente. Código:" .. result.code, "success")
            cb({
                status = "success",
                garageData = result
            })
        else
            QBCore.Functions.Notify(result, "error")
            cb({
                status = "error",
                message = result
            })
        end
    end, garageName)
end)

RegisterNUICallback('joinSharedGarage', function(data, cb)
    local accessCode = data.code

    if not accessCode or accessCode == "" then
        cb({
            status = "error",
            message = "Código de acceso no válido"
        })
        return
    end

    TriggerServerEvent('DP-Garages:server:RequestJoinSharedGarage', accessCode)
    cb({
        status = "success"
    })
end)

RegisterNUICallback('openSharedGarage', function(data, cb)
    local garageId = data.garageId

    if not garageId then
        cb({
            status = "error",
            message = "ID de garaje no válido"
        })
        return
    end

    local garageInfo = sharedGaragesData[garageId]
    if not garageInfo then
        cb({
            status = "error",
            message = "No se encontraron datos del garaje"
        })
        return
    end

    SetNuiFocus(false, false)

    TriggerEvent('DP-Garages:client:OpenGarage', {
        garageId = garageId,
        garageType = "shared",
        garageInfo = garageInfo
    })

    cb({
        status = "success"
    })
end)

RegisterNUICallback('manageSharedGarageMembers', function(data, cb)
    local garageId = data.garageId

    if not garageId then
        cb({
            status = "error",
            message = "ID de garaje no válido"
        })
        return
    end

    QBCore.Functions.TriggerCallback('DP-Garages:server:GetSharedGarageMembers', function(members)
        if members then
            SendNUIMessage({
                action = "openSharedGarageMembersManager",
                members = members,
                garageId = garageId
            })
            cb({
                status = "success",
                members = members
            })
        else
            cb({
                status = "error",
                message = "No se pudieron obtener los miembros"
            })
        end
    end, garageId)
end)

RegisterNUICallback('removeSharedGarageMember', function(data, cb)
    local memberId = data.memberId
    local garageId = data.garageId

    if not memberId or not garageId then
        cb({
            status = "error",
            message = "Datos no válidos"
        })
        return
    end

    TriggerServerEvent('DP-Garages:server:RemoveMemberFromSharedGarage', memberId, garageId)
    cb({
        status = "success"
    })
end)

RegisterNUICallback('deleteSharedGarage', function(data, cb)
    local garageId = data.garageId

    if not garageId then
        cb({
            status = "error",
            message = "ID de garaje no válido"
        })
        return
    end

    TriggerServerEvent('DP-Garages:server:DeleteSharedGarage', garageId)
    cb({
        status = "success"
    })
end)

RegisterNetEvent('DP-Garages:client:ReceiveJoinRequest', function(data)
    table.insert(pendingJoinRequests, data)

    QBCore.Functions.Notify(data.requesterName .. " quiere unirse a tu " .. data.garageName .. " garaje", "primary",
        10000)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openJoinRequest",
        request = data
    })
end)

RegisterNUICallback('handleJoinRequest', function(data, cb)
    local requestId = data.requestId
    local approved = data.approved

    if not requestId then
        cb({
            status = "error",
            message = "ID de solicitud no válida"
        })
        return
    end

    local requestData = nil
    for i, request in ipairs(pendingJoinRequests) do
        if request.requesterId == requestId then
            requestData = request
            table.remove(pendingJoinRequests, i)
            break
        end
    end

    if not requestData then
        cb({
            status = "error",
            message = "Solicitud no encontrada"
        })
        return
    end

    if approved then
        TriggerServerEvent('DP-Garages:server:ApproveJoinRequest', requestData)
    else
        TriggerServerEvent('DP-Garages:server:DenyJoinRequest', requestData)
    end

    cb({
        status = "success"
    })
end)

RegisterNetEvent('DP-Garages:client:RefreshVehicleList', function()
    if not currentGarage or not isMenuOpen then
        return
    end

    local garageId = currentGarage.id
    local garageType = currentGarage.type

    if garageType == "public" then
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetPersonalVehicles', function(vehicles)
            if vehicles then
                SendNUIMessage({
                    action = "refreshVehicles",
                    vehicles = FormatVehiclesForNUI(vehicles)
                })
            end
        end, garageId)
    elseif garageType == "gang" then
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetGangVehicles', function(vehicles)
            if vehicles then
                SendNUIMessage({
                    action = "refreshVehicles",
                    vehicles = FormatVehiclesForNUI(vehicles)
                })
            end
        end, PlayerData.gang.name, garageId)
    elseif garageType == "shared" then
        QBCore.Functions.TriggerCallback('DP-Garages:server:GetSharedGarageVehicles', function(vehicles)
            if vehicles then
                SendNUIMessage({
                    action = "refreshVehicles",
                    vehicles = FormatVehiclesForNUI(vehicles)
                })
            end
        end, garageId)
    end
end)

RegisterNetEvent('DP-Garages:client:VehicleTransferCompleted', function(successful, plate)
    if successful then
        if currentGarage and isMenuOpen then
            local garageId = currentGarage.id
            local garageType = currentGarage.type

            if garageType == "public" then
                QBCore.Functions.TriggerCallback('DP-Garages:server:GetPersonalVehicles', function(vehicles)
                    if vehicles then
                        SendNUIMessage({
                            action = "refreshVehicles",
                            vehicles = FormatVehiclesForNUI(vehicles)
                        })
                    end
                end, garageId)
            elseif garageType == "shared" then
                QBCore.Functions.TriggerCallback('DP-Garages:server:GetSharedGarageVehicles', function(vehicles)
                    if vehicles then
                        SendNUIMessage({
                            action = "refreshVehicles",
                            vehicles = FormatVehiclesForNUI(vehicles)
                        })
                    end
                end, garageId)
            end
        end
    end
end)

function GetVehicleClassName(vehicleClass)
    local classes = {
        [0] = "Compact",
        [1] = "Sedan",
        [2] = "SUV",
        [3] = "Coupe",
        [4] = "Muscle",
        [5] = "Sports Classic",
        [6] = "Sports",
        [7] = "Super",
        [8] = "Motorcycle",
        [9] = "Off-road",
        [10] = "Industrial",
        [11] = "Utility",
        [12] = "Van",
        [13] = "Cycle",
        [14] = "Boat",
        [15] = "Helicopter",
        [16] = "Plane",
        [17] = "Service",
        [18] = "Emergency",
        [19] = "Military",
        [20] = "Commercial",
        [21] = "Train",
        [22] = "Open Wheel"
    }
    return classes[vehicleClass] or "Desconocido"
end

function GetVehicleHoverInfo(vehicle)
    if not DoesEntityExist(vehicle) then
        return nil
    end

    local ped = PlayerPedId()
    local plate = QBCore.Functions.GetPlate(vehicle)
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local make = GetMakeNameFromVehicleModel(model)
    local vehicleClass = GetVehicleClass(vehicle)
    local className = GetVehicleClassName(vehicleClass)
    local inVehicle = (GetVehiclePedIsIn(ped, false) == vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local fuelLevel = 0

    if GetResourceState('LegacyFuel') ~= 'missing' then
        fuelLevel = exports['LegacyFuel']:GetFuel(vehicle)
    elseif GetResourceState('ps-fuel') ~= 'missing' then
        fuelLevel = exports['ps-fuel']:GetFuel(vehicle)
    elseif GetResourceState('qb-fuel') ~= 'missing' then
        fuelLevel = exports['qb-fuel']:GetFuel(vehicle)
    else
        fuelLevel = GetVehicleFuelLevel(vehicle)
    end

    local vehicleInfo = nil
    QBCore.Functions.TriggerCallback('DP-Garages:server:GetVehicleInfo', function(info)
        vehicleInfo = info
    end, plate)

    local info = {
        plate = plate,
        model = displayName,
        make = make,
        class = className,
        netId = NetworkGetNetworkIdFromEntity(vehicle),
        inVehicle = inVehicle,
        fuel = fuelLevel,
        engine = engineHealth / 10,
        body = bodyHealth / 10,
        ownerName = "Tú",
        garage = "Desconocido",
        state = 1
    }

    if vehicleInfo then
        info.name = vehicleInfo.name or info.model
        info.ownerName = vehicleInfo.ownerName or "Tú"
        info.garage = vehicleInfo.garage or "Desconocido"
        info.state = vehicleInfo.state or 1
    end

    return info
end

function RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    local direction = RotationToDirection(cameraRotation)
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(cameraCoord.x, cameraCoord.y, cameraCoord.z,
        destination.x, destination.y, destination.z, 1, PlayerPedId(), 0)
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)
    return hit, endCoords, entityHit
end

function RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

RegisterNUICallback('enterVehicle', function(data, cb)
    local netId = data.netId
    local vehicle = NetworkGetEntityFromNetworkId(netId)

    if DoesEntityExist(vehicle) then
        local ped = PlayerPedId()
        TaskEnterVehicle(ped, vehicle, -1, -1, 1.0, 1, 0)
    end

    cb({
        status = "success"
    })
end)

RegisterNUICallback('exitVehicle', function(data, cb)
    local ped = PlayerPedId()
    TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
    cb({
        status = "success"
    })
end)

RegisterNUICallback('storeHoveredVehicle', function(data, cb)
    local plate = data.plate
    local netId = data.netId
    local vehicle = NetworkGetEntityFromNetworkId(netId)

    if DoesEntityExist(vehicle) then
        local garageId, garageType = GetClosestGarage()

        if garageId then
            StoreVehicleInGarage(vehicle, garageId, garageType)
            cb({
                status = "success"
            })
        else
            QBCore.Functions.Notify("No cerca de un garaje", "error")
            cb({
                status = "error",
                message = "No cerca de un garaje"
            })
        end
    else
        cb({
            status = "error",
            message = "Vehículo no encontrado"
        })
    end
end)

RegisterNUICallback('showVehicleDetails', function(data, cb)
    local plate = data.plate
    local netId = data.netId
    local vehicle = NetworkGetEntityFromNetworkId(netId)

    if DoesEntityExist(vehicle) then
        if vehicleHoverInfo then
            showVehicleInfoModal(vehicleHoverInfo)
            cb({
                status = "success"
            })
        else
            cb({
                status = "error",
                message = "Información del vehículo no encontrada"
            })
        end
    else
        cb({
            status = "error",
            message = "Vehículo no encontrado"
        })
    end
end)

function GetClosestGarage()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestDistance = 999999
    local closestGarage = nil
    local closestGarageType = nil

    for k, v in pairs(Config.Garages) do
        local distance = #(playerCoords - vector3(v.coords.x, v.coords.y, v.coords.z))
        if distance < closestDistance and distance < 30.0 then
            closestDistance = distance
            closestGarage = k
            closestGarageType = "public"
        end
    end

    for k, v in pairs(Config.JobGarages) do
        if PlayerData.job and PlayerData.job.name == v.job then
            local distance = #(playerCoords - vector3(v.coords.x, v.coords.y, v.coords.z))
            if distance < closestDistance and distance < 30.0 then
                closestDistance = distance
                closestGarage = k
                closestGarageType = "job"
            end
        end
    end

    for k, v in pairs(Config.GangGarages) do
        if PlayerData.gang and PlayerData.gang.name == v.gang then
            local distance = #(playerCoords - vector3(v.coords.x, v.coords.y, v.coords.z))
            if distance < closestDistance and distance < 30.0 then
                closestDistance = distance
                closestGarage = k
                closestGarageType = "gang"
            end
        end
    end

    return closestGarage, closestGarageType
end

function StoreVehicleInGarage(vehicle, garageId, garageType)
    local plate = QBCore.Functions.GetPlate(vehicle)
    local props = QBCore.Functions.GetVehicleProperties(vehicle)
    props = AddVisualDamageToProps(vehicle, props)
    local fuel = 0

    if GetResourceState('LegacyFuel') ~= 'missing' then
        fuel = exports['LegacyFuel']:GetFuel(vehicle)
    elseif GetResourceState('ps-fuel') ~= 'missing' then
        fuel = exports['ps-fuel']:GetFuel(vehicle)
    elseif GetResourceState('qb-fuel') ~= 'missing' then
        fuel = exports['qb-fuel']:GetFuel(vehicle)
    else
        fuel = GetVehicleFuelLevel(vehicle)
    end

    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)

    FadeOutVehicle(vehicle, function()
        TriggerServerEvent('DP-Garages:server:StoreVehicle', plate, garageId, props, fuel, engineHealth, bodyHealth,
            garageType)
        QBCore.Functions.Notify("Vehículo guardado en garaje.", "success")
    end)
end

RegisterNetEvent('DP-Garages:client:OpenImpoundLot')
AddEventHandler('DP-Garages:client:OpenImpoundLot', function(data)
    local impoundId = data.impoundId
    local impoundInfo = Config.ImpoundLots[impoundId]

    if not impoundInfo then
        QBCore.Functions.Notify("Lote de incautación no válido", "error")
        return
    end

    currentImpoundLot = {
        id = impoundId,
        label = impoundInfo.label,
        coords = impoundInfo.coords
    }

    QBCore.Functions.TriggerCallback('DP-Garages:server:GetImpoundedVehicles', function(vehicles)
        if vehicles and #vehicles > 0 then
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = "setImpoundOnly",
                forceImpoundOnly = true
            })

            SendNUIMessage({
                action = "openImpound",
                vehicles = FormatVehiclesForNUI(vehicles),
                impound = {
                    name = impoundInfo.label,
                    id = impoundId,
                    location = impoundInfo.label
                }
            })
        else
            QBCore.Functions.Notify("No hay vehículos incautados", "error")
        end
    end)
end)

RegisterCommand('impound', function(source, args)
    if not PlayerData.job or not Config.ImpoundJobs[PlayerData.job.name] then
        QBCore.Functions.Notify("No está autorizado a incautar vehículos.", "error")
        return
    end

    local impoundFine = tonumber(args[1]) or Config.ImpoundFee

    impoundFine = math.max(100, math.min(10000, impoundFine))

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = nil

    if IsPedInAnyVehicle(ped, false) then
        vehicle = GetVehiclePedIsIn(ped, false)
    else
        vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    end

    if not DoesEntityExist(vehicle) then
        QBCore.Functions.Notify("No hay ningún vehículo cerca para incautar", "error")
        return
    end

    local plate = QBCore.Functions.GetPlate(vehicle)
    if not plate then
        QBCore.Functions.Notify("No se pudo leer la matrícula del vehículo", "error")
        return
    end

    local props = QBCore.Functions.GetVehicleProperties(vehicle)
    props = AddVisualDamageToProps(vehicle, props)

    local dialog = exports['DP-Input']:ShowInput({
        header = "Confiscar Vehículo",
        submitText = "Confirmar",
        inputs = {{
            text = "Motivo del embargo",
            name = "reason",
            type = "text"
        }}
    })

    if dialog and dialog.reason then
        local impoundType = "police"

        TaskStartScenarioInPlace(ped, "PROP_HUMAN_CLIPBOARD", 0, true)
        QBCore.Functions.Progressbar("impounding_vehicle", "Incautando vehículo...", 10000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true
        }, {}, {}, {}, function()
            ClearPedTasks(ped)

            TriggerServerEvent('DP-Garages:server:ImpoundVehicleWithParams', plate, props, dialog.reason, impoundType,
                PlayerData.job.name, PlayerData.charinfo.firstname .. " " .. PlayerData.charinfo.lastname, impoundFine)

            FadeOutVehicle(vehicle, function()
                DeleteVehicle(vehicle)
                QBCore.Functions.Notify("Vehículo incautado con $ " .. impoundFine .. " multa", "success")
            end)
        end, function()
            ClearPedTasks(ped)
            QBCore.Functions.Notify("Incautación cancelada", "error")
        end)
    end
end, false)

TriggerEvent('chat:addSuggestion', '/impound', 'Incautar un vehículo con multa personalizada', {{
    name = "fine",
    help = "Cantidad de la multa ($100-$10,000)"
}})

function OpenImpoundUI(vehicles, impoundInfo, impoundId)
    local formattedVehicles = {}

    for i, vehicle in ipairs(vehicles) do
        local vehicleInfo = QBCore.Shared.Vehicles[vehicle.vehicle]
        if vehicleInfo then
            local enginePercent = round(vehicle.engine / 10, 1)
            local bodyPercent = round(vehicle.body / 10, 1)
            local fuelPercent = vehicle.fuel or 100

            local displayName = vehicleInfo.name
            if vehicle.custom_name and vehicle.custom_name ~= "" then
                displayName = vehicle.custom_name
            end

            local totalFee = Config.ImpoundFee
            if vehicle.impoundfee ~= nil then
                local customFee = tonumber(vehicle.impoundfee)
                if customFee and customFee > 0 then
                    totalFee = customFee
                end
            end

            local reasonString = vehicle.impoundreason or "No se especifica ningún motivo"
            if reasonString and #reasonString > 50 then
                reasonString = reasonString:sub(1, 47) .. "..."
            end

            table.insert(formattedVehicles, {
                id = i,
                plate = vehicle.plate,
                model = vehicle.vehicle,
                name = displayName,
                fuel = fuelPercent,
                engine = enginePercent,
                body = bodyPercent,
                impoundFee = totalFee,
                impoundReason = reasonString,
                impoundType = vehicle.impoundtype or "Policía",
                impoundedBy = vehicle.impoundedby or "Oficial desconocido"
            })
        end
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openImpound",
        vehicles = formattedVehicles,
        impound = {
            name = impoundInfo.label,
            id = impoundId,
            location = impoundInfo.label
        }
    })
end

RegisterNUICallback('releaseImpoundedVehicle', function(data, cb)
    local plate = data.plate
    local impoundId = currentImpoundLot.id
    local fee = data.fee

    if not plate or not impoundId then
        cb({
            status = "error",
            message = "Invalid data"
        })
        return
    end

    QBCore.Functions.TriggerCallback('DP-Garages:server:CanPayImpoundFee', function(canPay)
        if canPay then
            local impoundInfo = Config.ImpoundLots[impoundId]
            local spawnPoint = FindClearSpawnPoint(impoundInfo.spawnPoints)

            if not spawnPoint then
                QBCore.Functions.Notify("¡Todos los lugares de aparición están bloqueados!", "error")
                cb({
                    status = "error",
                    message = "Generación bloqueada"
                })
                return
            end

            QBCore.Functions.TriggerCallback('DP-Garages:server:GetVehicleByPlate', function(vehData)
                if vehData then
                    QBCore.Functions.SpawnVehicle(vehData.vehicle, function(veh)
                        SetEntityHeading(veh, spawnPoint.w)
                        SetEntityCoords(veh, spawnPoint.x, spawnPoint.y, spawnPoint.z)

                        exports['LegacyFuel']:SetFuel(veh, vehData.fuel or 100)
                        SetVehicleNumberPlateText(veh, plate)

                        QBCore.Functions.TriggerCallback('DP-Garages:server:GetVehicleProperties', function(properties)
                            if properties then
                                QBCore.Functions.SetVehicleProperties(veh, properties)

                                local engineHealth = math.max(vehData.engine * 10, 200.0)
                                local bodyHealth = math.max(vehData.body * 10, 200.0)

                                SetVehicleEngineHealth(veh, engineHealth)
                                SetVehicleBodyHealth(veh, bodyHealth)
                                SetVehicleDirtLevel(veh, 0.0)

                                FixEngineSmoke(veh)

                                SetVehicleUndriveable(veh, false)
                                SetVehicleEngineOn(veh, true, true, false)

                                TriggerServerEvent('DP-Garages:server:PayImpoundFee', plate, fee)

                                QBCore.Functions.Notify("Vehículo liberado del depósito", "success")
                                cb({
                                    status = "success"
                                })
                            else
                                QBCore.Functions.Notify("No se pudieron cargar las propiedades del vehículo", "error")
                                cb({
                                    status = "error",
                                    message = "No se pudo cargar el vehículo"
                                })
                            end
                        end, plate)
                    end, vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z), true)
                else
                    QBCore.Functions.Notify("Datos del vehículo no encontrados", "error")
                    cb({
                        status = "error",
                        message = "Vehículo no encontrado"
                    })
                end
            end, plate)
        else
            QBCore.Functions.Notify("No tienes suficiente dinero para pagar la tarifa de incautación", "error")
            cb({
                status = "error",
                message = "Fondos insuficientes"
            })
        end
    end, fee)
end)

RegisterNetEvent('DP-Garages:client:ImpoundVehicle')
AddEventHandler('DP-Garages:client:ImpoundVehicle', function()
    if not PlayerData.job or not Config.ImpoundJobs[PlayerData.job.name] then
        QBCore.Functions.Notify("No está autorizado a incautar vehículos.", "error")
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = nil

    if IsPedInAnyVehicle(ped, false) then
        vehicle = GetVehiclePedIsIn(ped, false)
    else
        vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    end

    if not DoesEntityExist(vehicle) then
        QBCore.Functions.Notify("No hay ningún vehículo cerca para incautar", "error")
        return
    end

    local plate = QBCore.Functions.GetPlate(vehicle)
    if not plate then
        QBCore.Functions.Notify("No se pudo leer la matrícula del vehículo", "error")
        return
    end

    local props = QBCore.Functions.GetVehicleProperties(vehicle)
    props = AddVisualDamageToProps(vehicle, props)
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local impoundType = "police"

    local dialog = exports['DP-Input']:ShowInput({
        header = "Confiscar Vehículo",
        submitText = "Confirmar",
        inputs = {{
            text = "Motivo del embargo",
            name = "reason",
            type = "text",
            isRequired = true
        }, {
            text = "Tipo de incautación",
            name = "type",
            type = "select",
            options = Config.ImpounderTypes,
            default = "police"
        }}
    })

    if dialog and dialog.reason then
        TaskStartScenarioInPlace(ped, "PROP_HUMAN_CLIPBOARD", 0, true)
        QBCore.Functions.Progressbar("impounding_vehicle", "Incautando vehículo...", 10000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true
        }, {}, {}, {}, function()
            ClearPedTasks(ped)

            TriggerServerEvent('DP-Garages:server:ImpoundVehicle', plate, props, dialog.reason, dialog.type,
                PlayerData.job.name, PlayerData.charinfo.firstname .. " " .. PlayerData.charinfo.lastname)

            FadeOutVehicle(vehicle, function()
                DeleteVehicle(vehicle)
                QBCore.Functions.Notify("Vehículo incautado con éxito", "success")
            end)
        end, function()
            ClearPedTasks(ped)
            QBCore.Functions.Notify("Incautación cancelada", "error")
        end)
    end
end)

RegisterNUICallback('closeImpound', function(data, cb)
    SetNuiFocus(false, false)
    cb({
        status = "success"
    })
end)

