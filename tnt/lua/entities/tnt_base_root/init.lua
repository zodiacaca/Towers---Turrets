
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("sv_cube.lua")

/*---------------------------------------------------------
   Name: Initialize
---------------------------------------------------------*/
function ENT:Initialize()

	self:PrecacheParticles()

	local model = (self.TurretModel)

	self.Entity:SetModel(model)

	self.Entity:PhysicsInit(SOLID_VPHYSICS)
	self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
	self.Entity:SetSolid(SOLID_VPHYSICS)
	self.Entity:DrawShadow(false)

	local phys = self.Entity:GetPhysicsObject()
	if phys:IsValid() then
		-- phys:EnableGravity(false)
		-- phys:EnableCollisions(false)
		-- phys:EnableMotion(false)
		-- phys:EnableDrag(false)
		phys:Wake()
	end

	self.Entity:SetUseType(SIMPLE_USE)

	self:SetHealth(self.TurretHealth)

	if self.SettleAngleRandom then
		self.Entity:ManipulateBoneAngles(self.Entity:LookupBone(self.AimYawBone), Angle(0, math.random(0,360), 0))
	end

	self:InitMeta()

	self.YawMotorThrottle = 0
	self.PitchMotorThrottle = 0
	self.MinTheta = { x = 0, y = 0 }
	self.Collided = false
	self.LastTargetTime = CurTime()
	self.LastShoot = CurTime()
	self.UpdateDelay = self.UpdateDelayLong
	self:SetRounds(self.ClipSize)
	self.Reloaded = true
	self:SetReloadTime(CurTime())
	self.Fires = 0
	self.Explored = false
	self.PlanB = false
	self.Owner = self:GetCreator()
	self.TurningLoop = CreateSound(self.Entity, self.TurretTurningSound)

	self:SetTrigger(true)	-- Touch

	if self.HasBase then
		self:SetReady(false)
		self:CreateIndicator()
	else
		self:SetReady(true)
	end

end

function ENT:PrecacheParticles()

	if self.ImpactParticle != nil then
		PrecacheParticleSystem(self.ImpactParticle)
	end

end

/*---------------------------------------------------------
   Recive the new statistics from stool
---------------------------------------------------------*/
function ENT:SetDamageScale( scale )
	self.DamageScale = scale
end

function ENT:SetSpread( spread )
	self.Spread = spread/10
end

function ENT:SetTurretRange( range )
	self.TurretRange = range
end

function ENT:SetCooldown( cooldown )
	self.Cooldown = cooldown
end

function ENT:SetBlastRadius( radius )
	self.BlastRadius = radius
end

function ENT:SetTakeAmmoPerShoot( ammo )
	self.TakeAmmoPerShoot = ammo
end

function ENT:SetFriends( friend )
	table.insert(tntfriends, string.lower(friend))
end

/*---------------------------------------------------------
   Name: OnTakeDamage
---------------------------------------------------------*/
function ENT:OnTakeDamage(dmginfo)

	if dmginfo:GetDamageType() ~= DMG_SLASH then

		local dmgAmount = dmginfo:GetDamage()
		local dmgDice = math.Clamp(dmgAmount, 1, 30)
		local health = self:Health() - dmgAmount
		health = math.Clamp(health, 0, 10000)
		local dice = math.random(1,math.Round(30/dmgDice))

		self:SetHealth(health)

		if (self:Health() <= 0.6 * self.TurretHealth) and (dice == 1) then
			if self.Fires <= 3 then
				self:DamageEffect()
			end
		end

		if (self:Health() <= 0) then
			self:Explosion()
		end

	end

end

function ENT:DamageEffect()

	if !self.HasDamagedState then return end

	local a = 255 * (self:Health()/self.TurretHealth)
	self:SetColor(Color(a, a, a, 255))

	local rpos = math.random(-self.FiresOffset,self.FiresOffset)

	self.FireEffect = ents.Create( "env_fire_trail" )
	self.FireEffect:SetPos(self:GetPos() + (self:GetForward() * rpos) + (self:GetRight() * rpos) + (self:GetUp() * self.FiresHeight))
	self.FireEffect:Spawn()
	self.FireEffect:SetParent(self)

	if !self.FireSound then
		self.FireSound = CreateSound(self, "ambient/fire/fire_big_loop1.wav")
	else
		self.FireSound:Play()
		self.FireSound:ChangePitch(100 * GetConVarNumber("host_timescale"))
	end

	self.Fires = self.Fires + 1

