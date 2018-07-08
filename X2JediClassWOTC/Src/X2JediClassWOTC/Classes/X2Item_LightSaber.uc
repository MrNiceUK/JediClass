class X2Item_LightSaber extends X2Item config (JediClass);

var config WeaponDamageValue LIGHTSABER_CONVENTIONAL_BASEDAMAGE;
var config int  LIGHTSABER_CONVENTIONAL_AIM;
var config int  LIGHTSABER_CONVENTIONAL_CRITCHANCE;
var config int  LIGHTSABER_CONVENTIONAL_ICLIPSIZE;
var config int  LIGHTSABER_CONVENTIONAL_ISOUNDRANGE;
var config int  LIGHTSABER_CONVENTIONAL_IENVIRONMENTDAMAGE;
var config array<name> LIGHTSABER_CONVENTIONAL_ABILITIES;

var config WeaponDamageValue LIGHTSABER_MAGNETIC_BASEDAMAGE;
var config int  LIGHTSABER_MAGNETIC_AIM;
var config int  LIGHTSABER_MAGNETIC_CRITCHANCE;
var config int  LIGHTSABER_MAGNETIC_ICLIPSIZE;
var config int  LIGHTSABER_MAGNETIC_ISOUNDRANGE;
var config int  LIGHTSABER_MAGNETIC_IENVIRONMENTDAMAGE;
var config array<name> LIGHTSABER_MAGNETIC_ABILITIES;

var config WeaponDamageValue LIGHTSABER_BEAM_BASEDAMAGE;
var config int  LIGHTSABER_BEAM_AIM;
var config int  LIGHTSABER_BEAM_CRITCHANCE;
var config int  LIGHTSABER_BEAM_ICLIPSIZE;
var config int  LIGHTSABER_BEAM_ISOUNDRANGE;
var config int  LIGHTSABER_BEAM_IENVIRONMENTDAMAGE;
var config array<name> LIGHTSABER_BEAM_ABILITIES;

var config name LIGHTSABER_DEFAULT_CRYSTAL;
var config name LIGHTSABER_DEFAULT_CELL;
var config name LIGHTSABER_DEFAULT_EMITTER;
var config name LIGHTSABER_DEFAULT_LENS;

var config array<name> LIGHTSABER_VALID_CRYSTALS;
var config array<name> LIGHTSABER_VALID_CELLS;
var config array<name> LIGHTSABER_VALID_EMITTERS;
var config array<name> LIGHTSABER_VALID_LENSES;

var config array<name> LIGHTSABER_TEMPLATE_NAMES;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Weapons;

	// Lightsabers
	Weapons.AddItem(CreateTemplate_LightSaber_ConventionalPrimary());
	Weapons.AddItem(CreateTemplate_LightSaber_MagneticPrimary());
	Weapons.AddItem(CreateTemplate_LightSaber_BeamPrimary());
	
	return Weapons;
}

