setfenv(1,_G)
AddCSLuaFile()

ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.Author          = "Earu"
ENT.Spawnable		= false
ENT.AdminSpawnable 	= false
ENT.PrintName		= "Hoverbike's Debris"

if SERVER then
    local mat = "models/shiny"
    local col = Color(155,155,0)
    local junk = {
        { Model = "models/gibs/helicopter_brokenpiece_03.mdl",    Color = col, Material = mat },
        { Model = "models/gibs/helicopter_brokenpiece_02.mdl",    Color = col, Material = mat },
        { Model = "models/props_debris/prison_wallchunk001a.mdl", Color = col, Material = mat },
        { Model = "models/props_debris/prison_wallchunk001c.mdl", Color = col, Material = mat },
        "models/props_wasteland/light_spotlight01_base.mdl",
        "models/props_wasteland/gear01.mdl",
        "models/props_c17/utilityconnecter006c.mdl",
        "models/props_vehicles/carparts_muffler01a.mdl",
    }

    function ENT:Initialize()
        local rand = math.random(1,#junk)
        local out = junk[rand]
        if istable(out) then
            self:SetModel(out.Model)
            self:SetMaterial(out.Material)
            self:SetColor(out.Color)
            self:SetNWString("MODEL",out.Model)
        else
            self:SetModel(out)
            self:SetNWString("MODEL",out)
        end
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS)

        local phys = self:GetPhysicsObject()
        if phys:IsValid() then
            phys:Wake()
        end
    end

    function ENT:Think()
        self:Fire("ignite")
    end

    function ENT:PhysicsCollide(data,collider)
        local ent = data.HitObject:GetEntity()
        if data.Speed > 300 then
            local dmg = DamageInfo()
            dmg:SetInflictor(self)
            dmg:SetAttacker(self.CPPIGetOwner and self:CPPIGetOwner() or self)
            dmg:SetDamage(100)
            dmg:SetDamageType(DMG_CRUSH)
            ent:TakeDamageInfo(dmg)
        else
            ent:Ignite(5)
        end
    end
end

if CLIENT then
    function ENT:Initialize()
        if self:GetNWString("MODEL") ~= "" then -- predictions crap idk
            self:SetModel(self:GetNWString("MODEL"))
        end
    end

    function ENT:Draw()
        self:DrawModel()
    end
end