end

function ENT:Explosion()

	if not IsValid(self.Entity) then
		self:Remove()
		return
	end

	if self.Explored then return end

	if self.HasBase then
		self:ExplosionEffect()
	end

	self.Explored = true

	self:Remove()

end

function ENT:ExplosionEffect()

	local pos = self.Entity:GetPos()

	local effectdata = EffectData()
		effectdata:SetEntity(self.Entity)
		effectdata:SetOrigin(self.Entity:GetPos())
		effectdata:SetScale(1.8)
	util.Effect("m9k_gdcw_tnt_tower_boom", effectdata)
	for i=1,1000 do
		local td = {
			start = pos,
			endpos = pos + Vector(math.Rand(-1,1), math.Rand(-1,1), math.Rand(-1,1)) * 256,
			filter = { self.Entity }
			}
		local ouchies = util.TraceLine(td)
		if IsValid(ouchies.Entity) then
			if !ouchies.Entity.Base == "tnt_base_deployable" then
				local dist = pos:Distance(ouchies.HitPos)
				dist = math.sqrt(dist)
				local dir = (ouchies.HitPos - pos):GetNormal()
				local dmg = DamageInfo()
					dmg:SetDamageType(DMG_SHOCK)
					dmg:SetDamage(90)
					dmg:SetAttacker(self.Entity)
					dmg:SetInflictor(self.Entity)
					dmg:SetFilter(self.Entity)
					dmg:SetDamagePosition(ouchies.HitPos)
					dmg:SetDamageForce((dir * 4 * 10^5)/dist)
				ouchies.Entity:TakeDamageInfo(dmg)
			end
		end
	end
	util.ScreenShake(pos, 800, 250, 0.75, 512)

	local ent = ents.Create("prop_physics")
		ent:SetModel("models/tnt/towers_razed"..math.random(1,2)..".mdl")
		ent:SetPos(self.Entity:GetPos())
		ent:SetAngles(Angle(0, math.random(0,360), 0))
		ent:Spawn()
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableCollisions(true)
		phys:EnableMotion(false)
	end

end

local YawBoneIndex, YawBonePos, YawBoneAng, PitchBoneIndex, PitchBonePos, PitchBoneAng, TargetBoneIndex
local YawBonePos_w, YawBoneAng_w, PitchBonePos_w, PitchBoneAng_w
local AimPosition_w, AimAngle_w, AimPosition, AimAngle, AngleAimYaw, AngleAimPitch, YawDiff, PitchDiff, newpos, newang
local RecoilBoneIndex, RecoilBonePos, RecoilBoneAng
local AttPos, AttAng
local recoil, back

function ENT:InitMeta()

	self.YawClampDelta = nil
	self.PitchClampDelta = nil

	self.AngularSpeed = Angle(0, 0, 0)
	self.PitchSpeed = Angle(0, 0, 0)

	self.p_AngDiff = { y = 0, p = 0 }
	self.p_YawBoneAng = Angle(0, 0, 0)
	self.p_PitchBoneAng = Angle(0, 0, 0)
	self.p_AngularSpeed = Angle(0, 0, 0)
	self.p_PitchSpeed = Angle(0, 0, 0)

end

/*---------------------------------------------------------
   Name: Think
---------------------------------------------------------*/
function ENT:Think()

	if self.HasBase and !self.Collided then
		local phys = self:GetPhysicsObject()
		if ( IsValid( phys ) ) then phys:AddVelocity( -self:GetUp() * 16 ) end
	end

	local CT = CurTime()

	if self.TurretIdleSound != nil then
		if self.LoopSound then
			if !(self:GetReady() == true) or !(CT > self:GetReloadTime()) then
				self.LoopSound:ChangeVolume(0, 0.5)
			else
				self.LoopSound:ChangeVolume(1, 0.5)
				self.LoopSound:ChangePitch(100 * GetConVarNumber("host_timescale"))
			end
		else
			self.LoopSound = CreateSound(self.Entity, Sound(self.TurretIdleSound))
			self.LoopSound:Play()
		end
	end

	self:UpdateTransformation()
	self:TurningTurret(CT)
	self:Recoil(CT)
	self:ReloadAmmo(CT)
	self:PostTransformation()

	self:RotateNPCCube(CT)

	self:NextThink(CurTime())

	return true
