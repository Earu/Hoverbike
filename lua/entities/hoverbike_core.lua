AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.Author    = "Earu"
ENT.Spawnable = false
ENT.PrintName = "Hoverbike's Core"
ENT.ClassName = "hoverbike_core"

if CLIENT then
	language.Add("hoverbike_core","Hoverbike's core")

	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:Initialize()
	end
end

if SERVER then
	function ENT:Initialize()
		self.Hit        = false
		self.ShouldBlow = true
		self.IsHacked   = false
		self.LastShout  = CurTime()

		self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")
		self:PhysicsInitBox(Vector(-20,-20,-20),Vector(20,20,20))
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
		self:SetNoDraw(true)
		self:DrawShadow(false)

		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:Wake()
			phys:EnableDrag(false)
			phys:EnableGravity(false)
			phys:AddGameFlag(FVPHYSICS_NO_IMPACT_DMG)
			phys:AddGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)
			phys:SetMass(50)
			phys:SetBuoyancyRatio(0)
		end

		self.Fear = ents.Create("ai_sound")
		self.Fear:SetPos(self:GetPos())
		self.Fear:SetParent(self)
		self.Fear:SetKeyValue("SoundType","8|1")
		self.Fear:SetKeyValue("Volume","1000")
		self.Fear:SetKeyValue("Duration","1")
		self.Fear:Spawn()

		self.WhirrSound = CreateSound(self,"weapons/physcannon/energy_sing_loop4.wav")
		self.WhirrSound:Play()

		self:Fire("kill",1,10)
	end

	function ENT:SetHacked(ishacked)
		local fx = EffectData()
		fx:SetEntity(self)
		if ishacked then
			util.Effect("hoverbike_core_hacked",fx,true)
		else
			util.Effect("hoverbike_core",fx,true)
		end
		self.IsHacked = ishacked
	end

	function ENT:Think()
		if self.LastShout < CurTime() then
			if IsValid(self.Fear) then
				self.Fear:Fire("EmitAISound")
			end
			self.LastShout = CurTime() + 0.1
		end

		if self.Hit then
			self:GetPhysicsObject():SetVelocity(Vector(0,0,0))
			self:SetNotSolid(true)

			local dmg,radius
            local fx = EffectData()
			fx:SetOrigin(self:GetPos())
			if self.IsHacked then
				dmg,radius = 415,400
				util.Effect("hoverbike_core_impact_hacked",fx)
			else
				dmg,radius = 215,200
				util.Effect("hoverbike_core_impact",fx)
			end
			util.ScreenShake(self:GetPos(),radius / 2,radius / 2,1,radius)

			if IsValid(self.Owner) and self.ShouldBlow then
				local dmginfo = DamageInfo()
				dmginfo:SetDamageType(DMG_DISSOLVE)

				if IsValid(self.Inflictor) then
					dmginfo:SetInflictor(self.Inflictor)
				else
					dmginfo:SetInflictor(self)
				end

				if IsValid(self.Owner) then
					dmginfo:SetAttacker(self.Owner)
				else
					dmginfo:SetAttacker(self)
				end

				dmginfo:SetDamage(dmg)
				dmginfo:SetDamageForce(self:GetVelocity():GetNormalized() * 2500)

				util.BlastDamageInfo(dmginfo,self:GetPos(),radius)
				--self:EmitSound("^hoverbike/coreimpact.wav",100,200)
			end
			self:Remove()
		end

		self:NextThink(CurTime())
		return true
	end

	function ENT:OnRemove()
		if self.WhirrSound then self.WhirrSound:Stop() end
		if IsValid(self.Fear) then self.Fear:Fire("kill") end
	end

	function ENT:PhysicsCollide(data,phys)
		if not self.Hit then
			local filter = self.TraceFilter or {}
			table.insert(filter,self)
			local tr = util.TraceHull({
                start  = self:GetPos(),
                endpos = data.HitPos,
                filter = filter,
                mask   = MASK_SHOT,
                mins   = self:OBBMins(),
                maxs   = self:OBBMaxs(),
			})
			if self.GetHoverbike and self:GetHoverbike():IsValid() then
				if not self.IsHacked then
					if tr.HitPos:Distance(self:GetHoverbike():GetPos()) > 200 then
						self.ShouldBlow = false
					end
				else
					if tr.HitPos:Distance(self:GetHoverbike():GetPos()) > 400 then
						self.ShouldBlow = false
					end
				end
			end
			self.Hit = true
		end
    end

	hook.Add("PhysgunPickup", "HoverbikeCore",function(ply,ent)
		if ent:GetClass() == "hoverbike_core" then return false end
	end)
end