static function X2DataTemplate CreateTemplate_LightSaber_ConventionalPrimary()
{
	local X2WeaponTemplate Template;

	`CREATE_X2TEMPLATE(class'X2WeaponTemplate', Template, default.LIGHTSABER_TEMPLATE_NAMES[0]);
	Template.GameplayInstanceClass = class'XGLightSaber';
	Template.WeaponPanelImage = "_Sword";                       // used by the UI. Probably determines iconview of the weapon.

	Template.ItemCat = 'weapon';
	Template.WeaponCat = 'lightsaber';
	Template.WeaponTech = 'conventional';
	Template.strImage = "img:///LightSaber_CV.UI.LightsaberIcon";
	Template.EquipSound = "Sword_Equip_Conventional";
	Template.InventorySlot = eInvSlot_PrimaryWeapon;
	Template.StowedLocation = eSlot_RightHand;
	// This all the resources; sounds, animations, models, physics, the works.
	Template.GameArchetype = "LightSaber_CV.Archetypes.WP_LightSaber_CV";
	//Template.AddDefaultAttachment('Sheath', "ConvSword.Meshes.SM_ConvSword_Sheath", true);
	Template.Tier = 0;
	Template.OnAcquiredFn = OnLightsaberAcquired;

	Template.iRadius = 1;
	Template.NumUpgradeSlots = 4;
	Template.InfiniteAmmo = true;
	Template.iPhysicsImpulse = 0;

	Template.iRange = 0;
	Template.BaseDamage = default.LIGHTSABER_CONVENTIONAL_BASEDAMAGE;
	
	Template.Aim = default.LIGHTSABER_CONVENTIONAL_AIM;
	Template.CritChance = default.LIGHTSABER_CONVENTIONAL_CRITCHANCE;
	Template.iSoundRange = default.LIGHTSABER_CONVENTIONAL_ISOUNDRANGE;
	Template.iEnvironmentDamage = default.LIGHTSABER_CONVENTIONAL_IENVIRONMENTDAMAGE;
	Template.BaseDamage.DamageType = 'Melee';

	AddConfigAbilities(Template, default.LIGHTSABER_CONVENTIONAL_ABILITIES);

	Template.StartingItem = false;
	Template.CanBeBuilt = false;
	Template.bInfiniteItem = false;
	Template.bAlwaysUnique = true;

	Template.DamageTypeTemplateName = 'Melee';

	return Template;
}

static function X2DataTemplate CreateTemplate_LightSaber_MagneticPrimary()
{
	local X2WeaponTemplate Template;

	`CREATE_X2TEMPLATE(class'X2WeaponTemplate', Template, default.LIGHTSABER_TEMPLATE_NAMES[1]);
	Template.GameplayInstanceClass = class'XGLightSaber';
	Template.WeaponPanelImage = "_Pistol";                       // used by the UI. Probably determines iconview of the weapon.

	Template.ItemCat = 'weapon';
	Template.WeaponCat = 'lightsaber';
	Template.WeaponTech = 'magnetic';
	Template.strImage = "img:///LightSaber_CV.UI.LightsaberIcon";
	Template.EquipSound = "Sword_Equip_Magnetic";
	Template.InventorySlot = eInvSlot_PrimaryWeapon;
	Template.StowedLocation = eSlot_RightHand;
	// This all the resources; sounds, animations, models, physics, the works.
	Template.GameArchetype = "LightSaber_CV.Archetypes.WP_LightSaber_CV";
	//Template.AddDefaultAttachment('R_Back', "MagSword.Meshes.SM_MagSword_Sheath", false);
	Template.Tier = 1;
	Template.OnAcquiredFn = OnLightsaberAcquired;

	Template.iRadius = 1;
	Template.NumUpgradeSlots = 4;
	Template.InfiniteAmmo = true;
	Template.iPhysicsImpulse = 0;

	Template.iRange = 0;
	Template.BaseDamage = default.LIGHTSABER_MAGNETIC_BASEDAMAGE;
	
	Template.Aim = default.LIGHTSABER_MAGNETIC_AIM;
	Template.CritChance = default.LIGHTSABER_MAGNETIC_CRITCHANCE;
	Template.iSoundRange = default.LIGHTSABER_MAGNETIC_ISOUNDRANGE;
	Template.iEnvironmentDamage = default.LIGHTSABER_MAGNETIC_IENVIRONMENTDAMAGE;
	Template.BaseDamage.DamageType='Melee';
	Template.DamageTypeTemplateName = 'Melee';
	
	AddConfigAbilities(Template, default.LIGHTSABER_MAGNETIC_ABILITIES);

	Template.BaseItem = 'LightSaber_CV_Primary'; // Which item this will be upgraded from
	
	Template.DamageTypeTemplateName = 'Melee';
	Template.BaseDamage.DamageType = 'Melee';
	
	Template.StartingItem = false;
	Template.CanBeBuilt = false;
	Template.bInfiniteItem = false;
	Template.bAlwaysUnique = true;

	return Template;
}