end

function ENT:UpdateTransformation()

	YawBoneIndex = self.Entity:LookupBone(self.AimYawBone)
	YawBonePos_w, YawBoneAng_w = self.Entity:GetBonePosition(YawBoneIndex)
	PitchBoneIndex = self.Entity:LookupBone(self.AimPitchBone)
	PitchBonePos_w, PitchBoneAng_w = self.Entity:GetBonePosition(PitchBoneIndex)
	YawBonePos, YawBoneAng = self:TranslateCoordinateSystem(YawBonePos_w, YawBoneAng_w)
	PitchBonePos, PitchBoneAng = self:TranslateCoordinateSystem(PitchBonePos_w, PitchBoneAng_w)

	self.AngularSpeed = YawBoneAng - self.p_YawBoneAng
	self.PitchSpeed = PitchBoneAng - self.p_PitchBoneAng

end

function ENT:PostTransformation()

	self.p_YawBoneAng = YawBoneAng
	self.p_PitchBoneAng = PitchBoneAng
	self.p_AngularSpeed = self.AngularSpeed
	self.p_PitchSpeed = self.PitchSpeed

end

function ENT:UpdateTarget(ct, target)

	if (ct - self.LastTargetTime) > self.UpdateDelay then

		self.LastTargetTime = ct

		if target == self.OldTarget then
			self.PlanB = !self.PlanB
		end

		self.OldTarget = target

	end

end

