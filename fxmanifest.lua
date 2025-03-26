fx_version 'cerulean'

games { 'gta5' }

author "syncfm"
version '1.0.0'

lua54 'yes'

client_script  {
  "client/**/*.lua"
}

server_script  {
  "server/**/*.lua"
}

files {
  'config_shared.lua',
}
