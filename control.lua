--require "locale/utils/event" --Yes this line is seriously commented out, and yes without this it won't even work. I guess you now HAVE TO change the settings to match what you need.
--require "config" --config which is mainly used by the announcements
--require "locale/utils/admin"	--Admin module to give the admins spectate, commands and character modifications.
--require "locale/utils/undecorator"	--Removes decorations
--require "locale/utils/utils"	--Old 3ra stuff... Dunno know
--require "locale/utils/gravestone"	--Module to generate a chest on player death with his/hers items
--require "announcements"	--Module to announce stuff ingame / give the players a welcome message
--require "bps"	--BluePrintString a module in which the player can enter a string and a blueprint get generated out of it.
--require "tag" --Module to let players set a tag behind their names to improve teamwork
--require "locale/utils/patreon" --Module to give patreons spectate and a nice unique tag
--require "rocket" --Module to stop people removing the rocket silo
--require "grid" --Worldgenerator which devides the world into a grid.
--require "void" --Worldgenerator which randomly generates holes in the world
--require "stats" --Module to generate stats and print them to the filesystem


-- Give player starting items.
-- @param event on_player_joined event
function player_joined(event)
	local player = game.players[event.player_index]
	player.insert { name = "iron-plate", count = 8 }
	player.insert { name = "pistol", count = 1 }
	player.insert { name = "firearm-magazine", count = 20 }
	player.insert { name = "burner-mining-drill", count = 2 }
	player.insert { name = "stone-furnace", count = 2 }
end

-- Give player weapons after they respawn.
-- @param event on_player_respawned event
function player_respawned(event)
	local player = game.players[event.player_index]
	player.insert { name = "pistol", count = 1 }
	player.insert { name = "firearm-magazine", count = 10 }
end


Event.register(defines.events.on_player_created, player_joined)
Event.register(defines.events.on_player_respawned, player_respawned)