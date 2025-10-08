local QBCore = exports['qb-core']:GetCoreObject()
local impoundedVehicles = {}
local activeImpounds = {}
local OutsideVehicles = {}
local trackedJobVehicles = {}
local trackedJobVehicles = {}
local jobVehicles = {}

QBCore.Functions.CreateCallback('DP-Garages:server:GetPersonalVehicles', function(source, cb, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb({})
    end

    local citizenid = Player.PlayerData.citizenid

    local query = 'SELECT *, COALESCE(is_favorite, 0) as is_favorite FROM player_vehicles WHERE citizenid = ?'
    local params = {citizenid}

    if garageId then
        query = query .. ' AND garage = ?'
        table.insert(params, garageId)
    end

    MySQL.Async.fetchAll(query, params, function(result)
        if result[1] then
            for i, vehicle in ipairs(result) do
            end
            cb(result)
        else
            cb({})
        end
    end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:GetVehiclesByGarage', function(source, cb, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb({})
    end

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE garage = ?', {garageId}, function(result)
        if result and #result > 0 then
            for i, vehicle in ipairs(result) do
            end
            cb(result)
        else
            cb({})
        end
    end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:GetGangVehicles', function(source, cb, gang, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb({})
    end

    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ?', {citizenid, garageId},
        function(personalResult)
            MySQL.Async.fetchAll(
                'SELECT pv.* FROM player_vehicles pv JOIN gang_vehicles gv ON pv.plate = gv.plate WHERE gv.gang = ? AND pv.citizenid != ? AND gv.stored = 1 AND pv.garage = ?',
                {gang, citizenid, garageId}, function(gangResult)
                    local allVehicles = {}

                    for _, vehicle in ipairs(personalResult) do
                        table.insert(allVehicles, vehicle)
                    end

                    for _, vehicle in ipairs(gangResult) do
                        table.insert(allVehicles, vehicle)
                    end

                    cb(allVehicles)
                end)
        end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:CheckOwnership', function(source, cb, plate, garageType)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb(false)
    end

    local citizenid = Player.PlayerData.citizenid
    local isOwner = false
    local isInGarage = false

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizenid},
        function(result)
            if result[1] then
                isOwner = true
            end

            if garageType == "gang" and not isOwner then
                local gang = Player.PlayerData.gang.name
                if gang and gang ~= "none" then
                    MySQL.Async.fetchAll('SELECT * FROM gang_vehicles WHERE plate = ? AND gang = ?', {plate, gang},
                        function(gangResult)
                            if gangResult[1] then
                                isInGarage = true
                            end
                            cb(isOwner, isInGarage)
                        end)
                else
                    cb(isOwner, isInGarage)
                end
            else
                cb(isOwner, isInGarage)
            end
        end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:CheckSharedAccess', function(source, cb, plate, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb(false)
    end

    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll('SELECT * FROM shared_garage_members WHERE garage_id = ? AND member_citizenid = ?',
        {garageId, citizenid}, function(memberResult)
            if memberResult and #memberResult > 0 then
                MySQL.Async.fetchAll(
                    'SELECT * FROM player_vehicles WHERE plate = ? AND shared_garage_id = ? AND state = 1',
                    {plate, garageId}, function(vehResult)
                        if vehResult and #vehResult > 0 then
                            cb(true)
                        else
                            cb(false)
                        end
                    end)
            else
                MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_citizenid = ?',
                    {garageId, citizenid}, function(ownerResult)
                        if ownerResult and #ownerResult > 0 then
                            MySQL.Async.fetchAll(
                                'SELECT * FROM player_vehicles WHERE plate = ? AND shared_garage_id = ? AND state = 1',
                                {plate, garageId}, function(vehResult)
                                    if vehResult and #vehResult > 0 then
                                        cb(true)
                                    else
                                        cb(false)
                                    end
                                end)
                        else
                            cb(false)
                        end
                    end)
            end
        end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:GetVehicleProperties', function(source, cb, plate)
    MySQL.Async.fetchAll('SELECT mods FROM player_vehicles WHERE plate = ?', {plate}, function(result)
        if result[1] then
            cb(json.decode(result[1].mods))
        else
            cb(nil)
        end
    end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:GetAllGarages', function(source, cb)
    local garages = {}

    for k, v in pairs(Config.Garages) do
        table.insert(garages, {
            id = k,
            name = v.label,
            type = "public"
        })
    end

    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        if Player.PlayerData.job then
            for k, v in pairs(Config.JobGarages) do
                if v.job == Player.PlayerData.job.name then
                    table.insert(garages, {
                        id = k,
                        name = v.label,
                        type = "job"
                    })
                end
            end
        end

        if Player.PlayerData.gang and Player.PlayerData.gang.name ~= "none" then
            for k, v in pairs(Config.GangGarages) do
                if v.gang == Player.PlayerData.gang.name then
                    table.insert(garages, {
                        id = k,
                        name = v.label,
                        type = "gang"
                    })
                end
            end
        end
    end

    cb(garages)
end)

RegisterNetEvent('DP-Garages:server:TransferVehicleToGarage', function(plate, newGarageId, cost)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end
    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizenid},
        function(result)
            if not result or #result == 0 then
                TriggerClientEvent('QBCore:Notify', src, "No eres dueño de este vehículo", "error")
                return
            end
            local vehicle = result[1]
            if vehicle.state ~= 1 then
                TriggerClientEvent('QBCore:Notify', src, "El vehículo debe estar almacenado para poder trasladarlo.",
                    "error")
                return
            end
            local transferCost = cost or Config.TransferCost or 500
            if Player.PlayerData.money["cash"] < transferCost then
                TriggerClientEvent('QBCore:Notify', src,
                    "Necesitas $" .. transferCost .. " para transferir este vehículo", "error")
                return
            end
            Player.Functions.RemoveMoney("cash", transferCost, "vehicle-transfer-fee")
            MySQL.Async.execute('UPDATE player_vehicles SET garage = ? WHERE plate = ?', {newGarageId, plate},
                function(rowsChanged)
                    if rowsChanged > 0 then
                        TriggerClientEvent('QBCore:Notify', src, "Vehículo transferido al garaje " .. newGarageId ..
                            " por $" .. transferCost, "success")
                        TriggerClientEvent('DP-Garages:client:TransferComplete', src, newGarageId, plate)
                    else
                        Player.Functions.AddMoney("cash", transferCost, "vehicle-transfer-refund")
                        TriggerClientEvent('QBCore:Notify', src, "Transferencia fallida", "error")
                    end
                end)
        end)
end)

