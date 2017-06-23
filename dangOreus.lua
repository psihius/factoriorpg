if MODULE_LIST then
	module_list_add("dangOreus")
end


--Sprinkle ore everywhere
function gOre(event)
    local oldores = event.surface.find_entities_filtered{type="resource", area=event.area}
    for k, v in pairs(oldores) do
        if v.prototype.resource_category == "basic-solid" then
            v.destroy()
        end
    end
    for x = event.area.left_top.x, event.area.left_top.x + 32 do
        for y = event.area.left_top.y, event.area.left_top.y + 32 do
            if event.surface.get_tile(x,y).collides_with("ground-tile") then
                local amount = (x^2 + y^2)^0.6
                --Radius of 50 tiles is clear
                --Radius of 200 tiles has no uranium
                if x^2 + y^2 >= 200^2 then
                    local type = global.diverse_ores[math.random(#global.diverse_ores)]
                    --With noise
                    event.surface.create_entity{name=type, amount=amount, position={x+0.45+0.1*math.random(), y+0.45+0.1*math.random()}}
                    --Without noise
                    -- event.surface.create_entity{name=type, amount=amount, position={x+0.5, y+0.5}}
                elseif x^2 + y^2 >= 50^2 then
                    local type = global.easy_ores[math.random(#global.easy_ores)]
                    --With noise
                    event.surface.create_entity{name=type, amount=amount, position={x+0.45+0.1*math.random(), y+0.45+0.1*math.random()}}
                    --Without noise
                    -- event.surface.create_entity{name=type, amount=amount, position={x+0.5, y+0.5}}
                end
            end
        end
    end
end

--Auto-destroy non-mining drills.
function dangOre(event)
    if event.created_entity.type == "mining-drill" or not event.created_entity.destructible then
        return
    end
    local last_user = event.created_entity.last_user
    local ores = event.created_entity.surface.count_entities_filtered{type="resource", area=event.created_entity.bounding_box}
    if ores > 0 then
        event.created_entity.die()
        if last_user then
            last_user.print("Cannot build non-miners on resources!")
        end
    end
end

function divOresity_init()
	global.diverse_ores = {}
    global.easy_ores = {}
	for k,v in pairs(game.entity_prototypes) do
		if v.type == "resource" and v.resource_category == "basic-solid" then
            table.insert(global.diverse_ores, v.name)
            if v.mineable_properties.required_fluid == nil then
			    table.insert(global.easy_ores, v.name)
            end
		end
	end
end

Event.register(defines.events.on_built_entity, dangOre)
Event.register(defines.events.on_robot_built_entity, dangOre)
Event.register(defines.events.on_chunk_generated, gOre)
Event.register(-1, divOresity_init)