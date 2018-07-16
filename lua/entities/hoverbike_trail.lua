AddCSLuaFile()

local maincol = Color(10,137,132)
local altcol  = Color(140,200,200,150)
local redcol  = Color(255,50,0)

AddCSLuaFile()
ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.Author          = "Earu"
ENT.Spawnable		= false
ENT.AdminSpawnable 	= false
ENT.PrintName		= "Hoverbike's Propeller"
ENT.ClassName       = "hoverbike_trail"

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")

    if SERVER then
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetModelScale(1)

        local phys = self:GetPhysicsObject()
        if phys:IsValid() then
            phys:Wake()
        end

        self.Trail = NULL
    end
end

function ENT:SetDrawVisible(bool)
    self:SetNWBool("DRAW",bool)
    if SERVER and self.Trail:IsValid() then
        self.Trail:SetNoDraw(not bool)
    end
end

function ENT:GetDrawVisible()
    return self:GetNWBool("DRAW",false)
end

function ENT:SetGlowCoef(coef)
    self:SetNWInt("COEF",coef)
end

function ENT:GetGlowCoef()
    return self:GetNWInt("COEF",1)
end

function ENT:GetHoverbike()
    return self:GetNWEntity("HOVERBIKE",NULL)
end

if SERVER then
    function ENT:SetTrail(startwidth,endwidth,lifetime)
        if self.Trail:IsValid() then self.Trail:Remove() end
        local res =  1 / (startwidth + endwidth) * 0.5

        self.Trail = util.SpriteTrail(self,0,maincol,true,startwidth,endwidth,lifetime,res,"trails/laser.vmt")

        self.Trail.StartWidth = startwidth
        self.Trail.EndWidth   = endwidth
        self.Trail.Lifetime   = lifetime
    end

    function ENT:HackTrail()
        local endwidth   = self.Trail.EndWidth   or 20
        local startwidth = self.Trail.StartWidth or 200
        local lifetime   = self.Trail.Lifetime   or 1.5
        local res        =  1 / (startwidth + endwidth) * 0.5

        if self.Trail:IsValid() then self.Trail:Remove() end
        self.Trail = util.SpriteTrail(self,0,Color(0,255,0),true,startwidth,endwidth,lifetime,res,"trails/laser.vmt")

        self.Trail.StartWidth = startwidth
        self.Trail.EndWidth   = endwidth
        self.Trail.Lifetime   = lifetime

        self:SetDrawVisible(self:GetDrawVisible())
    end

    function ENT:GetTrail()
        return self.Trail
    end
end

if CLIENT then
    language.Add("hoverbike_trail","Hoverbike's Propeller")

    local spritemat = CreateMaterial("hoverbikesprite","UnlitGeneric",util.KeyValuesToTable([[
    "UnLitGeneric"
    {
        "$basetexture"		"sprites/light_glow01"
        "$nocull" 1
        "$additive" 1
        "$vertexalpha" 1
        "$vertexcolor" 1
        "$ignorez"	0
    }
    ]]))

    function ENT:DrawGlow()
        local underwater = self:WaterLevel() > 0
        local pos = self:GetPos()
        local mult = self:GetGlowCoef()
		render.SetMaterial(spritemat)
		local size = 2 * mult
        if underwater then
            if mult < 30 then
                render.DrawSprite(pos,size,size,altcol)
                render.DrawSprite(pos,8 * mult,1.5 * mult,altcol)
                size = 2 * mult
                render.DrawSprite(pos,size,size,redcol)
                render.DrawSprite(pos,12 * mult,1.5 * mult,redcol)
            end
        else
           	render.DrawSprite(pos,size,size,altcol)
            render.DrawSprite(pos,8 * mult,1.5 * mult,altcol)
            size = 2 * mult
            local bike = self:GetHoverbike()
            if bike:IsValid() then
                if bike:IsHacked() then
                    render.DrawSprite(pos,size,size,Color(0,255,0))
                    render.DrawSprite(pos,12 * mult,1.5 * mult,Color(0,255,0))
                else
                    render.DrawSprite(pos,size,size,maincol)
                    render.DrawSprite(pos,12 * mult,1.5 * mult,maincol)
                end
            end
        end
	end

    function ENT:Draw()
        if self:WaterLevel() == 0 and not self:GetDrawVisible() then return end
        self:DrawGlow()
    end
end