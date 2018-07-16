AddCSLuaFile()

local maincol    = Color(10,137,132)
local altcol     = Color(140,200,200,150)
local redcol     = Color(255,50,0)
local Clamp      = math.Clamp
local Sin,Cos    = math.sin,math.cos
local Rand       = math.random
local Abs        = math.abs
local Min        = math.min
local Max        = math.max
local AngleDiff  = math.AngleDifference
local TraceLine  = util.TraceLine
local PID
if SERVER then
    PID          = include("hoverbike/pid.lua")
end

--util.PrecacheSound("hoverbike/shoot.wav")
for _,f in pairs((file.Find("sound/hoverbike/*","GAME"))) do
    util.PrecacheSound("sound/hoverbike/" .. f)
end

list.Set("Vehicles","hoverbike",{
    AdminOnly       = false,
    Name            = "Hoverbike",
    Class           = "hoverbike",
    PrintName		= "Hoverbike",
    ClassName       = "hoverbike",
    Category        = "Half-Life 2",
    Information     = "A REAL Hoverbike!",
    Model           = "models/hoverbike/hoverbike.mdl",
})

ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.Author          = "Earu"
ENT.Spawnable		= false
ENT.AdminOnly       = false
ENT.AdminSpawnable 	= false
ENT.MaxTemp         = 1200 -- Maximum temperature
ENT.MinTemp         = 20   -- Minimum temperature

function ENT:IsTurnedON()
    return self:GetNWBool("TURNED_ON",false)
end

function ENT:GetSeat()
    return self:GetNWEntity("SEAT",NULL)
end

function ENT:GetDriver()
    if self:GetSeat():IsValid() and SERVER then
        return self:GetSeat():GetDriver()
    else
        return NULL
    end
end

function ENT:GetResponsible()
    if self:GetDriver():IsValid() then
        return self:GetDriver()
    elseif self.CPPIGetOwner and self:CPPIGetOwner():IsValid() then
        return self:CPPIGetOwner()
    elseif IsValid(self.Owner) then
        return self.Owner
    else
        return self
    end
end

function ENT:GetWeaponHeat()
    return self:GetNWInt("WEAPON_HEAT",self.MinTemp)
end

function ENT:GetMaxWeaponHeat()
    return self:GetNWInt("MAX_WEAPON_HEAT",self.MaxTemp)
end

function ENT:IsHacked()
    return self:GetNWBool("IS_HACKED",false)
end

function ENT:MaxHealth()
    return self:IsHacked() and 6000 or 1000
end

function ENT:GetKmpH()
    local speed = self:GetVelocity():Length2D()
    speed = speed * 0.01905 -- to meter/s
    speed = speed * 3.6 -- to km/h
    return speed
end

