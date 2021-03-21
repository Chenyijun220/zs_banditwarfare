include("shared.lua")

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.Seed = 0
function ENT:Initialize()
	self:SetRenderBounds(Vector(-128, -128, -128), Vector(128, 128, 200))
	self.AmbientSound = CreateSound(self, "ambient/machines/combine_terminal_loop1.wav")
	self.Seed = math.Rand(0, 10)
end

function ENT:Think()
	if EyePos():Distance(self:GetPos()) <= 1000 then
		self.AmbientSound:PlayEx(1, 135)
	else
		self.AmbientSound:Stop()
	end
end

function ENT:OnRemove()
	self.AmbientSound:Stop()
end

ENT.Rotation = math.random(360)

local matBeam = Material("cable/new_cable_lit")
local cDrawWhite = Color(255, 255, 255)

function ENT:DrawTranslucent()
	self:RemoveAllDecals()
	local curtime = CurTime()
	local eyepos = EyePos()
	local eyeangles = EyeAngles()
	local teamcolor = nil
	if (self:GetLastCaptureTeam() == TEAM_BANDIT or self:GetLastCaptureTeam() == TEAM_HUMAN) then 
		teamcolor = team.GetColor(self:GetLastCaptureTeam())
	else
		teamcolor = COLOR_GREY
	end
	render.SuppressEngineLighting(true)
	self:DrawModel()
	render.SuppressEngineLighting(false)

	local curtime = CurTime() + self.Seed
	if MySelf:IsValid() then
		local ringtime = (math.sin(curtime*2)+19)/20
		local ringsize = ringtime *200
		local beamsize = 6
		local up = self:GetUp()
		local ang = self:GetForward():Angle()
		ang.yaw = curtime * 30 % 360
		local ringpos = self:GetPos()

		render.SetMaterial(matBeam)
		render.StartBeam(40)
		for i=1, 40 do
			render.AddBeam(ringpos + ang:Forward() * ringsize, beamsize, beamsize, teamcolor)
			ang:RotateAroundAxis(up, 20)
		end
		render.EndBeam()
	end

end