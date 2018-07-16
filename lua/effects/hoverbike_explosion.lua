AddCSLuaFile()

local alive_seconds = 1 -- Constant since this effect does not mutate...
local smoke = {
	"particle/smokesprites_0001",
	"particle/smokesprites_0002",
	"particle/smokesprites_0003",
	"particle/smokesprites_0004",
	"particle/smokesprites_0005",
	"particle/smokesprites_0006",
	"particle/smokesprites_0007",
	"particle/smokesprites_0008",
	"particle/smokesprites_0009",
	"particle/smokesprites_0010",
	"particle/smokesprites_0012",
	"particle/smokesprites_0013",
	"particle/smokesprites_0014",
	"particle/smokesprites_0015",
	"particle/smokesprites_0016",
}

local sounds = {
	"ambient/explosions/explode_5.wav",
	"ambient/explosions/explode_8.wav",
	"ambient/explosions/explode_9.wav",
}

local function VectorRand() -- This makes it a ball instead of a cube.
	return Angle(math.random(0,360),math.random(0,360),0):Forward()
end

function EFFECT:ChooseMaterial(typ)
	if typ == "fire" then
		return "particles/flamelet" .. math.random(1,5)
	elseif typ == "smoke" then
		return table.Random(smoke)
	end
end

local function DrawSunBeamsInWorld(position,amount,size)
	if util.QuickTrace(EyePos(), position - EyePos(), { LocalPlayer() }).HitWorld then return end
	local pos = position:ToScreen()
	DrawSunbeams(0,amount * math.Clamp(LocalPlayer():GetAimVector():Dot((position - EyePos()):GetNormalized()) - 0.5,0,1) * 2,size,pos.x / ScrW(),pos.y / ScrH())
end

EFFECT.DieTime = 0

function EFFECT:Init(data)
	-- This effect is not scaleable. And does not have a normal.
	local origin = data:GetOrigin()
	self:SetPos(origin + Vector(0,0,5))

	-- Sound
	sound.Play(table.Random(sounds),data:GetOrigin(),160,math.random(70,130))

	local emitter = ParticleEmitter(origin)
    if not emitter then return end
    local wind = Vector(math.random(-200,200),math.random(-200,200),math.random(-50,50))

    -- Calculate our fps for fps scaling effect.
    local fps = 1 / FrameTime()
    local times = fps > 100 and 100 or fps > 45 and fps or 1
    times = math.floor(times)

    for i = 0,5 do -- some bawls for us.
        -- Bouncing ligballs ("debris")
        local lightball = emitter:Add("sprites/light_glow02_add",origin)
        if lightball then
            local color = math.random(200,255)
            local life = math.Rand(0.5,1)
            local vec = VectorRand()

            lightball:SetVelocity(vec * 1000) -- it will bounce off walls so no need for normal.
            lightball:SetDieTime(life)
            lightball:SetStartAlpha(50)
            lightball:SetEndAlpha(50)
            lightball:SetStartSize(math.random(50,100))
            lightball:SetEndSize(0)
            lightball:SetColor(255,color,color * 0.6)
            lightball:SetAirResistance(0)
            lightball:SetGravity(Vector(0,0,-1000 * math.Rand(0.5,1)) + wind)
            lightball:SetCollide(true)
            lightball:SetBounce(0.5)
        end

        -- Core "fire"
        for i = 0,times do
            local lightball = emitter:Add("effects/fire_cloud" .. math.random(1,2),origin)
            if lightball then
                local life = math.Rand(1,1.3)
                local vec = VectorRand()

                lightball:SetVelocity(vec * 300)
                lightball:SetDieTime(life)
                lightball:SetStartAlpha(math.random(200,255))
                lightball:SetEndAlpha(0)
                lightball:SetStartSize(0)
                lightball:SetEndSize(math.random(50,80))
                lightball:SetColor(0,200,200)
                lightball:SetAirResistance(50)
                lightball:SetCollide(true)
                lightball:SetBounce(0.5)
                lightball:SetGravity(wind)
            end

            -- Smoke that vooshes back to center as the air pressure smoothens
            local smoke = emitter:Add(self:ChooseMaterial("smoke"),origin)
            if smoke then
                local life = math.Rand(0.4,0.5)
                local vec = VectorRand()

                smoke:SetAngles(Angle(math.random(360),math.random(360),math.random(360)))
                smoke:SetStartSize(0)
                smoke:SetEndSize(math.random(40,50))
                smoke:SetDieTime(life * 2)

                smoke:SetStartAlpha(255)
                smoke:SetEndAlpha(0)
                smoke:SetColor(0,0,0)

                smoke:SetRoll(math.Rand(-0.5,0.5))
                smoke:SetRollDelta(math.Rand(-0.5,0.5))

                smoke:SetAirResistance(100)
                smoke:SetVelocity(vec * 3000 * life * 2) -- it will bounce off walls so no need for normal.
                smoke:SetGravity(vec * -3500 + wind * 0.5)
            end
        end
    end

    emitter:Finish()

	-- Last so if we don't get here die instantly.
	self.DieTime = CurTime() + alive_seconds
end

function EFFECT:Think()
	if self.DieTime < CurTime() then
		return false
	end
	return true
end

function EFFECT:Render()
	local beams = ((self.DieTime - CurTime()) / alive_seconds) * 0.3 -- Dividing is evil. Takes more time.
	DrawSunBeamsInWorld(self:GetPos(), beams,0.1)
end