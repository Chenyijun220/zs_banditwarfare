AddCSLuaFile()

if CLIENT then
	SWEP.TranslateName = "weapon_redeemer_name"
	SWEP.TranslateDesc = "weapon_redeemer_desc"
	SWEP.Slot = 1
	SWEP.SlotPos = 0

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 50

	SWEP.HUD3DBone = "v_weapon.slide_right"
	SWEP.HUD3DPos = Vector(1, 0.1, -1)
	SWEP.HUD3DScale = 0.015
end

SWEP.Base = "weapon_zs_base"

SWEP.HoldType = "duel"

SWEP.ViewModel = "models/weapons/cstrike/c_pist_elite.mdl"
SWEP.WorldModel = "models/weapons/w_pist_elite.mdl"
SWEP.UseHands = true

SWEP.Primary.Sound = Sound("Weapon_ELITE.Single")
SWEP.Primary.Damage = 5
SWEP.Primary.NumShots = 6
SWEP.Primary.Delay = 0.29

SWEP.Primary.ClipSize = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "pistol"
SWEP.Primary.DefaultClip = 90

SWEP.ConeMax = 0.32
SWEP.ConeMin = 0.04
SWEP.Recoil = 0.75
function SWEP:SecondaryAttack()
end

function SWEP:SendWeaponAnimation()
	self:SendWeaponAnim(self:Clip1() % 2 == 0 and ACT_VM_PRIMARYATTACK or ACT_VM_SECONDARYATTACK)
end

if not CLIENT then return end

function SWEP:GetTracerOrigin()
	local owner = self:GetOwner()
	if owner:IsValid() then
		local vm = owner:GetViewModel()
		if vm and vm:IsValid() then
			local attachment = vm:GetAttachment(self:Clip1() % 2 + 3)
			if attachment then
				return attachment.Pos
			end
		end
	end
end