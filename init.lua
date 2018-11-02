local function load_data()
	ms = priv_roles.storage
	local data = {}
	data.players = minetest.deserialize(ms:get_string("players")) or {} -- Table of what players have what roles
	data.roles = minetest.deserialize(ms:get_string("roles")) or {} -- Table of roles and associated privs
	return data
end

local function save_data()
	local p = minetest.serialize(priv_roles.data.players)
	priv_roles.storage:set_string("players", p)
end

local function save_roles()
	local r = minetest.serialize(priv_roles.data.roles)
	priv_roles.storage:set_string("roles", r)
end

-- This really ought to be standard
function table.shallow_copy(t)
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end

-- Global mod list
priv_roles = {}
local p = minetest.get_modpath(minetest.get_current_modname())

-- Get old set_privs function
priv_roles.set_player_privs = minetest.set_player_privs

-- Call this to make sure that a player's role will exist
priv_roles.check_for_player = function(name)
	if priv_roles.data.players[name] == nil then
		priv_roles.data.players[name] = table.shallow_copy(priv_roles.default_roles)
      priv_roles.data.players[name]["_extra"] = {}
	end
   -- Make sure _extra is defined
   if priv_roles.data.players[name]["_extra"] == nil then
      priv_roles.data.players[name]["_extra"] = {}
   end
end

priv_roles.calc_privs = function(player, only_role_based)
	priv_roles.check_for_player(player)
	local roles = priv_roles.data.players[player]
	if roles then
		local privs = {}
		for r, _ in pairs(roles) do
         -- It could be the _extra role; if so ignore it
         if r == "_extra" then
         -- It could be a role that was removed; if so remove it
         elseif priv_roles.data.roles[r] == nil then
            priv_roles.data.players[player][r] = nil
         else
			   local r_privs = table.shallow_copy(priv_roles.data.roles[r])
			   -- If "_all" is in r_privs, expand it to be all privs excepts ones mentioned in the role
			   if r_privs["_all"] then
			      for p, _ in pairs(minetest.registered_privileges) do
			         if r_privs[p] == nil then
			            r_privs[p] = true
			         end
               end
	           r_privs["_all"] = nil
            end
			   -- If "_nothing" is in r_privs, give no privs
			   if r_privs["_nothing"] then return {} end
			   -- Calculate the privs table
			   for p, v in pairs(r_privs) do
               if privs[v] ~= false then -- If the priv is removed by a role, other roles can't re-add it
                  privs[p] = v
               end
            end
         end
		end
      if only_role_based ~= true then
         -- Apply all the privs in the _extra role
         for priv, value in pairs(roles["_extra"]) do
            privs[priv] = value
         end
      end
		-- Get rid of all the privs with a value of false
		local privs_table = {}
		for p, v in pairs(privs) do
			if v then
				privs_table[p] = v
			end
		end
				return privs_table
	else
		return {}
	end
end

-- Redefine minetest.set_player_privs

function minetest.set_player_privs(player, full_privs)
   -- Make sure player is valid
   if (player == nil) or (not minetest.player_exists(player)) then
      return false
   end
   -- Make sure privs table is valid
   if full_privs == nil or type(full_privs) ~= "table" then
      return false
   end
   -- Make sure the player has a roles table
   priv_roles.check_for_player(player)
   -- Get all the role-based privs
   local privs = priv_roles.calc_privs(player, true)
   local extra_privs = {}
   -- Figure out what extra priv need to be granted
   for p, _ in pairs(full_privs) do
      if privs[p] == nil then
         extra_privs[p] = true
      end
   end
   -- Figure out what extra privs need to be removed
   for p, _ in pairs(privs) do
      if full_privs[p] == nil then
         extra_privs[p] = false
      end
   end
   -- Update _extra
   priv_roles.data.players[player]["_extra"] = extra_privs
   -- Calculate
   local privs_final = priv_roles.calc_privs(player)
   -- Set privs
   priv_roles.set_player_privs(player, privs_final)
   -- Save data
   save_data()
end

-- Set up roles on joinplayer
minetest.register_on_joinplayer(function(player)
	local pName = player:get_player_name()
	priv_roles.check_for_player(pName)
	-- Update privs (necessary for new players or if privs of a role were changed)
	priv_roles.set_player_privs(pName, priv_roles.calc_privs(pName))
end)