-- Improved version of CheckJobAccess that also returns the job name
QBCore.Functions.CreateCallback('DP-Garages:server:CheckJobVehicleAccess', function(source, cb, plate)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb(false, nil)
    end

    local jobName = Player.PlayerData.job.name
    if not jobName then
        return cb(false, nil)
    end

    if trackedJobVehicles[plate] then
        local vehicleJob = trackedJobVehicles[plate].job
        return cb(vehicleJob == jobName, vehicleJob)
    end

    return cb(false, nil)
end)

RegisterNetEvent('DP-Garages:server:TrackJobVehicle', function(plate, jobName, props)
    local src = source

    if not plate or not jobName then
        return
    end

    jobVehicles[plate] = {
        job = jobName,
        props = props,
        lastUpdated = os.time()
    }
end)

-- Check if player has job access to a vehicle
QBCore.Functions.CreateCallback('DP-Garages:server:CheckJobAccess', function(source, cb, plate)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb(false)
    end

    local playerJob = Player.PlayerData.job.name

    if jobVehicles[plate] and jobVehicles[plate].job == playerJob then
        return cb(true)
    end

    return cb(false)
end)

-- Get job vehicle data
QBCore.Functions.CreateCallback('DP-Garages:server:GetJobVehicleData', function(source, cb, plate)
    if trackedJobVehicles[plate] then
        cb(trackedJobVehicles[plate])
    else
        cb(nil)
    end
end)

RegisterNetEvent('DP-Garages:server:StoreVehicle',
    function(plate, garageId, props, fuel, engineHealth, bodyHealth, garageType)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then
            return
        end
        local citizenid = Player.PlayerData.citizenid

        MySQL.Async.fetchAll('SHOW COLUMNS FROM player_vehicles LIKE "stored"', {}, function(storedColumn)
            local hasStoredColumn = #storedColumn > 0
            MySQL.Async.fetchAll('SHOW COLUMNS FROM player_vehicles LIKE "state"', {}, function(stateColumn)
                local hasStateColumn = #stateColumn > 0

                -- FIXED QUERY: Don't clear shared_garage_id automatically
                local query = 'UPDATE player_vehicles SET garage = ?, mods = ?, fuel = ?, engine = ?, body = ?'
                local params = {garageId, json.encode(props), fuel, engineHealth, bodyHealth}
                if hasStoredColumn then
                    query = query .. ', `stored` = 1'
                end
                if hasStateColumn then
                    query = query .. ', state = 1'
                end
                query = query .. ' WHERE plate = ?'
                table.insert(params, plate)

                MySQL.Async.execute(query, params, function(rowsChanged)
                    if rowsChanged > 0 then
                        OutsideVehicles[plate] = nil

                        if garageType == "gang" then
                            local gang = Player.PlayerData.gang.name
                            if gang and gang ~= "none" then
                                MySQL.Async
                                    .execute('UPDATE gang_vehicles SET `stored` = 1 WHERE plate = ? AND gang = ?',
                                    {plate, gang})
                            end
                        end

                        -- Trigger refresh events
                        TriggerClientEvent('DP-Garages:client:RefreshVehicleList', src)
                    else
                        TriggerClientEvent('QBCore:Notify', src, "No se pudo almacenar el vehículo", "error")
                    end
                end)
            end)
        end)
    end)

RegisterNetEvent('DP-Garages:server:UpdateGangVehicleState', function(plate, state)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local gang = Player.PlayerData.gang.name
    if gang and gang ~= "none" then
        MySQL.Async.execute('UPDATE gang_vehicles SET `stored` = ? WHERE plate = ? AND gang = ?', {state, plate, gang})
    end
end)

RegisterNetEvent('DP-Garages:server:UpdateVehicleName', function(plate, newName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizenid},
        function(result)
            if result[1] then
                MySQL.Async.execute('UPDATE player_vehicles SET custom_name = ? WHERE plate = ? AND citizenid = ?',
                    {newName, plate, citizenid}, function(rowsChanged)
                        if rowsChanged > 0 then
                            TriggerClientEvent('QBCore:Notify', src, 'Nombre del vehículo actualizado', 'success')
                        else
                            TriggerClientEvent('QBCore:Notify', src, 'No se pudo actualizar el nombre del vehículo',
                                'error')
                        end
                    end)
            else
                TriggerClientEvent('QBCore:Notify', src, 'No eres dueño de este vehículo', 'error')
            end
        end)
end)

RegisterNetEvent('DP-Garages:server:ToggleFavorite', function(plate, isFavorite)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local favoriteValue = isFavorite and 1 or 0

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizenid},
        function(result)
            if result[1] then
                -- Update favorite status
                MySQL.Async.execute('UPDATE player_vehicles SET is_favorite = ? WHERE plate = ? AND citizenid = ?',
                    {favoriteValue, plate, citizenid}, function(rowsChanged)
                        if rowsChanged < 0 then
                            TriggerClientEvent('QBCore:Notify', src, 'No se pudo actualizar el estado de favorito',
                                'error')
                        end
                    end)
            else
                TriggerClientEvent('QBCore:Notify', src, 'No eres dueño de este vehículo', 'error')
            end
        end)
end)

RegisterNetEvent('qb-garage:server:ToggleFavorite', function(plate, isFavorite)
    TriggerEvent('DP-Garages:server:ToggleFavorite', plate, isFavorite)
end)

RegisterNetEvent('DP-Garages:server:StoreVehicleInGang', function(plate, gangName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Verify ownership first
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizenid},
        function(result)
            if result[1] then
                MySQL.Async.fetchAll('SELECT * FROM gang_vehicles WHERE plate = ? AND gang = ? AND owner = ?',
                    {plate, gangName, citizenid}, function(gangResult)
                        if gangResult[1] then
                            TriggerClientEvent('QBCore:Notify', src,
                                'El vehículo ya está compartido con tu banda.', 'error')
                        else
                            MySQL.Async.execute(
                                'INSERT INTO gang_vehicles (plate, gang, owner, vehicle, `stored`) VALUES (?, ?, ?, ?, 1)',
                                {plate, gangName, citizenid, result[1].vehicle}, function(rowsChanged)
                                    if rowsChanged > 0 then
                                        MySQL.Async.execute(
                                            'UPDATE player_vehicles SET stored_in_gang = ? WHERE plate = ? AND citizenid = ?',
                                            {gangName, plate, citizenid})

                                        TriggerClientEvent('QBCore:Notify', src, 'Vehículo compartido con tu banda',
                                            'success')
                                        TriggerClientEvent('DP-Garages:client:RefreshVehicleList', src)
                                    else
                                        TriggerClientEvent('QBCore:Notify', src,
                                            'No se pudo compartir el vehículo con la banda', 'error')
                                    end
                                end)
                        end
                    end)
            else
                TriggerClientEvent('QBCore:Notify', src, 'No eres dueño de este vehículo', 'error')
            end
        end)
