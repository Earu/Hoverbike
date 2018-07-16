AddCSLuaFile()

AccessorFunc(EFFECT,"StartPos","StartPos")
AccessorFunc(EFFECT,"EndPos","EndPos")
AccessorFunc(EFFECT,"Direction","Direction")
AccessorFunc(EFFECT,"TracerTime","TracerTime")

EFFECT.Length = 0.1
EFFECT.TracerMaterial = Material("effects/spark")
EFFECT.Speed = 10000

--copied from garry's laser tracer pretty much
function EFFECT:Init(effectdata)
	self:SetStartPos(effectdata:GetStart())
	self:SetEndPos(effectdata:GetOrigin())

	self:SetDirection(self:GetEndPos() - self:GetStartPos())
	self:SetRenderBoundsWS(self:GetStartPos(),self:GetEndPos())

	self:SetTracerTime(math.min(1,self.StartPos:Distance(self:GetEndPos()) / self.Speed))
	self.DieTime = CurTime() + self:GetTracerTime()
end

function EFFECT:Think()
	return self.DieTime > CurTime()
end

local maincol = Color(10,137,132)
local altcol  = Color(140,200,200,150)
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

local function DrawGlow(pos,mult)
    render.SetMaterial(spritemat)
    local size = 2 * mult
    render.DrawSprite(pos,size,size,altcol)
    render.DrawSprite(pos,8 * mult,1.5 * mult,altcol)
    size = 2 * mult
    render.DrawSprite(pos,size,size,maincol)
    render.DrawSprite(pos,12 * mult,1.5 * mult,maincol)
end

function EFFECT:Render()
	local fDelta = (self.DieTime - CurTime()) / self:GetTracerTime()
	fDelta = math.Clamp(fDelta,0,1) ^ 0.5

	render.SetMaterial(self.TracerMaterial)

	local sinWave = math.sin(fDelta * math.pi)

	local startpos = self:GetEndPos() - self:GetDirection() * (fDelta - sinWave * self.Length)
	local endpos = self:GetEndPos() - self:GetDirection() * (fDelta + sinWave * self.Length)

    DrawGlow(startpos,32)
	render.DrawBeam(startpos,endpos,32,1,0,maincol)
end