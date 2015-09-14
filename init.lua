local players = {}
local lightmap = {}
lightmap[1] = {}
table.insert(lightmap[1], {x=0, y=0, z=0})
lightmap[2] = {}

--calculate megatorch map once at startup
local step = 4
local radius = 10

local unstep = 1/step
local radiussq = math.pow(radius, 10)
for x = -radius, radius, step do
	for y = -radius, radius, step do
		for z = -radius, radius, step do
			if math.pow(x, 2) + math.pow(y, 2) + math.pow(z, 2) <= radiussq then
				table.insert(lightmap[2], {x=x, y=y, z=z})
			end
		end
	end
end

minetest.register_on_joinplayer(function(mt_player)
	local name = mt_player:get_player_name()
	players[name] = {name=name,pos={x=0,y=32000,z=0},wielding=0,mt_player=mt_player}
end)

minetest.register_on_leaveplayer(function(mt_player)
	local name = mt_player:get_player_name()
	local pinfo=players[name]
	if pinfo.wielding > 0 then
		pinfo.wielding = 0
		pinfo.light_changed = true
		update_light_player(pinfo)
	end
	players[name] = nil
end)

--wielding_light returns 0 for no light; 1 for regular light; 2 for megatorch.  Outside of this function we don't care what's being wielded, carried or worn, just what needs to be done.
function wielding_light(pinfo)
	local item = pinfo.mt_player:get_wielded_item():get_name()
	if item == "walking_light:megatorch" then
		return 2
	elseif item == "default:torch" or item == "walking_light:pick_mese" or item == "walking_light:helmet_diamond" then
		return 1
	else
		
		local inv = pinfo.mt_player:get_inventory()
		local hotbar=inv:get_list("main")
		for index=1,8,1 do
			item = hotbar[index]:get_name()
			if item == "default:torch" or item == "walking_light:pick_mese" or item == "walking_light:helmet_diamond" then
				return 1
			end
		end

		local armor = minetest.get_inventory({type="detached", name = pinfo.name .. "_armor"})
		if armor then
			local stack = ItemStack("walking_light:helmet_diamond")
			if armor:contains_item("armor", stack) then
				return 1
			end
		end
		return 0
	end
end

function update_light_player(pinfo)
	local removes = {}
	local adds = {}
	if pinfo.wielded > 0 then
		for i,v in ipairs(lightmap[pinfo.wielded]) do
			local pos={
				x = pinfo.old_pos.x + v.x,
				y = pinfo.old_pos.y + v.y,
				z = pinfo.old_pos.z + v.z}
			local hash = (pos.x%64)*4096 + (pos.y%64)*64 + pos.z%64
			removes[hash] = pos;
		end
	end
	
	if pinfo.wielding > 0 then
		for i,v in ipairs(lightmap[pinfo.wielding]) do
			local pos={
				x= pinfo.pos.x + v.x,
				y= pinfo.pos.y + v.y,
				z= pinfo.pos.z + v.z}
			local hash = (pos.x%64)*4096 + (pos.y%64)*64 + pos.z%64
			removes[hash] = nil
			adds[hash] = pos
		end
	end
	
	for h,p in pairs(adds) do
		local node = minetest.env:get_node_or_nil(p)
		if node == nil or (node ~= nil and node.name == "air") then
			minetest.env:add_node(p, {type="node",name="walking_light:light"})
		end
	end

	for h,p in pairs(removes) do
		local node = minetest.env:get_node_or_nil(p)
		if node ~= nil and node.name == "walking_light:light" then
			minetest.env:add_node(p, {type="node",name="air"})
		end
	end
end

function update_light_all(dtime)
	for name,pinfo in pairs(players) do
		local pos = pinfo.mt_player:getpos()
		pinfo.wielded = pinfo.wielding
		pinfo.wielding = wielding_light(pinfo)
		pinfo.old_pos = pinfo.pos
		pinfo.pos = {
			x=math.floor(pos.x + 0.5),
			y=math.floor(pos.y + 1.5),
			z=math.floor(pos.z + 0.5)
		}
		--if we're wielding a megatorch it doesn't really matter where we're actually at, just the closest grid point
		if pinfo.wielding == 2 then
			pinfo.pos = {
				x=math.floor(pinfo.pos.x*unstep+.5)*step,
				y=math.floor(pinfo.pos.y*unstep+.5)*step,
				z=math.floor(pinfo.pos.z*unstep+.5)*step
			}
		end
		pinfo.pos_changed=(
			pinfo.old_pos.x ~= pinfo.pos.x or
			pinfo.old_pos.y ~= pinfo.pos.y or
			pinfo.old_pos.z ~= pinfo.pos.z)
		pinfo.light_changed=pinfo.pos_changed or (pinfo.wielded ~= pinfo.wielding)
		players[pinfo.name] = pinfo

		if pinfo.light_changed then
			update_light_player(pinfo)
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

