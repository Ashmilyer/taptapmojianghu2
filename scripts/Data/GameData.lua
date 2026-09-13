local EquipmentData = require("Data.EquipmentData")

local M = {}

M.Character = {
    name = "无名侠客",
    level = 1,
    rootBone = 10,
    dexterity = 10,
    vitality = 10,
    baseLife = 50,
    baseInnerForce = 40,
    baseOuterAttack = 0,
    baseInnerAttack = 0,
    baseArmor = 0,
    baseDodge = 0.0,
    baseCrit = 0.0,
    baseAttackSpeed = 0.0,
    baseCastSpeed = 0.0,
    movementSpeed = 5.0,   -- 基础移动速度 m/s（俯视战场走位/寻怪基准）
    skillDamage = 0.0,
    cooldownRecovery = 0.0,
    -- 暴击值%加成通道：普通加算之和（如“提高10%暴击值”）、额外独立乘区。当前普通一级底材无此类词缀，默认 0/空。
    critValuePercentBonus = 0.0,
    extraCritValueBonuses = {},
    yangResistance = 0.0,
    yinResistance = 0.0,
    hunyuanResistance = 0.0,
    toxinResistance = 0.0,
    levelBonus = {
        rootBone = 0, dexterity = 0, vitality = 0, life = 0, innerForce = 0, qi = 0,
    },
}

M.Equipment = EquipmentData
M.Loadout = EquipmentData.CreateDefaultLoadout()

M.Skills = {
    {
        id = "basic_sword",
        name = "流云剑式",
        kind = "外攻招式",
        mainAttribute = "根骨",
        damageType = "物理",
        baseOuterAttack = 1.0,
        baseInnerAttack = 0,
        cost = 0,
        cooldown = 2.5,
        castTime = 0.0,
        tags = { "外攻", "近战", "物理" },
        baseCrit = 0,
        extraDamageBonuses = {},
        -- 空间字段：单点近战（需贴身到 range 内命中单个目标）
        space = { shape = "point_melee", range = 1.6, targetCount = 1 },
        description = "以武器物理点伤为基础的自动攻击招式。",
    },
    {
        id = "inner_sword",
        name = "青冥内息",
        kind = "内攻招式",
        mainAttribute = "元气",
        damageType = "阴性",
        baseOuterAttack = 0,
        baseInnerAttack = 28,
        cost = 8,
        cooldown = 4.0,
        castTime = 1.2,
        tags = { "内攻", "阴性", "范围" },
        baseCrit = 500,
        extraDamageBonuses = {},
        -- 空间字段：自身周围圆形范围，命中 radius 内所有敌人
        space = { shape = "circle", range = 6.0, radius = 3.0, angle = 360.0 },
        description = "基础内攻伤害来自招式，琴提供附加点伤。",
    },
}

M.Enemy = {
    name = "山魈",
    level = 1,
    maxLife = 180,
    outerAttack = 8,
    attackInterval = 3.0,
    armor = 2,
    yangResistance = 0.1,
    yinResistance = 0.1,
    hunyuanResistance = 0.1,
    toxinResistance = 0.1,
    rewardGold = 12,
    rewardExperience = 18,
}

return M
