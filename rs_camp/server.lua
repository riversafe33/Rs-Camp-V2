local VORPcore = exports.vorp_core:GetCore()
local VorpInv = exports.vorp_inventory:vorp_inventoryApi()
local Inv = exports.vorp_inventory
local loadedCamps = {}

local function registerStorage(prefix, name, limit)
    local isInvRegistered <const> = Inv:isCustomInventoryRegistered(prefix)
    if not isInvRegistered then
        local data <const> = {
            id = prefix,
            name = name,
            limit = limit,
            acceptWeapons = true,
            shared = false,
            ignoreItemStackLimit = true,
            whitelistItems = false,
            UsePermissions = false,
            UseBlackList = false,
            whitelistWeapons = false,
        }
        Inv:registerInventory(data)
    end
end

AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() ~= resource then return end

    exports.oxmysql:execute('SELECT * FROM rs_camp', {}, function(results)
        if results then
            loadedCamps = {}
            for _, row in pairs(results) do
                local campsData = {
                    id = row.id,
                    x = row.x,
                    y = row.y,
                    z = row.z,
                    rotation = { x = row.rot_x, y = row.rot_y, z = row.rot_z },
                    item = {
                        name = row.item_name,
                        model = row.item_model
                    }
                }
                table.insert(loadedCamps, campsData)
            end
        end
    end)
end)

RegisterNetEvent('rs_camp:server:requestCamps')
AddEventHandler('rs_camp:server:requestCamps', function()
    local src = source
    TriggerClientEvent('rs_camp:client:receiveCamps', src, loadedCamps)
end)

RegisterNetEvent('rs_camp:server:savecampOwner')
AddEventHandler('rs_camp:server:savecampOwner', function(coords, rotation, itemName)
    local src = source
    local User = VORPcore.getUser(src)
    if not User then return end

    local Character = User.getUsedCharacter
    if not Character then return end

    if not Config.Items[itemName] then return end

    local itemModel = Config.Items[itemName].model
    local rotX, rotY, rotZ = rotation.x, rotation.y, rotation.z

    local query = [[
        INSERT INTO rs_camp (owner_identifier, owner_charid, x, y, z, rot_x, rot_y, rot_z, item_name, item_model)
        VALUES (@identifier, @charid, @x, @y, @z, @rot_x, @rot_y, @rot_z, @item_name, @item_model)
    ]]

    local params = {
        ['@identifier'] = Character.identifier,
        ['@charid'] = Character.charIdentifier,
        ['@x'] = coords.x,
        ['@y'] = coords.y,
        ['@z'] = coords.z,
        ['@rot_x'] = rotX,
        ['@rot_y'] = rotY,
        ['@rot_z'] = rotZ,
        ['@item_name'] = itemName,
        ['@item_model'] = itemModel
    }

    exports.oxmysql:execute(query, params, function(result)
        if result and result.insertId then
            local campsData = {
                id = result.insertId,
                x = coords.x,
                y = coords.y,
                z = coords.z,
                rotation = { x = rotX, y = rotY, z = rotZ },
                item = {
                    name = itemName,
                    model = itemModel
                }
            }
            table.insert(loadedCamps, campsData)
            TriggerClientEvent('rs_camp:client:spawnCamps', -1, campsData)
        end
    end)
end)

RegisterNetEvent('rs_camp:server:pickUpByOwner')
AddEventHandler('rs_camp:server:pickUpByOwner', function(uniqueId)
    local src = source
    local User = VORPcore.getUser(src)
    if not User then return end

    local Character = User.getUsedCharacter
    if not Character then return end

    local u_identifier = Character.identifier
    local u_charid = Character.charIdentifier

    exports.oxmysql:execute(
        'SELECT * FROM rs_camp WHERE id = ? AND owner_identifier = ? AND owner_charid = ?',
        {uniqueId, u_identifier, u_charid},
        function(results)
            if results and #results > 0 then
                local row = results[1]

                TriggerClientEvent('rs_camp:client:removeCamp', -1, uniqueId)

                for i, camp in ipairs(loadedCamps) do
                    if camp.id == uniqueId then
                        table.remove(loadedCamps, i)
                        break
                    end
                end

                exports.oxmysql:execute(
                    'DELETE FROM rs_camp WHERE id = ?',
                    {uniqueId},
                    function(result)
                        local affected = result and (result.affectedRows or result.affected_rows or result.changes)
                        if affected and affected > 0 then
                            if row.item_name then
                                VorpInv.addItem(src, row.item_name, 1)
                            end

                            VORPcore.NotifyLeft(src, Config.Text.Camp, Config.Text.Picked, "generic_textures", "tick", 4000, "COLOR_GREEN")
                        end
                    end
                )
            else
                VORPcore.NotifyLeft(src, Config.Text.Camp, Config.Text.Dont, "menu_textures", "cross", 3000, "COLOR_RED")
            end
        end
    )
end)