-- ENT.Time = 0
function ENT:TurningTurret(ct)

	if GetConVar("ai_disabled"):GetBool() then return end
	if !IsValid(self.NPCCube) then self.TurningLoop:Stop() return end

	-- if ct > self.Time then
		-- self.Time = ct + 3
		-- local tbl = {
			-- ["tgt_time"] = self.LastTargetTime,
			-- ["delay"] = self.UpdateDelay,
			-- ["planB"] = self.PlanB,
			-- ["tgt"] = self.Target,
			-- ["old_tgt"] = self.OldTarget,
			-- ["tgt = old_tgt"] = (self.Target == self.OldTarget)
		-- }
		-- PrintTable(tbl)
	-- end

	if self.PlanB then
		self.Target = self:GetTargetB()
	else
		self.Target = self:GetTargetA()
	end
	self:UpdateTarget(ct, self.Target)

	if (self:GetReady() == true) and (ct > self:GetReloadTime()) and (self.Target != nil) then

		-- Angles between the target and the bones
		TargetBoneIndex = self.Target:LookupBone(self.Target:GetBoneName(1))
		if TargetBoneIndex == nil then
			self.PlanB = !self.PlanB
			return
		end
		AimPosition_w, AimAngle_w = self.Target:GetBonePosition(TargetBoneIndex)
		AimPosition, AimAngle = self:TranslateCoordinateSystem(AimPosition_w, AimAngle_w)
		AngleAimYaw = (AimPosition - YawBonePos):Angle()
		AngleAimPitch = (AimPosition - PitchBonePos):Angle()
		if AngleAimPitch.x >= self.PitchLimitDown && AngleAimPitch.x <= self.PitchLimitUp then
			if self.TurningLoop then
				self.TurningLoop:Stop()
			end
			self.PlanB = !self.PlanB
			return
		end

		-- The angle differences between them
		YawDiff = AngleAimYaw - YawBoneAng
		PitchDiff = AngleAimPitch - PitchBoneAng

		-- Make sure the turret don't turn like a maniac
		if math.abs(YawDiff.y) > 180 then
			YawDiff.y = -YawDiff.y/math.abs(YawDiff.y) * (360 - math.abs(YawDiff.y))
		end
		if math.abs(PitchDiff.x) > 180 then
			PitchDiff.x = -PitchDiff.x/math.abs(PitchDiff.x) * (360 - math.abs(PitchDiff.x))
		end
		if math.abs(YawDiff.y) < self.MinTheta.y then
			YawDiff.y = 0
		end
		if math.abs(PitchDiff.x) < self.MinTheta.x then
			PitchDiff.x = 0
		end

		-- throttle
		if self.p_AngDiff.y * YawDiff.y <= 0 then
			self.YawMotorThrottle = 0
		else
			self.YawMotorThrottle = Lerp(0.1, self.YawMotorThrottle, math.Clamp(math.abs(YawDiff.y) / self.RotateSpeed, 0, 1))
		end
		if self.p_AngDiff.p * PitchDiff.p <= 0 then
			self.PitchMotorThrottle = 0
		else
			self.PitchMotorThrottle = Lerp(0.1, self.PitchMotorThrottle, math.Clamp(math.abs(PitchDiff.x) / (self.RotateSpeed * self.RotateSpeedRatio), 0, 1))
		end
		self.p_AngDiff.y = YawDiff.y
		self.p_AngDiff.p = PitchDiff.p

		local as = self.AngularSpeed
		if math.abs(as.y) <= self.MinTheta.y then	-- vehicle shaking
			as.y = self.YawMotorThrottle * self.RotateSpeed	-- ManipulateBone updates every 2 Think
			if self.p_AngularSpeed.y != 0 then
				as.y = math.min(as.y, math.abs(self.p_AngularSpeed.y) + self.RotateSpeed / 7.5)
			end
		else
			if math.abs(as.y) > 180 then
				as.y = -as.y/math.abs(as.y) * (360 - math.abs(as.y))
			end
		end
		as.y = math.abs(as.y)

		local ps = self.PitchSpeed
		if math.abs(ps.x) <= self.MinTheta.x then
			ps.x = self.PitchMotorThrottle * self.RotateSpeed * self.RotateSpeedRatio
			if self.p_PitchSpeed.x != 0 then
				ps.x = math.min(ps.x, math.abs(self.p_PitchSpeed.x) + self.RotateSpeed * self.RotateSpeedRatio / 10)
			end
		else
			if math.abs(ps.x) > 180 then
				ps.x = -ps.x/math.abs(ps.x) * (360 - math.abs(ps.x))
			end
		end
		ps.x = math.abs(ps.x)

		self.MinTheta.y = math.Clamp(self.YawMotorThrottle * 0.5, 0.05, 1)
		self.MinTheta.x = math.Clamp(self.PitchMotorThrottle * 0.5, 0.05, 1)
		self.YawClampDelta = self.RotateSpeed * GetConVarNumber("host_timescale") * (as.y / self.RotateSpeed)
		self.PitchClampDelta = self.RotateSpeed * GetConVarNumber("host_timescale") * (ps.x / self.RotateSpeed)
		YawDiff.y = math.Clamp(YawDiff.y, -self.YawClampDelta, self.YawClampDelta) * self.YawMotorThrottle
		if math.abs(YawDiff.y) > 0 and math.abs(YawDiff.y) < self.MinTheta.y then
			YawDiff.y = math.abs(YawDiff.y) / YawDiff.y * self.MinTheta.y
		end
		PitchDiff.x = math.Clamp(PitchDiff.x, -self.PitchClampDelta, self.PitchClampDelta) * self.PitchMotorThrottle
		if math.abs(PitchDiff.x) > 0 and math.abs(PitchDiff.x) < self.MinTheta.x then
			PitchDiff.x = math.abs(PitchDiff.x) / PitchDiff.x * self.MinTheta.x
		end

		-- Turning
		self.Entity:ManipulateBoneAngles(YawBoneIndex, Angle(0, YawBoneAng.y - self.ExistAngle + YawDiff.y, 0))
		self.Entity:ManipulateBoneAngles(PitchBoneIndex, Angle(PitchBoneAng.x + PitchDiff.x, 0, 0))
		-- print(PitchDiff.x)
		self:TurningSound()
		self:Aiming(ct)

	else

		self.YawMotorThrottle = 0
		self.PitchMotorThrottle = 0
		-- self:EliminateHesitation()
		self.UpdateDelay = self.UpdateDelayShort
		if self.TurningLoop then self.TurningLoop:Stop() end

	end

end

