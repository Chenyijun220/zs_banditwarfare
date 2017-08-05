--[[

Zombie Survival
by William "JetBoom" Moodhe
williammoodhe@gmail.com -or- jetboom@noxiousnet.com
http://www.noxiousnet.com/

Further credits displayed by pressing F1 in-game.
This was my first ever gamemode. A lot of stuff is from years ago and some stuff is very recent.

Zombie Survival:Bandits!
by Jooho "air rice" Lee

A total overhaul of Zombie Survival, focusing more on combat and PVP.
]]
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

AddCSLuaFile("sh_translate.lua")
AddCSLuaFile("sh_colors.lua")
AddCSLuaFile("sh_serialization.lua")
AddCSLuaFile("sh_globals.lua")
AddCSLuaFile("sh_crafts.lua")
AddCSLuaFile("sh_util.lua")
AddCSLuaFile("sh_options.lua")
AddCSLuaFile("sh_animations.lua")
AddCSLuaFile("sh_sigils.lua")
AddCSLuaFile("sh_channel.lua")

AddCSLuaFile("cl_draw.lua")
AddCSLuaFile("cl_util.lua")
AddCSLuaFile("cl_options.lua")
AddCSLuaFile("cl_scoreboard.lua")
AddCSLuaFile("cl_targetid.lua")
AddCSLuaFile("cl_postprocess.lua")
AddCSLuaFile("cl_deathnotice.lua")
AddCSLuaFile("cl_floatingscore.lua")
AddCSLuaFile("cl_dermaskin.lua")
AddCSLuaFile("cl_hint.lua")

AddCSLuaFile("obj_vector_extend.lua")
AddCSLuaFile("obj_player_extend.lua")
AddCSLuaFile("obj_player_extend_cl.lua")
AddCSLuaFile("obj_weapon_extend.lua")
AddCSLuaFile("obj_entity_extend.lua")

AddCSLuaFile("vgui/dgamestate.lua")
AddCSLuaFile("vgui/dsigilcounter.lua")
AddCSLuaFile("vgui/dteamcounter.lua")
AddCSLuaFile("vgui/dmodelpanelex.lua")
AddCSLuaFile("vgui/dammocounter.lua")
AddCSLuaFile("vgui/dpingmeter.lua")
AddCSLuaFile("vgui/dteamheading.lua")
AddCSLuaFile("vgui/dteamscores.lua")
AddCSLuaFile("vgui/dsidemenu.lua")
AddCSLuaFile("vgui/dmodelkillicon.lua")

AddCSLuaFile("vgui/dexroundedpanel.lua")
AddCSLuaFile("vgui/dexroundedframe.lua")
AddCSLuaFile("vgui/dexrotatedimage.lua")
AddCSLuaFile("vgui/dexnotificationslist.lua")
AddCSLuaFile("vgui/dexchanginglabel.lua")

AddCSLuaFile("vgui/mainmenu.lua")
AddCSLuaFile("vgui/pmainmenu.lua")
AddCSLuaFile("vgui/poptions.lua")
AddCSLuaFile("vgui/phelp.lua")
AddCSLuaFile("vgui/pclassselect.lua")
AddCSLuaFile("vgui/pweapons.lua")
AddCSLuaFile("vgui/pendboard.lua")
AddCSLuaFile("vgui/pworth.lua")
AddCSLuaFile("vgui/psigils.lua")
AddCSLuaFile("vgui/dtooltip.lua")
AddCSLuaFile("vgui/ppointshop.lua")
AddCSLuaFile("vgui/zshealtharea.lua")

include("shared.lua")
include("sv_options.lua")
include("sv_crafts.lua")
include("obj_entity_extend_sv.lua")
include("obj_player_extend_sv.lua")
include("mapeditor.lua")
include("sv_playerspawnentities.lua")
include("sv_profiling.lua")
include("sv_sigils.lua")

GM.ClassicMode = false

if file.Exists(GM.FolderName.."/gamemode/maps/"..game.GetMap()..".lua", "LUA") then
	include("maps/"..game.GetMap()..".lua")
end

function BroadcastLua(code)
	for _, pl in pairs(player.GetAll()) do
		pl:SendLua(code)
	end
end

player.GetByUniqueID = player.GetByUniqueID or function(uid)
	for _, pl in pairs(player.GetAll()) do
		if pl:UniqueID() == uid then return pl end
	end
end

function GM:WorldHint(hint, pos, ent, lifetime, filter)
	net.Start("zs_worldhint")
		net.WriteString(hint)
		net.WriteVector(pos or ent and ent:IsValid() and ent:GetPos() or vector_origin)
		net.WriteEntity(ent or NULL)
		net.WriteFloat(lifetime or 8)
	if filter then
		net.Send(filter)
	else
		net.Broadcast()
	end
end

