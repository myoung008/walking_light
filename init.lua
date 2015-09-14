local players = {}
local player_positions = {}
local last_wielded = {}
local megatorch_map = {}

-- we don't need to modify the mapgen params, just a one-shot startup function to calc the megatorch map
minetest.register_on_mapgen_init (function(params)
	local pos2
	local step = -4
	local unstep = 1/step
	local radius = 10
	
	--do the math for 1/8 of the sphere, then mirror
	for x = 0 - radius, 0, step do
		for y = 0 - radius, 0, step do
			for z = 0 - radius, 0, step do
				dx = math.floor((x*unstep)+.5)*step
				dy = math.floor((y*unstep)+.5)*step
				dz = math.floor((z*unstep)+.5)*step
				distance = math.sqrt(math.pow(x, 2) + math.pow(y, 2) + math.pow(z, 2))
				if distance <= radius and can_add_light( pos2 ) then
					table.insert(megatorch_map, {x= x2, y= y2, z= dz})
					table.insert(megatorch_map, {x= x2, y= y2, z=-dz})
					table.insert(megatorch_map, {x= x2, y=-y2, z= dz})
					table.insert(megatorch_map, {x= x2, y=-y2, z=-dz})
					table.insert(megatorch_map, {x=-x2, y= y2, z= dz})
					table.insert(megatorch_map, {x=-x2, y= y2, z=-dz})
					table.insert(megatorch_map, {x=-x2, y=-y2, z= dz})
					table.insert(megatorch_map, {x=-x2, y=-y2, z=-dz})
				end
			end
		end
	end
end)

minetest.register_on_joinplayer(function(player)
	local player_name = player:get_player_name()
	table.insert(players, player_name)
	local pos = player:getpos()
	pos = {x=math.floor(pos.x + 0.5),y=math.floor(pos.y + 1.5),z=math.floor(pos.z + 0.5)}
	last_wielded[player_name] =  wielding_light(player)
	player_positions[player_name] = pos;
end)

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	for i,v in ipairs(players) do
		if v == player_name then 
			table.remove(players, i)
		end
	end
	if 	last_wielded[player_name] then
		local pos = player:getpos()
		pos = {x=math.floor(pos.x + 0.5),y=math.floor(pos.y + 1.5),z=math.floor(pos.z + 0.5)}
		minetest.env:add_node(pos,{type="node",name="air"})
	end
	last_wielded[player_name] = 0
	player_positions[player_name]=nil
end)

function wielding_light(player)
	local item = player:get_wielded_item():get_name()
	if item == "walking_light:megatorch" then
		return 2
	elseif item == "default:torch" or item == "walking_light:pick_mese" or item == "walking_light:helmet_diamond" then
		return 1
	else
		
		local inv = player:get_inventory()
		local hotbar=inv:get_list("main")
		for index=1,8,1 do
			item = hotbar[index]:get_name()
			if item == "default:torch" or item == "walking_light:pick_mese" or item == "walking_light:helmet_diamond" then
				return 1
			end
		end

		local armor = minetest.get_inventory({type="detached", name = player:get_player_name() .. "_armor"})
		if armor then
			local stack = ItemStack("walking_light:helmet_diamond")
			if armor:contains_item("armor", stack) then
				return 1
			end
		end
		return 0
	end
end

function update_light_all(dtime)
	for i,player_name in ipairs(players) do
		local player = minetest.env:get_player_by_name(player_name)
		local wielding = 0
		local pos
		local old_pos = player_positions[player_name]
		local pos_changed = false
		if player ~= nil then
			wielding = wielding_light(player)
			if wielding > 0 or last_wielded[player_name] then
				pos = player:getpos()
				pos = {x=math.floor(pos.x + 0.5),y=math.floor(pos.y + 1.5),z=math.floor(pos.z + 0.5)}
				player_positions[player_name] = pos
				pos_changed = (old_pos.x ~= pos.x or old_pos.y ~= pos.y or old_pos.z ~= pos.z)
			end
		end
		
		--calc changes first to avoid removing and replacing light in the same pos
		local changes = {}
		if last_wielded[player_name] == 1 and (pos_changed or wielding ~= 1) then
			changes[old_pos] = 0
		elseif last_wielded[player_name] == 2 and (pos_changed or wielding ~= 2) then
			for i in ipairs(megatorch_map) do
				local pos2={x=pos.x+i.x, y=pos.y+i.y, z=pos.z+i.z}
				changes[pos2] = 0
			end
		end
		
		if wielding == 1 then
			changes[pos] = 1
		elseif wielding == 2 then
			for i in ipairs(megatorch_map) do
				local pos2={x=pos.x+i.x, y=pos.y+i.y, z=pos.z+i.z}
				changes[pos2] = 1
			end
		end
		
		-- Now we make the changes.  If lua sorts tables by their index this will cause flicker, if by chronological time there's no problem.
		for i,v in ipairs(changes) do
			local node = minetest.env:get_node_or_nil(i)
			if v == 1 and node.name == "air" then
				minetest.env:add_node(old_pos,{type="node",name="walking_light:light"})
			elseif v == 0 and node.name == "walking_light:light" then
				minetest.env:add_node(old_pos,{type="node",name="air"})
			end
			last_wielded[player_name] = wielding
		end
	end
