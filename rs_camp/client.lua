local campsEntities = {}
local dynamicDoors = {}
local campsData = {}
local doorStates = {}
local renderDistance = Config.RenderDistace
local closestDoorEntity, closestDoorId = nil, nil
local closestCampEntity, closestCampId = nil, nil
local closestChestEntity, closestChestId = nil, nil
local targetEnabled = false

local campPromptGroup = UipromptGroup:new(Config.Promp.Controls)
local campPickUpPrompt = Uiprompt:new(Config.Promp.Key.Pickut, Config.Promp.Collect, campPromptGroup)
campPickUpPrompt:setHoldMode(true)

local chestPromptGroup = UipromptGroup:new(Config.Promp.Chest)
local chestPrompt = Uiprompt:new(Config.Promp.Key.Chest, Config.Promp.Chestopen, chestPromptGroup)
chestPrompt:setStandardMode(true)

local doorPromptGroup = UipromptGroup:new(Config.Promp.Door)
local doorPrompt = Uiprompt:new(Config.Promp.Key.Door, Config.Promp.Dooropen, doorPromptGroup)
doorPrompt:setStandardMode(true)

local function RotationToDirection(rot)
    local radX = math.rad(rot.x)
    local radZ = math.rad(rot.z)
    local cosX = math.cos(radX)
    return vector3(-math.sin(radZ) * cosX, math.cos(radZ) * cosX, math.sin(radX))
end

local function RaycastFromCamera(distance)
    local playerPed = PlayerPedId()
    local coords = GetGameplayCamCoord()
    local rotation = GetGameplayCamRot(2)
    local forwardVector = RotationToDirection(rotation)
    local dest = coords + (forwardVector * distance)

    local rayHandle = StartShapeTestRay(coords.x, coords.y, coords.z, dest.x, dest.y, dest.z, 1572865 + 16 + 32, playerPed, 0)
    local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

    if hit == 1 and DoesEntityExist(entityHit) then
        return entityHit
    end
    return nil
end

local function hideCampPrompt()
    campPromptGroup:setActive(false)
    campPickUpPrompt:setVisible(false)
    campPickUpPrompt:setEnabled(false)
    closestCampEntity, closestCampId = nil, nil
end

local function DrawCrosshair(isTarget)
    local dict = "blips"
    local name = "blip_ambient_eyewitness"

    if not HasStreamedTextureDictLoaded(dict) then
        RequestStreamedTextureDict(dict)
        while not HasStreamedTextureDictLoaded(dict) do
            Wait(0)
        end
    end

    local r, g, b = 255, 255, 255
    if isTarget then r, g, b = 0, 255, 0 end
    DrawSprite(dict, name, 0.5, 0.5, 0.02, 0.03, 0.0, r, g, b, 255)
end

local function isChestObject(model)
    for _, v in pairs(Config.Chests) do
        if GetHashKey(v.object) == model then
            return true
        end
    end
    return false
end

local AllVegetation = 1+2+4+8+16+32+64+128+256
local VMT_Cull = 1+2+4+8+16+32

local ActiveVegZones = {}

local function AddVegModifierSphere(x, y, z, radius)
    return Citizen.InvokeNative(0xFA50F79257745E74, x, y, z, radius, VMT_Cull, AllVegetation, 0)
end

local function RemoveVegModifierSphere(sphere, p1)
    return Citizen.InvokeNative(0x9CF1836C03FB67A2, Citizen.PointerValueIntInitialized(sphere), p1)
end

RegisterNetEvent('rs_camp:client:spawnCamps')
AddEventHandler('rs_camp:client:spawnCamps', function(data)
    campsData[data.id] = data
end)

CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local activeCamps = {}

        for id, data in pairs(campsData) do
            local pos = vector3(data.x, data.y, data.z)
            local dist = #(playerCoords - pos)

            if dist < renderDistance and not campsEntities[id] then
                local modelHash = GetHashKey(data.item.model)
                local isDynamic = false
                local modelName = data.item.model
                for _, door in pairs(Config.Doors or {}) do
                    if door.modelDoor == modelName then
                        isDynamic = true
                        dynamicDoors[id] = GetHashKey(modelName)
                        break
                    end
                end
                local object = CreateObjectNoOffset(modelHash, data.x, data.y, data.z, false, false, isDynamic)

                SetEntityRotation(object,
                    tonumber(data.rotation.x or 0.0) % 360.0,
                    tonumber(data.rotation.y or 0.0) % 360.0,
                    tonumber(data.rotation.z or 0.0) % 360.0
                )
                FreezeEntityPosition(object, true)
                SetEntityAsMissionEntity(object, true)

                campsEntities[id] = object

                for _, item in pairs(Config.Items or {}) do
                    if item.model == data.item.model and item.veg then
                        ActiveVegZones[id] = AddVegModifierSphere(data.x, data.y, data.z, item.veg)
                        break
                    end
                end
            end

            if dist > renderDistance and campsEntities[id] then
                DeleteEntity(campsEntities[id])
                campsEntities[id] = nil

                if ActiveVegZones[id] then
                    RemoveVegModifierSphere(ActiveVegZones[id], 0)
                    ActiveVegZones[id] = nil
                end
                dynamicDoors[id] = nil
            end

            if dist < renderDistance then
                activeCamps[id] = true
            end
        end

        for id, sphere in pairs(ActiveVegZones) do
            if not activeCamps[id] then
                RemoveVegModifierSphere(sphere, 0)
                ActiveVegZones[id] = nil
            end
        end

        Wait(1000)
    end
end)

RegisterNetEvent('rs_camp:client:removeCamp')
AddEventHandler('rs_camp:client:removeCamp', function(uniqueId)

    if ActiveVegZones[uniqueId] then
        RemoveVegModifierSphere(ActiveVegZones[uniqueId], 0)
        ActiveVegZones[uniqueId] = nil
    end

    local entity = campsEntities[uniqueId]
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    campsEntities[uniqueId] = nil
    campsData[uniqueId] = nil
    dynamicDoors[uniqueId] = nil
end)

Citizen.CreateThread(function()
    TriggerServerEvent('rs_camp:server:requestCamps')
end)

RegisterNetEvent('rs_camp:client:receiveCamps')
AddEventHandler('rs_camp:client:receiveCamps', function(camps)
    if camps then
        for _, data in pairs(camps) do
            TriggerEvent('rs_camp:client:spawnCamps', data)
        end
    end
end)

RegisterCommand(Config.Commands.Camp, function()
    targetEnabled = not targetEnabled

    if targetEnabled then
        TriggerEvent("vorp:NotifyLeft", Config.Text.Target, Config.Text.Targeton, "generic_textures", "tick", 2000, "COLOR_GREEN")
        SendNUIMessage({
            action = "showtarget",
            text = Config.Text.TargetActiveText .. Config.Commands.Camp .. Config.Text.TargetActiveText1
        })
    else
        TriggerEvent("vorp:NotifyLeft", Config.Text.Target, Config.Text.Targetoff, "menu_textures", "cross", 2000, "COLOR_RED")
        hideCampPrompt()
        SendNUIMessage({ action = "hidetarget" })
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if targetEnabled then
            local entityHit = RaycastFromCamera(10.0)
            local found = false
            closestCampEntity, closestCampId = nil, nil

            if entityHit then
                for uniqueId, entity in pairs(campsEntities) do
                    if entityHit == entity then
                        closestCampEntity = entity
                        closestCampId = uniqueId
                        found = true
                        break
                    end
                end
            end

            DrawCrosshair(found)

            if found then
                campPromptGroup:setActive(true)
                campPickUpPrompt:setVisible(true)
                campPickUpPrompt:setEnabled(true)
            else
                hideCampPrompt()
            end
        else
            hideCampPrompt()
        end
    end
end)

