
function EFFECT:Init(data)

	self.Entity 		= data:GetEntity()		// Entity determines what is creating the dynamic light
	self.Pos		= data:GetOrigin()		// Origin determines the global position of the effect
	self.Scale 		= data:GetScale()		// Scale determines how large the effect is
	self.Radius 		= data:GetRadius() or 1		// Radius determines what type of effect to create, default is Concrete
	self.DirVec 		= data:GetNormal()		// Normal determines the direction of impact for the effect
	self.PenVec 		= data:GetStart()		// PenVec determines the direction of the round for penetrations
	self.Particles 		= data:GetMagnitude()		// Particles determines how many puffs to make, primarily for "trails"
	self.Angle 		= self.DirVec:Angle()		// Angle is the angle of impact from Normal
	self.DebrizzlemyNizzle = 10+data:GetScale()		// Debrizzle my Nizzle is how many "trails" to make
	self.Size 		= 5*self.Scale		// Size is exclusively for the explosion "trails" size
	self.Emitter 	= ParticleEmitter( self.Pos )		// Emitter must be there so you don't get an error
	sound.Play( "physics/flesh/flesh_squishy_impact_hard" .. math.random(1,4) .. ".wav", self.Pos, 180, 100 )

	self:Blood()

end

 function EFFECT:Blood()
 
		for i=0,30*self.Scale do		// If you recieve over 50,000 joules of energy, you become red mist.
		local Smoke = self.Emitter:Add( "particle/particle_composite", self.Pos )
		if (Smoke) then
		Smoke:SetVelocity( VectorRand():GetNormalized()*math.random(100,600)*self.Scale )
		Smoke:SetDieTime( math.Rand(1,2) )
		Smoke:SetStartAlpha( 80 )
		Smoke:SetEndAlpha( 0 )
		Smoke:SetStartSize( 30*self.Scale )
		Smoke:SetEndSize( 100*self.Scale )
		Smoke:SetRoll( math.Rand(150,360) )
		Smoke:SetRollDelta( math.Rand(-2,2) )
		Smoke:SetColor( 70,35,35 )
		Smoke:SetGravity( Vector(math.Rand(-50,50)*self.Scale, math.Rand(-50,50)*self.Scale, math.Rand(0,-200)) )
		Smoke:SetAirResistance( 400 )
		end
		end

		for i=0,20*self.Scale do		// Add some finer details....
		local Smoke = self.Emitter:Add( "particle/smokesprites_000"..math.random(1,9), self.Pos )
		if (Smoke) then
		Smoke:SetVelocity( VectorRand():GetNormalized()*math.random(200,600)*self.Scale )
		Smoke:SetDieTime( math.Rand(1,4) )
		Smoke:SetStartAlpha( 120 )
		Smoke:SetEndAlpha( 0 )
		Smoke:SetStartSize( 30*self.Scale )
		Smoke:SetEndSize( 100*self.Scale )
		Smoke:SetRoll( math.Rand(150,360) )
		Smoke:SetRollDelta( math.Rand(-2,2) )
		Smoke:SetColor( 70,35,35 )
		Smoke:SetGravity( Vector(math.Rand(-50,50)*self.Scale,math.Rand(-50,50)*self.Scale,math.Rand(-50,-300)) )
		Smoke:SetAirResistance( 400 )
		end
		end

		for i=1,5 do		// Into the flash!
		local Flash = self.Emitter:Add( "effects/muzzleflash"..math.random(1,4), self.Pos )
		if (Flash) then
		Flash:SetVelocity( self.DirVec*100 )
		Flash:SetDieTime( 0.15 )
		Flash:SetStartAlpha( 255 )
		Flash:SetEndAlpha( 0 )
		Flash:SetStartSize( 300*self.Scale )
		Flash:SetEndSize( 0 )
		Flash:SetRoll( math.Rand(180,480) )
		Flash:SetRollDelta( math.Rand(-1,1) )
		Flash:SetColor( 255,255,255 )
		Flash:SetAirResistance( 200 )
		end
		end

		for i=1,20*self.Scale do		// Chunkage NOT contained
		local Debris = self.Emitter:Add( "effects/fleck_cement"..math.random(1,2), self.Pos-(self.DirVec*5) )
		if (Debris) then
		Debris:SetVelocity ( VectorRand():GetNormalized()*400*self.Scale )
		Debris:SetDieTime( math.random(0.3,0.6) )
		Debris:SetStartAlpha( 255 )
		Debris:SetEndAlpha( 0 )
		Debris:SetStartSize( 8 )
		Debris:SetEndSize( 9 )
		Debris:SetRoll( math.Rand(0,360) )
		Debris:SetRollDelta( math.Rand(-5,5) )
		Debris:SetColor( 70,35,35 )
		Debris:SetGravity( Vector(0,0,-600) )
		Debris:SetAirResistance( 30 )
		Debris:SetCollide( true )
		Debris:SetBounce( 0.2 )
		end
		end

end

function EFFECT:Think( )
	return false
end
function EFFECT:Render()
end