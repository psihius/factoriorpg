--Nougat Mining, logistic mining designed for scenario use
--Written by Mylon, 2017
--MIT License

if MODULE_LIST then
	module_list_add("Nougat Mining")
end

nougat = {}
nougat.LOGISTIC_RADIUS = true --Use the logistic radius, else use construction radius.
nougat.TARGET_RATIO = 0.10 --Aim to keep this proportion of construction bots free.
nougat.DEFAULT_RATIO = 0.5 --The ratio of choclate to chew.  Err, I mean how many bots we assign to mining.  Starts here, changes later based on bot availability.
nougat.MAX_ITEMS = 400 --Spawning more than this gets really laggy.
nougat.USE_CARGO_COUNT = false --Turning this on is ridiculously OP.
global.nougat = {roboports = {}, index=1, easy_ores={}, networks={}, optout={}} --Networks is of format {network=network, ratio=ratio}

function nougat.bake()
    for k,v in pairs(game.entity_prototypes) do
        if v.type == "resource" and v.resource_category == "basic-solid" then
            if v.mineable_properties.required_fluid == nil and not v.infinite_resource then
                table.insert(global.nougat.easy_ores, v.name)
            end
        end
    end
    if game.entity_prototypes["electric-mining-drill"] then
        local proto  = game.entity_prototypes["electric-mining-drill"]
        --How much pollution to create per stack of products.
        --This assumes a mining hardness of 0.9
        global.nougat.pollution = (proto.electric_energy_source_prototype.emissions * proto.energy_usage * 60) / proto.mining_power / proto.mining_speed * 0.9
    else
        --Fallback if "electric-mining-drill" doesn't exist.
        global.nougat.pollution = 9 * 0.9
    end
end

function nougat.register(event)
    --game.print("Built something!")
    if (event.created_entity and event.created_entity.valid and event.created_entity.type == "roboport") then
        --Check opt-out status
        if event.created_entity.last_user then
            if global.nougat.optout[event.created_entity.last_user.index] then
                return
            end
        end
        --game.print("Built a roboport.")
        if event.created_entity.logistic_cell and event.created_entity.logistic_cell.valid then
            local roboport = event.created_entity
            local radius = nougat.how_many_licks(roboport)
            if not radius then --Some mods use weird roboports.
                return
            end
            --game.print("Roboport is on.")
            --We'll check for solid-resource entities later.
            --game.print("Roboport Radius: "  .. roboport.logistic_cell.construction_radius)
            local count = event.created_entity.surface.count_entities_filtered{type="resource", area={{roboport.position.x - radius, roboport.position.y - radius}, {roboport.position.x + radius-1, roboport.position.y + radius-1}}}
            --game.print("Found number of ores: " .. count)

            if count > 0 then
                local network_registered = false
                for k,v in pairs(global.nougat.networks) do
                    if v.network == event.created_entity.logistic_cell.logistic_network then
                        network_registered = true
                    end
                end
                if not network_registered then
                    table.insert(global.nougat.networks, {network=event.created_entity.logistic_cell.logistic_network, ratio=nougat.DEFAULT_RATIO})
                end
                table.insert(global.nougat.roboports, event.created_entity)
                --game.print("Adding mining roboport")
            end
        end
    end
end