local function updateChestPrompts()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    closestChestEntity, closestChestId = nil, nil
    local closestDistance = 2.0

    for uniqueId, entity in pairs(campsEntities or {}) do
        if DoesEntityExist(entity) and isChestObject(GetEntityModel(entity)) then
            local entCoords = GetEntityCoords(entity)
            local distance = #(playerCoords - entCoords)
            if distance <= closestDistance then
                closestDistance = distance
                closestChestEntity = entity
                closestChestId = uniqueId
            end
        end
    end

    local foundChest = (closestChestEntity ~= nil)

    chestPromptGroup:setActive(foundChest)

    if foundChest and closestChestId then
        chestPrompt:setText(Config.Promp.Chestopen .. " ID - " .. tostring(closestChestId) .. " ")
    end

    chestPrompt:setVisible(foundChest)
    chestPrompt:setEnabled(foundChest)
end

local function updateDoorPrompts()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    closestDoorEntity, closestDoorId = nil, nil
    local closestDistance = 2.0

    for uniqueId, entity in pairs(campsEntities or {}) do
        if DoesEntityExist(entity) and dynamicDoors[uniqueId] then
            local entCoords = GetEntityCoords(entity)
            local distance = #(playerCoords - entCoords)
            if distance <= closestDistance then
                closestDistance = distance
                closestDoorEntity = entity
                closestDoorId = uniqueId
            end
        end
    end

    local foundDoor = (closestDoorEntity ~= nil)
    doorPromptGroup:setActive(foundDoor)

    if foundDoor and closestDoorId then
        doorPrompt:setText(Config.Promp.Dooropen .. " ID - " .. tostring(closestDoorId))
    end

    doorPrompt:setVisible(foundDoor)
    doorPrompt:setEnabled(foundDoor)
end

CreateThread(function()
    while true do
        Wait(500)
        updateDoorPrompts()
    end
end)

CreateThread(function()
    while true do
        Wait(500)
        updateChestPrompts()
    end
end)

campPromptGroup:setOnHoldModeJustCompleted(function(group, prompt)
    if closestCampEntity and DoesEntityExist(closestCampEntity) then
        if prompt == campPickUpPrompt and closestCampId then
            TriggerServerEvent('rs_camp:server:pickUpByOwner', closestCampId)
            hideCampPrompt()
        end
    end
end)

chestPromptGroup:setOnStandardModeJustCompleted(function(group, prompt)
    if closestChestEntity and DoesEntityExist(closestChestEntity) then
        if prompt == chestPrompt and closestChestId then
            TriggerServerEvent('rs_camp:server:openChest', closestChestId)
        end
    end
end)

doorPromptGroup:setOnStandardModeJustCompleted(function(group, prompt)
    if closestDoorEntity and DoesEntityExist(closestDoorEntity) and closestDoorId then
        TriggerServerEvent('rs_camp:server:toggleDoor', closestDoorId)
    end
end)

UipromptManager:startEventThread()

RegisterNetEvent('rs_camp:client:toggleDoor')
AddEventHandler('rs_camp:client:toggleDoor', function(campId)
    local door = campsEntities[campId]
    if door and DoesEntityExist(door) then
        local rot = GetEntityRotation(door, 2)
        local open = doorStates[campId] or false

        if not open then
            SetEntityRotation(door, rot.x, rot.y, rot.z + 90.0, 2, true)
            doorStates[campId] = true
        else
            SetEntityRotation(door, rot.x, rot.y, rot.z - 90.0, 2, true)
            doorStates[campId] = false
        end
    end
end)

local function GetModelRadius(modelHash)
    local minDim, maxDim = GetModelDimensions(modelHash)
    if minDim and maxDim then
        local sizeX = math.abs(maxDim.x - minDim.x)
        local sizeY = math.abs(maxDim.y - minDim.y)
        local sizeZ = math.abs(maxDim.z - minDim.z)
        local maxSize = math.max(sizeX, sizeY, sizeZ)
        return maxSize * 1.0
    else
        return 5.0
    end
end

