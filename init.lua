local players = {}
local player_positions = {}
local last_wielded = {}

minetest.register_on_joinplayer(function(player)
	local player_name = player:get_player_name()
	table.insert(players, player_name)
	local pos = player:getpos()
	pos = {x=math.floor(pos.x + 0.5),y=math.floor(pos.y + 1.5),z=math.floor(pos.z + 0.5)}
	local wielded_item = player:get_wielded_item():get_name()
	last_wielded[player_name] =  wielded_item ~= "default:torch" and wielded_item ~= "walking_light:pick_mese"
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
	last_wielded[player_name] = false
	player_positions[player_name]=nil
end)

minetest.register_globalstep(function(dtime)
	for i,player_name in ipairs(players) do
		local player = minetest.env:get_player_by_name(player_name)
		local wielded = false
		local pos
		local old_pos = player_positions[player_name]
		local pos_changed = false
		if player ~= nil then
			local wielded_item = player:get_wielded_item():get_name()
			wielded = wielded_item == "default:torch" or wielded_item == "walking_light:pick_mese"
			if wielded or last_wielded[player_name] then
				pos = player:getpos()
				pos = {x=math.floor(pos.x + 0.5),y=math.floor(pos.y + 1.5),z=math.floor(pos.z + 0.5)}
				player_positions[player_name] = pos
				pos_changed = (old_pos.x ~= pos.x or old_pos.y ~= pos.y or old_pos.z ~= pos.z)
			end
		end
		
		if wielded then
			local node = minetest.env:get_node_or_nil(pos)
			if (node == nil or (node ~= nil and node.name == "air")) then
				minetest.env:add_node(pos,{type="node",name="walking_light:light"})
			end
		end
		
		if last_wielded[player_name] and (pos_changed or not wielded) then
			local node = minetest.env:get_node_or_nil(old_pos)
			if node ~= nil and node.name == "walking_light:light" then
				minetest.env:add_node(old_pos,{type="node",name="air"})
			end
		end
		
		last_wielded[player_name] = wielded
	end
end)

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

minetest.register_craft({
	output = 'walking_light:pick_mese',
	recipe = {
		{'default:torch'},
		{'default:pick_mese'},
	}
})
