fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'Camp script '
author 'riversafe'
version '2.0'

ui_page {
	'html/index.html'
}

files {
	'html/index.html',
}

shared_scripts {
    'config.lua'
}

client_scripts {
    "@uiprompt/uiprompt.lua",
    'client.lua',
}

server_scripts {
    'server.lua'
}