RegisterNetEvent('rs_camp:client:placePropCamp')
AddEventHandler('rs_camp:client:placePropCamp', function(itemName)
    if not Config.Items[itemName] then return end

    local modelName = Config.Items[itemName].model
    local modelHash = GetHashKey(modelName)
    if not modelHash then return end

    local playerPed = PlayerPedId()
    local ox, oy, oz = table.unpack(GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 4.0, 0.0))

    local tempObj = CreateObject(modelHash, ox, oy, oz, true, true, true)
    if not tempObj then return end

    local dynamicRadius = GetModelRadius(modelHash)

    local posStep = 0.1
    local rotStep = posStep * 10
    local tempVegSphere = nil

    SetEntityCoords(tempObj, ox, oy, oz, false, false, false, false)
    FreezeEntityPosition(tempObj, true)
    SetEntityCollision(tempObj, false, false)
    SetEntityAlpha(tempObj, 180, false)
    SetEntityVisible(tempObj, true)
    SetModelAsNoLongerNeeded(modelHash)

    lastPlacedCamp = {entity = tempObj, coords = vector3(ox, oy, oz), rotation = vector3(0,0,0), model = modelName}

    tempVegSphere = AddVegModifierSphere(ox, oy, oz, dynamicRadius)

    SendNUIMessage({
        action = "showcamp",
        title = Config.ControlsPanel.title,
        controls = Config.ControlsPanel.controls,
        speed = Config.Text.SpeedLabel .. ": " .. string.format("%.2f", posStep)
    })

    local posX, posY, posZ = ox, oy, oz
    local rotX, rotY, rotZ = 0.0, 0.0, 0.0
    local isPlacing = true

    CreateThread(function()
        while isPlacing do
            Wait(0)
            for _, keyCode in pairs(Config.Keys) do
                DisableControlAction(0, keyCode, true)
            end

            local moved = false

            if IsDisabledControlJustPressed(0, Config.Keys.moveForward) then posY = posY + posStep; moved = true end
            if IsDisabledControlJustPressed(0, Config.Keys.moveBackward) then posY = posY - posStep; moved = true end
            if IsDisabledControlJustPressed(0, Config.Keys.moveLeft) then posX = posX - posStep; moved = true end
            if IsDisabledControlJustPressed(0, Config.Keys.moveRight) then posX = posX + posStep; moved = true end
            if IsDisabledControlJustPressed(0, Config.Keys.moveUp) then posZ = posZ + posStep; moved = true end
            if IsDisabledControlJustPressed(0, Config.Keys.moveDown) then posZ = posZ - posStep; moved = true end
            if IsDisabledControlJustPressed(0, Config.Keys.rotateRightZ) then rotZ = rotZ + rotStep; moved = true end
            if IsDisabledControlJustPressed(0, Config.Keys.rotateLeftZ) then rotZ = rotZ - rotStep; moved = true end
            if IsDisabledControlJustPressed(0, Config.Keys.rotateUpX) then rotX = rotX + rotStep; moved = true end
            if IsDisabledControlJustPressed(0, Config.Keys.rotateDownX) then rotX = rotX - rotStep; moved = true end
            if IsDisabledControlJustPressed(0, Config.Keys.rotateRightY) then rotY = rotY + rotStep; moved = true end
            if IsDisabledControlJustPressed(0, Config.Keys.rotateLeftY) then rotY = rotY - rotStep; moved = true end

            if IsDisabledControlJustPressed(0, Config.Keys.placeOnGround) then
                if DoesEntityExist(tempObj) then
                    PlaceObjectOnGroundProperly(tempObj)
                    local pos3 = GetEntityCoords(tempObj, true)
                    posX, posY, posZ = pos3.x, pos3.y, pos3.z
                    rotX, rotY, rotZ = table.unpack(GetEntityRotation(tempObj, 2))
                end
            end

            if IsDisabledControlJustPressed(0, Config.Keys.increaseSpeed) then
                posStep = math.min(posStep + 0.01, 5.0)
                rotStep = posStep * 10
                SendNUIMessage({
                    action = "showcamp",
                    title = Config.ControlsPanel.title,
                    controls = Config.ControlsPanel.controls,
                    speed = Config.Text.SpeedLabel .. ": " .. string.format("%.2f", posStep)
                })
            end
            
            if IsDisabledControlJustPressed(0, Config.Keys.decreaseSpeed) then
                posStep = math.max(posStep - 0.01, 0.01)
                rotStep = posStep * 10
                SendNUIMessage({
                    action = "showcamp",
                    title = Config.ControlsPanel.title,
                    controls = Config.ControlsPanel.controls,
                    speed = Config.Text.SpeedLabel .. ": " .. string.format("%.2f", posStep)
                })
            end

            if moved then
                SetEntityCoords(tempObj, posX, posY, posZ, true, true, true, false)
                SetEntityRotation(tempObj, rotX, rotY, rotZ, 2, true)

                if tempVegSphere then
                    RemoveVegModifierSphere(tempVegSphere, 0)
                end
                tempVegSphere = AddVegModifierSphere(posX, posY, posZ, dynamicRadius)
            end

            if IsDisabledControlJustPressed(0, Config.Keys.confirmPlace) then
                isPlacing = false
                SendNUIMessage({ action = "hidecamp" })
                if DoesEntityExist(tempObj) then DeleteObject(tempObj) end
                lastPlacedCamp = nil

                if tempVegSphere then
                    RemoveVegModifierSphere(tempVegSphere, 0)
                    tempVegSphere = nil
                end

                local pos = vector3(posX, posY, posZ)
                local rot = vector3(rotX, rotY, rotZ)
                TriggerServerEvent('rs_camp:server:savecampOwner', pos, rot, itemName)
                TriggerServerEvent("rs_camp:removeItem", itemName)
                TriggerEvent("vorp:NotifyLeft", Config.Text.Camp, Config.Text.Place, "generic_textures", "tick", 2000, "COLOR_GREEN")
            end

            if IsDisabledControlJustPressed(0, Config.Keys.cancelPlace) then
                isPlacing = false
                SendNUIMessage({ action = "hidecamp" })
                if DoesEntityExist(tempObj) then DeleteObject(tempObj) end
                lastPlacedCamp = nil

                if tempVegSphere then
                    RemoveVegModifierSphere(tempVegSphere, 0)
                    tempVegSphere = nil
                end

                TriggerEvent("vorp:NotifyLeft", Config.Text.Camp, Config.Text.Cancel, "menu_textures", "cross", 2000, "COLOR_RED")
            end
        end
    end)