end)

RegisterNetEvent('qb-garage:server:StoreVehicleInGang', function(plate, gangName)
    TriggerEvent('DP-Garages:server:StoreVehicleInGang', plate, gangName)
end)

RegisterNetEvent('qb-garage:server:UpdateVehicleState', function(plate, state)
    MySQL.Async.execute('UPDATE player_vehicles SET state = ?, `stored` = ? WHERE plate = ?', {state, state, plate})
end)

RegisterNetEvent('qb-garage:server:UpdateGangVehicleState', function(plate, state)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local gang = Player.PlayerData.gang.name
    if gang and gang ~= "none" then
        MySQL.Async.execute('UPDATE gang_vehicles SET `stored` = ? WHERE plate = ? AND gang = ?', {state, plate, gang})
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    MySQL.Async.fetchAll('SHOW COLUMNS FROM player_vehicles LIKE "impoundedtime"', {}, function(result)
        if result and #result > 0 then
        else
            Wait(100)
        end
    end)

    -- Initialize the OutsideVehicles table when server starts
    MySQL.Async.fetchAll('SELECT plate FROM player_vehicles WHERE state = 0', {}, function(result)
        if result and #result > 0 then
            for _, v in ipairs(result) do
                OutsideVehicles[v.plate] = true
            end
        else
            Wait(100)
        end
    end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:IsVehicleOut', function(source, cb, plate)
    MySQL.Async.fetchAll('SELECT state FROM player_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            cb(result[1].state == 0)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:CreateSharedGarage', function(source, cb, garageName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return cb(false, "Jugador no encontrado")
    end

    local citizenid = Player.PlayerData.citizenid

    local code = tostring(math.random(1000, 9999))

    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE owner_citizenid = ?', {citizenid}, function(result)
        if result and #result > 0 then
            cb(false, "Ya tienes un garaje compartido")
            return
        end

        MySQL.Async.insert('INSERT INTO shared_garages (name, owner_citizenid, access_code) VALUES (?, ?, ?)',
            {garageName, citizenid, code}, function(garageId)
                if garageId > 0 then
                    MySQL.Async.insert('INSERT INTO shared_garage_members (garage_id, member_citizenid) VALUES (?, ?)',
                        {garageId, citizenid})

                    cb(true, {
                        id = garageId,
                        code = code,
                        name = garageName
                    })
                else
                    cb(false, "No se pudo crear el garaje compartido")
                end
            end)
    end)
end)

RegisterNetEvent('DP-Garages:server:RequestJoinSharedGarage', function(accessCode)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE access_code = ?', {accessCode}, function(result)
        if not result or #result == 0 then
            TriggerClientEvent('QBCore:Notify', src, "Código de acceso no válido", "error")
            return
        end

        local garageData = result[1]

        MySQL.Async.fetchAll('SELECT * FROM shared_garage_members WHERE garage_id = ? AND member_citizenid = ?',
            {garageData.id, citizenid}, function(memberResult)
                if memberResult and #memberResult > 0 then
                    TriggerClientEvent('QBCore:Notify', src, "Ya eres miembro de este garaje", "error")
                    return
                end

                MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM shared_garage_members WHERE garage_id = ?',
                    {garageData.id}, function(countResult)
                        if countResult[1].count >= Config.MaxSharedGarageMembers then
                            TriggerClientEvent('QBCore:Notify', src, "Este garaje ha alcanzado su límite de miembros.",
                                "error")
                            return
                        end

                        local ownerPlayer = QBCore.Functions.GetPlayerByCitizenId(garageData.owner_citizenid)
                        if not ownerPlayer then
                            TriggerClientEvent('QBCore:Notify', src, "El propietario del garaje no está en línea",
                                "error")
                            return
                        end

                        TriggerClientEvent('DP-Garages:client:ReceiveJoinRequest', ownerPlayer.PlayerData.source, {
                            requesterId = citizenid,
                            requesterName = Player.PlayerData.charinfo.firstname .. ' ' ..
                                Player.PlayerData.charinfo.lastname,
                            garageId = garageData.id,
                            garageName = garageData.name
                        })

                        TriggerClientEvent('QBCore:Notify', src,
                            "Solicitud de ingreso enviada al propietario del garaje", "success")
                    end)
            end)
    end)
end)

RegisterNetEvent('DP-Garages:server:ApproveJoinRequest', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local ownerCitizenid = Player.PlayerData.citizenid
    local requesterId = data.requesterId
    local garageId = data.garageId

    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_citizenid = ?',
        {garageId, ownerCitizenid}, function(result)
            if not result or #result == 0 then
                TriggerClientEvent('QBCore:Notify', src, "Este garaje no te pertenece", "error")
                return
            end

            MySQL.Async.insert('INSERT INTO shared_garage_members (garage_id, member_citizenid) VALUES (?, ?)',
                {garageId, requesterId}, function(memberId)
                    if memberId > 0 then
                        local requesterPlayer = QBCore.Functions.GetPlayerByCitizenId(requesterId)
                        if requesterPlayer then
                            TriggerClientEvent('QBCore:Notify', requesterPlayer.PlayerData.source,
                                "Su solicitud para unirse al garaje " .. result[1].name .. " ha sido aprobada",
                                "success")
                        end

                        TriggerClientEvent('QBCore:Notify', src, "Solicitud de membresía de garaje aprobada", "success")
                    else
                        TriggerClientEvent('QBCore:Notify', src, "No se pudo agregar miembro", "error")
                    end
                end)
        end)
end)

RegisterNetEvent('DP-Garages:server:DenyJoinRequest', function(data)
    local src = source
    local requesterId = data.requesterId

    local requesterPlayer = QBCore.Functions.GetPlayerByCitizenId(requesterId)
    if requesterPlayer then
        TriggerClientEvent('QBCore:Notify', requesterPlayer.PlayerData.source,
            "Su solicitud para unirse al garaje compartido ha sido denegada", "error")
    end

    TriggerClientEvent('QBCore:Notify', src, "Solicitud de membresía de garaje denegada", "success")
end)

