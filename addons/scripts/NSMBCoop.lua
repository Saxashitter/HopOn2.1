-- NSMBCoop.lua is by Saxashitter.
-- This is entirely reusable.

rawset(_G, "NSMBCOOP_PICKUPSTATES", {})

local PICKUP_TIME = TICRATE*3/2
local PICKUP_RANGE = 12*FU
local THROW_SPEED = 16*FU
local PICKUP_BUTTON = BT_ATTACK
local DROP_BUTTON = BT_FIRENORMAL

local function check(p)
	return p and p.mo and p.mo.health
end

local function reset(p, loopfailsafe)
	if p.pickedplayer and not loopfailsafe then
		if check(p.pickedplayer) then
			reset(p.pickedplayer, true)
		end
		p.pickedplayer = nil
	end

	p.pickedplayer = nil
	p.pickedbyplayer = nil
	p.pickuptime = 0
end

local function pickup_player(p, sp)
	p.pickedplayer = sp
	p.pickuptime = PICKUP_TIME

	reset(sp)

	sp.pickedbyplayer = p
	if sp.pickedplayer then
		if check(sp.pickedplayer) then
			sp.pickedplayer.pickedbyplayer = nil
		end
		sp.pickedplayer = nil
	end

	S_StartSound(p.mo, sfx_s3k51)
end

local function throw_player(p)
	local sp = p.pickedplayer

	P_SetOrigin(sp.mo, p.mo.x, p.mo.y, p.mo.z+p.mo.height)

	P_InstaThrust(sp.mo, p.mo.angle, FixedMul(THROW_SPEED, p.mo.scale))
	P_SetObjectMomZ(sp.mo, -2*p.mo.scale)

	sp.mo.momx = $+p.mo.momx
	sp.mo.momx = $+p.mo.momy
	sp.mo.momz = $+p.mo.momz

	S_StartSound(p.mo, sfx_s1ab)

	reset(p)
	reset(sp)
end

local function drop_player(p)
	local sp = p.pickedplayer

	P_SetOrigin(sp.mo, p.mo.x, p.mo.y, p.mo.z)
	sp.mo.state = S_PLAY_STND

	reset(p)
	reset(sp)
end

local function pickup_thinker(p)
	if p.pickedbyplayer or p.pickedplayer then
		return
	end

	for sp in players.iterate do
		if sp == p then continue end

		if not (p.cmd.buttons & PICKUP_BUTTON and not (p.lastbuttons & PICKUP_BUTTON)) then
			continue
		end

		if not (check(sp) and not p.pickedplayer) then
			continue
		end

		local dist = FixedHypot(p.mo.x-sp.mo.x, p.mo.y-sp.mo.y)

		if p.mo.z > sp.mo.z+sp.mo.height then continue end
		if sp.mo.z > p.mo.z+p.mo.height then continue end

		local radius = fixmul(p.mo.radius, p.mo.scale)+fixmul(sp.mo.radius, sp.mo.scale)
		if dist > radius+PICKUP_RANGE then continue end

		pickup_player(p, sp)
	end
end

addHook("PlayerSpawn", function(p)
	reset(p)
end)

addHook("PreThinkFrame", do
	for p in players.iterate do
		if not check(p) then continue end

		if p.pickedbyplayer then
			p.cmd.buttons = 0
			p.cmd.forwardmove = 0
			p.cmd.sidemove = 0
		end
	end
end)

addHook("ShouldDamage", function(t)
	if (t and t.player and t.player.pickedbyplayer) then
		return false
	end
end, MT_PLAYER)

addHook("PlayerThink", function(p)
	if not check(p) then
		reset(p)
		return
	end

	if p.pickedplayer
	and not check(p.pickedplayer) then
		p.pickedplayer = nil
	end
	if p.pickedbyplayer
	and not check(p.pickedbyplayer) then
		p.pickedbyplayer = nil
	end
	p.pickuptime = max($-1, 0)

	if p.pickedplayer then
		if p.cmd.buttons & PICKUP_BUTTON
		and not (p.lastbuttons & PICKUP_BUTTON) then
			throw_player(p)
			return
		end

		if p.cmd.buttons & DROP_BUTTON
		and not (p.lastbuttons & DROP_BUTTON) then
			drop_player(p)
			return
		end
	else
		pickup_thinker(p)
	end
end)

addHook("ThinkFrame", do
	for p in players.iterate do
		if not check(p) then
			reset(p)
			continue
		end

		if p.pickedbyplayer then
			local sp = p.pickedbyplayer
			local lerp = ease.outcubic(
				0,
				sp.mo.height,
				FixedDiv(PICKUP_TIME-p.pickuptime, PICKUP_TIME)
			)

			P_MoveOrigin(p.mo, sp.mo.x,sp.mo.y,sp.mo.z+lerp)
			p.mo.momx = sp.mo.momx
			p.mo.momy = sp.mo.momy
			p.mo.momz = sp.mo.momz
			p.drawangle = sp.drawangle
			p.mo.state = NSMBCOOP_PICKUPSTATES[p.mo.skin] or S_PLAY_PAIN
		end
	end
end)