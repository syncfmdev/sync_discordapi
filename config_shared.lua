local config_shared = {}

config_shared.botToken = GetConvar('discord_botToken', '')
config_shared.guildId = GetConvar('discord_guildId', '')
config_shared.logConnections = true

return config_shared