QBCore.Functions.CreateCallback('DP-Garages:server:GetSharedGarages', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return cb({})
    end

    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll("SHOW TABLES LIKE 'shared_garages'", {}, function(tableExists)
        if not tableExists or #tableExists == 0 then
            CreateSharedGaragesTables(src, function()
                cb({})
            end)
            return
        end

        MySQL.Async.fetchAll(
            'SELECT DISTINCT sg.* FROM shared_garages sg LEFT JOIN shared_garage_members sgm ON sg.id = sgm.garage_id WHERE sgm.member_citizenid = ? OR sg.owner_citizenid = ?',
            {citizenid, citizenid}, function(result)
                if result and #result > 0 then
                    for i, garage in ipairs(result) do
                        result[i].isOwner = (garage.owner_citizenid == citizenid)
                    end
                    cb(result)
                else
                    cb({})
                end
            end)
    end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:GetSharedGarageVehicles', function(source, cb, garageId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb({})
    end

    MySQL.Async.fetchAll(
        'SELECT pv.*, p.charinfo FROM player_vehicles pv LEFT JOIN players p ON pv.citizenid = p.citizenid WHERE pv.shared_garage_id = ? AND pv.state = 1',
        {garageId}, function(vehicles)
            if vehicles and #vehicles > 0 then
                for i, vehicle in ipairs(vehicles) do
                    if vehicle.charinfo then
                        local charinfo = json.decode(vehicle.charinfo)
                        if charinfo then
                            vehicles[i].owner_name = charinfo.firstname .. ' ' .. charinfo.lastname
                        else
                            vehicles[i].owner_name = "Desconocido"
                        end
                    else
                        vehicles[i].owner_name = "Desconocido"
                    end
                end
                cb(vehicles)
            else
                cb({})
            end
        end)
end)

function getSharedGarageVehicles(garageId, citizenid, cb)
    MySQL.Async.fetchAll(
        'SELECT pv.*, p.charinfo FROM player_vehicles pv LEFT JOIN players p ON pv.citizenid = p.citizenid WHERE pv.shared_garage_id = ?',
        {garageId}, function(vehicles)
            if vehicles and #vehicles > 0 then
                for i, vehicle in ipairs(vehicles) do
                    local charinfo = json.decode(vehicle.charinfo)
                    if charinfo then
                        vehicles[i].owner_name = charinfo.firstname .. ' ' .. charinfo.lastname
                    else
                        vehicles[i].owner_name = "Desconocido"
                    end
                end
                cb(vehicles)
            else
                cb({})
            end
        end)
end

RegisterNetEvent('DP-Garages:server:StoreVehicleInSharedGarage',
    function(plate, garageId, props, fuel, engineHealth, bodyHealth)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then
            return
        end

        local citizenid = Player.PlayerData.citizenid

        MySQL.Async.fetchAll('SELECT * FROM shared_garage_members WHERE garage_id = ? AND member_citizenid = ?',
            {garageId, citizenid}, function(memberResult)
                if not memberResult or #memberResult == 0 then
                    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_citizenid = ?',
                        {garageId, citizenid}, function(ownerResult)
                            if not ownerResult or #ownerResult == 0 then
                                TriggerClientEvent('QBCore:Notify', src, "No tienes acceso a este garaje compartido",
                                    "error")
                                return
                            end

                            storeVehicleInSharedGarage(src, plate, garageId, props, fuel, engineHealth, bodyHealth)
                        end)
                else
                    storeVehicleInSharedGarage(src, plate, garageId, props, fuel, engineHealth, bodyHealth)
                end
            end)
    end)

function storeVehicleInSharedGarage(src, plate, garageId, props, fuel, engineHealth, bodyHealth)
    local Player = QBCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizenid},
        function(result)
            if not result or #result == 0 then
                TriggerClientEvent('QBCore:Notify', src, "No eres dueño de este vehículo", "error")
                return
            end

            MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM player_vehicles WHERE shared_garage_id = ?', {garageId},
                function(countResult)
                    if countResult[1].count >= Config.MaxSharedVehicles then
                        TriggerClientEvent('QBCore:Notify', src, "El garaje compartido está lleno.", "error")
                        return
                    end

                    MySQL.Async.execute(
                        'UPDATE player_vehicles SET shared_garage_id = ?, mods = ?, fuel = ?, engine = ?, body = ?, state = 1, `stored` = 1 WHERE plate = ?',
                        {garageId, json.encode(props), fuel, engineHealth, bodyHealth, plate}, function(rowsChanged)
                            if rowsChanged > 0 then
                                TriggerClientEvent('QBCore:Notify', src, "Vehículo guardado en garaje compartido.",
                                    "success")

                                TriggerClientEvent('DP-Garages:client:RefreshVehicleList', src)
                            else
                                TriggerClientEvent('QBCore:Notify', src, "No se pudo almacenar el vehículo", "error")
                            end
                        end)
                end)
        end)
end

RegisterNetEvent('DP-Garages:server:UpdateVehicleState', function(plate, state)
    -- Remove the 'stored' column reference
    MySQL.Async.execute('UPDATE player_vehicles SET state = ?, last_update = ? WHERE plate = ?',
        {state, os.time(), plate}, function(rowsChanged)
            if rowsChanged > 0 then

                -- Update OutsideVehicles tracking table
                if state == 0 then
                    OutsideVehicles[plate] = true
                else
                    OutsideVehicles[plate] = nil
                end
            else
                Wait(100)
            end
        end)
end)

RegisterNetEvent('DP-Garages:server:RemoveVehicleFromSharedGarage', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local citizenid = Player.PlayerData.citizenid
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizenid},
        function(result)
            if not result or #result == 0 then
                TriggerClientEvent('QBCore:Notify', src, "No eres dueño de este vehículo", "error")
                TriggerClientEvent('DP-Garages:client:VehicleTransferCompleted', src, false, plate)
                return
            end

            -- Remove from shared garage
            MySQL.Async.execute('UPDATE player_vehicles SET shared_garage_id = NULL WHERE plate = ?', {plate},
                function(rowsChanged)
                    if rowsChanged > 0 then
                        TriggerClientEvent('QBCore:Notify', src, "Vehículo retirado del garaje compartido", "success")

                        TriggerClientEvent('DP-Garages:client:VehicleTransferCompleted', src, true, plate)

                        TriggerClientEvent('DP-Garages:client:RefreshVehicleList', src)
                    else
                        TriggerClientEvent('QBCore:Notify', src, "No se pudo retirar el vehículo", "error")
                        TriggerClientEvent('DP-Garages:client:VehicleTransferCompleted', src, false, plate)
                    end
                end)
        end)
end)

RegisterNetEvent('DP-Garages:server:TakeOutSharedVehicle', function(plate, garageId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll('SELECT * FROM shared_garage_members WHERE garage_id = ? AND member_citizenid = ?',
        {garageId, citizenid}, function(memberResult)
            if not memberResult or #memberResult == 0 then
                MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_citizenid = ?',
                    {garageId, citizenid}, function(ownerResult)
                        if not ownerResult or #ownerResult == 0 then
                            TriggerClientEvent('QBCore:Notify', src, "No tienes acceso a este garaje compartido",
                                "error")
                            return
                        end

                        takeOutSharedVehicle(src, plate, garageId)
                    end)
            else
                takeOutSharedVehicle(src, plate, garageId)
            end
        end)
end)