function ENT:TranslateCoordinateSystem(pos, ang)

	newpos, newang = WorldToLocal(pos, ang, self.Entity:GetPos(), self.Entity:GetAngles())

	return newpos, newang
end

function ENT:EliminateHesitation()

	local targets = {}

	-- the hesitation delay equals to the short update delay time, so use a small number like 0.5, and it's not so necessary so leave it in the comments
	for k,v in pairs(ents.GetAll()) do
		if v:IsValid() && v:IsNPC() then
			if !(table.HasValue(tntfriends, string.lower(v:GetClass())) || table.HasValue(tntfilter, string.lower(v:GetClass())) || string.match(v:GetClass(), "bullseye")) then
				if self.Entity:GetPos():Distance(v:GetPos()) < self.TurretRange then
					if v:IsLineOfSightClear(self.Entity:GetPos() + self:GetUp() * self.AimHeight) and v:Health() > 0 then
						table.insert(targets, v)
					end
				end
			end
		end
	end

	if table.Count(targets) == 1 and self.OldTarget != nil then

		self.UpdateDelay = 0

	end

end

function ENT:GetTargetA()

	local targets = {}

	for k,v in pairs(ents.GetAll()) do
		if v:IsValid() && (v:IsNPC() or (v:IsPlayer() and !GetConVar("ai_ignoreplayers"):GetBool() and GetConVar("tnt_attack_player"):GetBool())) then
			if !(table.HasValue(tntfriends, string.lower(v:GetClass())) || table.HasValue(tntfilter, string.lower(v:GetClass())) || string.match(v:GetClass(), "bullseye")) then
				if self.Entity:GetPos():Distance(v:GetPos()) < self.TurretRange then
					if v:IsLineOfSightClear(self.Entity:GetPos() + self:GetUp() * self.AimHeight) and v:Health() > 0 then
						if IsValid(self.Owner) then
							local target = { ent = v, health = v:Health(), dist = self.Owner:GetPos():Distance(v:GetPos()) }
							table.insert(targets, target)
						else
							local target = { ent = v, health = v:Health() }
							table.insert(targets, target)
						end
					end
				end
			end
		end
	end

	if table.Count(targets) > 0 then

		if table.Count(targets) != 1 then
			self.UpdateDelay = self.UpdateDelayLong
		end

		table.SortByMember(targets, "health", true)

		return targets[1].ent

	end

end

function ENT:GetTargetB()

	local targets = {}

	for k,v in pairs(ents.GetAll()) do
		if v:IsValid() && (v:IsNPC() or (v:IsPlayer() and !GetConVar("ai_ignoreplayers"):GetBool() and GetConVar("tnt_attack_player"):GetBool())) then
			if !(table.HasValue(tntfriends, string.lower(v:GetClass())) || table.HasValue(tntfilter, string.lower(v:GetClass())) || string.match(v:GetClass(), "bullseye")) then
				if self.Entity:GetPos():Distance(v:GetPos()) < self.TurretRange then
					if v:IsLineOfSightClear(self.Entity:GetPos() + self:GetUp() * self.AimHeight) and v:Health() > 0 then
						if IsValid(self.Owner) then
							local target = { ent = v, health = v:Health(), dist = self.Owner:GetPos():Distance(v:GetPos()) }
							table.insert(targets, target)
						else
							local target = { ent = v, health = v:Health() }
							table.insert(targets, target)
						end
					end
				end
			end
		end
	end

	if table.Count(targets) > 0 then

		table.SortByMember(targets, "health", true)

		if table.Count(targets) == 1 then

			if targets[1].ent != self.OldTarget then

				self.UpdateDelay = self.UpdateDelayLong
				return targets[1].ent

			end

		elseif targets[1].ent != self.OldTarget then

			self.UpdateDelay = self.UpdateDelayLong
			return targets[1].ent

		else

			self.UpdateDelay = self.UpdateDelayLong
			return targets[2].ent

		end

	end

end

function ENT:TurningSound()

	if self.TurretTurningSound == nil then return end

	if self.TurningLoop then
		if self.p_AngDiff.y != YawDiff.y then
			self.TurningLoop:Play()
			self.TurningLoop:ChangeVolume(math.Clamp(self.YawMotorThrottle, 0.5, 1))
			self.TurningLoop:ChangePitch(100 * GetConVarNumber("host_timescale"))
		else
			self.TurningLoop:Stop()
		end
	else
		self.TurningLoop = CreateSound(self.Entity, self.TurretTurningSound)
	end