RegisterNetEvent('rs_camp:server:openChest')
AddEventHandler('rs_camp:server:openChest', function(campId)
    local src = source
    local User = VORPcore.getUser(src)
    if not User then return end
    local Character = User.getUsedCharacter

    exports.oxmysql:execute('SELECT * FROM rs_camp WHERE id = ?', {campId}, function(results)
        if results and #results > 0 then
            local row = results[1]

            local hasAccess = false
            if row.owner_identifier == Character.identifier and row.owner_charid == Character.charIdentifier then
                hasAccess = true
            else
                local sharedWith = json.decode(row.shared_with) or {}
                for _, data in ipairs(sharedWith) do
                    if data and data.charIdentifier == Character.charIdentifier then
                        hasAccess = true
                        break
                    end
                end
            end

            if not hasAccess then
                VORPcore.NotifyLeft(src, Config.Text.Chest, Config.Text.Dontchest, "menu_textures", "cross", 2000, "COLOR_RED")
                return
            end

            local prefix = "camp_storage_" .. campId
            local capacity = 1000
            for _, v in pairs(Config.Chests) do
                if v.object == row.item_model then
                    capacity = v.capacity
                    break
                end
            end

            registerStorage(prefix, Config.Text.StorageName, capacity)
            Inv:openInventory(src, prefix)
        end
    end)
end)

RegisterNetEvent('rs_camp:server:toggleDoor')
AddEventHandler('rs_camp:server:toggleDoor', function(campId)
    local src = source
    local User = VORPcore.getUser(src)
    if not User then return end
    local Character = User.getUsedCharacter
    if not Character then return end

    exports.oxmysql:execute('SELECT * FROM rs_camp WHERE id = ?', {campId}, function(results)
        if results and #results > 0 then
            local row = results[1]

            local hasAccess = false
            if row.owner_identifier == Character.identifier and row.owner_charid == Character.charIdentifier then
                hasAccess = true
            else
                local sharedWith = json.decode(row.shared_with) or {}
                for _, data in ipairs(sharedWith) do
                    if data and data.charIdentifier == Character.charIdentifier then
                        hasAccess = true
                        break
                    end
                end
            end

            if not hasAccess then
                VORPcore.NotifyLeft(src, Config.Text.Door, Config.Text.Dontdoor, "menu_textures", "cross", 2000, "COLOR_RED")
                return
            end

            TriggerClientEvent('rs_camp:client:toggleDoor', -1, campId)
        end
    end)
end)

RegisterCommand(Config.Commands.Shareperms, function(source, args, rawCommand)
    local src = source
    local User = VORPcore.getUser(src)
    if not User then return end
    local Character = User.getUsedCharacter

    local campId = tonumber(args[1])
    local targetPlayerId = tonumber(args[2])
    if not campId or not targetPlayerId then
        return
    end

    exports.oxmysql:execute('SELECT shared_with, owner_identifier, owner_charid FROM rs_camp WHERE id = ?', {campId}, function(results)
        if results and #results > 0 then
            local row = results[1]

            if row.owner_identifier ~= Character.identifier or row.owner_charid ~= Character.charIdentifier then
                VORPcore.NotifyLeft(src, Config.Text.Perms, Config.Text.Dontowner, "menu_textures", "cross", 3000, "COLOR_RED")
                return
            end

            local targetUser = VORPcore.getUser(targetPlayerId)
            if not targetUser then
                VORPcore.NotifyLeft(src, Config.Text.Perms,  Config.Text.Playerno, "menu_textures", "cross", 3000, "COLOR_RED")
                return
            end

            local targetCharId = targetUser.getUsedCharacter.charIdentifier
            local targetIdentifier = targetUser.getUsedCharacter.identifier

            local sharedWith = json.decode(row.shared_with) or {}

            local cleanArray = {}
            local alreadyExists = false
            for _, v in ipairs(sharedWith) do
                if v ~= nil then
                    if v.charIdentifier == targetCharId then
                        alreadyExists = true
                    end
                    table.insert(cleanArray, v)
                end
            end

            if alreadyExists then
                VORPcore.NotifyLeft(src, Config.Text.Perms, Config.Text.Already, "menu_textures", "cross", 3000, "COLOR_RED")
                return
            end

            table.insert(cleanArray, { identifier = targetIdentifier, charIdentifier = targetCharId })

            exports.oxmysql:execute('UPDATE rs_camp SET shared_with = ? WHERE id = ?', {json.encode(cleanArray), campId}, function()
                VORPcore.NotifyLeft(src, Config.Text.Perms, Config.Text.Permsyes, "generic_textures", "tick", 3000, "COLOR_GREEN")
            end)
        else
            VORPcore.NotifyLeft(src, Config.Text.Perms, Config.Text.Permsdont, "menu_textures", "cross", 3000, "COLOR_RED")
        end
    end)
end, false)

