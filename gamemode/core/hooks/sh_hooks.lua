function GM:PlayerNoClip(client)
	return client:IsAdmin()
end

HOLDTYPE_TRANSLATOR = HOLDTYPE_TRANSLATOR or {}
HOLDTYPE_TRANSLATOR[""] = "normal"
HOLDTYPE_TRANSLATOR["physgun"] = "smg"
HOLDTYPE_TRANSLATOR["ar2"] = "smg"
HOLDTYPE_TRANSLATOR["crossbow"] = "shotgun"
HOLDTYPE_TRANSLATOR["rpg"] = "shotgun"
HOLDTYPE_TRANSLATOR["slam"] = "normal"
HOLDTYPE_TRANSLATOR["grenade"] = "grenade"
HOLDTYPE_TRANSLATOR["melee2"] = "melee"
HOLDTYPE_TRANSLATOR["passive"] = "smg"
HOLDTYPE_TRANSLATOR["knife"] = "melee"
HOLDTYPE_TRANSLATOR["duel"] = "pistol"
HOLDTYPE_TRANSLATOR["camera"] = "smg"
HOLDTYPE_TRANSLATOR["magic"] = "normal"
HOLDTYPE_TRANSLATOR["revolver"] = "pistol"

PLAYER_HOLDTYPE_TRANSLATOR = PLAYER_HOLDTYPE_TRANSLATOR or {}
PLAYER_HOLDTYPE_TRANSLATOR[""] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["normal"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["revolver"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["fist"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["pistol"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["grenade"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["melee"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["slam"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["melee2"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["knife"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["duel"] = "normal"
PLAYER_HOLDTYPE_TRANSLATOR["bugbait"] = "normal"

local getModelClass = nut.anim.getModelClass
local IsValid = IsValid
local string = string

local stringFind = string.find
local stringLower = string.lower

local type = type

/*
	This file is one of the main offenders for bad performance in the gamemode.
	As razor says: haunted code

	Turns out, metamethods call __index of the metatable twice. Best to precache.

	Deep table traversal is bad for performance, unfortunately most nutscript functions
	are on average 3 layers deep.

	Example, any character metamethods are going to traverse 5-6 layers deep into the table.
*/

local Entity_Meta = FindMetaTable("Entity")
local Entity_GetClass = Entity_Meta.GetClass
local Entity_isChair = Entity_Meta.isChair
local Player_GetNetVar = Entity_Meta.getNetVar

local MoveData_Meta = FindMetaTable("CMoveData")
local Move_KeyDown = MoveData_Meta.KeyDown
local Move_SetForwardSpeed = MoveData_Meta.SetForwardSpeed
local Move_SetSideSpeed = MoveData_Meta.SetSideSpeed

local Player_Meta = FindMetaTable("Player")

local Player_GetModel = Entity_Meta.GetModel
local Player_GetWalkSpeed = Player_Meta.GetWalkSpeed
local Player_OnGround = Entity_Meta.OnGround
local Player_GetActiveWeapon = Player_Meta.GetActiveWeapon
local Player_IsWepRaised = Player_Meta.isWepRaised
local Player_SetLocalPos = Entity_Meta.SetLocalPos
local Player_GetVehicle = Player_Meta.GetVehicle
local Player_LookupSequence = Entity_Meta.LookupSequence
local Player_ManipulateBonePosition = Entity_Meta.ManipulateBonePosition
local Player_AnimRestartGesture = Player_Meta.AnimRestartGesture
local Player_InVehicle = Player_Meta.InVehicle
local Player_GetMoveType = Entity_Meta.GetMoveType
local Player_EyeAngles = Entity_Meta.EyeAngles
local Player_SetPoseParameter = Entity_Meta.SetPoseParameter
local Player_SetIK = Entity_Meta.SetIK

local Vector_Meta = FindMetaTable("Vector")
local Vector_Length2DSqr = Vector_Meta.Length2DSqr


local Weapon_Meta = FindMetaTable("Weapon")
local Weapon_GetHoldType = Weapon_Meta.GetHoldType

local configGet = nut.config.get

local nutAnim = nut.anim
local nutAnimZombie = nut.anim.zombie
local nutAnimFastZombie = nut.anim.fastZombie
local nutAnimPlayer = nut.anim.player

local PLAYER_HOLDTYPE_TRANSLATOR = PLAYER_HOLDTYPE_TRANSLATOR
local HOLDTYPE_TRANSLATOR = HOLDTYPE_TRANSLATOR

function GM:TranslateActivity(client, act)
	local model = stringLower(client.GetModel(client))
	local class = getModelClass(model) or "player"
	local weapon = Player_GetActiveWeapon(client)
	if (class == "player") then
		if (
			not configGet("wepAlwaysRaised") and
			IsValid(weapon) and
			(client.isWepRaised and not client:isWepRaised()) and
			Player_OnGround(client)
		) then
			if (stringFind(model, "zombie")) then
				local tree = nutAnimZombie

				if (stringFind(model, "fast")) then
					tree = nutAnimFastZombie
				end

				if (tree[act]) then
					return tree[act]
				end
			end

			local holdType = IsValid(weapon)
				and (weapon.HoldType or Weapon_GetHoldType(weapon))
				or "normal"
			holdType = PLAYER_HOLDTYPE_TRANSLATOR[holdType] or "passive"

			local tree = nutAnimPlayer[holdType]

			if (tree and tree[act]) then
				if (type(tree[act]) == "string") then
					client.CalcSeqOverride = Player_LookupSequence(client, tree[act])
					return
				else
					return tree[act]
				end
			end
		end

		return self.BaseClass.TranslateActivity(self.BaseClass, client, act)
	end

	local tree = nutAnim[class]

	if (tree) then
		local subClass = "normal"

		if (Player_InVehicle(client)) then
			local vehicle = Player_GetVehicle(client)
			local class = Entity_isChair(vehicle) and "chair" or Entity_GetClass(vehicle)

			if (tree.vehicle and tree.vehicle[class]) then
				local act = tree.vehicle[class][1]
				local fixvec = tree.vehicle[class][2]

				if (fixvec) then
					Player_SetLocalPos(client, Vector(16.5438, -0.1642, -20.5493))
				end

				if (type(act) == "string") then
					client.CalcSeqOverride = Player_LookupSequence(client, act)

					return
				else
					return act
				end
			else
				act = tree.normal[ACT_MP_CROUCH_IDLE][1]

				if (type(act) == "string") then
					client.CalcSeqOverride = Player_LookupSequence(client, act)
				end

				return
			end
		elseif (Player_OnGround(client)) then
			Player_ManipulateBonePosition(client, 0, vector_origin)

			if (IsValid(weapon)) then
				subClass = weapon.HoldType or Weapon_GetHoldType(weapon)
				subClass = HOLDTYPE_TRANSLATOR[subClass] or subClass
			end

			if (tree[subClass] and tree[subClass][act]) then
				local index = (not client.isWepRaised or client:isWepRaised())
					and 2
					or 1
				local act2 = tree[subClass][act][index]

				if (type(act2) == "string") then
					client.CalcSeqOverride = Player_LookupSequence(client, act2)

					return
				end

				return act2
			end
		elseif (tree.glide) then
			return tree.glide
		end
	end
end

local Player_AnimRestartMainSequence = Player_Meta.AnimRestartMainSequence
local Player_AnimRestartGestureSlot = Player_Meta.AnimResetGestureSlot

function GM:DoAnimationEvent(client, event, data)
	local class = getModelClass(Player_GetModel(client))

	if (class == "player") then
		return self.BaseClass:DoAnimationEvent(client, event, data)
	else
		local weapon = Player_GetActiveWeapon(client)

		if (IsValid(weapon)) then
			local holdType = weapon.HoldType or Weapon_GetHoldType(weapon)
			holdType = HOLDTYPE_TRANSLATOR[holdType] or holdType

			local animation = nutAnim[class][holdType]

			if (event == PLAYERANIMEVENT_ATTACK_PRIMARY) then
				Player_AnimRestartGesture(client, GESTURE_SLOT_ATTACK_AND_RELOAD, animation.attack or ACT_GESTURE_RANGE_ATTACK_SMG1, true)

				return ACT_VM_PRIMARYATTACK
			elseif (event == PLAYERANIMEVENT_ATTACK_SECONDARY) then
				Player_AnimRestartGesture(client, GESTURE_SLOT_ATTACK_AND_RELOAD, animation.attack or ACT_GESTURE_RANGE_ATTACK_SMG1, true)

				return ACT_VM_SECONDARYATTACK
			elseif (event == PLAYERANIMEVENT_RELOAD) then
				Player_AnimRestartGesture(client, GESTURE_SLOT_ATTACK_AND_RELOAD, animation.reload or ACT_GESTURE_RELOAD_SMG1, true)

				return ACT_INVALID
			elseif (event == PLAYERANIMEVENT_JUMP) then
				client.m_bJumping = true
				client.m_bFistJumpFrame = true
				client.m_flJumpStartTime = CurTime()

				Player_AnimRestartMainSequence(client)

				return ACT_INVALID
			elseif (event == PLAYERANIMEVENT_CANCEL_RELOAD) then
				Player_AnimRestartGestureSlot(client, GESTURE_SLOT_ATTACK_AND_RELOAD)

				return ACT_INVALID
			end
		end
	end

	return ACT_INVALID
end

function GM:EntityEmitSound(data)
	if (data.Entity.nutIsMuted) then
		return false
	end
end

local vectorAngle = FindMetaTable("Vector").Angle
local normalizeAngle = math.NormalizeAngle
local oldCalcSeqOverride

local Vector_LengthSqr = Vector_Meta.LengthSqr

function GM:HandlePlayerLanding(client, velocity, wasOnGround)
	if (Player_GetMoveType(client) == MOVETYPE_NOCLIP) then return end

	if (Player_OnGround(client) and not wasOnGround) then
		local length = Vector_LengthSqr(client.lastVelocity or velocity)
		local animClass = getModelClass(Player_GetModel(client))
		if (animClass ~= "player" and length < 100000) then return end

		Player_AnimRestartGesture(client, GESTURE_SLOT_JUMP, ACT_LAND, true)
		return true
	end
end

function GM:CalcMainActivity(client, velocity)
	client.CalcIdeal = ACT_MP_STAND_IDLE
	
	oldCalcSeqOverride = client.CalcSeqOverride
	client.CalcSeqOverride = -1

	local animClass = getModelClass(Player_GetModel(client))

	if (animClass ~= "player") then
		local eyeAngles = Player_EyeAngles(client)
		local yaw = vectorAngle(velocity)[2]
		local normalized = normalizeAngle(yaw - eyeAngles[2])

		Player_SetPoseParameter(client, "move_yaw", normalized)
	end

	if (
		self:HandlePlayerLanding(client, velocity, client.m_bWasOnGround) or
		self:HandlePlayerNoClipping(client, velocity) or
		self:HandlePlayerDriving(client) or
		self:HandlePlayerVaulting(client, velocity) or
		(usingPlayerAnims and self:HandlePlayerJumping(client, velocity)) or
		self:HandlePlayerSwimming(client, velocity) or
		self:HandlePlayerDucking(client, velocity)
	) then
	else
		local len2D = Vector_Length2DSqr(velocity)
		if (len2D > 22500) then
			client.CalcIdeal = ACT_MP_RUN
		elseif (len2D > 0.25) then
			client.CalcIdeal = ACT_MP_WALK
		end
	end

	client.m_bWasOnGround = Player_OnGround(client)
	client.m_bWasNoclipping = Player_GetMoveType(client) == MOVETYPE_NOCLIP
		and not Player_InVehicle(client)
	client.lastVelocity = velocity

	if (CLIENT) then
		Player_SetIK(client, false)
	end

	return client.CalcIdeal, client.nutForceSeq or oldCalcSeqOverride
end

function GM:OnCharVarChanged(char, varName, oldVar, newVar)
	if (nut.char.varHooks[varName]) then
		for k, v in pairs(nut.char.varHooks[varName]) do
			v(char, oldVar, newVar)
		end
	end
end

function GM:GetDefaultCharName(client, faction)
	local info = nut.faction.indices[faction]

	if (info and info.onGetDefaultName) then
		return info:onGetDefaultName(client)
	end
end

function GM:CanPlayerUseChar(client, char)
	local banned = char:getData("banned")

	if (banned) then
		if (type(banned) == "number" and banned < os.time()) then
			return
		end

		return false, "@charBanned"
	end

	local faction = nut.faction.indices[char:getFaction()]
	if (
		faction and
		hook.Run("CheckFactionLimitReached", faction, char, client)
	) then
		return false, "@limitFaction"
	end
end

-- Whether or not more players are not allowed to load a character of
-- a specific faction since the faction is full.
function GM:CheckFactionLimitReached(faction, character, client)
	if (isfunction(faction.onCheckLimitReached)) then
		return faction:onCheckLimitReached(character, client)
	end

	if (not isnumber(faction.limit)) then return false end

	-- By default, the limit is the number of players allowed in that faction.
	local maxPlayers = faction.limit
	
	-- If some number less than 1, treat it as a percentage of the player count.
	if (faction.limit < 1) then
		maxPlayers = math.Round(#player.GetAll() * faction.limit)
	end

	return team.NumPlayers(faction.index) >= maxPlayers
end

function GM:CanProperty(client, property, entity)
	if (client:IsAdmin()) then
		return true
	end

	if (CLIENT and (property == "remover" or property == "collision")) then
		return true
	end

	return false
end

function GM:PhysgunPickup(client, entity)
	if (client:IsSuperAdmin()) then
		return true
	end
	
	if (client:IsAdmin() and !(entity:IsPlayer() and entity:IsSuperAdmin())) then
		return true
	end

	if (self.BaseClass:PhysgunPickup(client, entity) == false) then
		return false
	end

	return false
end

function GM:Move(client, moveData)
	local char = Player_GetNetVar(client, "char")

	if (char) then
		if (Player_GetMoveType(client) == MOVETYPE_WALK and Move_KeyDown(moveData, IN_WALK)) then
			local mf, ms = 0, 0
			local speed = Player_GetWalkSpeed(client)
			local ratio = configGet("walkRatio")

			if (Move_KeyDown(moveData, IN_FORWARD)) then
				mf = ratio
			elseif (Move_KeyDown(moveData, IN_BACK)) then
				mf = -ratio
			end

			if (Move_KeyDown(moveData, IN_MOVELEFT)) then
				ms = -ratio
			elseif (Move_KeyDown(moveData, IN_MOVERIGHT)) then
				ms = ratio
			end

			Move_SetForwardSpeed(moveData, mf * speed) 
			Move_SetSideSpeed(moveData, ms * speed) 
		end
	end
end

function GM:CanItemBeTransfered(itemObject, curInv, inventory)
	if (itemObject.onCanBeTransfered) then
		local itemHook = itemObject:onCanBeTransfered(curInv, inventory)
		
		return (itemHook != false)
	end
end
