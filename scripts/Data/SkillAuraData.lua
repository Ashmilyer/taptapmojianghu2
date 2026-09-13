-- TLIDB 光环技能 → 《默江湖》辅助功法（自动生成 + 手工效果映射）
-- 光环 = 常驻被动：装备功法槽后持续生效。页面数值按 L20 展示，
-- 此处存储「每级效果值」= L20/20（线性换算，功法默认 L1；为后续功法升级铺路）。
-- stats 通道：moveSpeedPct/lifeRegen/innerForceRegen/qiFlat/armorFlat/dodgeFlat
--   physicalDamage/elementalDamage/toxinDamage/skillDamage/meleeDamage/rangedDamage/dotDamage
--   yangRes/yinRes/hunyuanRes（抗性%，普通加算）critValuePct/qiPct/armorPct/dodgePct
local M = {}
M.AuraSkills = {
    {
        id = "Fearless",
        name = "狂猛",
        sourceName = "狂猛",
        kind = "辅助功法",
        sourceTags = {"光环", "范围", "近战"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：近战技能 +80% 暴击值近战技能额外 +30% 伤害",
        stats = {
            { stat = "meleeDamage", value = 1.5, kind = "%" },
            { stat = "critValuePct", value = 4.0, kind = "%" },
        },
    },
    {
        id = "Weapon_Amplification",
        name = "武器增幅",
        sourceName = "武器增幅",
        kind = "辅助功法",
        sourceTags = {"光环", "范围", "物理"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：额外 +35% 物理伤害",
        stats = {
            { stat = "physicalDamage", value = 1.75, kind = "%" },
        },
    },
    {
        id = "Rejuvenation",
        name = "再生",
        sourceName = "再生",
        kind = "辅助功法",
        sourceTags = {"光环", "范围"},
        manaSeal = "10%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：+227 生命每秒自然回复",
        stats = {
            { stat = "lifeRegen", value = 11.35, kind = "flat" },
        },
    },
    {
        id = "Electric_Conversion",
        name = "电能转化",
        sourceName = "电能转化",
        kind = "辅助功法",
        sourceTags = {"光环", "范围", "闪电"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：额外 +35% 闪电伤害",
        stats = {
            { stat = "elementalDamage", value = 1.75, kind = "%" },
        },
    },
    {
        id = "Frigid_Domain",
        name = "冰寒领域",
        sourceName = "冰寒领域",
        kind = "辅助功法",
        sourceTags = {"光环", "范围", "冰冷"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：额外 +35% 冰冷伤害",
        stats = {
            { stat = "elementalDamage", value = 1.75, kind = "%" },
        },
    },
    {
        id = "Nimbleness",
        name = "灵敏",
        sourceName = "灵敏",
        kind = "辅助功法",
        sourceTags = {"光环", "范围"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：+6000 闪避值额外 +10% 闪避值",
        stats = {
            { stat = "dodgeFlat", value = 300.0, kind = "flat" },
            { stat = "dodgePct", value = 0.5, kind = "%" },
        },
    },
    {
        id = "Spell_Amplification",
        name = "法术增幅",
        sourceName = "法术增幅",
        kind = "辅助功法",
        sourceTags = {"光环", "范围", "法术"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：额外 +35% 法术伤害",
        stats = {
            { stat = "skillDamage", value = 1.75, kind = "%" },
        },
    },
    {
        id = "Energy_Fortress",
        name = "能量壁垒",
        sourceName = "能量壁垒",
        kind = "辅助功法",
        sourceTags = {"光环", "范围"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：319.7 最大护盾额外 13.37% 最大护盾",
        stats = {
            { stat = "qiFlat", value = 16.0, kind = "flat" },
            { stat = "qiPct", value = 0.67, kind = "%" },
        },
    },
    {
        id = "Magical_Source",
        name = "魔源",
        sourceName = "魔源",
        kind = "辅助功法",
        sourceTags = {"光环", "范围"},
        manaSeal = "10%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：+140 魔力每秒自然回复",
        stats = {
            { stat = "innerForceRegen", value = 7.0, kind = "flat" },
        },
    },
    {
        id = "Precise_Projectiles",
        name = "精准投射",
        sourceName = "精准投射",
        kind = "辅助功法",
        sourceTags = {"光环", "范围", "投射物"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：额外 +35% 投射物伤害额外 +35% 投射物造成的异常伤害+10% 投射物速度",
        stats = {
            { stat = "rangedDamage", value = 1.75, kind = "%" },
        },
    },
    {
        id = "Elemental_Resistance",
        name = "元素抵抗",
        sourceName = "元素抵抗",
        kind = "辅助功法",
        sourceTags = {"光环", "范围", "火焰", "冰冷", "闪电"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：+10% 元素抗性额外 -12% 受到的元素伤害",
        stats = {
            { stat = "yangRes", value = 0.5, kind = "%" },
            { stat = "yinRes", value = 0.5, kind = "%" },
            { stat = "hunyuanRes", value = 0.5, kind = "%" },
        },
    },
    {
        id = "Swiftness",
        name = "疾速",
        sourceName = "疾速",
        kind = "辅助功法",
        sourceTags = {"光环", "范围"},
        manaSeal = "10%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：14.5% 移动速度",
        stats = {
            { stat = "moveSpeedPct", value = 0.725, kind = "%" },
        },
    },
    {
        id = "Deep_Pain",
        name = "深层苦痛",
        sourceName = "深层苦痛",
        kind = "辅助功法",
        sourceTags = {"光环", "范围"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：额外 +35% 持续伤害",
        stats = {
            { stat = "dotDamage", value = 1.75, kind = "%" },
        },
    },
    {
        id = "Erosion_Amplification",
        name = "腐蚀增幅",
        sourceName = "腐蚀增幅",
        kind = "辅助功法",
        sourceTags = {"光环", "范围", "腐蚀"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：额外 +35% 腐蚀伤害",
        stats = {
            { stat = "toxinDamage", value = 1.75, kind = "%" },
        },
    },
    {
        id = "Charged_Flames",
        name = "烈焰充能",
        sourceName = "烈焰充能",
        kind = "辅助功法",
        sourceTags = {"光环", "范围", "火焰"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：额外 +35% 火焰伤害",
        stats = {
            { stat = "elementalDamage", value = 1.75, kind = "%" },
        },
    },
    {
        id = "Steadfast",
        name = "坚固",
        sourceName = "坚固",
        kind = "辅助功法",
        sourceTags = {"光环", "范围"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：+6000 护甲值额外 +10% 护甲值",
        stats = {
            { stat = "armorFlat", value = 300.0, kind = "flat" },
            { stat = "armorPct", value = 0.5, kind = "%" },
        },
    },
    {
        id = "Radical_Order",
        name = "激进号令",
        sourceName = "激进号令",
        kind = "辅助功法",
        sourceTags = {"光环", "范围", "召唤"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：额外 +35% 召唤物伤害+25% 召唤物侵略性（不受光环效果影响）",
        stats = {
            { stat = "skillDamage", value = 1.75, kind = "%" },
        },
    },
    {
        id = "Cruelty",
        name = "暴虐",
        sourceName = "暴虐",
        kind = "辅助功法",
        sourceTags = {"光环", "范围", "攻击"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：额外 +19% 攻击伤害自身击败敌人时获得 1 层增益；击中劲敌时 +40% 几率获得 5 层增益每层增益使该技能额外 2.5% 光环效果，持续 4 秒，最多增加 40 次（不受光环效果影响）",
        stats = {
            { stat = "physicalDamage", value = 0.95, kind = "%" },
            { stat = "meleeDamage", value = 0.95, kind = "%" },
        },
    },
    {
        id = "Domain_Expansion",
        name = "领域扩张",
        sourceName = "领域扩张",
        kind = "辅助功法",
        sourceTags = {"光环", "范围"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：额外 +33% 范围伤害额外 +33% 范围技能造成的异常伤害10 米内至少有 8 个敌人时，+20% 技能范围",
        stats = {
            { stat = "skillDamage", value = 1.65, kind = "%" },
        },
    },
    {
        id = "Ailment_Amplification",
        name = "异常增幅",
        sourceName = "异常增幅",
        kind = "辅助功法",
        sourceTags = {"光环", "范围"},
        manaSeal = "50%",
        castTime = "1 秒",
        description = "激活光环，自身和一定范围内的所有友军获得增益：额外 23.5% 异常伤害+10% 几率造成伤害型异常状态+10% 异常状态持续时间",
        stats = {
            { stat = "dotDamage", value = 1.175, kind = "%" },
        },
    },
}

M.ById = {}
for _, aura in ipairs(M.AuraSkills) do
    M.ById[aura.id] = aura
end

return M