end)

Citizen.CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Shareperms, Config.Text.Shared, {
        { name = Config.Text.Corret, help = Config.Text.Corret },
        { name = Config.Text.Sharecorret, help = Config.Text.Playerpermi}
    })

    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Unshareperms, Config.Text.Remove, {
        { name = Config.Text.Corret, help = Config.Text.Corret }
    })
end)

function GetCurentTownName()
    local pedCoords = GetEntityCoords(PlayerPedId())
    local town_hash = Citizen.InvokeNative(0x43AD8FC02B429D33, pedCoords, 1)

    local townNames = {
        [GetHashKey("Annesburg")] = "Annesburg",
        [GetHashKey("Armadillo")] = "Armadillo",
        [GetHashKey("Blackwater")] = "Blackwater",
        [GetHashKey("Rhodes")] = "Rhodes",
        [GetHashKey("StDenis")] = "StDenis",
        [GetHashKey("Strawberry")] = "Strawberry",
        [GetHashKey("Tumbleweed")] = "Tumbleweed",
        [GetHashKey("Valentine")] = "Valentine"
    }

    return townNames[town_hash]
end

RegisterNetEvent('rs_camp:client:sendTownToServer', function(itemName)
    local town = GetCurentTownName()
    TriggerServerEvent('rs_camp:server:checkTownAndPlace', itemName, town)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for uniqueId, _ in pairs(campsEntities) do

        if ActiveVegZones[uniqueId] then
            RemoveVegModifierSphere(ActiveVegZones[uniqueId], 0)
            ActiveVegZones[uniqueId] = nil
        end

        local entity = campsEntities[uniqueId]
        if entity and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end

        campsEntities[uniqueId] = nil
        campsData[uniqueId] = nil
        dynamicDoors[uniqueId] = nil
    end
end)