function nougat.chewy(event, assigned)
    if (#global.nougat.roboports == 0) then
        return
    end
    local index = global.nougat.index
    if index > #global.nougat.roboports then
        global.nougat.index = 1
        index = global.nougat.index
    end
    local roboport = global.nougat.roboports[index]
    if not (roboport and roboport.valid) then
        --game.print("Removing roboport.  Roboport.valid: " .. string(roboport.valid) )
        table.remove(global.nougat.roboports, index)
        return
    end
    if not (roboport.logistic_cell and roboport.logistic_cell.valid and roboport.logistic_cell.logistic_network) then --Not powered.
        global.nougat.index = global.nougat.index + 1
        return
    end
    if not (roboport.prototype.electric_energy_source_prototype.buffer_capacity == roboport.energy) then --Low power
        global.nougat.index = global.nougat.index + 1
        return
    end
    local radius = nougat.how_many_licks(roboport)
    --In case an update changes a roboport...
    if not radius or radius == 0 then
        table.remove(global.nougat.roboports, index)
        return
    end
    local area = {{roboport.position.x - radius, roboport.position.y - radius}, {roboport.position.x + radius-1, roboport.position.y + radius-1}}
    local ores = roboport.surface.find_entities_filtered{type="resource", limit=5, area=area}
    --Filter out oil...
    if #ores > 0 then
        for i = #ores, 1, -1 do
            if ores[i].prototype.resource_category == "basic-fluid" or ores[i].prototype.mineable_properties.required_fluid or ores[i].prototype.infinite_resource or ores[i].prototype.mineable_properties.hardness > 100 then
                table.remove(ores, i)
            end
        end
    end
    --Now check again.
    if #ores == 0 then
        --Try harder.
        for k,v in pairs(global.nougat.easy_ores) do
            ores = roboport.surface.find_entities_filtered{name=v, limit=1, area=area}
            if #ores > 0 then
                break
            end
        end
        if #ores == 0 then
            --If we're still here, there must be nothing left to mine.
            table.remove(global.nougat.roboports, index)
            return
        end
        --game.print("Removing roboport.  No ore found.")
    end
    if not assigned then assigned = 0 end
    local count = nougat.oompa_loompa(roboport.logistic_cell.logistic_network) - assigned
    if count < 30 then
        --We shouldn't bother. Need to advance index in case this is an isolated roboport.
        global.nougat.index = global.nougat.index + 1
        return
    end
	
	local force = roboport.force
	
	--Modify force construction limit since this mod can easily spam more than enough requests!
    --This is on a per tick basis, and we check every 60 ticks.
    if force.max_successful_attemps_per_tick_per_construction_queue * 60 < count then
        force.max_successful_attemps_per_tick_per_construction_queue = math.floor(count / 60)
    end

	
    --Finally, let's do some mining.
    --game.print("Time to mine.")
    local ore = ores[math.random(1,#ores)]
    local position = ore.position --Just in case we kill the ore.
    local surface = roboport.surface
    local productivity = force.mining_drill_productivity_bonus + 1
    local cargo_multiplier = 1
    if nougat.USE_CARGO_COUNT then
        cargo_multiplier = force.worker_robots_storage_bonus + 1
    end
    local products = {}
    
    count = math.min(math.ceil(ore.amount / cargo_multiplier), nougat.MAX_ITEMS, count)
	
    for k,v in pairs(ore.prototype.mineable_properties.products) do
		local product
        if v.type == "item" then --If fluid, not sure what to do here.    
            if v.amount then
                product = {name=v.name, count=v.amount}
            elseif v.probability then
                if math.random() < v.probability then
                    if v.amount_min ~= v.amount_max then
                        product = {name=v.name, count=math.random(v.amount_min, v.amount_max)}
                    else
                        product = {name=v.name, count=v.amount_max}
                    end
                end
            else --Shouldn't have to use this.
                product = {name=v.name, count=1}
            end
        end
		if product then
			product.count = product.count * cargo_multiplier

			table.insert(products, {name=product.name, count=product.count})
        end 
    end
	
    for i = 1, count do
        for k, v in pairs(products) do
            local oreitem = surface.create_entity{name="item-on-ground", stack=v, position=position}
            if oreitem and oreitem.valid then --Why is oreitem sometimes nil or invalid?
                oreitem.order_deconstruction(force)
                --game.print(oreitem.stack.name .. " #"..i.." created for pickup. ")
            end
        end
    end
    --Also add pollution.  Mining productivity is omitted.
    surface.pollute(position, global.nougat.pollution * count * cargo_multiplier)
    
    --Add to productivity stats.
    for k,v in pairs(products) do
        force.item_production_statistics.on_flow(v.name, v.count * count * cargo_multiplier)
    end
    
    --game.print("Created " .. #products .. " for pickup.")

    --Deplete the ore.
    --Note, a few extra ore may be produced per entity. (amount / cargo_multiplier) is rounded up.
    if ore.amount > math.ceil(count * cargo_multiplier / productivity) then
        ore.amount = ore.amount - math.ceil(count * cargo_multiplier / productivity)
    else
        script.raise_event(defines.events.on_resource_depleted, {entity=ore, name=defines.events.on_resource_depleted})
        if ore and ore.valid then
            ore.destroy()
        end
        --Let's go again.
        global.nougat.index = global.nougat.index + 1
        return nougat.chewy(event, count+assigned)
    end

    --Finally let's advance the index.
    global.nougat.index = global.nougat.index + 1
end

--Determine roboport radius.
function nougat.how_many_licks(entity)
    local radius
    if entity and entity.valid and entity.logistic_cell then
        if nougat.LOGISTIC_RADIUS then
            radius = entity.logistic_cell.logistic_radius
        else
            radius = entity.logistic_cell.construction_radius
        end
    end
    if radius and radius > 0 then
        return radius
    else --Invalid entity/roboport
        return nil
    end
end

--Figure out how many bots we're assigning and update the ratio along the way.
function nougat.oompa_loompa(network)
    --Fetch the table associated with this network.
    local data
    for i = #global.nougat.networks, 1, -1 do
        if not (global.nougat.networks[i].network and global.nougat.networks[i].network.valid) then
            table.remove(global.nougat.networks, i)
        elseif global.nougat.networks[i].network == network then
            data = global.nougat.networks[i]
            break
        end
    end
    if not data then --Register network.
        data = {network=network, ratio=nougat.DEFAULT_RATIO}
        table.insert(global.nougat.networks, data)
    end
    if network.available_construction_robots / network.all_construction_robots > nougat.TARGET_RATIO then
        data.ratio = math.min(data.ratio + 0.01, 2)
    else
        data.ratio = math.max(data.ratio - 0.01, 0.01)
    end
    return math.floor(network.available_construction_robots * data.ratio)
end

commands.add_command("nougat", "Toggle nougat mining", function()
    if global.nougat.optout[game.player.index] then
        global.nougat.optout[game.player.index] = nil
        game.player.print("Nougat Mining turned on.")
    else
        global.nougat.optout[game.player.index] = true
        game.player.print("Nougat Mining turned off.")
        for i = #global.nougat.roboports, 1, -1 do
            local v = global.nougat.roboports[i]
            if v and v.valid and v.last_user == game.player then
                table.remove(global.nougat.roboports, i)
            end
        end
    end
end)

-- script.on_nth_tick(60, nougat.chewy)
-- script.on_init(function(event) nougat.bake() end)
-- script.on_event(defines.events.on_robot_built_entity, function(event) nougat.register(event) end)
-- script.on_event(defines.events.on_built_entity, function(event) nougat.register(event) end)
-- script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
-- 	if event.setting == "use construction range" then
-- 		global.nougat = {roboports = {}, index=1, easy_ores={}, networks={}, optout={}}
-- 		global.nougat.pollution = 9 * 0.9
-- 		for _, surface in pairs(game.surfaces) do
-- 			for __, roboport in pairs(surface.find_entities_filtered{type="roboport"}) do
-- 				nougat.register({created_entity=roboport})
-- 			end
-- 		end
-- 	end
-- end)


Event.register('on_init', nougat.bake)
Event.register(-60, nougat.chewy)
Event.register(defines.events.on_robot_built_entity, nougat.register)
Event.register(defines.events.on_built_entity, nougat.register)