-- Modify in server.lua
function CheckForLostVehicles()
    local currentTime = os.time()

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE state = 0', {}, function(vehicles)
        if not vehicles or #vehicles == 0 then
            return
        end

        for _, vehicle in ipairs(vehicles) do
            local lastUpdate = vehicle.last_update or 0

            -- If vehicle has been out for more than the configured timeout
            if (currentTime - lastUpdate) > Config.LostVehicleTimeout then
                MySQL.Async.execute(
                    'UPDATE player_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ?, impoundfee = ? WHERE plate = ?',
                    {currentTime, "Vehículo abandonado o perdido", "Sistema automatizado", "police",
                     Config.ImpoundFee, vehicle.plate})
                if OutsideVehicles[vehicle.plate] then
                    OutsideVehicles[vehicle.plate] = nil
                end
            end
        end
    end)
end

RegisterNetEvent('vehiclemod:server:syncDeletion', function(netId, plate)
    if plate then
        -- Clean the plate (remove spaces)
        plate = plate:gsub("%s+", "")

        -- Check if this is a player-owned vehicle
        MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result and #result > 0 then
                local currentTime = os.time()

                -- Update vehicle to impound state
                MySQL.Async.execute(
                    'UPDATE player_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ?, impoundfee = ? WHERE plate = ?',
                    {currentTime, "Vehicle was towed", "City Towing", "police", Config.ImpoundFee, plate})
                if OutsideVehicles[plate] then
                    OutsideVehicles[plate] = nil
                end
            end
        end)
    end
end)

CreateThread(function()
    Wait(60000) -- Wait 1 minute after resource start

    while true do
        CheckForLostVehicles()
        Wait(300000) -- Check every 5 minutes
    end
end)

CreateThread(function()
    while true do
        Wait(3600000)
        CheckForLostVehicles()
    end
end)

function takeOutSharedVehicle(src, plate, garageId)
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND shared_garage_id = ? AND state = 1',
        {plate, garageId}, function(result)
            if not result or #result == 0 then
                TriggerClientEvent('QBCore:Notify', src, "Vehículo no encontrado o ya retirado", "error")
                return
            end

            -- Just update state without removing shared_garage_id association
            MySQL.Async.execute('UPDATE player_vehicles SET state = 0, `stored` = 0 WHERE plate = ?', {plate},
                function(rowsChanged)
                    if rowsChanged > 0 then
                        TriggerClientEvent('QBCore:Notify', src, "Vehículo sacado del garaje compartido", "success")
                        TriggerClientEvent('DP-Garages:client:TakeOutSharedVehicle', src, plate, result[1])
                    else
                        TriggerClientEvent('QBCore:Notify', src, "No se pudo sacar el vehículo", "error")
                    end
                end)
        end)
end

QBCore.Functions.CreateCallback('DP-Garages:server:CheckVehicleStatus', function(source, cb, plate)
    MySQL.Async.fetchAll('SELECT state FROM player_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            -- Return true if state is 1 (in garage), false otherwise
            cb(result[1].state == 1)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:GetSharedGarageMembers', function(source, cb, garageId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return cb({})
    end

    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_citizenid = ?', {garageId, citizenid},
        function(result)
            if not result or #result == 0 then
                cb({})
                return
            end

            -- Get members
            MySQL.Async.fetchAll(
                'SELECT sgm.*, p.charinfo FROM shared_garage_members sgm LEFT JOIN players p ON sgm.member_citizenid = p.citizenid WHERE sgm.garage_id = ?',
                {garageId}, function(members)
                    if members and #members > 0 then
                        local formattedMembers = {}
                        for i, member in ipairs(members) do
                            local charinfo = json.decode(member.charinfo)
                            local memberData = {
                                id = member.id,
                                citizenid = member.member_citizenid,
                                name = "Desconocido"
                            }

                            if charinfo then
                                memberData.name = charinfo.firstname .. ' ' .. charinfo.lastname
                            end

                            if member.member_citizenid ~= citizenid then
                                table.insert(formattedMembers, memberData)
                            end
                        end
                        cb(formattedMembers)
                    else
                        cb({})
                    end
                end)
        end)
end)

RegisterNetEvent('DP-Garages:server:HandleDeletedVehicle', function(plate)
    if not plate then
        return
    end

    plate = plate:gsub("%s+", "")

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            MySQL.Async.execute(
                'UPDATE player_vehicles SET state = 2, garage = "impound", impoundedtime = ? WHERE plate = ? AND state = 0',
                {os.time(), plate}, function(rowsChanged)
                    if rowsChanged > 0 then
                    end
                end)
        end
    end)
end)

-- Función helper para obtener matrículas en el servidor
function GetVehiclePlate(vehicle)
    if not DoesEntityExist(vehicle) then
        return nil
    end
    local plate = GetVehicleNumberPlateText(vehicle)
    return plate and plate:gsub("%s+", "") or nil
end

RegisterNetEvent('QBCore:Server:DeleteVehicle', function(netId)
    if netId then
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(vehicle) and vehicle ~= nil then
            local plate = GetVehiclePlate(vehicle)
            if plate then
                MySQL.Async.execute(
                    'UPDATE player_vehicles SET state = 2, garage = "impound", impoundedtime = ? WHERE plate = ? AND state = 0',
                    {os.time(), plate}, function(rowsChanged)
                        if rowsChanged > 0 then
                            -- Éxito
                        end
                    end)
            end
        end
    end
end)

RegisterNetEvent('QBCore:Server:OnVehicleDelete', function(plate)
    if not plate then
        return
    end

    -- Clean the plate (remove spaces)
    plate = plate:gsub("%s+", "")

    -- Check if this is a player-owned vehicle
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            local currentTime = os.time()

            -- Update vehicle to impound state
            MySQL.Async.execute(
                'UPDATE player_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ?, impoundfee = ? WHERE plate = ?',
                {currentTime, "El vehículo fue remolcado", "Remolque urbano", "police", Config.ImpoundFee, plate})
            if OutsideVehicles[plate] then
                OutsideVehicles[plate] = nil
            end
        end
    end)
end)

