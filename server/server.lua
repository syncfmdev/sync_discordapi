local Config <const> = require('config_shared')
local Players = {}

local function trim(str)
    ---@param str string|nil 
    return str and str:gsub("^%s*(.-)%s*$", "%1") or str
end

local Discord <const> = {
    BASE_URL = 'https://discordapp.com/api',
    HEADERS = {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = ('Bot %s'):format(Config.botToken)
    }
}

---@param endpoint string 
---@return table|nil
function Discord.fetch(endpoint)
    local p <const> = promise.new()
    local url <const> = ('%s/%s'):format(Discord.BASE_URL, endpoint:gsub('^/+', ''))

    PerformHttpRequest(url, function(status, response)
        if status ~= 200 or not response then
            p:resolve(nil)
            return
        end
        p:resolve(json.decode(response))
    end, 'GET', '', Discord.HEADERS)

    return p
end

---@param guildId string 
---@param userId string 
---@return table|nil
function Discord.getGuildMember(guildId, userId)
    local endpoint <const> = ('guilds/%s/members/%s'):format(guildId, userId)
    return Discord.fetch(endpoint)
end

---@param guildId string 
---@return table|nil 
function Discord.getGuildInfo(guildId)
    local endpoint <const> = ('guilds/%s'):format(guildId)
    return Discord.fetch(endpoint)
end

---@param playerId number 
---@return table|nil 
function Players.getIdentifiers(playerId)
    if not playerId or not GetPlayerName(playerId) then
        return nil
    end

    local identifiers = {}
    for _, id in ipairs(GetPlayerIdentifiers(playerId)) do
        local prefix, value = id:match("([^:]+):(.+)")
        if prefix then
            identifiers[prefix] = value
        end
    end

    return identifiers
end

---@param playerId number
---@param options table|nil
---@return table|nil
function Players.getDiscordData(playerId, options)
    options = options or { rolesOnly = false }
    local identifiers <const> = Players.getIdentifiers(playerId)

    if not identifiers or not identifiers.discord then
        return nil
    end

    local memberData <const> = Citizen.Await(Discord.getGuildMember(Config.guildId, identifiers.discord))
    if not memberData then
        return nil
    end

    local roles = {}
    for _, role in ipairs(memberData.roles or {}) do
        table.insert(roles, tonumber(role))
    end

    if options.rolesOnly then
        return roles
    end

    local user <const> = memberData.user

    return {
        username = user and ('%s#%s'):format(user.username, user.discriminator),
        avatar = user and user.avatar and ('https://cdn.discordapp.com/avatars/%s/%s.%s'):format(
            identifiers.discord,
            user.avatar,
            user.avatar:sub(1, 1) == '_' and 'gif' or 'png'
        ),
        roles = roles
    }
end

---@param playerId number 
---@param role number|table 
---@return boolean, number|nil 
function Players.hasRole(playerId, role)
    local roles <const> = Players.getCachedData(playerId, 'roles')
    if not roles then return false end

    if type(role) == 'table' then
        for _, r in ipairs(role) do
            if table.contains(roles, r) then
                return true, r
            end
        end
        return false
    end

    return table.contains(roles, role)
end

---@param playerId number
---@param key string|nil
---@return any
function Players.getCachedData(playerId, key)
    if not Players.cache[playerId] then return nil end
    return key and Players.cache[playerId][key] or Players.cache[playerId]
end

Players.cache = {}

RegisterNetEvent('sync_discord:playerConnected', function()
    local playerId <const> = source

    local discordData <const> = Players.getDiscordData(playerId)
    if not discordData then
        print(('[^3sync_discordapi^0] Player ^5%s^0 (ID: ^5%s^0) is not in Discord server')
            :format(GetPlayerName(playerId), playerId))
        return
    end

    Players.cache[playerId] = discordData

    if Config.logConnections then
        if #discordData.roles > 0 then
            print(('[^3sync_discordapi^0] Player ^5%s^0 (ID: ^5%s^0) has roles with IDs: ^2%s^0')
                :format(GetPlayerName(playerId), playerId, table.concat(discordData.roles, ', ')))
        else
            print(('[^3sync_discordapi^0] Player ^5%s^0 (ID: ^5%s^0) has no roles')
                :format(GetPlayerName(playerId), playerId))
        end
    end
end)

AddEventHandler('playerDropped', function()
    local playerId <const> = source
    Players.cache[playerId] = nil
end)

CreateThread(function()
    if not Config.botToken or trim(Config.botToken) == '' then
        return error('Invalid Discord bot token in configuration')
    end

    if not Config.guildId or trim(Config.guildId) == '' then
        return error('Invalid Discord guild ID in configuration')
    end

    local guildInfo <const> = Citizen.Await(Discord.getGuildInfo(Config.guildId))
    if not guildInfo or not guildInfo.name then
        return error('Failed to authenticate with Discord. Please verify your configuration')
    end

    local guildName = guildInfo.name
    guildName = guildName:gsub('[%c%z]', '')
    guildName = trim(guildName)

    print(('[^3SYNC_DISCORD^0] Successfully connected to Discord server: ^5"%s"^0')
        :format(guildName))
end)

exports('getPlayerRoles', function(playerId)
    ---@param playerId number
    return Players.getCachedData(playerId, 'roles')
end)

exports('doesPlayerHaveRole', function(playerId, role)
    ---@param playerId number
    ---@param role number|table
    return Players.hasRole(playerId, role)
end)

exports('getPlayerUsername', function(playerId)
    ---@param playerId number
    return Players.getCachedData(playerId, 'username')
end)

exports('getPlayerAvatar', function(playerId)
    ---@param playerId number
    return Players.getCachedData(playerId, 'avatar')
end)

exports('getPlayerData', function(playerId)
    ---@param playerId number
    return Players.getCachedData(playerId)
end)