RegisterCommand(Config.Commands.Unshareperms, function(source, args, rawCommand)
    local src = source
    local User = VORPcore.getUser(src)
    if not User then return end
    local Character = User.getUsedCharacter

    local campId = tonumber(args[1])
    if not campId then
        return
    end

    exports.oxmysql:execute('SELECT shared_with, owner_identifier, owner_charid FROM rs_camp WHERE id = ?', {campId}, function(results)
        if results and #results > 0 then
            local row = results[1]

            if row.owner_identifier ~= Character.identifier or row.owner_charid ~= Character.charIdentifier then
                VORPcore.NotifyLeft(src, Config.Text.Perms, Config.Text.Dontowner, "menu_textures", "cross", 3000, "COLOR_RED")
                return
            end

            local emptyList = {}

            exports.oxmysql:execute('UPDATE rs_camp SET shared_with = ? WHERE id = ?', {json.encode(emptyList), campId}, function()
                VORPcore.NotifyLeft(src, Config.Text.Perms, Config.Text.Allpermission, "generic_textures", "tick", 3000, "COLOR_GREEN")
            end)
        else
            VORPcore.NotifyLeft(src, Config.Text.Perms, Config.Text.Permsdont, "menu_textures", "cross", 3000, "COLOR_RED")
        end
    end)
end, false)

local MAX_ITEMS_PER_PLAYER = Config.MaxObject

for itemName, itemData in pairs(Config.Items) do
    VorpInv.RegisterUsableItem(itemName, function(data)
        local src = data.source
        local User = VORPcore.getUser(src)
        if not User then return end

        local Character = User.getUsedCharacter
        if not Character then return end

        TriggerClientEvent('rs_camp:client:sendTownToServer', src, itemName)
    end)
end

RegisterNetEvent('rs_camp:server:checkTownAndPlace', function(itemName, town)
    local src = source
    local User = VORPcore.getUser(src)
    if not User then return end

    local Character = User.getUsedCharacter
    if not Character then return end

    local allowed = Config.AllowedTowns[town]
    if allowed == false then
        VorpInv.CloseInv(src)
        VORPcore.NotifySimpleTop(src, Config.Text.Camp, Config.Text.NotInTown, 4000)
        return
    end

    exports.oxmysql:execute(
        'SELECT COUNT(*) as count FROM rs_camp WHERE owner_identifier = @identifier AND owner_charid = @charid',
        {
            ['@identifier'] = Character.identifier,
            ['@charid'] = Character.charIdentifier
        },
        function(result)
            local count = result[1] and result[1].count or 0

            if count >= MAX_ITEMS_PER_PLAYER then
                VorpInv.CloseInv(src)
                VORPcore.NotifySimpleTop(src, Config.Text.Camp, Config.Text.MaxItems, 4000)
                return
            end

            VorpInv.CloseInv(src)
            TriggerClientEvent("rs_camp:client:placePropCamp", src, itemName)
        end
    )
end)

RegisterNetEvent("rs_camp:removeItem", function(itemName)
    local src = source
    if Config.Items[itemName] then
        VorpInv.subItem(src, itemName, 1)
    end
end)
