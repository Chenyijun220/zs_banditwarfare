AddCSLuaFile()

if CLIENT then
	SWEP.TranslateName = "weapon_capturedroneremote_name"
	SWEP.TranslateDesc = "weapon_capturedroneremote_desc"

	SWEP.ViewModelFOV = 50

	SWEP.BobScale = 0.5
	SWEP.SwayScale = 0.5

	SWEP.Slot = 4
	SWEP.SlotPos = 0
end

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/weapons/w_slam.mdl"
SWEP.UseHands = true

SWEP.Primary.Delay = 0
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.Delay = 20
SWEP.Secondary.Heal = 10

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.WalkSpeed = SPEED_FAST

SWEP.NoMagazine = true
SWEP.Undroppable = true
SWEP.NoPickupNotification = true

SWEP.HoldType = "slam"

function SWEP:Initialize()
	self:SetWeaponHoldType(self.HoldType)
	self:SetDeploySpeed(10)
	if CLIENT then
		if self.TranslateName then
			self.PrintName = translate.Get(self.TranslateName)
		end
	end
end

function SWEP:Think()
	if self.IdleAnimation and self.IdleAnimation <= CurTime() then
		self.IdleAnimation = nil
		self:SendWeaponAnim(ACT_VM_IDLE)
	end

	if SERVER then
		for _, ent in pairs(ents.FindByClass("prop_drone")) do
			if ent:GetOwner() == self.Owner then
				return
			end
		end

		self.Owner:StripWeapon(self:GetClass())
	end
end

function SWEP:PrimaryAttack()
	if IsFirstTimePredicted() then
		self:SetDTBool(0, not self:GetDTBool(0))

		if CLIENT then
			LocalPlayer():EmitSound(self:GetDTBool(0) and "buttons/button17.wav" or "buttons/button19.wav", 0)
		end
	end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
	return false
end
	
function SWEP:Deploy()
	gamemode.Call("WeaponDeployed", self.Owner, self)

	self.IdleAnimation = CurTime() + self:SequenceDuration()

	return true
end

function SWEP:Holster()
	self:SetDTBool(0, false)

	return true
end

function SWEP:Reload()
end

if not CLIENT then return end

function SWEP:DrawWeaponSelection(...)
	return self:BaseDrawWeaponSelection(...)
end

function SWEP:DrawHUD()
	if self:GetDTBool(0) then
	for _, ent in pairs(ents.FindByClass("prop_obj_sigil")) do
		local teamcolor = nil
		if ent:GetSigilTeam() ~= nil then 
			teamcolor = team.GetColor(ent:GetSigilTeam())
		end
		
		self:DrawTarget(ent,32,0,teamcolor)
	end
	end
	if self.BaseClass.DrawHUD then
		self.BaseClass.DrawHUD(self)
	end
end

local texScope = Material("vgui/hud/autoaim")
function SWEP:DrawTarget(tgt, size, offset, color)
	local scrpos = tgt:GetPos():ToScreen()
	scrpos.x = math.Clamp(scrpos.x, size, ScrW() - size)
	scrpos.y = math.Clamp(scrpos.y, size, ScrH() - size)
	--surface.SetMaterial(texScope)
	--surface.DrawTexturedRect( scrpos.x - size, scrpos.y - size, size * 2, size * 2 )
	--surface.DrawCircle(scrpos.x - size, scrpos.y - size, size * 2,255,0,0,150)
	draw.RoundedBox( 10,scrpos.x - size, scrpos.y - size, size * 2, size * 2, color ~= nil and color or COLOR_GREY )
	local text = math.ceil(self.Owner:GetPos():Distance(tgt:GetPos()))
	local w, h = surface.GetTextSize(text)
	--surface.SetFont("ZSHUDFontSmall")
	--surface.DrawText(text)
	draw.SimpleText(text, "ZSHUDFontSmallest", scrpos.x - size- w/2,scrpos.y - size+ (offset * size) - h/2)
end