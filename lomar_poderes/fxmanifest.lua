fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lumina_poderes'
description 'Sistema Exclusivo de Poderes Sobrenaturais e Magias'
author 'LOMAR DEV'
version '2.0.0'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/sounds/*.ogg',
    'ui/sounds/*.mp3',
}

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}