RegisterNetEvent('vehiclemod:server:syncDeletion', function(netId, plate)
    if plate then
        -- Clean the plate (remove spaces)
        plate = plate:gsub("%s+", "")

        -- Check if this is a player-owned vehicle
        MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result and #result > 0 then
                local currentTime = os.time()

                -- Update vehicle to impound state
                MySQL.Async.execute(
                    'UPDATE player_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ?, impoundfee = ? WHERE plate = ?',
                    {currentTime, "El vehículo fue remolcado", "remolque urbano", "police", Config.ImpoundFee, plate})
                if OutsideVehicles[plate] then
                    OutsideVehicles[plate] = nil
                end
            end
        end)
    end
end)

RegisterNetEvent('qb-garage:server:UpdateOutsideVehicles', function(plate, state)
    if plate and state == 2 then
        -- Vehicle was deleted/impounded by some external script
        MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result and #result > 0 then
                local currentTime = os.time()

                -- Update vehicle to impound state
                MySQL.Async.execute(
                    'UPDATE player_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ?, impoundfee = ? WHERE plate = ?',
                    {currentTime, "El vehículo fue remolcado", "remolque urbano", "police", Config.ImpoundFee, plate})
                if OutsideVehicles[plate] then
                    OutsideVehicles[plate] = nil
                end
            end
        end)
    end
end)

RegisterNetEvent('DP-Garages:server:RemoveMemberFromSharedGarage', function(memberId, garageId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_citizenid = ?', {garageId, citizenid},
        function(result)
            if not result or #result == 0 then
                TriggerClientEvent('QBCore:Notify', src, "Este garaje no te pertenece", "error")
                return
            end

            MySQL.Async
                .fetchAll('SELECT * FROM shared_garage_members WHERE id = ? AND garage_id = ?', {memberId, garageId},
                function(memberResult)
                    if not memberResult or #memberResult == 0 then
                        TriggerClientEvent('QBCore:Notify', src, "Miembro no encontrado", "error")
                        return
                    end

                    MySQL.Async
                        .execute('DELETE FROM shared_garage_members WHERE id = ?', {memberId}, function(rowsChanged)
                        if rowsChanged > 0 then
                            TriggerClientEvent('QBCore:Notify', src, "Miembro eliminado del garaje compartido",
                                "success")

                            local memberCitizenid = memberResult[1].member_citizenid
                            local memberPlayer = QBCore.Functions.GetPlayerByCitizenId(memberCitizenid)
                            if memberPlayer then
                                TriggerClientEvent('QBCore:Notify', memberPlayer.PlayerData.source,
                                    "Te han eliminado del garaje compartido " .. result[1].name, "error")
                            end
                        else
                            TriggerClientEvent('QBCore:Notify', src, "No se pudo eliminar el miembro", "error")
                        end
                    end)
                end)
        end)
end)

RegisterNetEvent('DP-Garages:server:DeleteSharedGarage', function(garageId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local citizenid = Player.PlayerData.citizenid
    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_citizenid = ?', {garageId, citizenid},
        function(result)
            if not result or #result == 0 then
                TriggerClientEvent('QBCore:Notify', src, "Este garaje no te pertenece", "error")
                return
            end

            MySQL.Async
                .execute('UPDATE player_vehicles SET shared_garage_id = NULL WHERE shared_garage_id = ?', {garageId},
                function()
                    MySQL.Async.execute('DELETE FROM shared_garage_members WHERE garage_id = ?', {garageId})

                    MySQL.Async.execute('DELETE FROM shared_garages WHERE id = ?', {garageId}, function(rowsChanged)
                        if rowsChanged > 0 then
                            TriggerClientEvent('QBCore:Notify', src, "Garaje compartido eliminado", "success")
                        else
                            TriggerClientEvent('QBCore:Notify', src, "No se pudo eliminar el garaje compartido", "error")
                        end
                    end)
                end)
        end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:StoreInSelectedSharedGarage', function(source, cb, plate, garageId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return cb({
            status = "error",
            message = "Jugador no encontrado"
        })
    end

    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizenid},
        function(result)
            if not result or #result == 0 then
                TriggerClientEvent('QBCore:Notify', src, "No eres dueño de este vehículo", "error")
                return cb({
                    status = "error",
                    message = "Error en la verificación de propiedad del vehículo"
                })
            end

            if result[1].state ~= 1 then
                TriggerClientEvent('QBCore:Notify', src, "El vehículo debe estar guardado para poder compartirlo.",
                    "error")
                return cb({
                    status = "error",
                    message = "El vehículo debe estar almacenado."
                })
            end

            MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM player_vehicles WHERE shared_garage_id = ?', {garageId},
                function(countResult)
                    if countResult[1].count >= Config.MaxSharedVehicles then
                        TriggerClientEvent('QBCore:Notify', src, "El garaje compartido está lleno.", "error")
                        return cb({
                            status = "error",
                            message = "El garaje compartido está lleno."
                        })
                    end

                    MySQL.Async
                        .execute('UPDATE player_vehicles SET shared_garage_id = ? WHERE plate = ?', {garageId, plate},
                        function(rowsChanged)
                            if rowsChanged > 0 then
                                TriggerClientEvent('QBCore:Notify', src, "Vehículo guardado en garaje compartido.",
                                    "success")
                                TriggerClientEvent('DP-Garages:client:RefreshVehicleList', src)
                                return cb({
                                    status = "success"
                                })
                            else
                                TriggerClientEvent('QBCore:Notify', src,
                                    "No se pudo guardar el vehículo en el garaje compartido", "error")
                                return cb({
                                    status = "error",
                                    message = "Error al actualizar la base de datos"
                                })
                            end
                        end)
                end)
        end)
end)

RegisterNetEvent('DP-Garages:server:TransferVehicleToSharedGarage', function(plate, garageId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local citizenid = Player.PlayerData.citizenid
    MySQL.Async.fetchAll('SELECT * FROM shared_garage_members WHERE garage_id = ? AND member_citizenid = ?',
        {garageId, citizenid}, function(memberResult)
            local hasAccess = false

            if memberResult and #memberResult > 0 then
                hasAccess = true
            else
                MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_citizenid = ?',
                    {garageId, citizenid}, function(ownerResult)
                        if ownerResult and #ownerResult > 0 then
                            hasAccess = true
                        end

                        if hasAccess then
                            TransferVehicleToSharedGarage(src, plate, garageId, citizenid)
                        else
                            TriggerClientEvent('QBCore:Notify', src, "No tienes acceso a este garaje compartido",
                                "error")
                            TriggerClientEvent('DP-Garages:client:VehicleTransferCompleted', src, false, plate)
                        end
                    end)
                return
            end

            if hasAccess then
                TransferVehicleToSharedGarage(src, plate, garageId, citizenid)
            end
        end)
end)

