local M = {}

local function Range(minValue, maxValue)
    return { min = minValue, max = maxValue }
end

local function DamageRange(minValue, maxValue)
    return Range(minValue, maxValue)
end

local function Equipment(id, name, sourceType, baseItemName, requiredLevel, base, rawBaseAffixes)
    return {
        id = id,
        name = name,
        sourceType = sourceType,
        baseItemName = baseItemName,
        requiredLevel = requiredLevel,
        base = base,
        rawBaseAffixes = rawBaseAffixes,
    }
end

local function OuterWeapon(id, name, sourceType, baseItemName, pointDamage, attackSpeed, critValue, tags, rawBaseAffixes)
    return {
        id = id,
        name = name,
        sourceType = sourceType,
        baseItemName = baseItemName,
        requiredLevel = 1,
        slot = "外攻武器",
        weaponKind = "外攻",
        outerPointDamage = pointDamage,
        baseAttackSpeed = attackSpeed,
        baseCritValue = critValue,
        tags = tags,
        rawBaseAffixes = rawBaseAffixes,
    }
end

local function InnerWeapon(id, name, sourceType, baseItemName, spellPointDamage, rawAttackDamage, critValue, attackSpeed, base, tags, rawBaseAffixes)
    return {
        id = id,
        name = name,
        sourceType = sourceType,
        baseItemName = baseItemName,
        requiredLevel = 1,
        slot = "内攻武器",
        weaponKind = "内攻",
        innerAdditionalPointDamage = spellPointDamage,
        rawAttackDamage = rawAttackDamage,
        baseCritValue = critValue,
        baseAttackSpeed = attackSpeed,
        base = base,
        tags = tags,
        rawBaseAffixes = rawBaseAffixes,
    }
end

M.Slots = {
    "外攻武器", "内攻武器", "副手", "头部", "胸甲", "手部", "足部", "腰部", "项链", "戒指一", "戒指二",
}