-- Define mod functions
priv_roles.grant = function(player, role)
	-- Get the role
	local r = priv_roles.data.roles[role]
	if r then -- Does the role exist
		if minetest.player_exists(player) then -- Does the player exist?
			priv_roles.check_for_player(player)
			-- Add role to player
			local p_roles = priv_roles.data.players[player]
			p_roles[role] = true
			priv_roles.data.players[player] = p_roles
         -- Override anything in _extra that conflicts with that role
         for p, _ in pairs(r) do
            if priv_roles.data.players[player]["_extra"][p] == false then
               priv_roles.data.players[player]["_extra"][p] = nil
            end
         end
         -- Cacluate privs
         local p_privs = priv_roles.calc_privs(player)
         -- Assign privs
			priv_roles.set_player_privs(player, p_privs)
			-- Save data
			save_data()
			return true, "Done!"
		else
			return false, "Player " .. player .. "does not exist."
		end
	else
		return false, "Role " .. role .. " does not exist."
	end
end

priv_roles.revoke = function(player, role)
	-- Get the role
	local r = priv_roles.data.roles[role]
	if r then -- Does the role exist
		if minetest.player_exists(player) then -- Does the player exist?
			priv_roles.check_for_player(player)
			if priv_roles.data.players[player][role] then -- Does the player have that role?
				-- Remove role from player
				priv_roles.data.players[player][role] = nil
            -- Override anything in _extra that has a priv in this role
            for p, _ in pairs(r) do
               if priv_roles.data.players[player]["_extra"][p] == true then
                  priv_roles.data.players[player]["_extra"][p] = nil
               end
            end
				-- Calc privs
				p_privs = priv_roles.calc_privs(player)
				priv_roles.set_player_privs(player, p_privs)
				-- Save data
				save_data()
				return true, "Done!"
			else
				return false, "Player " .. player .. " does not have role " .. role
			end
		else
			return false, "Player " .. player .. " does not exist."
		end
	else
		return false, "Role " .. role .. " does not exist."
	end
end

priv_roles.list = function(player)
	if minetest.player_exists(player) then
		priv_roles.check_for_player(player)
		local roles = priv_roles.data.players[player]
		local r_str = "Roles of " .. player .. ":"
		for r, _ in pairs(roles) do
         if r ~= "_extra" then
            r_str = r_str .. " " .. r
         end
		end
		return true, r_str
	else
		return false, "Player " .. player .. " does not exist."
	end
end

-- Load mod data
priv_roles.storage = minetest.get_mod_storage()
priv_roles.data = load_data()

-- Add in roles
dofile(p .. "/settings.lua")

-- Roles chat command
ChatCmdBuilder.new("roles", function(cmd)
	-- grant player a role
	cmd:sub("grant :name :role", function(name, t, r)
		if minetest.check_player_privs(name, {privs = true}) then
			local worked, msg = priv_roles.grant(t, r)
			if worked then
				minetest.chat_send_player(t, name .. " granted you the " .. r .. " role!")
			end
			return worked, msg
		else
			return false, "You don't have permission to run this command"
		end
	end)
	-- revoke player a role
	cmd:sub("revoke :name :role", function(name, t, r)
		if minetest.check_player_privs(name, {privs = true}) then
			local worked, msg = priv_roles.revoke(t, r)
			if worked then
				minetest.chat_send_player(t, name .. " revoked from you the " .. r .. " role!")
			end
			return worked, msg
		else
			return false, "You don't have permission to run this command"
		end
	end)
	-- List player roles
	cmd:sub("of :name", function(name, t)
		local worked, msg = priv_roles.list(t)
		return worked, msg
	end)
	-- List all roles
	cmd:sub("list", function(name)
		local l_str = "Available roles:"
		for r, _ in pairs(priv_roles.data.roles) do
			l_str = l_str .. " " .. r
		end
		return true, l_str
	end)
	-- Help
	cmd:sub("help", function(name)
		return true, "/roles grant <name> <role>: Grants player named <name> the role <role>\n" ..
					 "/roles revoke <name> <role>: Revokes role <role> from player named <name>\n" ..
					 "/roles of <name>: Lists the roles of player named <name>\n" ..
					 "/roles list: Lists all roles\n" ..
					 "/roles help: Shows this help"
	end)
end, {
	description = "Manage/view player roles",
	privs = {
		interact = true
	}
})