function TransferVehicleToSharedGarage(src, plate, garageId, citizenid)
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizenid},
        function(result)
            if not result or #result == 0 then
                TriggerClientEvent('QBCore:Notify', src, "No eres dueño de este vehículo", "error")
                TriggerClientEvent('DP-Garages:client:VehicleTransferCompleted', src, false, plate)
                return
            end

            if result[1].state ~= 1 then
                TriggerClientEvent('QBCore:Notify', src,
                    "El vehículo deberá estar guardado en un garaje para poder trasladarlo.", "error")
                -- Notify client that transfer failed
                TriggerClientEvent('DP-Garages:client:VehicleTransferCompleted', src, false, plate)
                return
            end

            MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM player_vehicles WHERE shared_garage_id = ?', {garageId},
                function(countResult)
                    if countResult[1].count >= Config.MaxSharedVehicles then
                        TriggerClientEvent('QBCore:Notify', src, "El garaje compartido está lleno.", "error")
                        TriggerClientEvent('DP-Garages:client:VehicleTransferCompleted', src, false, plate)
                        return
                    end

                    MySQL.Async
                        .execute('UPDATE player_vehicles SET shared_garage_id = ? WHERE plate = ?', {garageId, plate},
                        function(rowsChanged)
                            if rowsChanged > 0 then
                                TriggerClientEvent('QBCore:Notify', src, "Vehículo transferido a garaje compartido",
                                    "success")

                                TriggerClientEvent('DP-Garages:client:VehicleTransferCompleted', src, true, plate)

                                TriggerClientEvent('DP-Garages:client:RefreshVehicleList', src)
                            else
                                TriggerClientEvent('QBCore:Notify', src, "No se pudo transferir el vehículo", "error")
                                TriggerClientEvent('DP-Garages:client:VehicleTransferCompleted', src, false, plate)
                            end
                        end)
                end)
        end)
end

QBCore.Functions.CreateCallback('DP-Garages:server:CheckIfVehicleOwned', function(source, cb, plate)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb(false)
    end

    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizenid},
        function(result)
            if result and #result > 0 then
                cb(true)
            else
                if Player.PlayerData.gang and Player.PlayerData.gang.name ~= "none" then
                    MySQL.Async.fetchAll('SELECT * FROM gang_vehicles WHERE plate = ? AND gang = ?',
                        {plate, Player.PlayerData.gang.name}, function(gangResult)
                            cb(gangResult and #gangResult > 0)
                        end)
                else
                    cb(false)
                end
            end
        end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:GetVehicleInfo', function(source, cb, plate)
    if not plate then
        return cb(nil)
    end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb(nil)
    end

    MySQL.Async.fetchAll(
        'SELECT pv.*, p.charinfo FROM player_vehicles pv LEFT JOIN players p ON pv.citizenid = p.citizenid WHERE pv.plate = ?',
        {plate}, function(result)
            if result and #result > 0 then
                local vehicleInfo = result[1]
                local ownerName = "Desconocido"

                if vehicleInfo.charinfo then
                    local charinfo = json.decode(vehicleInfo.charinfo)
                    if charinfo then
                        ownerName = charinfo.firstname .. ' ' .. charinfo.lastname
                    end
                end

                if vehicleInfo.citizenid == Player.PlayerData.citizenid then
                    ownerName = "Tú"
                end

                local formattedInfo = {
                    name = vehicleInfo.custom_name or nil,
                    ownerName = ownerName,
                    garage = vehicleInfo.garage or "Desconocido",
                    state = vehicleInfo.state or 1,
                    storedInGang = vehicleInfo.stored_in_gang ~= nil,
                    storedInShared = vehicleInfo.shared_garage_id ~= nil,
                    isOwner = vehicleInfo.citizenid == Player.PlayerData.citizenid
                }

                cb(formattedInfo)
            else
                cb(nil)
            end
        end)
end)

RegisterNetEvent('DP-Garages:server:CreateSharedGaragesTables')
AddEventHandler('DP-Garages:server:CreateSharedGaragesTables', function()
    local src = source
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS shared_garages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(50) NOT NULL,
            owner_citizenid VARCHAR(50) NOT NULL,
            access_code VARCHAR(10) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]], {}, function()
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS shared_garage_members (
                id INT AUTO_INCREMENT PRIMARY KEY,
                garage_id INT NOT NULL,
                member_citizenid VARCHAR(50) NOT NULL,
                joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (garage_id) REFERENCES shared_garages(id) ON DELETE CASCADE
            )
        ]], {}, function()
            MySQL.Async.execute([[
                ALTER TABLE player_vehicles ADD COLUMN IF NOT EXISTS shared_garage_id INT NULL;
                ALTER TABLE player_vehicles ADD COLUMN IF NOT EXISTS is_favorite INT DEFAULT 0;
            ]], {}, function()
                TriggerClientEvent('QBCore:Notify', src, "Función de garajes compartidos inicializada", "success")
            end)
        end)
    end)
end)

function CreateSharedGaragesTables(src, callback)
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS shared_garages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(50) NOT NULL,
            owner_citizenid VARCHAR(50) NOT NULL,
            access_code VARCHAR(10) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]], {}, function()
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS shared_garage_members (
                id INT AUTO_INCREMENT PRIMARY KEY,
                garage_id INT NOT NULL,
                member_citizenid VARCHAR(50) NOT NULL,
                joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (garage_id) REFERENCES shared_garages(id) ON DELETE CASCADE
            )
        ]], {}, function()
            MySQL.Async.execute([[
                ALTER TABLE player_vehicles ADD COLUMN IF NOT EXISTS shared_garage_id INT NULL
            ]], {}, function()
                QBCore.Functions.Notify(src, "Función de garajes compartidos inicializada", "success")
                callback()
            end)
        end)
    end)
end