function GM:CreateGibs(pos, headoffset)
	headoffset = headoffset or 0

	local headpos = Vector(pos.x, pos.y, pos.z + headoffset)
	for i = 1, 2 do
		local ent = ents.CreateLimited("prop_playergib")
		if ent:IsValid() then
			ent:SetPos(headpos + VectorRand() * 5)
			ent:SetAngles(VectorRand():Angle())
			ent:SetGibType(i)
			ent:Spawn()
		end
	end

	for i=1, 4 do
		local ent = ents.CreateLimited("prop_playergib")
		if ent:IsValid() then
			ent:SetPos(pos + VectorRand() * 12)
			ent:SetAngles(VectorRand():Angle())
			ent:SetGibType(math.random(3, #GAMEMODE.HumanGibs))
			ent:Spawn()
		end
	end
end

function GM:TryHumanPickup(pl, entity)
	if pl.NoObjectPickup or not pl:Alive() or not (pl:Team() == TEAM_BANDIT or pl:Team() == TEAM_HUMAN) then return end

	if entity:IsValid() and not entity.m_NoPickup then
		local entclass = string.sub(entity:GetClass(), 1, 12)
		if (entclass == "prop_physics" or entclass == "func_physbox" or entity.HumanHoldable and entity:HumanHoldable(pl)) and not entity:IsNailed() and entity:GetMoveType() == MOVETYPE_VPHYSICS and entity:GetPhysicsObject():IsValid() and entity:GetPhysicsObject():GetMass() <= CARRY_MAXIMUM_MASS and entity:GetPhysicsObject():IsMoveable() and entity:OBBMins():Length() + entity:OBBMaxs():Length() <= CARRY_MAXIMUM_VOLUME then
			local holder, status = entity:GetHolder()
			if not holder and not pl:IsHolding() and CurTime() >= (pl.NextHold or 0)
			and pl:GetShootPos():Distance(entity:NearestPoint(pl:GetShootPos())) <= 64 and pl:GetGroundEntity() ~= entity then
				local newstatus = ents.Create("status_human_holding")
				if newstatus:IsValid() then
					pl.NextHold = CurTime() + 0.25
					pl.NextUnHold = CurTime() + 0.05
					newstatus:SetPos(pl:GetShootPos())
					newstatus:SetOwner(pl)
					newstatus:SetParent(pl)
					newstatus:SetObject(entity)
					newstatus:Spawn()
				end
			end
		end
	end
end

function GM:AddResources()
	resource.AddFile("resource/fonts/typenoksidi.ttf")
	resource.AddFile("resource/fonts/hidden.ttf")

	for _, filename in pairs(file.Find("materials/zombiesurvival/*.vmt", "GAME")) do
		resource.AddFile("materials/zombiesurvival/"..filename)
	end

	for _, filename in pairs(file.Find("materials/zombiesurvival/killicons/*.vmt", "GAME")) do
		resource.AddFile("materials/zombiesurvival/killicons/"..filename)
	end

	resource.AddFile("materials/zombiesurvival/filmgrain/filmgrain.vmt")
	resource.AddFile("materials/zombiesurvival/filmgrain/filmgrain.vtf")

	for _, filename in pairs(file.Find("sound/zombiesurvival/*.ogg", "GAME")) do
		resource.AddFile("sound/zombiesurvival/"..filename)
	end
	for _, filename in pairs(file.Find("sound/zombiesurvival/*.wav", "GAME")) do
		resource.AddFile("sound/zombiesurvival/"..filename)
	end
	for _, filename in pairs(file.Find("sound/zombiesurvival/*.mp3", "GAME")) do
		resource.AddFile("sound/zombiesurvival/"..filename)
	end

	resource.AddFile("materials/refract_ring.vmt")
	resource.AddFile("materials/killicon/redeem_v2.vtf")
	resource.AddFile("materials/killicon/redeem_v2.vmt")
	resource.AddFile("materials/killicon/zs_axe.vtf")
	resource.AddFile("materials/killicon/zs_keyboard.vtf")
	resource.AddFile("materials/killicon/zs_sledgehammer.vtf")
	resource.AddFile("materials/killicon/zs_fryingpan.vtf")
	resource.AddFile("materials/killicon/zs_pot.vtf")
	resource.AddFile("materials/killicon/zs_plank.vtf")
	resource.AddFile("materials/killicon/zs_hammer.vtf")
	resource.AddFile("materials/killicon/zs_shovel.vtf")
	resource.AddFile("materials/killicon/zs_axe.vmt")
	resource.AddFile("materials/killicon/zs_keyboard.vmt")
	resource.AddFile("materials/killicon/zs_sledgehammer.vmt")
	resource.AddFile("materials/killicon/zs_fryingpan.vmt")
	resource.AddFile("materials/killicon/zs_pot.vmt")
	resource.AddFile("materials/killicon/zs_plank.vmt")
	resource.AddFile("materials/killicon/zs_hammer.vmt")
	resource.AddFile("materials/killicon/zs_shovel.vmt")
	resource.AddFile("models/weapons/v_zombiearms.mdl")
	resource.AddFile("materials/models/weapons/v_zombiearms/zombie_classic_sheet.vmt")
	resource.AddFile("materials/models/weapons/v_zombiearms/zombie_classic_sheet.vtf")
	resource.AddFile("materials/models/weapons/v_zombiearms/zombie_classic_sheet_normal.vtf")
	resource.AddFile("materials/models/weapons/v_zombiearms/ghoulsheet.vmt")
	resource.AddFile("materials/models/weapons/v_zombiearms/ghoulsheet.vtf")
	resource.AddFile("models/weapons/v_fza.mdl")
	resource.AddFile("models/weapons/v_pza.mdl")
	resource.AddFile("materials/models/weapons/v_fza/fast_zombie_sheet.vmt")
	resource.AddFile("materials/models/weapons/v_fza/fast_zombie_sheet.vtf")
	resource.AddFile("materials/models/weapons/v_fza/fast_zombie_sheet_normal.vtf")
	resource.AddFile("models/weapons/v_annabelle.mdl")
	resource.AddFile("materials/models/weapons/w_annabelle/gun.vtf")
	resource.AddFile("materials/models/weapons/sledge.vtf")
	resource.AddFile("materials/models/weapons/sledge.vmt")
	resource.AddFile("materials/models/weapons/temptexture/handsmesh1.vtf")
	resource.AddFile("materials/models/weapons/temptexture/handsmesh1.vmt")
	resource.AddFile("materials/models/weapons/hammer2.vtf")
	resource.AddFile("materials/models/weapons/hammer2.vmt")
	resource.AddFile("materials/models/weapons/hammer.vtf")
	resource.AddFile("materials/models/weapons/hammer.vmt")
	resource.AddFile("models/weapons/w_sledgehammer.mdl")
	resource.AddFile("models/weapons/v_sledgehammer/v_sledgehammer.mdl")
	resource.AddFile("models/weapons/w_hammer.mdl")
	resource.AddFile("models/weapons/v_hammer/v_hammer.mdl")

	resource.AddFile("models/weapons/v_aegiskit.mdl")

	resource.AddFile("materials/models/weapons/v_hand/armtexture.vmt")

	resource.AddFile("models/wraith_zsv1.mdl")
	for _, filename in pairs(file.Find("materials/models/wraith1/*.vmt", "GAME")) do
		resource.AddFile("materials/models/wraith1/"..filename)
	end
	for _, filename in pairs(file.Find("materials/models/wraith1/*.vtf", "GAME")) do
		resource.AddFile("materials/models/wraith1/"..filename)
	end

	resource.AddFile("models/weapons/v_supershorty/v_supershorty.mdl")
	resource.AddFile("models/weapons/w_supershorty.mdl")
	for _, filename in pairs(file.Find("materials/weapons/v_supershorty/*.vmt", "GAME")) do
		resource.AddFile("materials/weapons/v_supershorty/"..filename)
	end
	for _, filename in pairs(file.Find("materials/weapons/v_supershorty/*.vtf", "GAME")) do
		resource.AddFile("materials/weapons/v_supershorty/"..filename)
	end
	for _, filename in pairs(file.Find("materials/weapons/w_supershorty/*.vmt", "GAME")) do
		resource.AddFile("materials/weapons/w_supershorty/"..filename)
	end
	for _, filename in pairs(file.Find("materials/weapons/w_supershorty/*.vtf", "GAME")) do
		resource.AddFile("materials/weapons/w_supershorty/"..filename)
	end
	for _, filename in pairs(file.Find("materials/weapons/survivor01_hands/*.vmt", "GAME")) do
		resource.AddFile("materials/weapons/survivor01_hands/"..filename)
	end
	for _, filename in pairs(file.Find("materials/weapons/survivor01_hands/*.vtf", "GAME")) do
		resource.AddFile("materials/weapons/survivor01_hands/"..filename)
	end

	for _, filename in pairs(file.Find("materials/models/weapons/v_pza/*.*", "GAME")) do
		resource.AddFile("materials/models/weapons/v_pza/"..string.lower(filename))
	end

	resource.AddFile("models/player/fatty/fatty.mdl")
	resource.AddFile("materials/models/player/elis/fty/001.vmt")
	resource.AddFile("materials/models/player/elis/fty/001.vtf")
	resource.AddFile("materials/models/player/elis/fty/001_normal.vtf")

	resource.AddFile("models/vinrax/player/doll_player.mdl")

	resource.AddFile("sound/weapons/melee/golf club/golf_hit-01.ogg")
	resource.AddFile("sound/weapons/melee/golf club/golf_hit-02.ogg")
	resource.AddFile("sound/weapons/melee/golf club/golf_hit-03.ogg")
	resource.AddFile("sound/weapons/melee/golf club/golf_hit-04.ogg")
	resource.AddFile("sound/weapons/melee/crowbar/crowbar_hit-1.ogg")
	resource.AddFile("sound/weapons/melee/crowbar/crowbar_hit-2.ogg")
	resource.AddFile("sound/weapons/melee/crowbar/crowbar_hit-3.ogg")
	resource.AddFile("sound/weapons/melee/crowbar/crowbar_hit-4.ogg")
	resource.AddFile("sound/weapons/melee/shovel/shovel_hit-01.ogg")
	resource.AddFile("sound/weapons/melee/shovel/shovel_hit-02.ogg")
	resource.AddFile("sound/weapons/melee/shovel/shovel_hit-03.ogg")
	resource.AddFile("sound/weapons/melee/shovel/shovel_hit-04.ogg")
	resource.AddFile("sound/weapons/melee/frying_pan/pan_hit-01.ogg")
	resource.AddFile("sound/weapons/melee/frying_pan/pan_hit-02.ogg")
	resource.AddFile("sound/weapons/melee/frying_pan/pan_hit-03.ogg")
	resource.AddFile("sound/weapons/melee/frying_pan/pan_hit-04.ogg")
	resource.AddFile("sound/weapons/melee/keyboard/keyboard_hit-01.ogg")
	resource.AddFile("sound/weapons/melee/keyboard/keyboard_hit-02.ogg")
	
	
	resource.AddFile("sound/weapons/melee/keyboard/keyboard_hit-03.ogg")
	resource.AddFile("sound/weapons/melee/keyboard/keyboard_hit-04.ogg")
	resource.AddFile("sound/zombiesurvival/hitsound.wav")
	resource.AddFile("sound/music/vlvx_song18.mp3")
	resource.AddFile("sound/music/vlvx_song21.mp3")
	resource.AddFile("sound/music/vlvx_song22.mp3")
	resource.AddFile("sound/music/vlvx_song23.mp3")
	resource.AddFile("sound/music/vlvx_song24.mp3")
	resource.AddFile("sound/music/vlvx_song27.mp3")
	resource.AddFile("sound/music/vlvx_song28.mp3")

	resource.AddFile("sound/killstreak/2kills.wav")
	resource.AddFile("sound/killstreak/3kills.wav")
	resource.AddFile("sound/killstreak/4kills.wav")
	resource.AddFile("sound/killstreak/5kills.wav")
	resource.AddFile("sound/killstreak/6kills.wav")
	resource.AddFile("sound/killstreak/7kills.wav")
	resource.AddFile("sound/killstreak/8kills.wav")
	
	resource.AddFile("materials/noxctf/sprite_bloodspray1.vmt")
	resource.AddFile("materials/noxctf/sprite_bloodspray2.vmt")
	resource.AddFile("materials/noxctf/sprite_bloodspray3.vmt")
	resource.AddFile("materials/noxctf/sprite_bloodspray4.vmt")
	resource.AddFile("materials/noxctf/sprite_bloodspray5.vmt")
	resource.AddFile("materials/noxctf/sprite_bloodspray6.vmt")
	resource.AddFile("materials/noxctf/sprite_bloodspray7.vmt")
	resource.AddFile("materials/noxctf/sprite_bloodspray8.vmt")

	resource.AddFile("sound/"..tostring(self.LastHumanSound))
	resource.AddFile("sound/"..tostring(self.AllLoseSound))
	resource.AddFile("sound/"..tostring(self.HumanWinSound))
	resource.AddFile("sound/"..tostring(self.DeathSound))
end

function GM:Initialize()
	self:RegisterPlayerSpawnEntities()
	self:AddResources()
	self:PrecacheResources()
	self:AddCustomAmmo()
	self:AddNetworkStrings()
	self:LoadProfiler()
	
	local mapname = string.lower(game.GetMap())
	if table.HasValue(self.ForceClassicMaps, mapname) then
		self:SetClassicMode(true)
	else
		self:SetClassicMode(math.random(0,1) == 1)
	end

	--[[if string.sub(mapname, 1, 3) == "zm_" then
		NOZOMBIEGASSES = true
	end]]
	
	game.ConsoleCommand("fire_dmgscale 1\n")
	game.ConsoleCommand("mp_flashlight 1\n")
	game.ConsoleCommand("sv_gravity 600\n")
end

function GM:AddNetworkStrings()
	util.AddNetworkString("zs_gamestate")
	util.AddNetworkString("zs_wavestart")
	util.AddNetworkString("zs_waveend")
	util.AddNetworkString("zs_suddendeath")

	util.AddNetworkString("zs_lasthuman")
	util.AddNetworkString("zs_gamemodecall")
	util.AddNetworkString("zs_lasthumanpos")
	util.AddNetworkString("zs_endround")
	util.AddNetworkString("zs_wavewonby")
	util.AddNetworkString("zs_centernotify")
	util.AddNetworkString("zs_topnotify")
	util.AddNetworkString("zs_zvols")
	util.AddNetworkString("zs_nextboss")
	util.AddNetworkString("zs_classunlock")
	util.AddNetworkString("zs_playerrespawntime")
	util.AddNetworkString("zs_killstreak")	
	util.AddNetworkString("zs_playerredeemed")
	util.AddNetworkString("zs_dohulls")
	util.AddNetworkString("zs_penalty")
	util.AddNetworkString("zs_nextresupplyuse")
	util.AddNetworkString("zs_lifestats")
	util.AddNetworkString("zs_lifestatsbd")
	util.AddNetworkString("zs_lifestatshd")
	util.AddNetworkString("zs_lifestatsbe")
	util.AddNetworkString("zs_boss_spawned")
	util.AddNetworkString("zs_commission")
	util.AddNetworkString("zs_capture")
	util.AddNetworkString("zs_healother")
	util.AddNetworkString("zs_repairobject")
	util.AddNetworkString("zs_worldhint")
	util.AddNetworkString("zs_honmention")
	util.AddNetworkString("zs_floatscore")
	util.AddNetworkString("zs_floatscore_vec")
	util.AddNetworkString("zs_zclass")
	util.AddNetworkString("zs_dmg")
	util.AddNetworkString("zs_dmg_prop")
	util.AddNetworkString("zs_legdamage")
	util.AddNetworkString("zs_currentsigils")
	util.AddNetworkString("zs_hitmarker")
	
	util.AddNetworkString("zs_crow_kill_crow")
	util.AddNetworkString("zs_pl_kill_pl")
	util.AddNetworkString("zs_pls_kill_pl")
	util.AddNetworkString("zs_pl_kill_self")
	util.AddNetworkString("zs_death")
end

function GM:IsClassicMode()
	return GetGlobalBool("classicmode",false)
end

function GM:CenterNotifyAll(...)
	net.Start("zs_centernotify")
		net.WriteTable({...})
	net.Broadcast()
end
GM.CenterNotify = GM.CenterNotifyAll

function GM:TopNotifyAll(...)
	net.Start("zs_topnotify")
		net.WriteTable({...})
	net.Broadcast()
end
GM.TopNotify = GM.TopNotifyAll

function GM:ShowHelp(pl)
	pl:SendLua("GAMEMODE:ShowHelp()")
end

function GM:ShowTeam(pl)
	if pl:Alive() and gamemode.Call("PlayerCanPurchase", pl) then
		pl:SendLua("GAMEMODE:OpenPointsShop()")
	end
end

function GM:ShowSpare1(pl)
	if pl:Team() == TEAM_HUMAN or pl:Team() == TEAM_BANDIT then
		pl:SendLua("MakepWeapons()")
	end
end

function GM:ShowSpare2(pl)
	pl:SendLua("MakepOptions()")
end

function GM:SetupSpawnPoints()
	local btab = ents.FindByClass("info_player_bandit")
	btab = table.Add(btab, ents.FindByClass("info_player_zombie"))
	btab = table.Add(btab, ents.FindByClass("info_player_rebel"))

	local htab = ents.FindByClass("info_player_human")
	htab = table.Add(htab, ents.FindByClass("info_player_combine"))

	local mapname = string.lower(game.GetMap())
	-- Terrorist spawns are usually in some kind of house or a main base in CS_  in order to guard the hosties. Put the humans there.
	if string.sub(mapname, 1, 3) == "cs_" or string.sub(mapname, 1, 3) == "zs_" then
		btab = table.Add(btab, ents.FindByClass("info_player_counterterrorist"))
		htab = table.Add(htab, ents.FindByClass("info_player_terrorist"))
	else -- Otherwise, this is probably a DE_, ZM_, or ZH_ map. In DE_ maps, the T's spawn away from the main part of the map and are zombies in zombie plugins so let's do the same.
		btab = table.Add(btab, ents.FindByClass("info_player_terrorist"))
		htab = table.Add(htab, ents.FindByClass("info_player_counterterrorist"))
	end

	-- Add all the old ZS spawns from GMod9.
	for _, oldspawn in pairs(ents.FindByClass("gmod_player_start")) do
		if oldspawn.BlueTeam then
			table.insert(htab, oldspawn)
		else
			table.insert(btab, oldspawn)
		end
	end

	-- You shouldn't play a DM map since spawns are shared but whatever. Let's make sure that there aren't team spawns first.
	if #htab == 0 then
		htab = ents.FindByClass("info_player_start")
		htab = table.Add(htab, ents.FindByClass("info_player_deathmatch")) -- Zombie Master
	end
	if #btab == 0 then
		btab = ents.FindByClass("info_player_start")
		btab = table.Add(btab, ents.FindByClass("info_zombiespawn")) -- Zombie Master
	end

	team.SetSpawnPoint(TEAM_BANDIT, btab)
	team.SetSpawnPoint(TEAM_HUMAN, htab)
	team.SetSpawnPoint(TEAM_SPECTATOR, htab)

	self.RedeemSpawnPoints = ents.FindByClass("info_player_redeemed")
	self.BossSpawnPoints = table.Add(ents.FindByClass("info_player_zombie_boss"), ents.FindByClass("info_player_undead_boss"))
end

function GM:PlayerPointsAdded(pl, amount)
end

local weaponmodelstoweapon = {}
weaponmodelstoweapon["models/props/cs_office/computer_keyboard.mdl"] = "weapon_zs_keyboard"
weaponmodelstoweapon["models/props_c17/computer01_keyboard.mdl"] = "weapon_zs_keyboard"
weaponmodelstoweapon["models/props_c17/metalpot001a.mdl"] = "weapon_zs_pot"
weaponmodelstoweapon["models/props_interiors/pot02a.mdl"] = "weapon_zs_fryingpan"
weaponmodelstoweapon["models/props_c17/metalpot002a.mdl"] = "weapon_zs_fryingpan"
weaponmodelstoweapon["models/props_junk/shovel01a.mdl"] = "weapon_zs_shovel"
weaponmodelstoweapon["models/props/cs_militia/axe.mdl"] = "weapon_zs_axe"
weaponmodelstoweapon["models/props_c17/tools_wrench01a.mdl"] = "weapon_zs_hammer"
weaponmodelstoweapon["models/weapons/w_knife_t.mdl"] = "weapon_zs_swissarmyknife"
weaponmodelstoweapon["models/weapons/w_knife_ct.mdl"] = "weapon_zs_swissarmyknife"
weaponmodelstoweapon["models/weapons/w_crowbar.mdl"] = "weapon_zs_crowbar"
weaponmodelstoweapon["models/weapons/w_stunbaton.mdl"] = "weapon_zs_stunbaton"
weaponmodelstoweapon["models/props_interiors/furniture_lamp01a.mdl"] = "weapon_zs_lamp"
weaponmodelstoweapon["models/props_junk/rock001a.mdl"] = "weapon_zs_stone"
weaponmodelstoweapon["models/props_c17/canister01a.mdl"] = "weapon_zs_oxygentank"
weaponmodelstoweapon["models/props_canal/mattpipe.mdl"] = "weapon_zs_pipe"
weaponmodelstoweapon["models/props_junk/meathook001a.mdl"] = "weapon_zs_hook"
function GM:InitPostEntity()
	gamemode.Call("InitPostEntityMap")
	RunConsoleCommand("mapcyclefile", "mapcycle_zombiesurvival.txt")
end

function GM:SetupProps()
	for _, ent in pairs(ents.FindByClass("prop_physics*")) do
		local mdl = ent:GetModel()
		if mdl then
			mdl = string.lower(mdl)
			if table.HasValue(self.BannedProps, mdl) then
				ent:Remove()
			elseif weaponmodelstoweapon[mdl] then
				local wep = ents.Create("prop_weapon")
				if wep:IsValid() then
					wep:SetPos(ent:GetPos())
					wep:SetAngles(ent:GetAngles())
					wep:SetWeaponType(weaponmodelstoweapon[mdl])
					wep:SetShouldRemoveAmmo(false)
					wep:Spawn()

					ent:Remove()
				end
			elseif ent:GetMaxHealth() == 1 and ent:Health() == 0 and ent:GetKeyValues().damagefilter ~= "invul" and ent:GetName() == "" then
				local health = math.min(2500, math.ceil((ent:OBBMins():Length() + ent:OBBMaxs():Length()) * 10))
				local hmul = self.PropHealthMultipliers[mdl]
				if hmul then
					health = health * hmul
				end

				ent.PropHealth = health
				ent.TotalHealth = health
			else
				ent:SetHealth(math.ceil(ent:Health() * 3))
				ent:SetMaxHealth(ent:Health())
			end
		end
	end
end

function GM:RemoveUnusedEntities()
	-- Causes a lot of needless lag.
	util.RemoveAll("prop_ragdoll")

	-- Remove NPCs because first of all this game is PvP and NPCs can cause crashes.
	util.RemoveAll("npc_maker")
	util.RemoveAll("npc_template_maker")
	util.RemoveAll("npc_zombie")
	util.RemoveAll("npc_zombie_torso")
	util.RemoveAll("npc_fastzombie")
	util.RemoveAll("npc_headcrab")
	util.RemoveAll("npc_headcrab_fast")
	util.RemoveAll("npc_headcrab_black")
	util.RemoveAll("npc_poisonzombie")

	-- Such a headache. Just remove them all.
	util.RemoveAll("item_ammo_crate")
	-- This is no longer a zombie mod.
	util.RemoveAll("zombiegasses")
	-- Shouldn't exist.
	util.RemoveAll("item_suitcharger")
end

function GM:ReplaceMapWeapons()
	for _, ent in pairs(ents.FindByClass("weapon_*")) do
		local wepclass = ent:GetClass()
		if wepclass ~= "weapon_map_base" then
			if string.sub(wepclass, 1, 10) == "weapon_zs_" then
				local wep = ents.Create("prop_weapon")
				if wep:IsValid() then
					wep:SetPos(ent:GetPos())
					wep:SetAngles(ent:GetAngles())
					wep:SetWeaponType(ent:GetClass())
					wep:SetShouldRemoveAmmo(false)
					wep:Spawn()
					wep.IsPreplaced = true
				end
			end
			ent:Remove()
		end
	end
end

local ammoreplacements = {
	["item_ammo_357"] = "357",
	["item_ammo_357_large"] = "357",
	["item_ammo_pistol"] = "pistol",
	["item_ammo_pistol_large"] = "pistol",
	["item_ammo_buckshot"] = "buckshot",
	["item_ammo_ar2"] = "ar2",
	["item_ammo_ar2_large"] = "ar2",
	["item_ammo_ar2_altfire"] = "pulse",
	["item_ammo_crossbow"] = "xbowbolt",
	["item_ammo_smg1"] = "smg1",
	["item_ammo_smg1_large"] = "smg1",
	["item_box_buckshot"] = "buckshot"
}
function GM:ReplaceMapAmmo()
	for classname, ammotype in pairs(ammoreplacements) do
		for _, ent in pairs(ents.FindByClass(classname)) do
			local newent = ents.Create("prop_ammo")
			if newent:IsValid() then
				newent:SetAmmoType(ammotype)
				newent.PlacedInMap = true
				newent:SetPos(ent:GetPos())
				newent:SetAngles(ent:GetAngles())
				newent:Spawn()
				newent:SetAmmo(self.AmmoCache[ammotype] or 1)
			end
			ent:Remove()
		end
	end

	util.RemoveAll("item_item_crate")
end

function GM:ReplaceMapBatteries()
	util.RemoveAll("item_battery")
end

local playermins = Vector(-17, -17, 0)
local playermaxs = Vector(17, 17, 4)
local LastSpawnPoints = {}

function GM:PlayerSelectSpawn(pl)
	local spawninplayer = false
	local teamid = pl:Team()
	local tab
	local epicenter

	if not tab or #tab == 0 then tab = team.GetValidSpawnPoint(teamid) end

	local count = #tab
	if count > 0 then
		local spawn = table.Random(tab)
		if spawn then
			LastSpawnPoints[teamid] = spawn
			pl.SpawnedOnSpawnPoint = true
			return spawn
		end
	end

	pl.SpawnedOnSpawnPoint = true

	-- Fallback.
	return LastSpawnPoints[teamid] or #tab > 0 and table.Random(tab)
end
function GM:PrintSpawnPoints(teamid)
	PrintTable(team.GetValidSpawnPoint(teamid))
end
local NextTick = 0
function GM:Think()
	local time = CurTime()
	
	if not self.RoundEnded then
		if self:GetWaveActive() then
			if self:GetWaveEnd() <= time and self:GetWaveEnd() ~= -1 then
				gamemode.Call("SetWaveActive", false)
			end
			
			if not self:IsClassicMode() then
				gamemode.Call("SigilCommsThink")
			end
		elseif self:GetWaveStart() ~= -1 then
			if self:GetWaveStart() <= time then
				gamemode.Call("SetWaveActive", true)
			elseif self:GetWaveStart() - 10 <= time then
				local humancount = table.Count(team.GetPlayers(TEAM_HUMAN))
			end
			for _, pl in pairs(player.GetAll()) do
				local numoutsidespawns = 0
				local teamspawns = {}
				teamspawns = team.GetValidSpawnPoint(pl:Team())
				for _, ent in pairs(teamspawns) do
					if ent:GetPos():Distance(pl:GetPos()) >= 256 and pl:Alive() then
						numoutsidespawns = numoutsidespawns + 1
					end
				end
				if numoutsidespawns >= #teamspawns then
					pl:SetPos(teamspawns[ math.random(#teamspawns) ]:GetPos())
					pl:CenterNotify(COLOR_RED, translate.ClientGet(pl, "before_wave_cant_go_outside_spawn"))
				end
			end
		end
	end
	
	local allplayers = player.GetAll()
	for _, pl in pairs(allplayers) do
		if pl:GetBarricadeGhosting() then
			pl:BarricadeGhostingThink()
		end

		if pl.m_PointQueue >= 1 and time >= pl.m_LastDamageDealt + 2 then
			pl:PointCashOut((pl.m_LastDamageDealtPosition or pl:GetPos()) + Vector(0, 0, 32), FM_NONE)
		end
	end

	if NextTick <= time then
		NextTick = time + 1

		local doafk = not self:GetWaveActive() and wave == 0

		for _, pl in pairs(allplayers) do
			if pl:Alive() then

				if pl:WaterLevel() >= 3 and not (pl.status_drown and pl.status_drown:IsValid()) then
					pl:GiveStatus("drown")
				end

				--[[if time >= pl.BonusDamageCheck + 10 then
					pl.BonusDamageCheck = time
					pl:AddPoints(1)
					--pl:PrintTranslatedMessage(HUD_PRINTCONSOLE, "minute_points_added", 1)
				end]]--

				if pl.BuffRegenerative and time >= pl.NextRegenerate and pl:Health() < pl:GetMaxHealth() then
					pl.NextRegenerate = time + 5
					pl:SetHealth(pl:Health() + 1)
				end
			end
		end
	end
end

function GM:OnNPCKilled(ent, attacker, inflictor)
end

function GM:LastHuman(pl)
	if not LASTHUMAN then
		net.Start("zs_lasthuman")
			net.WriteEntity(pl or NULL)
		net.Broadcast()

		for _, ent in pairs(ents.FindByClass("logic_infliction")) do
			ent:Input("onlasthuman", pl, pl, pl and pl:IsValid() and pl:EntIndex() or -1)
		end

		LASTHUMAN = true
	end

	self.TheLastHuman = pl
end

function GM:PlayerHealedTeamMember(pl, other, health, wep)
	if self:GetWave() == 0 then return end

	pl.HealedThisRound = pl.HealedThisRound + health
	pl.CarryOverHealth = (pl.CarryOverHealth or 0) + health

	local hpperpoint = self.MedkitPointsPerHealth
	if hpperpoint <= 0 then return end

	local points = math.floor(pl.CarryOverHealth / hpperpoint)

	if 1 <= points then
		pl:AddPoints(points)

		pl.CarryOverHealth = pl.CarryOverHealth - points * hpperpoint

		net.Start("zs_healother")
			net.WriteEntity(other)
			net.WriteUInt(points, 16)
		net.Send(pl)
	end
end

function GM:ObjectPackedUp(pack, packer, owner)
end

function GM:PlayerRepairedObject(pl, other, health, wep)
	if self:GetWave() == 0 then return end

	pl.RepairedThisRound = pl.RepairedThisRound + health
	pl.CarryOverRepair = (pl.CarryOverRepair or 0) + health

	local hpperpoint = self.RepairPointsPerHealth
	if hpperpoint <= 0 then return end

	local points = math.floor(pl.CarryOverRepair / hpperpoint)

	if 1 <= points then
		pl:AddPoints(points)

		pl.CarryOverRepair = pl.CarryOverRepair - points * hpperpoint

		net.Start("zs_repairobject")
			net.WriteEntity(other)
			net.WriteUInt(points, 16)
		net.Send(pl)
	end
end

function GM:CacheHonorableMentions()
	if self.CachedHMs then return end

	self.CachedHMs = {}

	for i, hm in ipairs(self.HonorableMentions) do
		if hm.GetPlayer then
			local pl, magnitude = hm.GetPlayer(self)
			if pl then
				self.CachedHMs[i] = {pl, i, magnitude or 0}
			end
		end
	end

	gamemode.Call("PostDoHonorableMentions")
end

function GM:DoHonorableMentions(filter)
	self:CacheHonorableMentions()

	for i, tab in pairs(self.CachedHMs) do
		net.Start("zs_honmention")
			net.WriteEntity(tab[1])
			net.WriteUInt(tab[2], 8)
			net.WriteInt(tab[3], 32)
		if filter then
			net.Send(filter)
		else
			net.Broadcast()
		end
	end
end

function GM:PostDoHonorableMentions()
end

function GM:PostEndRound(winner)
end

-- You can override or hook and return false in case you have your own map change system.
local function RealMap(map)
	return string.match(map, "(.+)%.bsp")
end

function GM:LoadNextMap()
	-- Just in case.
	--timer.Simple(10, game.LoadNextMap)
	--timer.Simple(15, function() RunConsoleCommand("changelevel", game.GetMap()) end)
	MapVote.Start(nil, nil, nil, nil)
	--[[if file.Exists(GetConVarString("mapcyclefile"), "GAME") then
		game.LoadNextMap()
	else
		local maps = file.Find("maps/zs_*.bsp", "GAME")
		maps = table.Add(maps, file.Find("maps/ze_*.bsp", "GAME"))
		maps = table.Add(maps, file.Find("maps/zm_*.bsp", "GAME"))
		table.sort(maps)
		if #maps > 0 then
			local currentmap = game.GetMap()
			for i, map in ipairs(maps) do
				local lowermap = string.lower(map)
				local realmap = RealMap(lowermap)
				if realmap == currentmap then
					if maps[i + 1] then
						local nextmap = RealMap(maps[i + 1])
						if nextmap then
							RunConsoleCommand("changelevel", nextmap)
						end
					else
						local nextmap = RealMap(maps[1])
						if nextmap then
							RunConsoleCommand("changelevel", nextmap)
						end
					end

					break
				end
			end
		end
	end]]
end

function GM:PreRestartRound()
	for _, pl in pairs(player.GetAll()) do
		pl:StripWeapons()
		pl:Spectate(OBS_MODE_ROAMING)
		pl:GodDisable()
	end
end

GM.CurrentRound = 1
function GM:RestartRound()
	self.CurrentRound = self.CurrentRound + 1

	self:RestartLua()
	self:RestartGame()
	
	net.Start("zs_gamemodecall")
		net.WriteString("RestartRound")
	net.Broadcast()
end
GM.TiedWaves = 0
GM.DynamicSpawning = true
GM.CappedInfliction = 0
GM.StartingZombie = {}
GM.CheckedOut = {}
GM.PreviouslyDied = {}
GM.CurrentSigilTable = {}
GM.CommsEnd = false
GM.SuddenDeath = false
GM.StoredUndeadFrags = {}
GM.CurrentWaveWinner = nil
function GM:RestartLua()
	self.CachedHMs = nil
	self.TheLastHuman = nil
	self.UseSigils = nil
	self:SetComms(0,0)
	self.CommsEnd = false
	self.SuddenDeath = false
	self.CurrentSigilTable = {}
	self:SetCurrentWaveWinner(nil)
	-- logic_pickups
	self.MaxWeaponPickups = nil
	self.MaxAmmoPickups = nil
	for _, ent in pairs(ents.FindByClass("logic_pickups")) do
		ent:Input("setmaxweaponpickups",5)
		ent:Input("setmaxammopickups",10)
	end
	self.MaxFlashlightPickups = nil
	self.WeaponRequiredForAmmo = nil
	for _, pl in pairs(player.GetAll()) do
		pl.AmmoPickups = nil
		pl.WeaponPickups = nil
	end
	
	self.OverrideEndSlomo = nil
	if type(GetGlobalBool("endcamera", 1)) ~= "number" then
		SetGlobalBool("endcamera", nil)
	end
	if GetGlobalString("winmusic", "-") ~= "-" then
		SetGlobalString("winmusic", nil)
	end
	if GetGlobalString("losemusic", "-") ~= "-" then
		SetGlobalString("losemusic", nil)
	end
	if type(GetGlobalVector("endcamerapos", 1)) ~= "number" then
		SetGlobalVector("endcamerapos", nil)
	end

	self.CappedInfliction = 0
	
	self.CheckedOut = {}
	self.PreviouslyDied = {}
	self.StoredUndeadFrags = {}

	ROUNDWINNER = nil

	hook.Remove("PlayerShouldTakeDamage", "EndRoundShouldTakeDamage")
	hook.Remove("PlayerCanHearPlayersVoice", "EndRoundCanHearPlayersVoice")
end

-- I don't know.
local function CheckBroken()
	for _, pl in pairs(player.GetAll()) do
		if pl:Alive() and (pl:Health() <= 0 or pl:GetObserverMode() ~= OBS_MODE_NONE or pl:OBBMaxs().x ~= 16) then
			pl:SetObserverMode(OBS_MODE_NONE)
			pl:UnSpectateAndSpawn()
		end
	end
end

function GM:DoRestartGame()
	self.RoundEnded = nil

	for _, ent in pairs(ents.FindByClass("prop_weapon")) do
		ent:Remove()
	end

	for _, ent in pairs(ents.FindByClass("prop_ammo")) do
		ent:Remove()
	end

	self:SetClassicMode(math.random(0,1) == 1)

	self:SetUseSigils(true)

	net.Start("zs_currentsigils")
		net.WriteTable({})
	net.Broadcast()
	self.CurrentSigilTable = {}
	self:SetWave(0)
	self:SetHumanScore(0)
	self:SetBanditScore(0)
	self:SetTieScore(0)
	self:SetWaveStart(CurTime() + self.WaveZeroLength)
	self:SetWaveEnd(self:GetWaveStart() + self:GetWaveOneLength())
	self:SetWaveActive(false)
	
	SetGlobalInt("numwaves", -2)

	timer.Create("CheckBroken", 10, 1, CheckBroken)

	game.CleanUpMap(false, self.CleanupFilter)
	gamemode.Call("InitPostEntityMap")
	gamemode.Call("ShuffleTeams")
	for _, pl in pairs(player.GetAll()) do
		pl:UnSpectateAndSpawn()
		pl:GodDisable()
		gamemode.Call("PlayerInitialSpawnRound", pl)
		gamemode.Call("PlayerReadyRound", pl)
	end
end

function GM:RestartGame()
	for _, pl in pairs(player.GetAll()) do
		pl:StripWeapons()
		pl:StripAmmo()
		pl:SetFrags(0)
		pl:SetDeaths(0)
		pl:SetKills(0)
		pl:SetPoints(0)
		pl:AddPoints(15)
		pl:DoHulls()
		pl.DeathClass = nil
	end
	self:SetWave(0)

	self:SetWaveStart(CurTime() + self.WaveZeroLength)

	self:SetWaveEnd(self:GetWaveStart() + self:GetWaveOneLength())
	self:SetWaveActive(false)

	SetGlobalInt("numwaves", -2)
	if GetGlobalString("hudoverride"..TEAM_BANDIT, "") ~= "" then
		SetGlobalString("hudoverride"..TEAM_BANDIT, "")
	end
	if GetGlobalString("hudoverride"..TEAM_HUMAN, "") ~= "" then
		SetGlobalString("hudoverride"..TEAM_HUMAN, "")
	end

	timer.Simple(0.25, function() GAMEMODE:DoRestartGame() end)
end

function GM:InitPostEntityMap(fromze)
	pcall(gamemode.Call, "LoadMapEditorFile")

	gamemode.Call("SetupSpawnPoints")
	gamemode.Call("RemoveUnusedEntities")
	if not fromze then
		gamemode.Call("ReplaceMapWeapons")
		gamemode.Call("ReplaceMapAmmo")
		gamemode.Call("ReplaceMapBatteries")
	end
	gamemode.Call("SetupProps")

	for _, ent in pairs(ents.FindByClass("prop_ammo")) do ent.PlacedInMap = true end
	for _, ent in pairs(ents.FindByClass("prop_weapon")) do ent.PlacedInMap = true end
end

local function EndRoundPlayerShouldTakeDamage(pl, attacker) return false end
local function EndRoundPlayerCanSuicide(pl) return true end

local function EndRoundSetupPlayerVisibility(pl)
	if GAMEMODE.LastHumanPosition and GAMEMODE.RoundEnded then
		AddOriginToPVS(GAMEMODE.LastHumanPosition)
	else
		hook.Remove("SetupPlayerVisibility", "EndRoundSetupPlayerVisibility")
	end
end

function GM:EndRound(winner)
	if self.RoundEnded then return end
	self.RoundEnded = true
	self.RoundEndedTime = CurTime()
	ROUNDWINNER = winner

	if self.OverrideEndSlomo == nil or self.OverrideEndSlomo then
		game.SetTimeScale(0.25)
		timer.Simple(2, function() game.SetTimeScale(1) end)
	end

	hook.Add("PlayerCanHearPlayersVoice", "EndRoundCanHearPlayersVoice", function() return true end)

	if self.OverrideEndCamera == nil or self.OverrideEndCamera then
		hook.Add("SetupPlayerVisibility", "EndRoundSetupPlayerVisibility", EndRoundSetupPlayerVisibility)
	end

	if self:ShouldRestartRound() then
		timer.Simple(self.EndGameTime - 3, function() gamemode.Call("PreRestartRound") end)
		timer.Simple(self.EndGameTime, function() gamemode.Call("RestartRound") end)
	else
		timer.Simple(self.EndGameTime, function() gamemode.Call("LoadNextMap") end)
	end

	-- Get rid of some lag.
	util.RemoveAll("prop_ammo")
	util.RemoveAll("prop_weapon")

	timer.Simple(5, function() gamemode.Call("DoHonorableMentions") end)

	net.Start("zs_endround")
		net.WriteUInt(winner or -1, 8)
		net.WriteString(game.GetMapNext())
	net.Broadcast()

	if winner == TEAM_HUMAN then
		for _, ent in pairs(ents.FindByClass("logic_winlose")) do
			ent:Input("onhwin")
		end
	elseif winner == TEAM_BANDIT then
		for _, ent in pairs(ents.FindByClass("logic_winlose")) do
			ent:Input("onbwin")
		end
	else
		for _, ent in pairs(ents.FindByClass("logic_winlose")) do
			ent:Input("onlose")
		end
	end

	gamemode.Call("PostEndRound", winner)

	self:SetWaveStart(CurTime() + 9999)
end

function GM:WaveEndWithWinner(winner)
	self:SetCurrentWaveWinner(winner)
	gamemode.Call("SetWaveEnd",CurTime())
end
function GM:GetCurrentWaveWinner()
	return self.CurrentWaveWinner
end
function GM:SetCurrentWaveWinner(winner)
	self.CurrentWaveWinner = winner
end
function GM:PlayerReady(pl)
	gamemode.Call("PlayerReadyRound", pl)
end

function GM:PlayerReadyRound(pl)
	if not pl:IsValid() then return end

	self:FullGameUpdate(pl)

	if self.OverrideStartingWorth then
		pl:SendLua("GAMEMODE.StartingWorth="..tostring(self.StartingWorth))
	end
	if pl:Team() == TEAM_HUMAN or pl:Team() == TEAM_BANDIT then
		pl:SendLua("GAMEMODE:OpenPointsShop()")
	end

	if self.RoundEnded then
		pl:SendLua("gamemode.Call(\"EndRound\", "..tostring(ROUNDWINNER)..", \""..game.GetMapNext().."\")")
		gamemode.Call("DoHonorableMentions", pl)
	end
	
	if self:IsClassicMode() then
		pl:SendLua("SetGlobalBool(\"classicmode\", true)")
	end
end

function GM:FullGameUpdate(pl)
	net.Start("zs_gamestate")
		net.WriteInt(self:GetWave(), 16)
		net.WriteFloat(self:GetWaveStart())
		net.WriteFloat(self:GetWaveEnd())
	if pl then
		net.Send(pl)
	else
		net.Broadcast()
	end
end

concommand.Add("initpostentity", function(sender, command, arguments)
	if not sender.DidInitPostEntity then
		sender.DidInitPostEntity = true

		gamemode.Call("PlayerReady", sender)
	end
end)

local playerheight = Vector(0, 0, 72)
local playermins = Vector(-17, -17, 0)
local playermaxs = Vector(17, 17, 4)
local function groupsort(a, b)
	return #a > #b
end

function GM:PlayerInitialSpawn(pl)
	gamemode.Call("PlayerInitialSpawnRound", pl)
end

function GM:PlayerInitialSpawnRound(pl)
	pl:SprintDisable()
	if pl:KeyDown(IN_WALK) then
		pl:ConCommand("-walk")
	end

	pl:SetCanWalk(false)
	pl:SetCanZoom(false)
	pl:SetNoCollideWithTeammates(true)
	pl:SetCustomCollisionCheck(true)

	pl.EnemyKilled = 0
	pl.BountyModifier = 0
	pl.EnemyKilledAssists = 0

	pl.ResupplyBoxUsedByOthers = 0

	pl.WaveJoined = self:GetWave()

	pl.CrowKills = 0
	pl.CrowVsCrowKills = 0
	pl.CrowBarricadeDamage = 0

	pl.BarricadeDamage = 0
	pl.DynamicSpawnedOn = 0

	pl.NextPainSound = 0

	pl.BonusDamageCheck = 0

	pl.LegDamage = 0

	pl.DamageDealt = 0
	pl.ObjectiveSigilsTaken = 0
	pl.LifeBarricadeDamage = 0
	pl.LifeEnemyDamage = 0
	pl.LifeEnemyKills = 0
	
	pl.m_PointQueue = 0
	pl.m_LastDamageDealt = 0
	pl.m_PreRespawn = nil
	pl:AddPoints(15)
	pl.HealedThisRound = 0
	local nosend = not pl.DidInitPostEntity
	pl.CarryOverHealth = 0
	pl.RepairedThisRound = 0
	pl.CarryOverRepair = 0
	pl.PointsCommission = 0
	pl.CarryOverCommision = 0
	pl.NextRegenerate = 0
		pl.SpawnedTime = CurTime()
		if #team.GetPlayers(TEAM_BANDIT) == #team.GetPlayers(TEAM_HUMAN) then
			pl:ChangeTeam(math.random(3,4))
		elseif #team.GetPlayers(TEAM_BANDIT) > #team.GetPlayers(TEAM_HUMAN) then
			pl:ChangeTeam(TEAM_HUMAN)
		else
			pl:ChangeTeam(TEAM_BANDIT)
		end
end
function GM:ShuffleTeams()
	local newbandit,newhuman = 0,0
	for _, pl in pairs(player.GetAll()) do
		if newbandit == newhuman then
			pl:ChangeTeam(math.random(3,4))
			if pl:Team() == TEAM_BANDIT then newbandit = newbandit+1
			elseif pl:Team() == TEAM_HUMAN then newhuman = newhuman+1
			end
		elseif newbandit > newhuman then
			pl:ChangeTeam(TEAM_HUMAN)
			newhuman = newhuman+1
		elseif newbandit < newhuman then
			pl:ChangeTeam(TEAM_BANDIT)
			newbandit = newbandit+1
		end		
	end
end
function GM:GetDynamicSpawning()
	return self.DynamicSpawning
end

function GM:PlayerDisconnected(pl)
	pl.Disconnecting = true

	local uid = pl:UniqueID()

	self.PreviouslyDied[uid] = CurTime()

	pl:DropAll()

	if pl:Health() > 0 and not pl:IsSpectator() then
		local lastattacker = pl:GetLastAttacker()
		if IsValid(lastattacker) then
			pl:TakeDamage(1000, lastattacker, lastattacker)

			PrintTranslatedMessage(HUD_PRINTCONSOLE, "disconnect_killed", pl:Name(), lastattacker:Name())
		end
	end
end

-- Reevaluates a prop and its constraint system (or all props if no arguments) to determine if they should be frozen or not from nails.
function GM:EvaluatePropFreeze(ent, neighbors)
	if not ent then
		for _, e in pairs(ents.GetAll()) do
			if e and e:IsValid() then
				self:EvaluatePropFreeze(e)
			end
		end

		return
	end

	if ent:IsNailedToWorldHierarchy() then
		ent:SetNailFrozen(true)
	elseif ent:GetNailFrozen() then
		ent:SetNailFrozen(false)
	end

	neighbors = neighbors or {}
	table.insert(neighbors, ent)

	for _, nail in pairs(ent:GetNails()) do
		if nail:IsValid() then
			local baseent = nail:GetBaseEntity()
			local attachent = nail:GetAttachEntity()
			if baseent:IsValid() and not baseent:IsWorld() and not table.HasValue(neighbors, baseent) then
				self:EvaluatePropFreeze(baseent, neighbors)
			end
			if attachent:IsValid() and not attachent:IsWorld() and not table.HasValue(neighbors, attachent) then
				self:EvaluatePropFreeze(attachent, neighbors)
			end
		end
	end
end

-- A nail takes some damage. isdead is true if the damage is enough to remove the nail. The nail is invalid after this function call if it dies.
function GM:OnNailDamaged(ent, attacker, inflictor, damage, dmginfo)
end

-- A nail is removed between two entities. The nail is no longer considered valid right after this function and is not in the entities' Nails tables. remover may not be nil if it was removed with the hammer's unnail ability.
local function evalfreeze(ent)
	if ent and ent:IsValid() then
		gamemode.Call("EvaluatePropFreeze", ent)
	end
end
function GM:OnNailRemoved(nail, ent1, ent2, remover)
	if ent1 and ent1:IsValid() and not ent1:IsWorld() then
		timer.Simple(0, function() evalfreeze(ent1) end)
		timer.Simple(0.2, function() evalfreeze(ent1) end)
	end
	if ent2 and ent2:IsValid() and not ent2:IsWorld() then
		timer.Simple(0, function() evalfreeze(ent2) end)
		timer.Simple(0.2, function() evalfreeze(ent2) end)
	end

	if remover and remover:IsValid() and remover:IsPlayer() then
		local deployer = nail:GetDeployer()
		if deployer:IsValid() and deployer ~= remover and (deployer:Team() == TEAM_HUMAN or deployer:Team() == TEAM_BANDIT) then
			PrintTranslatedMessage(HUD_PRINTCONSOLE, "nail_removed_by", remover:Name(), deployer:Name())
		end
	end
end

-- A nail is created between two entities.
function GM:OnNailCreated(ent1, ent2, nail)
	if ent1 and ent1:IsValid() and not ent1:IsWorld() then
		timer.Simple(0, function() evalfreeze(ent1) end)
	end
	if ent2 and ent2:IsValid() and not ent2:IsWorld() then
		timer.Simple(0, function() evalfreeze(ent2) end)
	end
end

function GM:RemoveDuplicateAmmo(pl)
	local AmmoCounts = {}
	local WepAmmos = {}
	for _, wep in pairs(pl:GetWeapons()) do
		if wep.Primary then
			local ammotype = wep:ValidPrimaryAmmo()
			if ammotype and wep.Primary.DefaultClip > 0 then
				AmmoCounts[ammotype] = (AmmoCounts[ammotype] or 0) + 1
				WepAmmos[wep] = wep.Primary.DefaultClip - wep.Primary.ClipSize
			end
			local ammotype2 = wep:ValidSecondaryAmmo()
			if ammotype2 and wep.Secondary.DefaultClip > 0 then
				AmmoCounts[ammotype2] = (AmmoCounts[ammotype2] or 0) + 1
				WepAmmos[wep] = wep.Secondary.DefaultClip - wep.Secondary.ClipSize
			end
		end
	end
	for ammotype, count in pairs(AmmoCounts) do
		if count > 1 then
			local highest = 0
			local highestwep
			for wep, extraammo in pairs(WepAmmos) do
				if wep.Primary.Ammo == ammotype then
					highest = math.max(highest, extraammo)
					highestwep = wep
				end
			end
			if highestwep then
				for wep, extraammo in pairs(WepAmmos) do
					if wep ~= highestwep and wep.Primary.Ammo == ammotype then
						pl:RemoveAmmo(extraammo, ammotype)
					end
				end
			end
		end
	end
end

local function TimedOut(pl)
	if pl:IsValid() and pl:Alive() and (pl:Team() == TEAM_HUMAN or pl:Team() == TEAM_BANDIT) and not GAMEMODE.CheckedOut[pl:UniqueID()] then
		--gamemode.Call("GiveRandomEquipment", pl)
	end
end
--[[
function GM:GiveDefaultOrRandomEquipment(pl)
	if not self.CheckedOut[pl:UniqueID()] then
		if self.StartingLoadout then
			self:GiveStartingLoadout(pl)
		else
			pl:SendLua("GAMEMODE:RequestedDefaultCart()")
			if self.StartingWorth > 0 then
				timer.Simple(4, function() TimedOut(pl) end)
			end
		end
	end
end

function GM:GiveStartingLoadout(pl)
	for item, amount in pairs(self.StartingLoadout) do
		for i=1, amount do
			pl:Give(item)
		end
	end
end

function GM:GiveRandomEquipment(pl)
	if self.CheckedOut[pl:UniqueID()] then return end
	self.CheckedOut[pl:UniqueID()] = true

	if self.StartingLoadout then
		self:GiveStartingLoadout(pl)
	elseif GAMEMODE.OverrideStartingWorth then
		pl:Give("weapon_zs_swissarmyknife")
	elseif #self.StartLoadouts >= 1 then
		for _, id in pairs(self.StartLoadouts[math.random(#self.StartLoadouts)]) do
			local tab = FindStartingItem(id)
			if tab then
				if tab.Callback then
					tab.Callback(pl)
				elseif tab.SWEP then
					pl:StripWeapon(tab.SWEP)
					pl:Give(tab.SWEP)
				end
			end
		end
	end
end

function GM:PlayerCanCheckout(pl)
	return pl:IsValid() and (pl:Team() == TEAM_HUMAN or pl:Team() == TEAM_BANDIT) and pl:Alive() and not self.CheckedOut[pl:UniqueID()] and not self.StartingLoadout and self.StartingWorth > 0
end]]

concommand.Add("zs_pointsshopbuy", function(sender, command, arguments)
	if not (sender:IsValid() and sender:IsConnected()) or #arguments == 0 then return end

	if sender:GetUnlucky() then
		sender:CenterNotify(COLOR_RED, translate.ClientGet(sender, "banned_for_life_warning"))
		sender:SendLua("surface.PlaySound(\"buttons/button10.wav\")")
		return
	end

	--[[if not sender:NearArsenalCrate() then
		sender:CenterNotify(COLOR_RED, translate.ClientGet(sender, "need_to_be_near_arsenal_crate"))
		sender:SendLua("surface.PlaySound(\"buttons/button10.wav\")")
		return
	end]]

	local itemtab
	local id = arguments[1]
	local num = tonumber(id)
	if num then
		itemtab = GAMEMODE.Items[num]
	else
		for i, tab in pairs(GAMEMODE.Items) do
			if tab.Signature == id then
				itemtab = tab
				break
			end
		end
	end

	if not itemtab then return end
	if not (gamemode.Call("PlayerCanPurchase", sender) and not (itemtab.SWEP and sender:HasWeapon(itemtab.SWEP))) then
		sender:CenterNotify(COLOR_RED, translate.ClientGet(sender, "cant_purchase_right_now"))
		sender:SendLua("surface.PlaySound(\"buttons/button10.wav\")")
		return
	end
	local points = sender:GetPoints()
	local cost = itemtab.Worth
	if not GAMEMODE:GetWaveActive() then
		cost = cost * GAMEMODE.ArsenalCrateMultiplier
	end

	cost = math.ceil(cost)
	if GAMEMODE:IsClassicMode() and itemtab.NoClassicMode then
		sender:CenterNotify(COLOR_RED, translate.ClientFormat(sender, "cant_use_x_in_classic_mode", itemtab.Name))
		sender:SendLua("surface.PlaySound(\"buttons/button10.wav\")")
		return
	end
	if points < cost then
		sender:CenterNotify(COLOR_RED, translate.ClientGet(sender, "dont_have_enough_points"))
		sender:SendLua("surface.PlaySound(\"buttons/button10.wav\")")
		return
	end

	if itemtab.Callback then
		itemtab.Callback(sender)
	elseif itemtab.SWEP then
		if sender:HasWeapon(itemtab.SWEP) then
			local stored = weapons.GetStored(itemtab.SWEP)
			if stored and stored.AmmoIfHas then
				sender:GiveAmmo(stored.Primary.DefaultClip, stored.Primary.Ammo)
			else
				local wep = ents.Create("prop_weapon")
				if wep:IsValid() then
					wep:SetPos(sender:GetShootPos())
					wep:SetAngles(sender:GetAngles())
					wep:SetWeaponType(itemtab.SWEP)
					wep:SetShouldRemoveAmmo(true)
					wep:Spawn()
				end
			end
		else
			local wep = sender:Give(itemtab.SWEP)
			if wep and wep:IsValid() and wep.EmptyWhenPurchased and wep:GetOwner():IsValid() then
				if wep.Primary then
					local primary = wep:ValidPrimaryAmmo()
					if primary then
						sender:RemoveAmmo(math.max(0, wep.Primary.DefaultClip - wep.Primary.ClipSize), primary)
					end
				end
				if wep.Secondary then
					local secondary = wep:ValidSecondaryAmmo()
					if secondary then
						sender:RemoveAmmo(math.max(0, wep.Secondary.DefaultClip - wep.Secondary.ClipSize), secondary)
					end
				end
			end
		end
	else
		return
	end

	sender:TakePoints(cost)
	sender:PrintTranslatedMessage(HUD_PRINTTALK, "purchased_x_for_y_points", itemtab.Name, cost)
	sender:SendLua("surface.PlaySound(\"ambient/levels/labs/coinslot1.wav\")")

	--[[local nearest = sender:NearestArsenalCrateOwnedByOther()
	if nearest then
		local owner = nearest:GetObjectOwner()
		if owner:IsValid() then
			local nonfloorcommission = cost * 0.07
			local commission = math.floor(nonfloorcommission)
			if commission > 0 then
				owner.PointsCommission = owner.PointsCommission + cost

				owner:AddPoints(commission)

				net.Start("zs_commission")
					net.WriteEntity(nearest)
					net.WriteEntity(sender)
					net.WriteUInt(commission, 16)
				net.Send(owner)
			end

			local leftover = nonfloorcommission - commission
			if leftover > 0 then
				owner.CarryOverCommision = owner.CarryOverCommision + leftover
				if owner.CarryOverCommision >= 1 then
					local carried = math.floor(owner.CarryOverCommision)
					owner.CarryOverCommision = owner.CarryOverCommision - carried
					owner:AddPoints(carried)

					net.Start("zs_commission")
						net.WriteEntity(nearest)
						net.WriteEntity(sender)
						net.WriteUInt(carried, 16)
					net.Send(owner)
				end
			end
		end
	end]]
end)
--[[
concommand.Add("worthrandom", function(sender, command, arguments)
	if sender:IsValid() and sender:IsConnected() and gamemode.Call("PlayerCanCheckout", sender) then
		gamemode.Call("GiveRandomEquipment", sender)
	end
end)

concommand.Add("worthcheckout", function(sender, command, arguments)
	if not (sender:IsValid() and sender:IsConnected()) or #arguments == 0 then return end

	if not gamemode.Call("PlayerCanCheckout", sender) then
		sender:CenterNotify(COLOR_RED, translate.ClientGet(sender, "cant_use_worth_anymore"))
		return
	end

	local cost = 0
	local hasalready = {}

	for _, id in pairs(arguments) do
		local tab = FindStartingItem(id)
		if tab and not hasalready[id] then
			cost = cost + tab.Worth
			hasalready[id] = true
		end
	end

	if cost > GAMEMODE.StartingWorth then return end

	local hasalready = {}

	for _, id in pairs(arguments) do
		local tab = FindStartingItem(id)
		if tab and not hasalready[id] then
			if tab.Callback then
				tab.Callback(sender)
				hasalready[id] = true
			elseif tab.SWEP then
				sender:StripWeapon(tab.SWEP) -- "Fixes" players giving each other empty weapons to make it so they get no ammo from the Worth menu purchase.
				sender:Give(tab.SWEP)
				hasalready[id] = true
			end
		end
	end

	if table.Count(hasalready) > 0 then
		GAMEMODE.CheckedOut[sender:UniqueID()] = true
	end

	gamemode.Call("RemoveDuplicateAmmo", sender)
end)]]

function GM:PlayerDeathThink(pl)
	if self.RoundEnded or pl.Revive then return end

	if pl:GetObserverMode() == OBS_MODE_CHASE then
		local target = pl:GetObserverTarget()
		if not target or not target:IsValid() or not target:IsPlayer() then
			pl:StripWeapons()
			pl:Spectate(OBS_MODE_DEATHCAM)
			pl:SpectateEntity(NULL)
		end
	end

	if pl.NextSpawnTime and pl.NextSpawnTime <= CurTime() and pl:KeyPressed(IN_ATTACK) then -- Force spawn.
		net.Start("zs_playerrespawntime")
			net.WriteFloat(-1)
			net.WriteEntity(pl)
		net.Broadcast()
		if not self:IsClassicMode() then 
		pl.m_PreRespawn = true
		pl:UnSpectateAndSpawn()
		local teamspawns = {}
		teamspawns = team.GetValidSpawnPoint(pl:Team())
		pl:SetPos(teamspawns[ math.random(#teamspawns) ]:GetPos())
		pl.m_PreRespawn = nil
		pl.SpawnedTime = CurTime()
		pl.NextSpawnTime = nil
		net.Start("zs_playerredeemed")
			net.WriteEntity(pl)
			net.WriteString(pl:Name())
		net.Broadcast()	
		end
	elseif pl:GetObserverMode() == OBS_MODE_NONE then -- Not in spectator yet.
		if self:GetWaveActive() then -- During wave.
			if not pl.StartSpectating or CurTime() >= pl.StartSpectating then
				pl.StartSpectating = nil
				pl:StripWeapons()
				pl:Spectate(OBS_MODE_DEATHCAM)
				pl:SpectateEntity(NULL)
			end
			
		end
	else -- In spectator.
		if pl:KeyPressed(IN_ATTACK2) then
			pl.SpectatedPlayerKey = (pl.SpectatedPlayerKey or 0) + 1

			local living = {}
			for _, v in pairs(team.GetPlayers(pl:Team())) do
				if v:Alive() then table.insert(living, v) end
			end

			pl:StripWeapons()

			if pl.SpectatedPlayerKey > #living then
				pl.SpectatedPlayerKey = 1
			end

			local specplayer = living[pl.SpectatedPlayerKey]
			if specplayer then
				pl:Spectate(OBS_MODE_CHASE)
				pl:SpectateEntity(specplayer)
			end
		--[[elseif pl:KeyPressed(IN_JUMP) then
			pl:Spectate(OBS_MODE_ROAMING)
			pl:SpectateEntity(NULL)
			pl.SpectatedPlayerKey = nil]]
		end
	end
end

function GM:CanRespawnQuicker(ply)
	if ply == nil or not ply:IsPlayer() then return false end
	local banditsigils, humansigils = 0,0
	for _, ent in pairs(ents.FindByClass("prop_obj_sigil")) do
		if ent:GetSigilCaptureProgress() > 0 then
			if ent:GetSigilTeam() == TEAM_BANDIT then
				banditsigils = banditsigils + 1
			elseif ent:GetSigilTeam() == TEAM_HUMAN then
				humansigils = humansigils + 1
			end
		end
	end
	if (banditsigils < humansigils and ply:Team() == TEAM_BANDIT) or (humansigils < banditsigils and ply:Team() == TEAM_HUMAN) then
		--ply:CenterNotify(COLOR_RED, translate.ClientGet(pl, "respawn_quicker"))
		return true
	else
		return false
	end
end

function GM:PropBreak(attacker, ent)
	gamemode.Call("PropBroken", ent, attacker)
end

function GM:PropBroken(ent, attacker)
end

function GM:NestDestroyed(ent, attacker)
end

function GM:EntityTakeDamage(ent, dmginfo)
	local attacker, inflictor = dmginfo:GetAttacker(), dmginfo:GetInflictor()

	if attacker == inflictor and attacker:IsProjectile() and dmginfo:GetDamageType() == DMG_CRUSH then -- Fixes projectiles doing physics-based damage.
		dmginfo:SetDamage(0)
		dmginfo:ScaleDamage(0)
		return
	end

	if ent._BARRICADEBROKEN then
		dmginfo:SetDamage(dmginfo:GetDamage() * 3)
	end

	if ent.GetObjectHealth then
		ent.m_LastDamaged = CurTime()
	end

	if ent.ProcessDamage and ent:ProcessDamage(dmginfo) then return end
	attacker, inflictor = dmginfo:GetAttacker(), dmginfo:GetInflictor()

	-- Don't allow blowing up props during wave 0.
	if self:GetWave() <= 0 and string.sub(ent:GetClass(), 1, 12) == "prop_physics" and inflictor.NoPropDamageDuringWave0 then
		dmginfo:SetDamage(0)
		dmginfo:SetDamageType(DMG_BULLET)
		return
	end

	-- We need to stop explosive chains team killing.
	if inflictor:IsValid() then
		local dmgtype = dmginfo:GetDamageType()
		if dmgtype == DMG_BLAST or dmgtype == DMG_BURN or dmgtype == DMG_SLOWBURN then
			if ent:IsPlayer() then
				if ent.EOD then
					dmginfo:ScaleDamage(0.25)
				end
				if inflictor.LastExplosionTeam == ent:Team() and inflictor.LastExplosionAttacker ~= ent and inflictor.LastExplosionTime and CurTime() < inflictor.LastExplosionTime + 10 then -- Player damaged by physics object explosion / fire.
					dmginfo:SetDamage(0)
					dmginfo:ScaleDamage(0)
					return
				end
			elseif inflictor ~= ent and string.sub(ent:GetClass(), 1, 12) == "prop_physics" and string.sub(inflictor:GetClass(), 1, 12) == "prop_physics" then -- Physics object damaged by physics object explosion / fire.
				ent.LastExplosionAttacker = inflictor.LastExplosionAttacker
				ent.LastExplosionTeam = inflictor.LastExplosionTeam
				ent.LastExplosionTime = CurTime()
			end
		elseif inflictor:IsPlayer() and string.sub(ent:GetClass(), 1, 12) == "prop_physics" then -- Physics object damaged by player.
			if ent:IsPlayer() and inflictor:Team() == ent:Team() then
				local phys = ent:GetPhysicsObject()
				if phys:IsValid() and phys:HasGameFlag(FVPHYSICS_PLAYER_HELD) and inflictor:GetCarry() ~= ent or ent._LastDropped and CurTime() < ent._LastDropped + 3 and ent._LastDroppedBy ~= inflictor then -- Human player damaged a physics object while it was being carried or recently carried. They weren't the carrier.
					dmginfo:SetDamage(0)
					dmginfo:ScaleDamage(0)
					return
				end
			end

			ent.LastExplosionAttacker = inflictor
			ent.LastExplosionTeam = inflictor:Team()
			ent.LastExplosionTime = CurTime()
		end
	end

	-- Prop is nailed. Forward damage to the nails.
	if ent:DamageNails(attacker, inflictor, dmginfo:GetDamage(), dmginfo) then return end

	local dispatchdamagedisplay = false

	local entclass = ent:GetClass()

	if ent:IsPlayer() then
		dispatchdamagedisplay = true
		if (attacker:IsPlayer() and attacker ~= ent) then
			local activewep = attacker:GetActiveWeapon()
			local dmgtype = dmginfo:GetDamageType()
			local head = (ent:LastHitGroup() == HITGROUP_HEAD)
			if dmgtype ~= DMG_BLAST or dmgtype ~= DMG_BURN or dmgtype ~= DMG_SLOWBURN then
				net.Start( "zs_hitmarker" )
					net.WriteBool( ent:IsPlayer() )
					net.WriteBool( head )
				net.Send( attacker )
			end
		end
	elseif ent.PropHealth then -- A prop that was invulnerable and converted to vulnerable.
		if self.NoPropDamageFromHumanMelee and attacker:IsPlayer() and (attacker:Team() == TEAM_HUMAN or attacker:Team() == TEAM_BANDIT) and inflictor.IsMelee then
			dmginfo:SetDamage(0)
			return
		end

		if gamemode.Call("ShouldAntiGrief", ent, attacker, dmginfo, ent.PropHealth) then
			attacker:AntiGrief(dmginfo)
			if dmginfo:GetDamage() <= 0 then return end
		end

		ent.PropHealth = ent.PropHealth - dmginfo:GetDamage()

		dispatchdamagedisplay = true

		if ent.PropHealth <= 0 then
			local effectdata = EffectData()
				effectdata:SetOrigin(ent:GetPos())
			util.Effect("Explosion", effectdata, true, true)
			ent:Fire("break")

			gamemode.Call("PropBroken", ent, attacker)
		else
			local brit = math.Clamp(ent.PropHealth / ent.TotalHealth, 0, 1)
			local col = ent:GetColor()
			col.r = 255
			col.g = 255 * brit
			col.b = 255 * brit
			ent:SetColor(col)
		end
	elseif entclass == "func_door_rotating" then
		if ent:GetKeyValues().damagefilter == "invul" or ent.Broken then return end

		if not ent.Heal then
			local br = ent:BoundingRadius()
			--if br > 80 then return end -- Don't break these kinds of doors that are bigger than this.

			local health = br * 35
			ent.Heal = health
			ent.TotalHeal = health
		end

		if gamemode.Call("ShouldAntiGrief", ent, attacker, dmginfo, ent.TotalHeal) then
			attacker:AntiGrief(dmginfo)
			if dmginfo:GetDamage() <= 0 then return end
		end

		if dmginfo:GetDamage() >= 20 and attacker:IsPlayer() and (attacker:Team() == TEAM_HUMAN or attacker:Team() == TEAM_BANDIT) then
			ent:EmitSound(math.random(2) == 1 and "npc/zombie/zombie_pound_door.wav" or "ambient/materials/door_hit1.wav")
		end

		ent.Heal = ent.Heal - dmginfo:GetDamage()
		local brit = math.Clamp(ent.Heal / ent.TotalHeal, 0, 1)
		local col = ent:GetColor()
		col.r = 255
		col.g = 255 * brit
		col.b = 255 * brit
		ent:SetColor(col)

		dispatchdamagedisplay = true

		if ent.Heal <= 0 then
			ent.Broken = true

			ent:EmitSound("Breakable.Metal")
			ent:Fire("unlock", "", 0)
			ent:Fire("open", "", 0.01) -- Trigger any area portals.
			ent:Fire("break", "", 0.1)
			ent:Fire("kill", "", 0.15)
		end
	elseif entclass == "prop_door_rotating" then
		--if ent:GetKeyValues().damagefilter == "invul" or ent:HasSpawnFlags(2048) or ent.Broken then return end

		ent.Heal = ent.Heal or ent:BoundingRadius() * 35
		ent.TotalHeal = ent.TotalHeal or ent.Heal

		if gamemode.Call("ShouldAntiGrief", ent, attacker, dmginfo, ent.TotalHeal) then
			attacker:AntiGrief(dmginfo)
			if dmginfo:GetDamage() <= 0 then return end
		end

		if dmginfo:GetDamage() >= 20 and attacker:IsPlayer() then
			ent:EmitSound(math.random(2) == 1 and "npc/zombie/zombie_pound_door.wav" or "ambient/materials/door_hit1.wav")
		end

		ent.Heal = ent.Heal - dmginfo:GetDamage()
		local brit = math.Clamp(ent.Heal / ent.TotalHeal, 0, 1)
		local col = ent:GetColor()
		col.r = 255
		col.g = 255 * brit
		col.b = 255 * brit
		ent:SetColor(col)

		dispatchdamagedisplay = true

		if ent.Heal <= 0 then
			ent.Broken = true

			ent:EmitSound("Breakable.Metal")
			ent:Fire("unlock", "", 0)
			ent:Fire("open", "", 0.01) -- Trigger any area portals.
			ent:Fire("break", "", 0.1)
			ent:Fire("kill", "", 0.15)

			local physprop = ents.Create("prop_physics")
			if physprop:IsValid() then
				physprop:SetPos(ent:GetPos())
				physprop:SetAngles(ent:GetAngles())
				physprop:SetSkin(ent:GetSkin() or 0)
				physprop:SetMaterial(ent:GetMaterial())
				physprop:SetModel(ent:GetModel())
				physprop:Spawn()
				physprop:SetPhysicsAttacker(attacker)
				if attacker:IsValid() then
					local phys = physprop:GetPhysicsObject()
					if phys:IsValid() then
						phys:SetVelocityInstantaneous((physprop:NearestPoint(attacker:EyePos()) - attacker:EyePos()):GetNormalized() * math.Clamp(dmginfo:GetDamage() * 3, 40, 300))
					end
				end
				if physprop:GetMaxHealth() == 1 and physprop:Health() == 0 then
					local health = math.ceil((physprop:OBBMins():Length() + physprop:OBBMaxs():Length()) * 2)
					if health < 2000 then
						physprop.PropHealth = health
						physprop.TotalHealth = health
					end
				end
			end
		end
	elseif string.sub(entclass, 1, 12) == "func_physbox" then
		local holder, status = ent:GetHolder()
		if holder then status:Remove() end

		if ent:GetKeyValues().damagefilter == "invul" then return end

		ent.Heal = ent.Heal or ent:BoundingRadius() * 35
		ent.TotalHeal = ent.TotalHeal or ent.Heal

		if gamemode.Call("ShouldAntiGrief", ent, attacker, dmginfo, ent.TotalHeal) then
			attacker:AntiGrief(dmginfo)
			if dmginfo:GetDamage() <= 0 then return end
		end

		ent.Heal = ent.Heal - dmginfo:GetDamage()
		local brit = math.Clamp(ent.Heal / ent.TotalHeal, 0, 1)
		local col = ent:GetColor()
		col.r = 255
		col.g = 255 * brit
		col.b = 255 * brit
		ent:SetColor(col)

		dispatchdamagedisplay = true

		if ent.Heal <= 0 then
			local foundaxis = false
			local entname = ent:GetName()
			local allaxis = ents.FindByClass("phys_hinge")
			for _, axis in pairs(allaxis) do
				local keyvalues = axis:GetKeyValues()
				if keyvalues.attach1 == entname or keyvalues.attach2 == entname then
					foundaxis = true
					axis:Remove()
					ent.Heal = ent.Heal + 120
				end
			end

			if not foundaxis then
				ent:Fire("break", "", 0)
			end
		end
	elseif entclass == "func_breakable" then
		if ent:GetKeyValues().damagefilter == "invul" then return end

		if gamemode.Call("ShouldAntiGrief", ent, attacker, dmginfo, ent:GetMaxHealth()) then
			attacker:AntiGrief(dmginfo, true)
			if dmginfo:GetDamage() <= 0 then return end
		end

		if ent:Health() == 0 and ent:GetMaxHealth() == 1 then return end

		local brit = math.Clamp(ent:Health() / ent:GetMaxHealth(), 0, 1)
		local col = ent:GetColor()
		col.r = 255
		col.g = 255 * brit
		col.b = 255 * brit
		ent:SetColor(col)

		dispatchdamagedisplay = true
	elseif ent:IsBarricadeProp() and attacker:IsPlayer() then
		dispatchdamagedisplay = true
	end
	if dmginfo:GetDamage() > 0 then
		local holder, status = ent:GetHolder()
		if holder then status:Remove() end

		if attacker:IsPlayer() and dispatchdamagedisplay then
			self:DamageFloater(attacker, ent, dmginfo)
		end
	end
end

function GM:DamageFloater(attacker, victim, dmginfo)
	local dmgpos = dmginfo:GetDamagePosition()
	if dmgpos == vector_origin then dmgpos = victim:NearestPoint(attacker:EyePos()) end

	net.Start(victim:IsPlayer() and "zs_dmg" or "zs_dmg_prop")
		if INFDAMAGEFLOATER then
			INFDAMAGEFLOATER = nil
			net.WriteUInt(9999, 16)
		else
			net.WriteUInt(math.ceil(dmginfo:GetDamage()), 16)
		end
		net.WriteVector(dmgpos)
	net.Send(attacker)
end

function GM:OnPlayerChangedTeam(pl, oldteam, newteam)
	if newteam == TEAM_HUMAN or newteam == TEAM_BANDIT then
		pl.DamagedBy = {}
		self.PreviouslyDied[pl:UniqueID()] = nil
		pl:SetBarricadeGhosting(false)
		--self.CheckedOut[pl:UniqueID()] = true
	end

	pl:SetLastAttacker(nil)
	for _, p in pairs(player.GetAll()) do
		if p.LastAttacker == pl then
			p.LastAttacker = nil
		end
	end

	pl.m_PointQueue = 0
end


function GM:SetClassicMode(mode)

	self.ClassicMode = mode 

	SetGlobalBool("classicmode", self.ClassicMode)

end

function GM:AllowPlayerPickup(pl, ent)
	return false
end

function GM:PlayerShouldTakeDamage(pl, attacker)
	if attacker.PBAttacker and attacker.PBAttacker:IsValid() and CurTime() < attacker.NPBAttacker then -- Protection against prop_physbox team killing. physboxes don't respond to SetPhysicsAttacker()
		attacker = attacker.PBAttacker
	end

	if attacker:IsPlayer() and attacker ~= pl and not attacker.AllowTeamDamage and not pl.AllowTeamDamage and attacker:Team() == pl:Team() then return false end

	return true
end

function GM:PlayerHurt(victim, attacker, healthremaining, damage)
	if 0 < healthremaining then
		victim:PlayPainSound()
	end

	if (victim:Team() == TEAM_HUMAN or victim:Team() == TEAM_BANDIT) then
		victim.BonusDamageCheck = CurTime()

		if healthremaining < 75 and 1 <= healthremaining then
			victim:ResetSpeed(nil, healthremaining)
		end
	end

	if attacker:IsValid() then
		if attacker:IsPlayer() then
			victim:SetLastAttacker(attacker)

			local myteam = attacker:Team()
			local otherteam = victim:Team()
			if myteam ~= otherteam then
				damage = math.min(damage, victim.m_PreHurtHealth)
				victim.m_PreHurtHealth = healthremaining

				attacker.DamageDealt = attacker.DamageDealt + damage

				attacker:AddLifeEnemyDamage(damage)
				victim.DamagedBy[attacker] = (victim.DamagedBy[attacker] or 0) + damage
				attacker.m_PointQueue = attacker.m_PointQueue + damage / victim:GetMaxHealth() * victim:GetBounty() + math.floor(victim:GetPoints()/150)
				attacker.m_LastDamageDealtPosition = victim:GetPos()
				attacker.m_LastDamageDealt = CurTime()
			end
		elseif attacker:GetClass() == "trigger_hurt" then
			victim.LastHitWithTriggerHurt = CurTime()
		end
	end
end

-- Don't change speed instantly to stop people from shooting and then running away with a faster weapon.
function GM:WeaponDeployed(pl, wep)
	local timername = tostring(pl).."speedchange"
	timer.Destroy(timername)

	local speed = pl:ResetSpeed(true) -- Determine what speed we SHOULD get without actually setting it.
	if speed < pl:GetMaxSpeed() then
		pl:SetSpeed(speed)
	elseif pl:GetMaxSpeed() < speed then
		timer.CreateEx(timername, 0.333, 1, ValidFunction, pl, "SetHumanSpeed", speed)
	end
end

function GM:KeyPress(pl, key)
	if key == IN_USE then
		if (pl:Team() == TEAM_HUMAN or pl:Team() == TEAM_BANDIT) and pl:Alive() then
			if pl:IsCarrying() then
				pl.status_human_holding:RemoveNextFrame()
			else
				self:TryHumanPickup(pl, pl:TraceLine(64).Entity)
			end
		end
	elseif key == IN_SPEED then
		if pl:Alive() then
			if (pl:Team() == TEAM_HUMAN or pl:Team() == TEAM_BANDIT) then
				pl:DispatchAltUse()
			end
		end
	elseif key == IN_ZOOM then
		if (pl:Team() == TEAM_HUMAN or pl:Team() == TEAM_BANDIT) and pl:Alive() and pl:IsOnGround() then -- and not self.ZombieEscape and pl:GetGroundEntity():IsWorld() then
			pl:SetBarricadeGhosting(true)
		end
	end
end

function GM:GetNearestSpawn(pos, teamid)
	local nearest = NULL

	local nearestdist = math.huge
	for _, ent in pairs(team.GetValidSpawnPoint(teamid)) do
		if ent.Disabled then continue end

		local dist = ent:GetPos():Distance(pos)
		if dist < nearestdist then
			nearestdist = dist
			nearest = ent
		end
	end

	return nearest
end

function GM:EntityWouldBlockSpawn(ent)
	local spawnpoint = self:GetNearestSpawn(ent:GetPos(), TEAM_BANDIT)

	if spawnpoint:IsValid() then
		local spawnpos = spawnpoint:GetPos()
		if spawnpos:Distance(ent:NearestPoint(spawnpos)) <= 40 then return true end
	end

	return false
end

function GM:GetNearestSpawnDistance(pos, teamid)
	local nearest = self:GetNearestSpawn(pos, teamid)
	if nearest:IsValid() then
		return nearest:GetPos():Distance(pos)
	end

	return -1
end

function GM:PlayerUse(pl, ent)
	if not pl:Alive() or pl:GetBarricadeGhosting() then return false end

	if pl:IsHolding() and pl:GetHolding() ~= ent then return false end

	local entclass = ent:GetClass()
	if entclass == "prop_door_rotating" then
		if CurTime() < (ent.m_AntiDoorSpam or 0) then -- Prop doors can be glitched shut by mashing the use button.
			return false
		end
		ent.m_AntiDoorSpam = CurTime() + 1
	elseif (pl:Team() == TEAM_HUMAN or pl:Team() == TEAM_BANDIT) and not pl:IsCarrying() and pl:KeyPressed(IN_USE) then
		self:TryHumanPickup(pl, ent)
	end

	return true
end

function GM:PlayerDeath(pl, inflictor, attacker)
	pl.NextSpawnTime = nil
	if self.PreviouslyDied[pl:UniqueID()]<=CurTime() or pl.NextSpawnTime == nil and not self:IsClassicMode() then
		pl.NextSpawnTime = CurTime()+16*(self:CanRespawnQuicker(pl) and 0.5 or 1)
		net.Start("zs_playerrespawntime")
			net.WriteFloat(pl.NextSpawnTime)
			net.WriteEntity(pl)
		net.Broadcast()
	end
end
function GM:PostPlayerDeath(pl)
	local banditcount = 0
	local humancount = 0
	for _, bandit in pairs(team.GetPlayers(TEAM_BANDIT)) do
		if bandit:Alive() then banditcount = banditcount +1 end
	end
	for _, human in pairs(team.GetPlayers(TEAM_HUMAN)) do
		if human:Alive() then humancount = humancount +1 end
	end

	if self:GetWaveActive() and self:IsClassicMode() then 
		if humancount == 0 and banditcount >=1 then
			timer.Simple(2, function() gamemode.Call("WaveEndWithWinner", TEAM_BANDIT) end)
			for _, pl in pairs(player.GetAll()) do
				pl:CenterNotify(COLOR_DARKGREEN, translate.ClientFormat(pl, "x_killed_all_enemies",translate.ClientGet(pl,"teamname_bandit")))
			end
		elseif banditcount == 0 and humancount >=1 then
			timer.Simple(2, function() gamemode.Call("WaveEndWithWinner", TEAM_HUMAN) end)
			for _, pl in pairs(player.GetAll()) do
				pl:CenterNotify(COLOR_DARKGREEN, translate.ClientFormat(pl, "x_killed_all_enemies",translate.ClientGet(pl,"teamname_human")))
			end
		end
	end
end
function GM:PlayerDeathSound()
	return true
end

local function SortDist(a, b)
	return a._temp < b._temp
end
function GM:CanPlayerSuicide(pl)
	if self.RoundEnded or pl:HasWon() then return false end

	if pl:Team() == TEAM_HUMAN or pl:Team() == TEAM_BANDIT then
		if self:GetWave() <= self.NoSuicideWave then
			pl:PrintTranslatedMessage(HUD_PRINTCENTER, "give_time_before_suicide")
			return false
		end

		if not IsValid(pl:GetLastAttacker()) then
		end
	end

	return pl:GetObserverMode() == OBS_MODE_NONE and pl:Alive() and (not pl.SpawnNoSuicide or pl.SpawnNoSuicide < CurTime())
end

function GM:PlayerKilledEnemy(pl, attacker, inflictor, dmginfo, headshot, suicide)

	-- Simply distributes based on damage but also do some stuff for assists.

	local totaldamage = 0
	for otherpl, dmg in pairs(pl.DamagedBy) do
		if otherpl:IsValid() and otherpl:Team() ~= pl:Team() then
			totaldamage = totaldamage + dmg
		end
	end

	local mostassistdamage = 0
	local halftotaldamage = totaldamage / 2
	local mostdamager
	for otherpl, dmg in pairs(pl.DamagedBy) do
		if otherpl ~= attacker and otherpl:IsValid() and otherpl:Team() ~= pl:Team() and dmg > mostassistdamage and dmg >= halftotaldamage then
			mostassistdamage = dmg
			mostdamager = otherpl
		end
	end
	attacker:AddLifeEnemyKills(1)
	attacker:SetKills(attacker:GetKills()+1)
	attacker.EnemyKilled = attacker.EnemyKilled + 1
	if attacker.BountyModifier < 0 then
		attacker.BountyModifier = 0
	else
		attacker.BountyModifier = attacker.BountyModifier+5
	end
	if mostdamager then
		attacker:PointCashOut(pl, FM_LOCALKILLOTHERASSIST)
		mostdamager:PointCashOut(pl, FM_LOCALASSISTOTHERKILL)

		mostdamager.EnemyKilledAssists = mostdamager.EnemyKilledAssists + 1
	else
		attacker:PointCashOut(pl, FM_NONE)
	end
	local killerstreak = attacker.LifeEnemyKills
	if killerstreak > 1 then
		--PrintMessage( HUD_PRINTCENTER, attacker:Name().."님의 "..attacker.LifeEnemyKills.."연킬!" )
	end
	net.Start("zs_killstreak")
		net.WriteEntity(attacker)
		net.WriteInt(killerstreak,16)
		net.WriteString(attacker:Name())
	net.Broadcast()	
	gamemode.Call("PostPlayerKilledEnemy", pl, attacker, inflictor, dmginfo, mostdamager, mostassistdamage, headshot)

	return mostdamager
end

function GM:PostPlayerKilledEnemy(pl, attacker, inflictor, dmginfo, assistpl, assistamount, headshot)
end

function GM:DoPlayerDeath(pl, attacker, dmginfo)
	pl:RemoveStatus("confusion", false, true)
	pl:RemoveStatus("ghoultouch", false, true)
	pl:RemoveStatus("bleed", false, true)
	pl.AmmoPickups = nil
	pl.WeaponPickups = nil
	self.CheckedOut[pl:UniqueID()] = false
	local inflictor = dmginfo:GetInflictor()
	local plteam = pl:Team()
	local ct = CurTime()
	local suicide = attacker == pl or attacker:IsWorld()
	if not suicide then
		if pl.BountyModifier >0 then
			pl.BountyModifier = 0
			if pl.BountyModifier > -20 then
				if pl.BountyModifier < -10 then
					pl.BountyModifier = pl.BountyModifier-2
				end
				pl.BountyModifier = pl.BountyModifier-2
			end
		end
	end
	pl:Freeze(false)

	local headshot = pl:LastHitGroup() == HITGROUP_HEAD and pl.m_LastHeadShot and CurTime() <= pl.m_LastHeadShot + 0.1
	
	if suicide then attacker = pl:GetLastAttacker() or attacker end
	pl:SetLastAttacker()
	
	if inflictor == NULL then inflictor = attacker end

	if inflictor == attacker and attacker:IsPlayer() then
		local wep = attacker:GetActiveWeapon()
		if wep:IsValid() then
			inflictor = wep
		end
	end

	if headshot then
		local effectdata = EffectData()
			effectdata:SetOrigin(dmginfo:GetDamagePosition())
			local force = dmginfo:GetDamageForce()
			effectdata:SetMagnitude(force:Length() * 3)
			effectdata:SetNormal(force:GetNormalized())
			effectdata:SetEntity(pl)
		util.Effect("headshot", effectdata, true, true)
	end

	
	if pl:Health() <= -70 and not pl.NoGibs then
		pl:Gib(dmginfo)
	else
		pl:CreateRagdoll()
	end

	pl:RemoveStatus("overridemodel", false, true)

	local revive
	local assistpl

	pl:PlayDeathSound()
	if (pl.LifeBarricadeDamage ~= 0 or pl.LifeEnemyDamage ~= 0 or pl.LifeEnemyKills ~= 0) then
		net.Start("zs_lifestats")
			net.WriteUInt(math.ceil(pl.LifeBarricadeDamage or 0), 24)
			net.WriteUInt(math.ceil(pl.LifeEnemyDamage or 0), 24)
			net.WriteUInt(pl.LifeEnemyKills or 0, 16)
		net.Send(pl)
	end
	if attacker:IsPlayer() and attacker ~= pl then
		gamemode.Call("PlayerKilledEnemy", pl, attacker, inflictor, dmginfo, headshot, suicide)
	end

	pl:DropAll()
	pl:AddDeaths(1)
	self.PreviouslyDied[pl:UniqueID()] = CurTime()
	if self:GetWave() == 0 then
		pl.DiedDuringWave0 = true
	end

	local frags = pl:Frags()
	if frags < 0 then
		pl.ChangeTeamFrags = math.ceil(frags / 5)
	else
		pl.ChangeTeamFrags = 0
	end

	if pl.SpawnedTime then
		pl.SurvivalTime = math.max(ct - pl.SpawnedTime, pl.SurvivalTime or 0)
		pl.SpawnedTime = nil
	end
			
	local hands = pl:GetHands()
	if IsValid(hands) then
		hands:Remove()
	end
	--if pl.NextSpawnTime
	if attacker == pl then
		net.Start("zs_pl_kill_self")
			net.WriteEntity(pl)
			net.WriteUInt(plteam, 16)
		net.Broadcast()
	elseif attacker:IsPlayer() then
		if assistpl then
			net.Start("zs_pls_kill_pl")
				net.WriteEntity(pl)
				net.WriteEntity(attacker)
				net.WriteEntity(assistpl)
				net.WriteString(inflictor:GetClass())
				net.WriteUInt(plteam, 16)
				net.WriteUInt(attacker:Team(), 16) -- Assuming assistants are always on the same team.
				net.WriteBit(headshot)
			net.Broadcast()

			gamemode.Call("PlayerKilledByPlayer", pl, assistpl, inflictor, headshot, dmginfo, true)
		else
			net.Start("zs_pl_kill_pl")
				net.WriteEntity(pl)
				net.WriteEntity(attacker)
				net.WriteString(inflictor:GetClass())
				net.WriteUInt(plteam, 16)
				net.WriteUInt(attacker:Team(), 16)
				net.WriteBit(headshot)
			net.Broadcast()
		end

		gamemode.Call("PlayerKilledByPlayer", pl, attacker, inflictor, headshot, dmginfo)
	else
		net.Start("zs_death")
			net.WriteEntity(pl)
			net.WriteString(inflictor:GetClass())
			net.WriteString(attacker:GetClass())
			net.WriteUInt(plteam, 16)
		net.Broadcast()
	end
end

function GM:PlayerKilledByPlayer(pl, attacker, inflictor, headshot, dmginfo)
end

function GM:PlayerCanPickupWeapon(pl, ent)
	if pl:IsSpectator() then return false end

	return ent:GetClass() ~= "weapon_stunstick"
end

function GM:PlayerFootstep(pl, vPos, iFoot, strSoundName, fVolume, pFilter)
end

function GM:PlayerStepSoundTime(pl, iType, bWalking)
	local fStepTime = 350

	if iType == STEPSOUNDTIME_NORMAL or iType == STEPSOUNDTIME_WATER_FOOT then
		local fMaxSpeed = pl:GetMaxSpeed()
		if fMaxSpeed <= 100 then
			fStepTime = 400
		elseif fMaxSpeed <= 300 then
			fStepTime = 350
		else
			fStepTime = 250
		end
	elseif iType == STEPSOUNDTIME_ON_LADDER then
		fStepTime = 450
	elseif iType == STEPSOUNDTIME_WATER_KNEE then
		fStepTime = 600
	end

	if pl:Crouching() then
		fStepTime = fStepTime + 50
	end

	return fStepTime
end

concommand.Add("zsdropweapon", function(sender, command, arguments)

	if not (sender:IsValid() and sender:Alive() and (sender:Team() == TEAM_HUMAN or sender:Team() == TEAM_BANDIT)) or CurTime() < (sender.NextWeaponDrop or 0) then return end
	sender.NextWeaponDrop = CurTime() + 0.15

	local currentwep = sender:GetActiveWeapon()
	if currentwep and currentwep:IsValid() then
		local ent = sender:DropWeaponByType(currentwep:GetClass())
		if ent and ent:IsValid() then
			local shootpos = sender:GetShootPos()
			local aimvec = sender:GetAimVector()
			ent:SetPos(util.TraceHull({start = shootpos, endpos = shootpos + aimvec * 32, mask = MASK_SOLID, filter = sender, mins = Vector(-2, -2, -2), maxs = Vector(2, 2, 2)}).HitPos)
			ent:SetAngles(sender:GetAngles())
		end
	end
end)

concommand.Add("zsemptyclip", function(sender, command, arguments)

	if not (sender:IsValid() and sender:Alive() and (sender:Team() == TEAM_HUMAN or sender:Team() == TEAM_BANDIT)) then return end

	sender.NextEmptyClip = sender.NextEmptyClip or 0
	if sender.NextEmptyClip <= CurTime() then
		sender.NextEmptyClip = CurTime() + 0.1

		local wep = sender:GetActiveWeapon()
		if wep:IsValid() and not wep.NoMagazine then
			local primary = wep:ValidPrimaryAmmo()
			if primary and 0 < wep:Clip1() then
				sender:GiveAmmo(wep:Clip1(), primary, true)
				wep:SetClip1(0)
			end
			local secondary = wep:ValidSecondaryAmmo()
			if secondary and 0 < wep:Clip2() then
				sender:GiveAmmo(wep:Clip2(), secondary, true)
				wep:SetClip2(0)
			end
		end
	end
end)

concommand.Add("zsgiveammo", function(sender, command, arguments)

	if not sender:IsValid() or not sender:Alive() or not(sender:Team() == TEAM_HUMAN or sender:Team() == TEAM_BANDIT) then return end

	local ammotype = arguments[1]
	if not ammotype or #ammotype == 0 or not GAMEMODE.AmmoCache[ammotype] then return end

	local count = sender:GetAmmoCount(ammotype)
	if count <= 0 then
		sender:SendLua("surface.PlaySound(\"buttons/button10.wav\")")
		sender:PrintTranslatedMessage(HUD_PRINTCENTER, "no_spare_ammo_to_give")
		return
	end

	local ent
	local dent = Entity(tonumbersafe(arguments[2] or 0) or 0)
	if GAMEMODE:ValidMenuLockOnTarget(sender, dent) then
		ent = dent
	end

	if not ent then
		ent = sender:MeleeTrace(48, 2).Entity
	end

	if ent and ent:IsValid() and ent:IsPlayer() and (ent:Team() == TEAM_HUMAN or ent:Team() == TEAM_BANDIT) and ent:Alive() and ent:Team() == sender:Team() then
		local desiredgive = math.min(count, GAMEMODE.AmmoCache[ammotype])
		if desiredgive >= 1 then
			sender:RemoveAmmo(desiredgive, ammotype)
			ent:GiveAmmo(desiredgive, ammotype)

			if CurTime() >= (sender.NextGiveAmmoSound or 0) then
				sender.NextGiveAmmoSound = CurTime() + 1
				sender:PlayGiveAmmoSound()
			end

			sender:RestartGesture(ACT_GMOD_GESTURE_ITEM_GIVE)

			return
		end
	else
		sender:SendLua("surface.PlaySound(\"buttons/button10.wav\")")
		sender:PrintTranslatedMessage(HUD_PRINTCENTER, "no_person_in_range")
	end
end)

concommand.Add("zsgiveweapon", function(sender, command, arguments)

	if not (sender:IsValid() and sender:Alive() and (sender:Team() == TEAM_HUMAN or sender:Team() == TEAM_BANDIT)) then return end

	local currentwep = sender:GetActiveWeapon()
	if currentwep and currentwep:IsValid() then
		local ent
		local dent = Entity(tonumbersafe(arguments[2] or 0) or 0)
		if GAMEMODE:ValidMenuLockOnTarget(sender, dent) then
			ent = dent
		end

		if not ent then
			ent = sender:MeleeTrace(48, 2).Entity
		end

		if ent and ent:IsValid() and ent:IsPlayer() and (ent:Team() == TEAM_HUMAN or ent:Team() == TEAM_BANDIT) and ent:Alive() and ent:Team() == sender:Team() then
			if not ent:HasWeapon(currentwep:GetClass()) then
				sender:GiveWeaponByType(currentwep, ent, false)
			else
				sender:SendLua("surface.PlaySound(\"buttons/button10.wav\")")
				sender:PrintTranslatedMessage(HUD_PRINTCENTER, "person_has_weapon")
			end
		else
			sender:SendLua("surface.PlaySound(\"buttons/button10.wav\")")
			sender:PrintTranslatedMessage(HUD_PRINTCENTER, "no_person_in_range")
		end
	end
end)

concommand.Add("zsgiveweaponclip", function(sender, command, arguments)

	if not (sender:IsValid() and sender:Alive() and (sender:Team() == TEAM_HUMAN or sender:Team() == TEAM_BANDIT)) then return end
	
	local currentwep = sender:GetActiveWeapon()
	if currentwep and currentwep:IsValid() then
		local ent
		local dent = Entity(tonumbersafe(arguments[2] or 0) or 0)
		if GAMEMODE:ValidMenuLockOnTarget(sender, dent) then
			ent = dent
		end

		if not ent then
			ent = sender:MeleeTrace(48, 2).Entity
		end

		if ent and ent:IsValid() and ent:IsPlayer() and (ent:Team() == TEAM_HUMAN or ent:Team() == TEAM_BANDIT) and ent:Alive() and ent:Team() == sender:Team() then
			if not ent:HasWeapon(currentwep:GetClass()) then
				sender:GiveWeaponByType(currentwep, ent, true)
			else
				sender:SendLua("surface.PlaySound(\"buttons/button10.wav\")")
				sender:PrintTranslatedMessage(HUD_PRINTCENTER, "person_has_weapon")
			end
		else
			sender:SendLua("surface.PlaySound(\"buttons/button10.wav\")")
			sender:PrintTranslatedMessage(HUD_PRINTCENTER, "no_person_in_range")
		end
	end
end)

concommand.Add("zsdropammo", function(sender, command, arguments)

	if not sender:IsValid() or not sender:Alive() or not (sender:Team() == TEAM_HUMAN or sender:Team() == TEAM_BANDIT) or CurTime() < (sender.NextDropClip or 0) then return end

	sender.NextDropClip = CurTime() + 0.2

	local wep = sender:GetActiveWeapon()
	if not wep:IsValid() then return end

	local ammotype = arguments[1] or wep:GetPrimaryAmmoTypeString()
	if GAMEMODE.AmmoNames[ammotype] and GAMEMODE.AmmoCache[ammotype] then
		local ent = sender:DropAmmoByType(ammotype, GAMEMODE.AmmoCache[ammotype] * 2)
		if ent and ent:IsValid() then
			ent:SetPos(sender:EyePos() + sender:GetAimVector() * 8)
			ent:SetAngles(sender:GetAngles())
			local phys = ent:GetPhysicsObject()
			if phys:IsValid() then
				phys:Wake()
				phys:SetVelocityInstantaneous(sender:GetVelocity() * 0.85)
			end
		end
	end
end)

local VoiceSetTranslate = {}
VoiceSetTranslate["models/player/alyx.mdl"] = "alyx"
VoiceSetTranslate["models/player/barney.mdl"] = "barney"
VoiceSetTranslate["models/player/breen.mdl"] = "male"
VoiceSetTranslate["models/player/combine_soldier.mdl"] = "combine"
VoiceSetTranslate["models/player/combine_soldier_prisonguard.mdl"] = "combine"
VoiceSetTranslate["models/player/combine_super_soldier.mdl"] = "combine"
VoiceSetTranslate["models/player/eli.mdl"] = "male"
VoiceSetTranslate["models/player/gman_high.mdl"] = "male"
VoiceSetTranslate["models/player/kleiner.mdl"] = "male"
VoiceSetTranslate["models/player/monk.mdl"] = "monk"
VoiceSetTranslate["models/player/mossman.mdl"] = "female"
VoiceSetTranslate["models/player/odessa.mdl"] = "male"
VoiceSetTranslate["models/player/police.mdl"] = "combine"
VoiceSetTranslate["models/player/brsp.mdl"] = "female"
VoiceSetTranslate["models/player/moe_glados_p.mdl"] = "female"
VoiceSetTranslate["models/grim.mdl"] = "combine"
VoiceSetTranslate["models/jason278-players/gabe_3.mdl"] = "monk"
function GM:PlayerSpawn(pl)
	pl:StripWeapons()
	pl:RemoveStatus("confusion", false, true)
	if pl:GetMaterial() ~= "" then
		pl:SetMaterial("")
	end

	pl:UnSpectate()

	pl.StartCrowing = nil
	pl.StartSpectating = nil
	pl.Gibbed = nil

	pl.SpawnNoSuicide = CurTime() + 1
	pl.SpawnedTime = CurTime()
	pl.NextSpawnTime = nil
	
	pl:ShouldDropWeapon(false)

	pl:SetLegDamage(0)
	pl:SetLastAttacker()
	pl.LifeBarricadeDamage = 0
	pl.LifeEnemyDamage = 0
	pl.LifeEnemyKills = 0
	if not self:IsClassicMode() then
		pl:GiveStatus("spawnbuff").Owner = pl
	end

	self.PreviouslyDied[pl:UniqueID()] = nil 
	if (pl:Team() == TEAM_HUMAN or pl:Team() == TEAM_BANDIT) then
		pl.m_PointQueue = 0
		pl.PackedItems = {}
		local desiredname = pl:GetInfo("cl_playermodel")
		local modelname = player_manager.TranslatePlayerModel(#desiredname == 0 and self.RandomPlayerModels[math.random(#self.RandomPlayerModels)] or desiredname)
		local lowermodelname = string.lower(modelname)
		if table.HasValue(self.RestrictedModels, lowermodelname) then
			modelname = "models/player/kleiner.mdl"
			lowermodelname = modelname
		end
		pl:SetModel(modelname)
		
		-- Cache the voice set.
		if VoiceSetTranslate[lowermodelname] then
			pl.VoiceSet = VoiceSetTranslate[lowermodelname]
		elseif string.find(lowermodelname, "female", 1, true) then
			pl.VoiceSet = "female"
		else
			pl.VoiceSet = "male"
		end

		pl.HumanSpeedAdder = nil

		pl.BonusDamageCheck = CurTime()

		pl:ResetSpeed()
		pl:SetJumpPower(DEFAULT_JUMP_POWER)
		pl:SetCrouchedWalkSpeed(0.65)

		pl:SetNoTarget(false)
		
		pl:SetMaxHealth(100)

		pl:Give("weapon_zs_fists")
		local nosend = not pl.DidInitPostEntity
		pl.HumanRepairMultiplier = nil
		pl.HumanHealMultiplier = nil
		pl.BuffResistant = nil
		pl.BuffRegenerative = nil
		pl.BuffMuscular = nil
		pl.IsWeak = nil
		pl.HumanSpeedAdder = nil
		pl.Cannibalistic = nil
		pl:SetPalsy(false, nosend)
		pl:SetHemophilia(false, nosend)
		pl:SetUnlucky(false)
		pl.Clumsy = nil
		pl.NoGhosting = nil
		pl.EOD = nil
		pl.BuffStrongShoes = nil
		pl:SendLua("LocalPlayer().BuffStrongShoes = nil")
		pl.BuffTightGrip = nil
		pl:SendLua("LocalPlayer().BuffTightGrip = nil")
		pl.BuffSights = nil
		pl:SendLua("LocalPlayer().BuffSights = nil")
		pl.NoGhosting = nil
		pl.NoObjectPickup = nil
		pl.DamageVulnerability = nil
			
		--[[if self.StartingLoadout then
			self:GiveStartingLoadout(pl)
		elseif pl.m_PreRespawn then
			gamemode.Call("GiveDefaultOrRandomEquipment",pl)	
		end]]

		local oldhands = pl:GetHands()
		if IsValid(oldhands) then
			oldhands:Remove()
		end

		local hands = ents.Create("zs_hands")
		if hands:IsValid() then
			hands:DoSetup(pl)
			hands:Spawn()
		end
		if (math.random(0,1)==1) then
			local stored = weapons.GetStored("weapon_zs_battleaxe")
			pl:Give("weapon_zs_battleaxe")
			pl:GiveAmmo(stored.Primary.DefaultClip/3, stored.Primary.Ammo)
		else
			local stored = weapons.GetStored("weapon_zs_peashooter")
			pl:Give("weapon_zs_peashooter")
			pl:GiveAmmo(stored.Primary.DefaultClip/3, stored.Primary.Ammo)
		end
		pl:Give("weapon_zs_swissarmyknife")
	end

	pl:DoMuscularBones()
	pl:DoNoodleArmBones()

	local pcol = Vector(pl:GetInfo("cl_playercolor"))
	pcol.x = math.Clamp(pcol.x, 0, 2.5)
	pcol.y = math.Clamp(pcol.y, 0, 2.5)
	pcol.z = math.Clamp(pcol.z, 0, 2.5)
	pl:SetPlayerColor(pcol)

	local wcol = Vector(pl:GetInfo("cl_weaponcolor"))
	wcol.x = math.Clamp(wcol.x, 0, 2.5)
	wcol.y = math.Clamp(wcol.y, 0, 2.5)
	wcol.z = math.Clamp(wcol.z, 0, 2.5)
	pl:SetWeaponColor(wcol)

	pl.m_PreHurtHealth = pl:Health()
end

function GM:SetWave(wave)
	SetGlobalInt("wave", wave)
end

GM.NextEscapeDamage = 0
function GM:WaveStateChanged(newstate)
	if newstate then
		
		local players = player.GetAll()
		for _, pl in pairs(players) do
			if not pl:Alive() then
				pl.m_PreRespawn = true
				pl:UnSpectateAndSpawn()
				local teamspawns = {}
				teamspawns = team.GetValidSpawnPoint(pl:Team())
				pl:SetPos(teamspawns[ math.random(#teamspawns) ]:GetPos())
				pl.m_PreRespawn = nil
				pl.SpawnedTime = CurTime()
				pl.NextSpawnTime = nil
				net.Start("zs_playerredeemed")
					net.WriteEntity(pl)
					net.WriteString(pl:Name())
				net.Broadcast()	
			end
			pl.BonusDamageCheck = CurTime()
		end

			
		local prevwave = self:GetWave()

		if prevwave >= self:GetNumberOfWaves() then return end
		if not self:IsClassicMode() then
			gamemode.Call("CreateSigils")
		end
		gamemode.Call("SetWave", prevwave + 1)
		gamemode.Call("SetWaveStart", CurTime())
		gamemode.Call("SetWaveEnd", self:GetWaveStart() + self:GetWaveOneLength() - (self:GetWave() - 1) * self.TimeLostPerWave)

		net.Start("zs_wavestart")
			net.WriteInt(self:GetWave(), 16)
			net.WriteFloat(self:GetWaveEnd())
		net.Broadcast()


		local curwave = self:GetWave()
		for _, ent in pairs(ents.FindByClass("logic_waves")) do
			if ent.Wave == curwave or ent.Wave == -1 then
				ent:Input("onwavestart", ent, ent, curwave)
			end
		end
		for _, ent in pairs(ents.FindByClass("logic_wavestart")) do
			if ent.Wave == curwave or ent.Wave == -1 then
				ent:Input("onwavestart", ent, ent, curwave)
			end
		end
	elseif self:GetWave() >= self:GetNumberOfWaves() then -- Last wave is over

		if self:GetCurrentWaveWinner() == TEAM_HUMAN then
			self:SetHumanScore(self:GetHumanScore()+1)
		elseif self:GetCurrentWaveWinner() == TEAM_BANDIT then
			self:SetBanditScore(self:GetBanditScore()+1)
		elseif self:GetCurrentWaveWinner() == nil then
			self:SetTieScore(self:GetTieScore()+1)
		end
		if self:GetHumanScore() > self:GetBanditScore() then
			gamemode.Call("EndRound", TEAM_HUMAN)
		elseif self:GetHumanScore() < self:GetBanditScore() then
			gamemode.Call("EndRound", TEAM_BANDIT)
		else
			gamemode.Call("EndRound", nil)
		end
		local curwave = self:GetWave()
		for _, ent in pairs(ents.FindByClass("logic_waves")) do
			if ent.Wave == curwave or ent.Wave == -1 then
				ent:Input("onwaveend", ent, ent, curwave)
			end
		end
		for _, ent in pairs(ents.FindByClass("logic_waveend")) do
			if ent.Wave == curwave or ent.Wave == -1 then
				ent:Input("onwaveend", ent, ent, curwave)
			end
		end
	else
		self:SetComms(0,0)
		self.CommsEnd = false
		self.SuddenDeath = false
		local shouldshuffle = false
		gamemode.Call("SetWaveStart", CurTime() + self.WaveIntermissionLength)
		if math.abs(#team.GetPlayers(TEAM_BANDIT) - #team.GetPlayers(TEAM_HUMAN)) >= 2 then
			shouldshuffle = true
			timer.Simple(5, function() gamemode.Call("ShuffleTeams") end)	
		end
		if self:GetCurrentWaveWinner() == TEAM_HUMAN then
			self:SetHumanScore(self:GetHumanScore()+1)
		elseif self:GetCurrentWaveWinner() == TEAM_BANDIT then
			self:SetBanditScore(self:GetBanditScore()+1)
		elseif self:GetCurrentWaveWinner() == nil then
			self:SetTieScore(self:GetTieScore()+1)
		end

		if (self:GetHumanScore() >= math.ceil((self:GetNumberOfWaves()-self:GetTieScore()+1)/2)) then
			gamemode.Call("EndRound", TEAM_HUMAN)
			return
		elseif (self:GetBanditScore() >= math.ceil((self:GetNumberOfWaves()-self:GetTieScore()+1)/2))then
			gamemode.Call("EndRound", TEAM_BANDIT)
			return
		end
		for _, pl in pairs(player.GetAll()) do
			--pl:SendLua("RunConsoleCommand( \"stopsound\" )")
			local teamspawns = {}
			teamspawns = team.GetValidSpawnPoint(pl:Team())
			if shouldshuffle then 
				pl:PrintMessage(HUD_PRINTCENTER, "팀 밸런스를 위해 5초 후 셔플합니다.")
			end
			if pl:Alive() then
				pl:SetPos(teamspawns[ math.random(#teamspawns) ]:GetPos())
			else
				pl:UnSpectateAndSpawn()	
				pl:SendLua("GAMEMODE:OpenPointsShop()")
			end
			--pl:SetMaxHealth(pl:GetMaxHealth() + 20)
			pl:SetHealth(pl:GetMaxHealth())
			local toadd = 15*(1+self:GetWave())
			if (self:GetCurrentWaveWinner() == TEAM_HUMAN and pl:Team() == TEAM_BANDIT) or (self:GetCurrentWaveWinner() == TEAM_BANDIT and pl:Team() == TEAM_HUMAN) then
				pl:AddPoints(toadd)
				pl:PrintTranslatedMessage(HUD_PRINTTALK, "loser_points_added", toadd)
			elseif 
				(self:GetCurrentWaveWinner() == TEAM_HUMAN and pl:Team() == TEAM_HUMAN) or (self:GetCurrentWaveWinner() == TEAM_BANDIT and pl:Team() == TEAM_BANDIT) then
				pl:AddPoints(toadd-5*(1+self:GetWave()))
				pl:PrintTranslatedMessage(HUD_PRINTTALK, "winner_points_added", toadd)
			end
			if (team.NumPlayers(TEAM_BANDIT) > team.NumPlayers(TEAM_HUMAN) and pl:Team() == TEAM_HUMAN) or (team.NumPlayers(TEAM_BANDIT) < team.NumPlayers(TEAM_HUMAN) and pl:Team() == TEAM_BANDIT) then
				pl:AddPoints(20)
				pl:PrintMessage(HUD_PRINTTALK, "팀 인원이 비교적 적어 20포인트를 받았다.")
			end
		end
		--print(self:GetHumanScore())
		
		net.Start("zs_waveend")
			net.WriteInt(self:GetWave(), 16)
			net.WriteFloat(self:GetWaveStart())
			net.WriteUInt(self:GetCurrentWaveWinner() or -1, 8)
		net.Broadcast()
		net.Start("zs_currentsigils")
			net.WriteTable({})
		net.Broadcast()
		self.CurrentSigilTable = {}
		util.RemoveAll("prop_ammo")
		util.RemoveAll("prop_weapon")
		util.RemoveAll("prop_obj_sigil")
		
			--[[We should spawn crates for each team, much like buyzones in CS.

			local banditspawn = table.Random(team.GetValidSpawnPoint(TEAM_BANDIT))
			if banditspawn and banditspawn:IsValid() then
				local ent = ents.Create("prop_arsenalcrate")
				if ent:IsValid() then
					ent:SetPos(banditspawn:GetPos())
					ent:Spawn()
					ent:DropToFloor()
					ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER) -- Just so no one gets stuck in it.
					ent.NoTakeOwnership = true
				end
			end
		
			local humanspawn = table.Random(team.GetValidSpawnPoint(TEAM_HUMAN))
			if humanspawn and humanspawn:IsValid() then
				local ent = ents.Create("prop_arsenalcrate")
				if ent:IsValid() then
					ent:SetPos(humanspawn:GetPos())
					ent:Spawn()
					ent:DropToFloor()
					ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER) -- Just so no one gets stuck in it.
					ent.NoTakeOwnership = true
				end
			end]]
		local curwave = self:GetWave()
		for _, ent in pairs(ents.FindByClass("logic_waves")) do
			if ent.Wave == curwave or ent.Wave == -1 then
				ent:Input("onwaveend", ent, ent, curwave)
			end
		end
		for _, ent in pairs(ents.FindByClass("logic_waveend")) do
			if ent.Wave == curwave or ent.Wave == -1 then
				ent:Input("onwaveend", ent, ent, curwave)
			end
		end
		timer.Simple(1, function() self:SetCurrentWaveWinner(nil) end)
	end
	gamemode.Call("OnWaveStateChanged")
end

function GM:SetObjectiveSigilsTaken(pl,new)
	if not pl:IsPlayer() then return end
	pl.ObjectiveSigilsTaken = new
end
function GM:GetObjectiveSigilsTaken(pl)
	if not pl:IsPlayer() then return nil end
	return pl.ObjectiveSigilsTaken
end
function GM:PlayerSwitchFlashlight(pl, newstate)
	return (pl:Team() == TEAM_HUMAN or pl:Team() == TEAM_BANDIT)
end

function GM:PlayerStepSoundTime(pl, iType, bWalking)
	return 350
end