end

function ENT:Aiming(ct)

	if self.AimAttachment == nil then
		print("AimAttachment expected, got nil")
		return
	end

	AttPos = self.Entity:GetAttachment(self.AimAttachment).Pos
	AttAng = self.Entity:GetAttachment(self.AimAttachment).Ang

	local max = 16

	local td = {
		start = AttPos,
		endpos = AttPos + AttAng:Forward() * 33000,
		maxs = Vector(max, max, max),
		mins = Vector(-max, -max, -max),
		filter = { self.Entity }
		}
	local tr = util.TraceHull(td)

	if (ct > (self.LastShoot + self.Cooldown)) then
		if tr.Entity:IsValid() and ((!GetConVar("tnt_attack_owner"):GetBool() and !(tr.Entity == self.Owner)) or GetConVar("tnt_attack_owner"):GetBool()) then
			timer.Create("tnt_shoot_delay"..self.Entity:EntIndex(), math.random(0.003, 0.006), 1, function()
				self:Shoot(ct, AttPos, AttAng)
			end)
		end
	end

end

function ENT:Shoot(ct, pos, ang)

	if (self:GetRounds() >= self.TakeAmmoPerShoot) then

		self:SetRounds(self:GetRounds() - self.TakeAmmoPerShoot)

		local dice = math.Rand(0.9,1.15)
		local damage = self.BlastDamage * self.DamageScale * dice

		self:MuzzleEffects(pos, ang)
		self:EjectCasing(pos, ang)
		util.ScreenShake(pos, 0.02 * damage, 0.05 * damage, 0.75, 2 * self.BlastRadius)

		local bullet = {}
			bullet.Num 		= 1
			bullet.Src 		= pos			-- Source
			bullet.Dir 		= ang:Forward()			-- Dir of bullet
			bullet.Spread 	= Vector(self.Spread, self.Spread, 0)		-- Aim Cone
			bullet.Tracer	= self.TracerCount									-- Show a tracer on every x bullets
			bullet.Force	= self.HitDamage * 0.75									-- Amount of force to give to phys objects
			bullet.Damage	= self.HitDamage * self.DamageScale * dice
			bullet.AmmoType = "Pistol"
			bullet.TracerName = self.TracerType
			bullet.Callback	= function(attacker, tracedata, dmginfo)
				if !tracedata.HitSky and self.BlastDamage != 0 and self.BlastRadius != 0 then
					if self.ImpactParticle != nil then
						ParticleEffect(self.ImpactParticle, tracedata.HitPos, Angle(0, 0, 0), nil)
					end
					if self.ImpactEffect != nil then
						local Impact_FX = EffectData()
							Impact_FX:SetEntity(self.Entity)
							Impact_FX:SetOrigin(tracedata.HitPos)
							Impact_FX:SetScale(self.ImpactScale)
						util.Effect(self.ImpactEffect, Impact_FX)
					end
					local Impact_Light = EffectData()
						Impact_Light:SetOrigin(tracedata.HitPos)
					util.Effect("tnt_effect_light", Impact_Light)
					util.BlastDamage(self.Entity, self.Entity, tracedata.HitPos, self.BlastRadius, damage)
					sound.Play(self.ImpactExplosionSound, tracedata.HitPos, 100, 100 * GetConVarNumber("host_timescale"), 1)
					util.ScreenShake(tracedata.HitPos, 0.2 * damage, 1 * damage, 0.75, 1 * self.BlastRadius)
				end
			end

		self.Entity:FireBullets(bullet)

		sound.Play(self.TurretShootSound, pos, 100, math.Rand(95,105) * GetConVarNumber("host_timescale"), 1 )

		if !self.HasBase then
			local phys = self:GetPhysicsObject()
			if ( IsValid( phys ) ) then phys:AddVelocity( -ang:Forward() * (0.6 * self.BlastDamage + 3 * self.HitDamage)) end
		end

		self.LastShoot = ct

	else

		for id, ent in pairs(ents.FindInSphere(self:GetPos(), 128)) do
			if string.match(ent:GetClass(), "ammo", 0) then

				self:SetReloadTime(CurTime() + 1/self.ReloadSpeed)
				self:SetRounds(self.ClipSize)
				self.Entity:EmitSound(self.TurretReloadSound, 65, 100 * GetConVarNumber("host_timescale"))

				ent:Remove()

				break

			end
		end

	end