QBCore.Functions.CreateCallback('DP-Garages:server:CheckSharedGaragesTables', function(source, cb)
    MySQL.Async.fetchAll("SHOW TABLES LIKE 'shared_garages'", {}, function(result)
        cb(result and #result > 0)
    end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:CanPayImpoundFee', function(source, cb, fee)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb(false)
    end

    if Player.PlayerData.money["cash"] >= fee then
        cb(true)
    elseif Player.PlayerData.money["bank"] >= fee then
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('DP-Garages:server:GetVehicleByPlate', function(source, cb, plate)
    if OutsideVehicles[plate] then
        cb(nil, true) -- Vehicle is already outside
        return
    end

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            if result[1].state == 0 then
                cb(nil, true) -- Vehicle is already out according to DB
            else
                cb(result[1], false) -- Vehicle is available
            end
        else
            cb(nil, false) -- Vehicle not found
        end
    end)
end)
-- Pay impound fee and release vehicle
RegisterNetEvent('DP-Garages:server:PayImpoundFee', function(plate, fee)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND state = 2', {plate}, function(result)
        if not result or #result == 0 then
            TriggerClientEvent('QBCore:Notify', src, "Vehículo no encontrado o ya liberado", "error")
            return
        end
        local vehicle = result[1]
        local actualFee = Config.ImpoundFee -- Default fee
        if vehicle.impoundfee ~= nil then
            local customFee = tonumber(vehicle.impoundfee)
            if customFee and customFee > 0 then
                actualFee = customFee
            end
        end

        if Player.PlayerData.money["cash"] >= actualFee then
            Player.Functions.RemoveMoney("cash", actualFee, "impound-fee")
        else
            Player.Functions.RemoveMoney("bank", actualFee, "impound-fee")
        end
        MySQL.Async.execute(
            'UPDATE player_vehicles SET state = 0, garage = NULL, impoundedtime = NULL, impoundreason = NULL, impoundedby = NULL, impoundtype = NULL, impoundfee = NULL, impoundtime = NULL WHERE plate = ?',
            {plate}, function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerClientEvent('QBCore:Notify', src,
                        "Has pagado $" .. actualFee .. " para recuperar tu vehículo", "success")
                end
            end)
    end)
end)

RegisterNetEvent('DP-Garages:server:ImpoundVehicle', function(plate, props, reason, impoundType, jobName, officerName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    if not Config.ImpoundJobs[Player.PlayerData.job.name] then
        TriggerClientEvent('QBCore:Notify', src, "No está autorizado a incautar vehículos.", "error")
        return
    end
    MySQL.Async.execute(
        'UPDATE player_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ? WHERE plate = ?',
        {os.time(), reason, officerName, impoundType, plate}, function(rowsChanged)
            if rowsChanged > 0 then
                TriggerClientEvent('QBCore:Notify', src, "Vehículo incautado con éxito", "success")

                local logData = {
                    plate = plate,
                    impoundedBy = officerName,
                    job = jobName,
                    reason = reason,
                    type = impoundType,
                    timestamp = os.time()
                }

                MySQL.Async.fetchAll('SELECT citizenid FROM player_vehicles WHERE plate = ?', {plate}, function(result)
                    if result and #result > 0 then
                        local ownerCitizenId = result[1].citizenid
                        local ownerPlayer = QBCore.Functions.GetPlayerByCitizenId(ownerCitizenId)

                        if ownerPlayer then
                            TriggerClientEvent('QBCore:Notify', ownerPlayer.PlayerData.source,
                                "Su vehículo con placa " .. plate .. " ha sido incautado", "error")
                        end
                    end
                end)
            else
                TriggerClientEvent('QBCore:Notify', src,
                    "No se pudo incautar el vehículo - Vehículo no encontrado en la base de datos", "error")
            end
        end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    MySQL.Async.fetchAll('SHOW COLUMNS FROM player_vehicles LIKE "impoundedtime"', {}, function(result)
        if result and #result > 0 then
        else
            Wait(100)
        end
    end)
end)

RegisterNetEvent('DP-Garages:server:ImpoundVehicleWithParams',
    function(plate, props, reason, impoundType, jobName, officerName, impoundFee)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then
            return
        end

        if not Config.ImpoundJobs[Player.PlayerData.job.name] then
            TriggerClientEvent('QBCore:Notify', src, "No está autorizado a incautar vehículos.", "error")
            return
        end
        local fee = tonumber(impoundFee)
        MySQL.Async.execute(
            'UPDATE player_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ?, impoundfee = ? WHERE plate = ?',
            {os.time(), reason, officerName, impoundType, fee, plate}, function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerClientEvent('QBCore:Notify', src, "Vehículo incautado con " .. fee .. " multa", "success")

                    local logData = {
                        plate = plate,
                        impoundedBy = officerName,
                        job = jobName,
                        reason = reason,
                        type = impoundType,
                        fee = fee,
                        timestamp = os.time()
                    }

                    MySQL.Async
                        .fetchAll('SELECT citizenid FROM player_vehicles WHERE plate = ?', {plate}, function(result)
                        if result and #result > 0 then
                            local ownerCitizenId = result[1].citizenid
                            local ownerPlayer = QBCore.Functions.GetPlayerByCitizenId(ownerCitizenId)

                            if ownerPlayer then
                                TriggerClientEvent('QBCore:Notify', ownerPlayer.PlayerData.source,
                                    "Su vehículo con placa " .. plate .. " ha sido incautado", "error")
                            end
                        end
                    end)
                else
                    TriggerClientEvent('QBCore:Notify', src,
                        "No se pudo incautar el vehículo - Vehículo no encontrado en la base de datos", "error")
                end
            end)
    end)

MySQL.Async.execute([[
    SHOW COLUMNS FROM player_vehicles LIKE 'impoundedtime';
]], {}, function(result)
    if result and #result == 0 then
        MySQL.Async.execute("ALTER TABLE player_vehicles ADD COLUMN impoundedtime INT NULL;", {})
        MySQL.Async.execute("ALTER TABLE player_vehicles ADD COLUMN impoundreason VARCHAR(255) NULL;", {})
        MySQL.Async.execute("ALTER TABLE player_vehicles ADD COLUMN impoundedby VARCHAR(255) NULL;", {})
        MySQL.Async.execute("ALTER TABLE player_vehicles ADD COLUMN impoundtype VARCHAR(50) NULL;", {})
        MySQL.Async.execute("ALTER TABLE player_vehicles ADD COLUMN impoundfee INT NULL;", {})
        MySQL.Async.execute("ALTER TABLE player_vehicles ADD COLUMN impoundtime INT NULL;", {})
    else
        Wait(100)
    end
end)

QBCore.Functions.CreateCallback('DP-Garages:server:GetImpoundedVehicles', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb({})
    end

    local citizenid = Player.PlayerData.citizenid

    -- Make sure we're properly selecting impounded vehicles (state = 2)
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE citizenid = ? AND state = 2', {citizenid},
        function(result)
            if result and #result > 0 then
                -- Add debug info to help track the issue
                for i, vehicle in ipairs(result) do
                end
                cb(result)
            else
                cb({})
            end
        end)
end)

QBCore.Functions.CreateCallback('DP-Garages:server:GetJobGarageVehicles', function(source, cb, garageId)

    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE garage = ? AND state = 1', {garageId}, function(result)
        if result and #result > 0 then
            for i, vehicle in ipairs(result) do
            end
            cb(result)
        else
            cb({})
        end
    end)
end)