if SERVER then
    util.AddNetworkString("HoverbikeHUD")
    util.AddNetworkString("HoverbikeHack")

    local function AddResourceDir(dir)
        for _,f in pairs((file.Find(dir .. "/*","GAME"))) do
            local path = dir .. "/" .. f
            resource.AddFile(path)
        end
    end

    local cvarallowfire = CreateConVar("hoverbike_allow_fire",     "1",FCVAR_ARCHIVE,"Allows hoverbike to fire")
    local cvarallowdmg  = CreateConVar("hoverbike_allow_dmg",      "1",FCVAR_ARCHIVE,"Allow players to damage hoverbikes")
    local cvarallowexpl = CreateConVar("hoverbike_allow_explosion","1",FCVAR_ARCHIVE,"Allow hoverbikes to explode when dying")
    local cvarallowdebr = CreateConVar("hoverbike_allow_debris",   "1",FCVAR_ARCHIVE,"Allow debris on hoverbike explosions")
    local cvarallowigni = CreateConVar("hoverbike_allow_ignite",   "1",FCVAR_ARCHIVE,"Allow hoverbikes to ignite when their health is going low")
    local cvaradminonly = CreateConVar("hoverbike_admin_only",     "0",FCVAR_ARCHIVE,"Makes the hoverbike admin only")
    local cvarspeed     = CreateConVar("hoverbike_speed_mult",     "5",FCVAR_ARCHIVE,"Changes the base hoverbike speed")
    local cvarturbo     = CreateConVar("hoverbike_turbo_mult",     "2",FCVAR_ARCHIVE,"Changes the turbo hoverbike speed")
    local cvarallowhack = CreateConVar("hoverbike_allow_hack",     "1",FCVAR_ARCHIVE,"Allows admins to hack hoverbikes to gain boosts")
    local cvarfastdl    = CreateConVar("hoverbike_fastdl",         "1",FCVAR_ARCHIVE,"Should clients download content for hoverbikes on join or not")

    if cvarfastdl:GetBool() then
        --AddResourceDir("models/hoverbike")
        AddResourceDir("materials/models/hoverbike")
        AddResourceDir("sound/hoverbike")
        AddResourceDir("resource/fonts")

        resource.AddFile("models/hoverbike/hoverbike.mdl")
        resource.AddFile("materials/entities/hoverbike.png")
    end

    local riders = {}
    local function IsRider(ply)
        return riders[ply] ~= nil
    end

    local GPO = FindMetaTable("Entity").GetPhysicsObject

    --[[
        <HOVERBIKE'S INPUTS>
    ]]--

    local function OnEnterVehicle(ply,veh)
        if veh.IsHoverbike then
            local bike = veh:GetHoverbike()
            riders[ply] = bike
            if ply:GetInfoNum("hoverbike_auto_switch",1) ~= 0 then
                bike:TurnON()
            end
            net.Start("HoverbikeHUD")
            net.WriteBool(true)
            net.WriteEntity(bike)
            net.Send(ply)
        end
    end

    local function OnLeaveVehicle(ply)
        local bike = riders[ply]
        if bike then
            bike.Forward   = false
            bike.Backward  = false
            bike.Left      = false
            bike.Right     = false
            bike.TurboCoef = 1
            bike.Firing    = false
            if ply:GetInfoNum("hoverbike_auto_switch",1) ~= 0 then
                bike:TurnOFF()
            end

            net.Start("HoverbikeHUD")
            net.WriteBool(false)
            net.WriteEntity(bike)
            net.Send(ply)

            timer.Simple(0,function() -- Small hack
                if bike:IsValid() and ply:IsValid() then
                    bike:ResetBoneAngles(ply)
                end
            end)

            riders[ply] = nil
        end
    end

    local controls = {
        [IN_FORWARD] = function(bike,bool)
            bike.Forward = bool
        end,
        [IN_BACK] = function(bike,bool)
            bike.Backward = bool
        end,
        [IN_MOVELEFT] = function(bike,bool)
            bike.Left = bool
        end,
        [IN_MOVERIGHT] = function(bike,bool)
            bike.Right = bool
        end,
        [IN_SPEED] = function(bike,bool)
            bike.TurboCoef = bool and cvarturbo:GetInt() or 1
        end,
        [IN_RELOAD] = function(bike,bool)
            if bool then return end
            if not bike:IsTurnedON() then
                bike:TurnON()
            else
                bike:TurnOFF()
            end
        end,
        [IN_JUMP] = function(bike,bool)
            if not bool then return end
            if not bike:IsAroundFlightHeight(20) then return end
            local phys = GPO(bike)
            phys:Wake()
            local ratio = (1000 / phys:GetMass()) * 1000
            if bike:IsHacked() then
                phys:AddVelocity(Vector(0,0,ratio))
            else
                phys:AddVelocity(Vector(0,0,ratio / 2))
            end
            bike:EmitSound("hoverbike/jump.wav")
        end,
        [IN_ATTACK2] = function(bike,bool)
            if not bool then return end
            if CurTime() < bike.NextDodge then return end
            local left = bike.Left and 1 or 0
            local right = bike.Right and 1 or 0
            if (left - right) ~= 0 then
                local phys = GPO(bike)
                phys:Wake()
                phys:AddAngleVelocity(Vector(0,150 * (left - right),0))
                phys:AddVelocity(bike:GetForward() * (left - right) * (bike.Speed * 100) * 2)
                bike:EmitSound("hoverbike/jump.wav",75,90)
                bike.NextDodge = CurTime() + 1.25
            end
        end,
        [IN_ATTACK] = function(bike,bool)
            bike.Firing = bool
        end,
    }

    local function OnKeyPress(ply,key)
        if IsRider(ply) then
            local veh = ply:GetVehicle()
            if IsValid(veh:GetHoverbike()) then
                if controls[key] then
                    controls[key](veh:GetHoverbike(),true)
                end
            end
        end
    end

    local function OnKeyRelease(ply,key)
        if IsRider(ply) then
            local veh = ply:GetVehicle()
            if IsValid(veh:GetHoverbike()) then
                if controls[key] then
                    controls[key](veh:GetHoverbike(),false)
                end
            end
        end
    end

    hook.Add("PlayerEnteredVehicle","Hoverbike",OnEnterVehicle)
    hook.Add("PlayerLeaveVehicle","Hoverbike",OnLeaveVehicle)
    hook.Add("PlayerDisconnected","Hoverbike",OnLeaveVehicle)
    hook.Add("KeyPress","Hoverbike",OnKeyPress)
    hook.Add("KeyRelease","Hoverbike",OnKeyRelease)

    --[[
        </HOVERBIKE'S INPUTS>
    ]]--

    ENT.FlyHeight        = 55    -- Base distance to ground
    ENT.FlyInterval      = 5     -- Variation in flight height
    ENT.Speed            = 6     -- Arbitrary speed coef
    ENT.TurboCoef        = 1     -- Speed coef multiplier (2 when shift is pressed)
    ENT.Forward          = false -- Are we going forward?
    ENT.Backward         = false -- Are we going backward?
    ENT.Left             = false -- Are we going left?
    ENT.Right            = false -- Are we going right?
    ENT.Firing           = false -- Are we firing (mouse1)?
    ENT.NextShoot        = 0     -- When are we able to shoot again(mouse1)
    ENT.ShootCount       = 0     -- The amount of bullets that have been fired
    ENT.MegaShootMult    = 5     -- Each x shot, a mega shoot will happen
    ENT.NextSCountReset  = 0     -- After how much time should we reset shoot count
    ENT.NextDodge        = 0     -- After how much time can we dodge again

    function ENT:ApplySitBoneAngles(ply)
        if not ply:IsValid() then return end
        local boneangles = {
            ["ValveBiped.Bip01_Head1"]      = Angle(0,20,0),   -- head
            ["ValveBiped.Bip01_Neck1"]      = Angle(0,20,0),   -- neck
            ["ValveBiped.Bip01_L_Clavicle"] = Angle(0,0,-48),  -- left clavicle
            ["ValveBiped.Bip01_L_Forearm"]  = Angle(-20,22,0), -- left forearm
            ["ValveBiped.Bip01_L_Thigh"]    = Angle(-25,40,0), -- left thigh
            ["ValveBiped.Bip01_R_Clavicle"] = Angle(0,0,48),   -- right clavicle
            ["ValveBiped.Bip01_R_Forearm"]  = Angle(0,28,0),   -- right forearm
            ["ValveBiped.Bip01_R_Thigh"]    = Angle(25,40,0)   -- right thigh
        }
        local count = (ply:GetBoneCount() or 0) - 1
        for name,ang in pairs(boneangles) do
            local id = ply:LookupBone(name)
            if id and id <= count and id >= 0 then
                ply:ManipulateBoneAngles(id,ang)
            end
        end
    end

    function ENT:ResetBoneAngles(ply)
        if not ply:IsValid() then return end
        local count = (ply:GetBoneCount() or 0) - 1
        for i=0,count do
            ply:ManipulateBoneAngles(i,Angle(0,0,0))
        end
    end

    function ENT:TurnON()
        if self:IsTurnedON() then return end
        if self:WaterLevel() > 0 then
            self:EmitSound("hoverbike/shutdown.wav")
            return
        end
        self:SetNWBool("TURNED_ON",true)
        self:SetPos(self:GetPos() + Vector(0,0,10))
        local cur = self:GetAngles()
        cur.roll = 0
        cur.pitch = 0
        self:SetAngles(cur)
        GPO(self):Wake()
        for _,trail in pairs(self.Trails) do
            if trail:IsValid() then
                trail:SetDrawVisible(true)
            end
        end
        self.FlyLoop = CreateSound(self,"npc/scanner/cbot_fly_loop.wav")
        self.FlyLoop:Play()
        self:EmitSound("ambient/machines/thumper_startup1.wav")
    end

    function ENT:TurnOFF()
        if not self:IsTurnedON() then return end
        self:SetNWBool("TURNED_ON",false)
        for _,trail in pairs(self.Trails) do
            if trail:IsValid() then
                trail:SetDrawVisible(false)
            end
        end
        self.FlyLoop:FadeOut(1)
        self:EmitSound("ambient/machines/thumper_shutdown1.wav")
        self.FlightPID:Reset()
        self.RollPID:Reset()
        self.PitchPID:Reset()
        self.ShootCount = 0
    end

    function ENT:HeatUp(increase)
        local cur = self:GetWeaponHeat()
        self:SetNWInt("WEAPON_HEAT",Clamp(cur + increase,self.MinTemp,self.MaxTemp))
    end

    function ENT:CoolDown(decrease)
        local cur = self:GetWeaponHeat()
        self:SetNWInt("WEAPON_HEAT",Clamp(cur - decrease,self.MinTemp,self.MaxTemp))
    end

    function ENT:CreateTrail(startw,endw,lifetime,coef,pos,islocal)
        self.Trails = self.Trails or {}
        local trail = ents.Create("hoverbike_trail")
        if islocal then
            trail:SetParent(self)
            trail:SetLocalPos(pos)
        else
            trail:SetPos(pos)
            trail:SetParent(self)
        end
        trail:Spawn()
        trail:SetTrail(startw,endw,lifetime)
        trail:SetGlowCoef(coef)
        trail:SetDrawVisible(false)
        trail:SetNotSolid(true)
        trail:SetNWEntity("HOVERBIKE",self)
        table.insert(self.Trails,trail)
    end

    -- Don't change the values in there
    function ENT:SetupTrails()
        -- Main trails
        local back = self:GetPos() + self:GetRight() * -75
        local left = self:GetForward() * 5
        local up = self:GetUp() * 40
        self:CreateTrail(200,20,1.5,45,back + left + up)
        self:CreateTrail(200,20,1.5,45,back - left + up)

        up = self:GetUp() * 30
        self:CreateTrail(200,20,1.5,45,back + left + up)
        self:CreateTrail(200,20,1.5,45,back - left + up)

        -- Aux trails
        back = self:GetPos() + self:GetRight() * -70
        left = self:GetForward() * 11
        up = self:GetUp() * 20
        self:CreateTrail(50,5,1,20,back + left + up)
        self:CreateTrail(50,5,1,20,back - left + up)

        up = self:GetUp() * 18
        left = self:GetForward() * 18
        self:CreateTrail(50,5,1,20,self:GetPos() + left + up)
        self:CreateTrail(50,5,1,20,self:GetPos() - left + up)
    end

    function ENT:Initialize()
        self:SetModel("models/hoverbike/hoverbike.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetMaxHealth(self:MaxHealth())
        self:SetHealth(1000)
        self:SetUseType(SIMPLE_USE)
        self:StartMotionController()
        self.Speed = cvarspeed:GetInt()

        local phys = GPO(self)
        if phys:IsValid() then
            phys:Wake()
        end

        self.FlightPID = PID(0.5,0,0.02)  -- PID controller for the flight height
        self.PitchPID  = PID(0.84,0,0.02) -- PID controller for laying on sides while turning
        self.RollPID   = PID(0.84,0,0.02) -- PID controller for setting angle according to world geometry
		self.Stabilizers = {
			{ PID = self.PitchPID, GetDir = self.GetForward, ForceDir = self.GetRight,   Sign = -1 },
			{ PID = self.RollPID,  GetDir = self.GetRight  , ForceDir = self.GetForward, Sign = 1  },
		}
        local seat = ents.Create("prop_vehicle_prisoner_pod")
        seat:SetModel("models/nova/jeep_seat.mdl")
        seat:SetPos(self:GetPos() + self:GetUp() * 45 - self:GetRight() * 30)
        seat:SetAngles(Angle(0,self:GetAngles().yaw + 180,-40))
        seat:SetKeyValue("vehiclescript","scripts/vehicles/airboat.txt")
        seat:SetKeyValue("limitview","1")
        seat:Spawn()
        seat:SetNoDraw(true)
        seat:SetParent(self)
        seat.IsHoverbike = true
        seat.GetHoverbike = function() return self end
        seat.GetVehicle = function() return self end
        self:SetNWEntity("SEAT",seat)

        self:SetNWInt("WEAPON_HEAT",self.MinTemp)
        self:SetNWInt("MAX_WEAPON_HEAT",self.MaxTemp)

        self:SetupTrails()
        self:TurnOFF()
    end

    function ENT:IsVehicle() -- This doesnt work
        return true
    end

    function ENT:GetFlightHeight()
        return self.FlyHeight + ((Sin(CurTime()) + Sin(CurTime()*2+123.3)*.7 + Sin(CurTime()*3-34.13)*.5) * self.FlyInterval * .3)
    end

    function ENT:GetTraceFilter()
        return table.Add({ self, self:GetSeat(), self:GetDriver() },self.Trails)
    end

    local function TraceStruct(self,startpos,dist)
        return {
            start  = startpos,
            endpos = startpos - Vector(0,0,dist),
            filter = self:GetTraceFilter(),
            mask   = bit.bor(MASK_SOLID,MASK_WATER,MASK_CURRENT),
        }
    end

    function ENT:IsAroundFlightHeight(err)
        local tr = TraceLine(TraceStruct(self,self:GetPos(),1000))
        if self:GetPos().z > tr.HitPos.z + self:GetFlightHeight() + err then
            return false
        else
            return true
        end
    end

	function ENT:PhysicsSimulate(phys,delta)
		local gravz = physenv.GetGravity().z
		local torque, acceleration = Vector(0,0,0),Vector(0,0,gravz) -- Otherwise no gravity
		if not self:IsTurnedON() then return torque,acceleration,SIM_NOTHING end
		local dampfactor  = 1.00001 -- Do NOT touch this
		local ang         = self:GetAngles()
		local vel, angvel = phys:GetVelocity(),phys:GetAngleVelocity()
		local pos, offset = self:WorldSpaceCenter(),self:GetRight() * 15 -- Right is the actual forward
        local front, back = pos + offset,pos - offset
        local flightz     = self:GetFlightHeight()
		local trfront     = TraceLine(TraceStruct(self,front,flightz * 2))
		local trback      = TraceLine(TraceStruct(self,back,flightz * 2))
		local trnorm      = (trfront.HitNormal or Vector(0,0,1)) * 0.5 + (trback.HitNormal or Vector(0,0,1)) * 0.5
		local targetz     = Max(trfront.HitPos.z,trback.HitPos.z) + flightz
		local zforce      = self.FlightPID:Compute(pos.z - targetz,delta) * gravz

		-- This is for jumps mostly
		if pos.z - targetz > 0 then
			acceleration.z = gravz / 5 -- We dont want the actual gravity, too strong
        else
            -- Force necessary to hover
			acceleration.z = zforce
		end

		local forward   = self.Forward  and 1 or 0
		local backward  = self.Backward and 1 or 0
		local moveleft  = self.Left     and 1 or 0
		local moveright = self.Right    and 1 or 0

		if (forward - backward) == 0 then
			-- Velocity decay if no backward or forward key pressed
			local decay = -vel * 2 / dampfactor
			acceleration.x = decay.x
			acceleration.y = decay.y
        else
            -- Apply forward/backward force
			local forcectrl = (self:GetRight() * self.Speed * (forward - backward) * self.TurboCoef) / delta
			acceleration.x = forcectrl.x
			acceleration.y = forcectrl.y
		end

		local up = trnorm * 1
		up = up:LengthSqr() < 0.001 and Vector(0,0,1) or up

		for _,stabilizer in ipairs(self.Stabilizers) do
			local dir      = stabilizer.GetDir(self)
			local forcedir = stabilizer.ForceDir(self)
			local pid      = stabilizer.PID
			local force    = up:Dot(dir)
			force          = pid:Compute(force,delta)

			-- clamp the pid
			-- pid.I = math.min(pid.I * (1 - delta * 3), 0.06)

			force = stabilizer.Sign * force * 3000

			stabilizer.force = force
			torque:Add(phys:WorldToLocalVector(forcedir * force))
		end

        local force_rotate = (moveleft - moveright) * ((self.Speed * 100) / 2) / self.TurboCoef
        torque:Add(phys:WorldToLocalVector(trnorm * force_rotate))
        torque:Add(phys:WorldToLocalVector(self:GetRight() * (moveleft - moveright) * -155))

		torque:Sub(angvel * 2)
		phys:Wake()
		return torque,acceleration,SIM_GLOBAL_ACCELERATION
	end

    local impactsounds = {
        "physics/metal/metal_solid_impact_soft1.wav",
        "physics/metal/metal_solid_impact_soft2.wav",
        "physics/metal/metal_solid_impact_soft3.wav",
        "physics/metal/metal_solid_impact_hard1.wav",
        "physics/metal/metal_solid_impact_hard2.wav",
        "physics/metal/metal_solid_impact_hard3.wav",
        "physics/metal/metal_solid_impact_hard4.wav",
        "physics/metal/metal_solid_impact_hard5.wav",
    }
    function ENT:PhysicsCollide(data,collider)
        local vel = self:IsTurnedON() and data.OurOldVelocity:Length2D() or data.OurOldVelocity:Length()
        if data.HitEntity.GetHoverbike and data.HitEntity:GetHoverbike() == self then return end
        if vel >= 200 then
            local s = vel <= 1000 and impactsounds[Rand(1,3)] or impactsounds[Rand(4,#impactsounds)]
            self:EmitSound(s)
            local dmg = DamageInfo()
            dmg:SetDamageType(DMG_CRUSH)
            dmg:SetInflictor(self)
            dmg:SetAttacker(data.HitEntity.CPPIGetOwner and data.HitEntity:CPPIGetOwner() or data.HitEntity or game.GetWorld())
            dmg:SetDamage(vel / 170)
            self:TakeDamageInfo(dmg)
        end
    end

    local function BulletStruct(self,pos,offset)
        return {
            Attacker     = self:GetResponsible(),
            Src          = pos + offset,
            Dir          = self:GetRight(),
            TracerName   = "hoverbike_tracer",
            Damage       = 20,
            Force        = 100,
            HullSize     = 10,
            IgnoreEntity = self,
        }
    end

    function ENT:FireCore(offset)
        offset = offset or Vector(0,0,0)
        local core = ents.Create("hoverbike_core")
        local pos = self:GetPos() + self:GetUp() * 20 + self:GetRight() * 40
        core:SetPos(pos + offset)
        core:Spawn()
        core.Owner = self:GetResponsible()
        core.Inflictor = self
        core.TraceFilter = self:GetTraceFilter()
        core:SetHacked(self:IsHacked())
        GPO(core):Wake()
        GPO(core):SetVelocity(self:GetRight() * 10000)
    end

    function ENT:FireLasers()
        if not cvarallowfire:GetBool() then return end
        self:HeatUp(2)
        if self:GetWeaponHeat() == self:GetMaxWeaponHeat() then
            self:KABOOM()
        end
        if CurTime() < self.NextShoot then return end
        local pos    = self:GetPos() + self:GetUp() * 23 + self:GetRight() * 40
        local offset = self:GetForward() * 30
        if self:IsHacked() or (not self:IsHacked() and self.ShootCount > 0 and self.ShootCount % self.MegaShootMult == 0) then
            self:EmitSound("hoverbike/shoot.wav",100,50)
            self:HeatUp(20)
            self:FireCore(offset)
            self:FireCore(-offset)
        else
            self:EmitSound("hoverbike/shoot.wav")
            self:FireBullets(BulletStruct(self,pos,offset))
            self:FireBullets(BulletStruct(self,pos,-offset))
        end
        self.ShootCount      = self.ShootCount + 1
        self.NextShoot       = CurTime() + 0.2
        self.NextSCountReset = CurTime() + 1
    end

    function ENT:Think()
        if self:IsTurnedON() then
            if self.Firing then
                self:FireLasers()
            else
                if CurTime() >= self.NextSCountReset then
                    self.ShootCount = 0
                end
                self:CoolDown(5)
            end
            self.FlyLoop:ChangePitch(75 + Clamp(self:GetKmpH(),0,75))
        else
            self:CoolDown(5)
        end
        if self:WaterLevel() > 0 then
            self:TurnOFF()
        end
        local driver = self:GetDriver()
        if driver:IsValid() then
            self:ResetBoneAngles(driver)
            self:ApplySitBoneAngles(driver)
        end
        self:NextThink(CurTime())
        return true
    end

    local function GetRandomDebrisVelocity()
        local x = Rand(-900,900)
        local y = Rand(-900,900)
        local z = Rand(1000,400)

        return Vector(x,y,z)
    end

    local explsounds = {
        "^weapons/explode3.wav",
        "^weapons/explode4.wav",
    }
    function ENT:KABOOM(dmg)
        if not cvarallowexpl:GetBool() then
            SafeRemoveEntity(self)
            return
        end
        if self.DidKaboom then return end
        if not dmg then
            dmg = DamageInfo()
            dmg:SetAttacker(self:GetResponsible())
            dmg:SetInflictor(self)
            dmg:SetDamage(100)
            dmg:SetDamageType(DMG_BLAST)
        end
        local pos = self:GetPos() + Vector(0,0,20)
        if cvarallowdebr:GetBool() then
            for i=1,Rand(6,8) do
                local debris = ents.Create("hoverbike_debris")
                debris:SetPos(pos)
                debris:Spawn()
                GPO(debris):SetVelocity(GetRandomDebrisVelocity())
                timer.Simple(10,function()
                    if debris:IsValid() then
                        debris:Remove()
                    end
                end)
            end
        end
        if self:GetDriver():IsValid() then
            local driver = self:GetDriver()
            dmg:SetInflictor(self)
            dmg:SetDamage(driver:Health() + 1)
            driver:TakeDamageInfo(dmg)
        end
        self.DidKaboom = true
        local data = EffectData()
        data:SetOrigin(pos)
        data:SetScale(3)
        data:SetRadius(10)
        util.Effect("hoverbike_explosion",data)
        local s = explsounds[Rand(1,#explsounds)]
        self:EmitSound(s,100)
        s = explsounds[Rand(1,#explsounds)]
        self:EmitSound(s,100)

        -- This looks stupid, I know but required because some addons are poorly coded :/
        local atcker = dmg:GetAttacker():IsValid() and dmg:GetAttacker() or game.GetWorld()
        local inflictor = self:IsValid() and self or self:GetDriver()
        if inflictor:IsValid() then
            util.BlastDamage(inflictor,atcker,pos,500,150)
        end

        SafeRemoveEntity(self)
    end

    function ENT:OnTakeDamage(dmg)
        if not cvarallowdmg:GetBool() then return end
        local amount = dmg:GetDamage()
        self:SetHealth(self:Health() - amount)
        local health = self:Health()
        if cvarallowigni:GetBool() then
            if health <= 200 and health > 0 then
                self:Fire("ignite")
            end
        end
        if health <= 0 then
            self:KABOOM(dmg)
        end
    end

    function ENT:Use(act,caller)
        if self:GetSeat():IsValid() then
            caller:EnterVehicle(self:GetSeat())
        end
    end

    -- Works only in sandbox and derived gamemodes it seems
    hook.Add("PlayerSpawnVehicle","Hoverbike",function(ply,model,name,t)
        if name == "hoverbike" then
            if cvaradminonly:GetBool() and not ply:IsAdmin() then
                ply:ChatPrint("You don't have the rights to spawn hoverbikes!")
                return false
            end
        end
    end)

    -- Sandbox only as well
    hook.Add("PlayerSpawnedVehicle","Hoverbike",function(ply,veh)
        if veh:GetClass() == "hoverbike" then
            veh.Owner = ply
        end
    end)

    function ENT:OnRemove()
        if self:IsTurnedON() then
            self:TurnOFF()
            self.FlyLoop:Stop()
        end
    end

    function ENT:HACK(ply)
        ply = IsValid(ply) and ply or self:GetResponsible()
        if not cvarallowhack:GetBool() then return end
        self:SetNWBool("IS_HACKED",true)
        for _,trail in ipairs(self.Trails) do
            trail:HackTrail()
        end
        self.MaxTemp = 5000
        self:SetNWInt("MAX_WEAPON_HEAT",self.MaxTemp)
        self.Speed = self.Speed * 2
        self:SetMaxHealth(self:MaxHealth())
        self:SetHealth(6000)
        if ply:IsValid() then
            net.Start("HoverbikeHack")
            net.WriteEntity(ply)
            net.Broadcast()
        end
    end
end

if CLIENT then
    language.Add("hoverbike","Hoverbike")

    local cvarauto  = CreateClientConVar("hoverbike_auto_switch","1",true,true,"Enabled, this automatically turns ON and OFF hoverbikes for you")
    local cvarlight = CreateClientConVar("hoverbike_lights","1",true,false,"Disabling this may improve FPS on some maps")
    local cvarhud   = CreateClientConVar("hoverbike_hud","1",true,false,"Disabling this may improve your FPS while riding an hoverbike")

    function ENT:ApplyLightSettings(dyna)
        dyna.pos = self:GetPos() + Vector(0,0,30)
        if self:WaterLevel() == 0 then
            if self:IsHacked() then
                dyna.r = 0
                dyna.g = 50
                dyna.b = 0
            else
                dyna.r = maincol.r
                dyna.g = maincol.g
                dyna.b = maincol.b
            end
        else
            dyna.r = redcol.r
            dyna.g = redcol.g
            dyna.b = redcol.b
        end
        dyna.brightness = 2
        dyna.decay      = 1000
        dyna.size       = 2048
        dyna.style      = 1
        dyna.dieTime    = CurTime() + 1
    end

    function ENT:Think()
        if self:WaterLevel() == 0 and not self:IsTurnedON() then return end
        if not cvarlight:GetBool() then return end
        local dyna = DynamicLight(self:EntIndex())
		if dyna then
            self:ApplyLightSettings(dyna)
        end
    end

    local maincol    = Color(0,255,255)
    local redcol     = Color(255,0,0)
    local viewmat    = Material("models/hoverbike/viewfinder.png")
    local targetmat  = Material("models/hoverbike/target.png")
    local panelmat   = Material("models/hoverbike/target_panel.png")
    local warningmat = Material("models/hoverbike/warning.png")
    local infomat    = Material("models/hoverbike/info_panel.png")
    local glow2      = Material("sprites/blueglow2")

    surface.CreateFont("HoverbikeLight",{font = "Guardians",size = 15,weight = 500,antialias = false,shadow = true})

    local GetPlayers = player.GetAll
    local surface    = _G.surface
    local render     = _G.render
    local function VectorToString(vec)
        return ("%d\t%d\t%d"):format(vec.x,vec.y,vec.z)
    end

    function ENT:HackedMaterial()
        if not IsValid(self.HackedClientProp) then
            local cent = ents.CreateClientProp("models/hoverbike/hoverbike.mdl")
            --cent:SetRenderMode(RENDERMODE_TRANSALPHA)
            cent:SetColor(Color(0,255,0))
            cent:SetMaterial("models/props_combine/portalball001_sheet")
            cent:SetPos(self:GetPos())
            cent:SetAngles(self:GetAngles())
            cent:SetModelScale(1.02)
            cent:Spawn()
            cent:SetParent(self)
            cent:SetNoDraw(not self:IsTurnedON())
            self.HackedClientProp = cent
        else
            self.HackedClientProp:SetColor(Color(0,255,0))
            self.HackedClientProp:SetNoDraw(not self:IsTurnedON())
        end
    end

    function ENT:OnRemove()
        if IsValid(self.HackedClientProp) then
            self.HackedClientProp:Remove()
        end
    end

    function ENT:Draw()
        self:DrawModel()
        if self:IsHacked() then
            self:HackedMaterial()
        end
    end

    -- Hoverbike ent,screen width,screen height
    local function DrawTargetPanel(bike,sw,sh)
        local sw,sh = ScrW(),ScrH()
        if not bike:IsTurnedON() then
            surface.SetDrawColor(redcol.r,redcol.g,redcol.b,180)
            surface.SetMaterial(panelmat)
            surface.DrawTexturedRect(0,0,sw,sh)
            surface.SetMaterial(warningmat)
            surface.DrawTexturedRect(sw / 2 - 50,sh / 2 - 50,100,100)
            surface.SetTextColor(redcol.r,redcol.g,redcol.b,180)
            local tw,_ = surface.GetTextSize("MAIN SYSTEMS OFFLINE")
            surface.SetTextPos(sw / 2 - tw / 2,sh / 2 + 65)
            surface.DrawText("MAIN SYSTEMS OFFLINE")

        else
            if not bike:IsHacked() then
                surface.SetDrawColor(maincol.r,maincol.g,maincol.b,220)
                surface.SetTextColor(maincol.r,maincol.g,maincol.b,120)
            else
                surface.SetDrawColor(0,255,0,220)
                surface.SetTextColor(0,255,0,120)
            end

            surface.SetMaterial(panelmat)
            surface.DrawTexturedRect(0,0,sw,sh)
        end
    end

    -- Hoverbike ent,screen width,screen height,size of viewfinder,rotation of viewfinder
    local function DrawViewFinder(bike,sw,sh,size,rot)
        local bikepos = bike:GetPos() + bike:GetUp() * 20
        local tr = TraceLine({
            start       = bikepos,
            endpos      = bikepos + bike:GetRight() * 3000,
            filter      = bike,
        })
        local hitpos = tr.HitPos:ToScreen()
        surface.SetMaterial(viewmat)
        if bike:IsHacked() then
            surface.SetDrawColor(0,255,0)
        else
            surface.SetDrawColor(maincol.r,maincol.g,maincol.b,255)
        end
        surface.DrawTexturedRectRotated(hitpos.x,hitpos.y,50 + size,50 + size,-rot)
    end

    -- Localplayer ent,screen width,size of the player info,rotation of the player info
    local function DrawPlayersInfo(bike,lp,sw,size,rot)
        if bike:IsHacked() then
            surface.SetDrawColor(0,255,0)
        else
            surface.SetDrawColor(maincol.r,maincol.g,maincol.b,180)
        end
        surface.SetMaterial(targetmat)
        for _,p in ipairs(GetPlayers()) do
            if p ~= lp then
                local ply = p:Alive() and p or p:GetRagdollEntity()
                if ply:IsValid() then
                    local tr = TraceLine({ start = lp:EyePos(), endpos = ply:WorldSpaceCenter(), filter = bike })
                    if bike:IsHacked() or tr.Hit and tr.Entity == ply then
                        local nick   = (ply:IsPlayer() and ply:Nick() or p:Nick()):gsub("<.->","")
                        local plpos  = ply:GetPos()
                        local pos    = (plpos + ply:OBBCenter()):ToScreen()
                        local strpos = VectorToString(plpos)

                        surface.DrawTexturedRectRotated(pos.x,pos.y,40 + size,40 + size,rot)
                        local offset = pos.x >= sw / 2 and -35 or 35
                        if offset == -35 then
                            local tw,_ = surface.GetTextSize(nick)
                            surface.SetTextPos(pos.x + offset - tw,pos.y)
                            surface.DrawText(nick)

                            tw = (surface.GetTextSize(strpos))
                            surface.SetTextPos(pos.x + offset - tw,pos.y + 15)
                            surface.DrawText(strpos)
                        else
                            surface.SetTextPos(pos.x + offset,pos.y)
                            surface.DrawText(nick)

                            surface.SetTextPos(pos.x + offset,pos.y + 15)
                            surface.DrawText(strpos)
                        end
                    end
                end
            end
        end
    end

    local function DrawOutlinedPoly(coords)
        for i,coord in ipairs(coords) do
            local nextc = coords[i + 1] or coords[1]
            surface.DrawLine(coord.x,coord.y,nextc.x,nextc.y)
        end
    end

    local function SetProperPolyColor(bike,alpha)
        if bike:IsTurnedON() then
            if bike:IsHacked() then
                surface.SetDrawColor(0,255,0,alpha + 75)
            else
                surface.SetDrawColor(maincol.r,maincol.g,maincol.b,alpha)
            end
        else
            surface.SetDrawColor(redcol.r,redcol.g,redcol.b,alpha)
        end
    end

    local health = 0
    local function DrawHoverbikeInfo(bike,sw,sh)
        local ratiox,ratioy = ScrW() / 2560, ScrH() / 1440
        local curhealth = bike:Health()
        local maxhealth = bike:MaxHealth()
        health = Clamp(health,0,maxhealth) -- Prevent some bugs
        if curhealth ~= health then
            if curhealth < health then
                health = Clamp(health - 2,curhealth,health)
            else
                health = Clamp(health + 2,health,curhealth)
            end
        end
        draw.NoTexture()
        local phealthbg = {
            { x = 180 * ratiox, y = 150 * ratioy },
            { x = 210 * ratiox, y = 100 * ratioy },
            { x = 480 * ratiox, y = 100 * ratioy },
            { x = 450 * ratiox, y = 150 * ratioy },
        }
        DrawOutlinedPoly(phealthbg)
        local hlposxtop = 210 * ratiox + 270 * (health / maxhealth) * ratiox
        local hlposxbot = 180 * ratiox + 270 * (health / maxhealth) * ratiox
        local hlposytop,hlposybot = 100 * ratioy,150 * ratioy
        local phealth = {
            { x = 180 * ratiox, y = 150 * ratioy },
            { x = 210 * ratiox, y = 100 * ratioy },
            { x = hlposxtop,    y = hlposytop    },
            { x = hlposxbot,    y = hlposybot    },
        }

        SetProperPolyColor(bike,120)
        surface.DrawPoly(phealth)
        SetProperPolyColor(bike,180)

        local _,th = surface.GetTextSize("HEALTH")
        surface.SetTextPos((hlposxtop + hlposxbot) / 2,(hlposybot + hlposytop) / 2 - (th + 1))
        surface.DrawText("HEALTH")

        _,th = surface.GetTextSize(tostring(health))
        surface.SetTextPos((hlposxtop + hlposxbot) / 2,(hlposybot + hlposytop) / 2 + 1)
        surface.DrawText(tostring(health))

        surface.SetTextPos(180 * ratiox,160 * ratioy)
        surface.DrawText("WEAPON HEAT")

        surface.SetTextPos(180 * ratiox,180 * ratioy)
        surface.DrawText("0")

        local maxheat = bike:GetMaxWeaponHeat()
        local n = maxheat / 10
        local amount = bike:GetWeaponHeat() / n
        for i=1,10 do
            local w,h = 15 * ratiox,10 * ratioy
            local x = 190 * ratiox + w * i + 5 * ratiox * (i - 1)
            local y = 185 * ratioy
            if i > amount then
                surface.DrawLine(x,y,x + w,y)
                surface.DrawLine(x,y,x,y + h)
            else
                surface.DrawRect(x,y,w,h)
            end
        end

        local maxtx = 220 * ratiox + 10 * 20 * ratiox
        surface.SetTextPos(maxtx,180 * ratioy)
        surface.DrawText(tostring(maxheat))

        surface.SetTextPos(180 * ratiox,210 * ratioy)
        surface.DrawText("WORLD\t" .. VectorToString(bike:WorldSpaceCenter()))

        surface.SetTextPos(180 * ratiox,230 * ratioy)
        local speed = bike:GetKmpH()
        surface.DrawText(("SPEED\t%d km/h"):format(speed))
    end

    local nextbeep = 0
    local function DrawHoverbikeNotifications(bike,sw,sh)
        local ratiox,ratioy = ScrW() / 2560, ScrH() / 1440
        surface.SetMaterial(infomat)
        surface.SetDrawColor(255,175,0)
        surface.SetTextColor(255,175,0)

        local warning = false
        if bike:Health() <= 200 then
            surface.SetTextPos(sw - 400 * ratiox,120 * ratioy)
            local tw,th = surface.GetTextSize("CRITICAL HEALTH STATUS")
            surface.DrawTexturedRect(sw - 410 * ratiox,110 * ratioy,(tw + 100) * ratiox,(th + 20) * ratioy)
            surface.DrawText("CRITICAL HEALTH STATUS")
            warning = true
        end

        if bike:GetWeaponHeat() >= bike:GetMaxWeaponHeat() - bike:GetMaxWeaponHeat() / 3 then
            local tw,th = surface.GetTextSize("WEAPONS OVERHEATING")
            local _,h = surface.GetTextSize("(MAX: " .. bike:GetMaxWeaponHeat() .. ")")
            th = th + h

            surface.DrawTexturedRect(sw - 410 * ratiox,170 * ratioy,(tw + 100) * ratiox,(th + 30) * ratioy)

            surface.SetTextPos(sw - 400 * ratiox,180 * ratioy)
            surface.DrawText("WEAPONS OVERHEATING")

            surface.SetTextPos(sw - 400 * ratiox,200 * ratioy)
            surface.DrawText("(MAX: " .. bike:GetMaxWeaponHeat() .. ")")

            warning = true
        end

        if warning and CurTime() >= nextbeep then
            surface.PlaySound("hoverbike/beep.wav")
            nextbeep = CurTime() + 0.8
        end
    end

    local hide = {
        CHudHealth                = true,
        CHudBattery               = true,
        CHudCrosshair             = true,
        CHudDamageIndicator       = true,
        CHudPoisonDamageIndicator = true,
        CHudSecondaryAmmo         = true,
        CHudVehicle               = true,
    }
    net.Receive("HoverbikeHUD",function()
        local shouldraw = net.ReadBool()
        local bike = net.ReadEntity()
        if shouldraw then
            hook.Add("HUDPaint","Hoverbike",function()
                if not cvarhud:GetBool() then return end
                local lp = LocalPlayer()
                if not bike:IsValid() then return end

                local sw,sh = ScrW(),ScrH()
                local time  = CurTime()
                local size  = Abs(Sin(time)) * 10
                local rot   = (time * 60) % 360

                draw.NoTexture()
                surface.SetFont("HoverbikeLight")

                DrawTargetPanel(bike,sw,sh) -- Text color is set inside this function
                DrawHoverbikeInfo(bike,sw,sh)
                if bike:IsTurnedON() then
                    DrawViewFinder(bike,sw,sh,size,rot)
                    DrawPlayersInfo(bike,lp,sw,size,rot)
                    DrawHoverbikeNotifications(bike,sw,sh)
                end
            end)
            hook.Add("HUDDrawTargetID","Hoverbike",function()
                if not cvarhud:GetBool() then return end
                return false
            end)
            hook.Add("HUDShouldDraw","Hoverbike",function(name)
                if not cvarhud:GetBool() then return end
                if hide[name] then return false end
            end)
        else
            hook.Remove("HUDPaint","Hoverbike")
            hook.Remove("HUDDrawTargetID","Hoverbike")
            hook.Remove("HUDShouldDraw","Hoverbike")
        end
    end)

    -- Truly a hacker
    net.Receive("HoverbikeHack",function()
        local ply = net.ReadEntity()
        chat.AddText(ply,Color(255,255,255)," earned the achievement ",Color(255,200,0),"Hackerman")
    end)
end