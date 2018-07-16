AddCSLuaFile()

function EFFECT:Init(data)
    self.LastFlash = CurTime()
    if not IsValid(data:GetEntity()) then return end
    self.Ent = data:GetEntity()
    self.Emitter = ParticleEmitter(self.Ent:GetPos())
    if IsValid(self.Ent) then
        self:SetParent(self.Ent)
    end
end

function EFFECT:Think()
    if not IsValid(self.Ent) or (IsValid(self.Ent) and self.Ent.Hit) then return false end
    if IsValid(self.Ent) and not self.Ent.Hit and self.LastFlash < CurTime() then
        for i=1,3 do
            local corona = self.Emitter:Add("effects/rollerglow",self.Ent:GetPos())

            if corona then
                corona:SetColor(225,40,80)
                corona:SetRoll(math.Rand(0,360))
                corona:SetVelocity(VectorRand():GetNormal() * math.random(0,20))
                corona:SetRoll(math.Rand(0, 360))
                corona:SetRollDelta(math.Rand(-2,2))
                corona:SetDieTime(0.01 + FrameTime())
                corona:SetStartSize(82.5)
                corona:SetStartAlpha(150)
                corona:SetEndAlpha(150)
                corona:SetEndSize(82.5)
            end

            local rot = self.Emitter:Add("particle/particle_ring_wave_8",self.Ent:GetPos())

            if rot then
                rot:SetColor(10,137,10)
                rot:SetRoll(math.Rand(0,360))
                rot:SetVelocity(VectorRand():GetNormal() * math.random(0,20))
                rot:SetRoll(math.Rand(0,360))
                rot:SetRollDelta(math.Rand(-2,2))
                rot:SetDieTime(0.01 + FrameTime())
                rot:SetStartSize(50)
                rot:SetStartAlpha(150)
                rot:SetEndAlpha(150)
                rot:SetEndSize(50)
            end

            local glow = self.Emitter:Add("particle/Particle_Glow_04",self.Ent:GetPos())

            if glow then
                glow:SetColor(60,187,60)
                glow:SetRoll(math.Rand(0,360))
                glow:SetVelocity(VectorRand():GetNormal() * math.random(0,20))
                glow:SetRoll(math.Rand(0,360))
                glow:SetRollDelta(math.Rand(-2,2))
                glow:SetDieTime(0.01 + FrameTime())
                glow:SetStartSize(20)
                glow:SetStartAlpha(200)
                glow:SetEndAlpha(255)
                glow:SetEndSize(20)
            end

            local glow_add = self.Emitter:Add("particle/Particle_Glow_05_AddNoFog",self.Ent:GetPos())

            if glow_add then
                glow_add:SetColor(90,217,90)
                glow_add:SetRoll(math.Rand(0,360))
                glow_add:SetVelocity(VectorRand():GetNormal() * math.random(0,20))
                glow_add:SetRoll(math.Rand(0,360))
                glow_add:SetRollDelta(math.Rand(-2,2))
                glow_add:SetDieTime(0.01 + FrameTime())
                glow_add:SetStartSize(75)
                glow_add:SetStartAlpha(255)
                glow_add:SetEndAlpha(255)
                glow_add:SetEndSize(75)
            end
        end
        self.LastPuff = CurTime() + 0.03
    end
    return true
end

function EFFECT:Render()
end