end


minetest.register_globalstep(update_light_all)

minetest.register_node("walking_light:light", {
	drawtype = "glasslike",
	tile_images = {"walking_light.png"},
	-- tile_images = {"walking_light_debug.png"},
	inventory_image = minetest.inventorycube("walking_light.png"),
	paramtype = "light",
	walkable = false,
	is_ground_content = true,
	light_propagates = true,
	sunlight_propagates = true,
	light_source = 13,
	selection_box = {
		type = "fixed",
		fixed = {0, 0, 0, 0, 0, 0},
	},
})
minetest.register_tool("walking_light:pick_mese", {
	description = "Mese Pickaxe with light",
	inventory_image = "walking_light_mesepick.png",
	wield_image = "default_tool_mesepick.png",
	tool_capabilities = {
		full_punch_interval = 1.0,
		max_drop_level=3,
		groupcaps={
			cracky={times={[1]=2.0, [2]=1.0, [3]=0.5}, uses=20, maxlevel=3},
			crumbly={times={[1]=2.0, [2]=1.0, [3]=0.5}, uses=20, maxlevel=3},
			snappy={times={[1]=2.0, [2]=1.0, [3]=0.5}, uses=20, maxlevel=3}
		}
	},
})

minetest.register_tool("walking_light:helmet_diamond", {
	description = "Diamond Helmet with light",
	inventory_image = "walking_light_inv_helmet_diamond.png",
	wield_image = "3d_armor_inv_helmet_diamond.png",
	groups = {armor_head=15, armor_heal=12, armor_use=100},
	wear = 0,
})

minetest.register_node("walking_light:megatorch", {
    description = "Megatorch",
    drawtype = "torchlike",
    tiles = {
        {
            name = "default_torch_on_floor_animated.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 3.0
            },
        },
        {
            name="default_torch_on_ceiling_animated.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 3.0
            },
        },
        {
            name="default_torch_animated.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 3.0
            },
        },
    },
    inventory_image = "default_torch_on_floor.png",
    wield_image = "default_torch_on_floor.png",
    paramtype = "light",
    paramtype2 = "wallmounted",
    sunlight_propagates = true,
    is_ground_content = false,
    walkable = false,
    light_source = 13,
    selection_box = {
        type = "wallmounted",
        wall_top = {-0.1, 0.5-0.6, -0.1, 0.1, 0.5, 0.1},
        wall_bottom = {-0.1, -0.5, -0.1, 0.1, -0.5+0.6, 0.1},
        wall_side = {-0.5, -0.3, -0.1, -0.5+0.3, 0.3, 0.1},
    },
    groups = {choppy=2,dig_immediate=3,flammable=1,attached_node=1},
    legacy_wallmounted = true,
    --sounds = default.node_sound_defaults(),
})

minetest.register_craft({
	output = 'walking_light:pick_mese',
	recipe = {
		{'default:torch'},
		{'default:pick_mese'},
	}
})

minetest.register_craft({
	output = 'walking_light:helmet_diamond',
	recipe = {
		{'default:torch'},
		{'3d_armor:helmet_diamond'},
	}
})

minetest.register_craft({
	output = 'walking_light:megatorch',
	recipe = {
		{'default:torch', 'default:torch', 'default:torch'},
		{'default:torch', 'default:torch', 'default:torch'},
		{'default:torch', 'default:torch', 'default:torch'},
	}
})

minetest.register_craft({
	output = 'default:torch 9',
	recipe = {
		{'walking_light:megatorch'},
	}
})