static function X2DataTemplate CreateTemplate_LightSaber_BeamPrimary()
{
	local X2WeaponTemplate Template;

	`CREATE_X2TEMPLATE(class'X2WeaponTemplate', Template, default.LIGHTSABER_TEMPLATE_NAMES[2]);
	Template.GameplayInstanceClass = class'XGLightSaber';
	Template.WeaponPanelImage = "_Pistol";                       // used by the UI. Probably determines iconview of the weapon.

	Template.ItemCat = 'weapon';
	Template.WeaponCat = 'lightsaber';
	Template.WeaponTech = 'beam';
	Template.strImage = "img:///LightSaber_CV.UI.LightsaberIcon";
	Template.EquipSound = "Sword_Equip_Beam";
	Template.InventorySlot = eInvSlot_PrimaryWeapon;
	Template.StowedLocation = eSlot_RightHand;
	// This all the resources; sounds, animations, models, physics, the works.
	Template.GameArchetype = "LightSaber_CV.Archetypes.WP_LightSaber_CV";
	//Template.AddDefaultAttachment('R_Back', "BeamSword.Meshes.SM_BeamSword_Sheath", false);
	Template.Tier = 2;
	Template.OnAcquiredFn = OnLightsaberAcquired;

	Template.iRadius = 1;
	Template.NumUpgradeSlots = 4;
	Template.InfiniteAmmo = true;
	Template.iPhysicsImpulse = 0;

	Template.iRange = 0;
	Template.BaseDamage = default.LIGHTSABER_BEAM_BASEDAMAGE;
	
	Template.Aim = default.LIGHTSABER_BEAM_AIM;
	Template.CritChance = default.LIGHTSABER_BEAM_CRITCHANCE;
	Template.iSoundRange = default.LIGHTSABER_BEAM_ISOUNDRANGE;
	Template.iEnvironmentDamage = default.LIGHTSABER_BEAM_IENVIRONMENTDAMAGE;
	
	AddConfigAbilities(Template, default.LIGHTSABER_BEAM_ABILITIES);

	Template.BaseItem = 'LightSaber_MG_Primary'; // Which item this will be upgraded from
	
	Template.BaseDamage.DamageType='Melee';
	Template.DamageTypeTemplateName = 'Melee';
	
	Template.StartingItem = false;
	Template.CanBeBuilt = false;
	Template.bInfiniteItem = false;
	Template.bAlwaysUnique = true;
	
	return Template;
}

static function AddConfigAbilities(out X2WeaponTemplate Template, array<name> Abilities)
{
	local name Ability;
	foreach Abilities (Ability)
	{
		Template.Abilities.AddItem(Ability);
	}
}

static function bool OnLightsaberAcquired(XComGameState NewGameState, XComGameState_Item ItemState)
{
	local X2ItemTemplateManager ItemTemplateMgr;
	local array<name> WeaponUpgradeNames;

	ItemTemplateMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	WeaponUpgradeNames = ItemState.GetMyWeaponUpgradeTemplateNames();

	if (default.LIGHTSABER_VALID_CRYSTALS.Find(WeaponUpgradeNames[0]) == INDEX_NONE)
	{
		ItemState.ApplyWeaponUpgradeTemplate(X2WeaponUpgradeTemplate(ItemTemplateMgr.FindItemTemplate(default.LIGHTSABER_DEFAULT_CRYSTAL)), 0);
	}
	if (default.LIGHTSABER_VALID_CELLS.Find(WeaponUpgradeNames[1]) == INDEX_NONE)
	{
		ItemState.ApplyWeaponUpgradeTemplate(X2WeaponUpgradeTemplate(ItemTemplateMgr.FindItemTemplate(default.LIGHTSABER_DEFAULT_CELL)), 1);
	}
	if (default.LIGHTSABER_VALID_EMITTERS.Find(WeaponUpgradeNames[2]) == INDEX_NONE)
	{
		ItemState.ApplyWeaponUpgradeTemplate(X2WeaponUpgradeTemplate(ItemTemplateMgr.FindItemTemplate(default.LIGHTSABER_DEFAULT_EMITTER)), 2);
	}
	if (default.LIGHTSABER_VALID_LENSES.Find(WeaponUpgradeNames[3]) == INDEX_NONE)
	{
		ItemState.ApplyWeaponUpgradeTemplate(X2WeaponUpgradeTemplate(ItemTemplateMgr.FindItemTemplate(default.LIGHTSABER_DEFAULT_LENS)), 3);
	}

	return true;
}

defaultproperties
{
	bShouldCreateDifficultyVariants = true
}