-- 所有区间均保留 TLIDB 原始结构；一级底材实例只写入页面实际显示的属性。
M.Weapons = {
    outer = {
        OuterWeapon("one_sword", "长剑", "单手剑", "锈斑铜剑", { 物理 = DamageRange(6, 6) }, 1.5, 500, { "外攻", "近战", "连续攻击" }, { "6 - 6 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        OuterWeapon("one_blade", "长刀", "单手斧", "锈斑铁斧", { 物理 = DamageRange(6, 6) }, 1.5, 500, { "外攻", "近战", "斩击" }, { "6 - 6 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        OuterWeapon("one_jian", "锏", "单手锤", "枯木粗棒", { 物理 = DamageRange(6, 6) }, 1.5, 500, { "外攻", "近战", "破击" }, { "6 - 6 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        OuterWeapon("two_sword", "重剑", "双手剑", "粗质木剑", { 物理 = DamageRange(7, 7) }, 1.5, 500, { "外攻", "近战", "连续攻击" }, { "7 - 7 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        OuterWeapon("two_blade", "大刀", "双手斧", "破碎铁斧", { 物理 = DamageRange(7, 7) }, 1.5, 500, { "外攻", "近战", "斩击" }, { "7 - 7 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        OuterWeapon("two_jian", "重锏", "双手锤", "粗铁重锤", { 物理 = DamageRange(7, 7) }, 1.5, 500, { "外攻", "近战", "破击" }, { "7 - 7 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        OuterWeapon("claw", "铁爪", "爪", "钉爪", { 物理 = DamageRange(6, 6) }, 1.5, 500, { "外攻", "近战", "幻影" }, { "6 - 6 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        OuterWeapon("dagger", "匕首", "匕首", "窃贼短匕", { 物理 = DamageRange(6, 6) }, 1.5, 500, { "外攻", "近战", "幻影" }, { "6 - 6 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        OuterWeapon("bow", "长弓", "弓", "朽木弓", { 物理 = DamageRange(7, 7) }, 1.5, 500, { "外攻", "远程", "投射物" }, { "7 - 7 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        OuterWeapon("crossbow", "连弩", "弩", "藤木轻弩", { 物理 = DamageRange(7, 7) }, 1.5, 500, { "外攻", "远程", "投射物" }, { "7 - 7 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        OuterWeapon("musket", "火铳", "火枪", "锈斑长枪", { 物理 = DamageRange(7, 7) }, 1.5, 500, { "外攻", "远程", "投射物" }, { "7 - 7 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        OuterWeapon("fire_cannon", "轰天铳", "火炮", "枯木重炮", { 物理 = DamageRange(7, 7) }, 1.5, 500, { "外攻", "远程", "抛射", "分裂" }, { "7 - 7 物理伤害", "500 暴击值", "1.5 攻击速度" }),
    },
    inner = {
        InnerWeapon("qin", "琴", "魔杖", "枯藤法杖", { 阴性 = DamageRange(2, 2) }, nil, 500, 1.2, nil, { "内攻", "法术", "投射物" }, { "500 暴击值", "1.2 攻击速度", "法术附加 2 - 2 点冰冷伤害" }),
        InnerWeapon("zen_staff", "禅杖", "锡杖", "枯藤长杖", { 阴性 = DamageRange(4, 4) }, nil, 500, 1.2, nil, { "内攻", "法术", "范围" }, { "500 暴击值", "1.2 攻击速度", "法术附加 4 - 4 点冰冷伤害" }),
        InnerWeapon("horsetail_whisk", "拂尘", "手杖", "云游者手杖", nil, { 物理 = DamageRange(6, 6) }, 500, 1.5, nil, { "内攻", "法术", "远程" }, { "6 - 6 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        InnerWeapon("long_staff", "长棍", "武杖", "枯木长杖", nil, { 物理 = DamageRange(7, 7) }, 500, 1.5, nil, { "内攻", "法术", "引导" }, { "7 - 7 物理伤害", "500 暴击值", "1.5 攻击速度" }),
        InnerWeapon("brush", "笔", "权杖", "枯叶魔杖", nil, nil, 500, 1.2, { sustainedDamage = Range(2, 2) }, { "内攻", "法术", "持续" }, { "500 暴击值", "1.2 攻击速度", "+2% 持续伤害" }),
        InnerWeapon("flute", "笛子", "灵杖", "萌芽灵杖", nil, nil, 500, 1.2, { summonDamage = Range(2, 2) }, { "内攻", "召唤", "法术" }, { "500 暴击值", "1.2 攻击速度", "+2% 召唤物伤害" }),
    },
}

M.Armor = {
    head = {
        str = Equipment("head_str_001", "蛮兵护盔", "力量头部", "蛮兵护盔", 1, { armor = Range(168, 168) }, { "+168 该装备护甲值" }),
        dex = Equipment("head_dex_001", "游荡者罩帽", "敏捷头部", "游荡者罩帽", 1, { dodgeValue = Range(168, 168) }, { "+168 该装备闪避值" }),
        int = Equipment("head_int_001", "草药师头巾", "智慧头部", "草药师头巾", 1, { qi = Range(9, 9) }, { "+9 该装备护盾" }),
    },
    chest = {
        str = Equipment("chest_str_001", "蛮兵护胸", "力量胸甲", "蛮兵护胸", 1, { armor = Range(196, 196) }, { "+196 该装备护甲值" }),
        dex = Equipment("chest_dex_001", "游荡者外套", "敏捷胸甲", "游荡者外套", 1, { dodgeValue = Range(196, 196) }, { "+196 该装备闪避值" }),
        int = Equipment("chest_int_001", "草药师长袍", "智慧胸甲", "草药师长袍", 1, { qi = Range(10, 10) }, { "+10 该装备护盾" }),
    },
    gloves = {
        str = Equipment("gloves_str_001", "蛮兵护手", "力量手套", "蛮兵护手", 1, { armor = Range(168, 168) }, { "+168 该装备护甲值" }),
        dex = Equipment("gloves_dex_001", "游荡者手套", "敏捷手套", "游荡者手套", 1, { dodgeValue = Range(168, 168) }, { "+168 该装备闪避值" }),
        int = Equipment("gloves_int_001", "草药师手套", "智慧手套", "草药师手套", 1, { qi = Range(9, 9) }, { "+9 该装备护盾" }),
    },
    boots = {
        str = Equipment("boots_str_001", "蛮兵护胫", "力量鞋子", "蛮兵护胫", 1, { armor = Range(168, 168) }, { "+168 该装备护甲值" }),
        dex = Equipment("boots_dex_001", "游荡者长靴", "敏捷鞋子", "游荡者长靴", 1, { dodgeValue = Range(168, 168) }, { "+168 该装备闪避值" }),
        int = Equipment("boots_int_001", "草药师护足", "智慧鞋子", "草药师护足", 1, { qi = Range(9, 9) }, { "+9 该装备护盾" }),
    },
    belt = Equipment("belt_001", "磐石护腰", "腰带", "磐石护腰", 1, { life = Range(10, 10) }, { "+10 最大生命" }),
    necklace = {
        life = Equipment("necklace_life_001", "玳瑁护符", "项链", "玳瑁护符", 1, { rootBone = Range(3, 3) }, { "+3 力量" }),
        dex = Equipment("necklace_dex_001", "辰砂吊坠", "项链", "辰砂吊坠", 1, { dexterity = Range(3, 3) }, { "+3 敏捷" }),
        int = Equipment("necklace_int_001", "黑曜颈链", "项链", "黑曜颈链", 1, { vitality = Range(3, 3) }, { "+3 智慧" }),
    },
    ring = {
        yang = Equipment("ring_yang_001", "灼烧炎戒", "戒指", "灼烧炎戒", 1, { yangResistance = Range(3, 3) }, { "+3% 火焰抗性" }),
        yin = Equipment("ring_yin_001", "寒风冰戒", "戒指", "寒风冰戒", 1, { yinResistance = Range(3, 3) }, { "+3% 冰冷抗性" }),
        hunyuan = Equipment("ring_hunyuan_001", "万厄雷戒", "戒指", "万厄雷戒", 1, { hunyuanResistance = Range(3, 3) }, { "+3% 闪电抗性" }),
        toxin = Equipment("ring_toxin_001", "深渊暗戒", "戒指", "深渊暗戒", 1, { toxinResistance = Range(3, 3) }, { "+3% 腐蚀抗性" }),
    },
}

M.OffHand = {
    id = "shield_str_001",
    name = "初心巨盾",
    sourceType = "力量盾牌",
    baseItemName = "初心巨盾",
    requiredLevel = 1,
    base = { armor = Range(168, 168) },
    rawBaseAffixes = { "+168 该装备护甲值" },
}

function M.CreateDefaultLoadout()
    return {
        outerWeapon = M.Weapons.outer[1],
        innerWeapon = M.Weapons.inner[1],
        offHand = M.OffHand,
        head = M.Armor.head.str,
        chest = M.Armor.chest.str,
        gloves = M.Armor.gloves.str,
        boots = M.Armor.boots.str,
        belt = M.Armor.belt,
        necklace = M.Armor.necklace.life,
        ring1 = M.Armor.ring.yang,
        ring2 = M.Armor.ring.yin,
    }
end

return M