end

function ENT:MuzzleEffects(p, a)

	local Muzzle_FX = EffectData()
		Muzzle_FX:SetEntity(self.Entity)
		Muzzle_FX:SetOrigin(p)
		Muzzle_FX:SetNormal(a:Forward())
		Muzzle_FX:SetScale(self.MuzzleScale)
		Muzzle_FX:SetAttachment(self.AimAttachment)
	util.Effect("gdcw_tnt_muzzle_cannon", Muzzle_FX)
	local Muzzle_Light = EffectData()
		Muzzle_Light:SetOrigin(p)
		Muzzle_Light:SetScale(self.MuzzleLightScale)
	util.Effect("tnt_effect_light", Muzzle_Light)

end

function ENT:EjectCasing(p, a)

	if self.EjectEffect != nil then
		local ShellEject = EffectData()
			ShellEject:SetOrigin(p + a:Forward() * self.EjectOffset)
			ShellEject:SetAngles(a + Angle(60, -120, 0))
		util.Effect(self.EjectEffect, ShellEject)
	end

end

function ENT:Recoil(ct)

	if self.RecoilBone == nil then return end

	RecoilBoneIndex = self.Entity:LookupBone(self.RecoilBone)
	RecoilBonePos, RecoilBoneAng = self.Entity:GetBonePosition(RecoilBoneIndex)

	recoil = (ct - self.LastShoot) * self.RecoilOffset
	back = (self.RecoilOffset * 1/self.RecoilRecoverPerThink) - (ct - self.LastShoot - 1/self.RecoilRecoverPerThink) * (0.5 * self.RecoilOffset)

	if (ct - self.LastShoot) < (3 * 1/self.RecoilRecoverPerThink) then
		if (ct - self.LastShoot) < 1/self.RecoilRecoverPerThink then
			self.Entity:ManipulateBonePosition(RecoilBoneIndex, Vector(-recoil, 0, 0))
		else
			self.Entity:ManipulateBonePosition(RecoilBoneIndex, Vector(-back, 0, 0))
		end
	end

end

function ENT:ReloadAmmo(ct)

	if !self.Reloaded and (ct > self:GetReloadTime()) then
		self:SetRounds(self.ClipSize)
		self.Reloaded = true
	end

end

/*---------------------------------------------------------
   Name: Touch
---------------------------------------------------------*/
function ENT:StartTouch(ent)

	if !self.CanReload then return end

	if (self:GetReady() == false) then return end

	if (string.match(ent:GetClass(), "ammo", 0) || string.match(ent:GetClass(), "sent_ball", 0)) && (self:GetRounds() < self.ClipSize) then

		self:SetReloadTime(CurTime() + 1/self.ReloadSpeed)
		SafeRemoveEntity(ent)
		self.Entity:EmitSound(self.TurretReloadSound, 65, 100 * GetConVarNumber("host_timescale"))
		self.Reloaded = false

	end

end

function ENT:EndTouch(ent)
end

function ENT:Touch(ent)
end

/*---------------------------------------------------------
   Name: Use
---------------------------------------------------------*/
function ENT:Use()

	self:SetReady(!self:GetReady())

end

/*---------------------------------------------------------
   Name: OnRemove
---------------------------------------------------------*/
function ENT:OnRemove()

	if self.LoopSound then
		self.LoopSound:Stop()
		self.LoopSound = nil
	end
	if self.TurningLoop then
		self.TurningLoop:Stop()
		self.TurningLoop = nil
	end
	if self.FireSound then
		self.FireSound:Stop()
		self.FireSound = nil
	end

	timer.Destroy("tower_ready_"..self:EntIndex())
	timer.Destroy("tnt_shoot_delay"..self.Entity:EntIndex())

	if IsValid(self.NPCCube) then
		self.NPCCube:Remove()
	end

end