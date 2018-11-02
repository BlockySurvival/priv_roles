-- Default roles; these are the roles given to a player when they join
priv_roles.default_roles = {player = true}

--
-- Player "ranks"
--

priv_roles.data.roles["player"] = {       interact = true,
                                          shout = true,
                                          home = true}

priv_roles.data.roles["trusted"] = {		lava = true,
         											areas_high_limit = true}

priv_roles.data.roles["moderator"] = {		kick = true,
         											ban = true,
                                          basic_privs = true,
                                          fly = true,
         											jail = true,
         											bring = true,
         											teleport = true,
         											fast = true,
         											lava = true}

priv_roles.data.roles["admin"] = {			_all = true,
         											server = false,
         											privs = false}

priv_roles.data.roles["owner"] = {			_all = true}

--
-- Server builders
--

priv_roles.data.roles["builder"] = {		fast = true,
            										fly = true,
            									   creative = true,
            										noclip = true,
            										teleport = true,
            										areas = true}

priv_roles.data.roles["expert_builder"] = {	worldedit = true}

--
-- Punishments
--

priv_roles.data.roles["noprivs"] = {		_nothing = true}
