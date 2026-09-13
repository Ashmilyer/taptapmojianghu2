-- 《默江湖》召唤类本地技能模板 + 召唤单位属性
-- 说明：元素之灵/智械/模组化/贯注系在 TLIDB 无独立技能页（0 字节验证），
--       以本地模板补入，用于 48 条专属精研绑定、通用精研总览与召唤战斗。
--       召唤单位数值为本项目自设基准（对照山魈：HP180/攻8/3s），非 TLIDB 直译；
--       伤害类型映射：火焰→阳性、冰冷→阴性、闪电/腐蚀→混元/毒素按语义。
local M = {}

-- 召唤单位模板（供 BattleSim 召唤）
M.Archetypes = {
    flame_spirit =      { name = "烈焰之灵", life = 120, outerAttack = 10, attackInterval = 1.6, moveSpeed = 4.0, radius = 0.5, range = 1.7, damageType = "阳性", scale = 0.85 },
    ice_spirit =        { name = "寒冰之灵", life = 115, outerAttack = 9,  attackInterval = 1.8, moveSpeed = 3.8, radius = 0.5, range = 1.7, damageType = "阴性", scale = 0.85 },
    rock_spirit =       { name = "磐石之灵", life = 170, outerAttack = 9,  attackInterval = 2.0, moveSpeed = 3.0, radius = 0.6, range = 1.7, damageType = "物理", scale = 0.95 },
    storm_spirit =      { name = "雷霆之灵", life = 110, outerAttack = 11, attackInterval = 1.7, moveSpeed = 4.2, radius = 0.5, range = 1.7, damageType = "混元", scale = 0.85 },
    toxin_spirit =      { name = "腐化之灵", life = 115, outerAttack = 10, attackInterval = 1.8, moveSpeed = 3.8, radius = 0.5, range = 1.7, damageType = "毒素", scale = 0.85 },
    synth_troop =       { name = "机关守卫", life = 160, outerAttack = 9,  attackInterval = 2.0, moveSpeed = 3.2, radius = 0.6, range = 1.7, damageType = "物理", scale = 0.9 },
    machine_guard =     { name = "机关傀儡", life = 150, outerAttack = 9,  attackInterval = 2.0, moveSpeed = 3.2, radius = 0.6, range = 1.7, damageType = "物理", scale = 0.9 },
    spider_tank =       { name = "蛛形机关", life = 120, outerAttack = 11, attackInterval = 1.8, moveSpeed = 3.6, radius = 0.55, range = 1.8, damageType = "毒素", scale = 0.9 },
    grim_phantom =      { name = "幽浮魅影", life = 100, outerAttack = 10, attackInterval = 1.5, moveSpeed = 4.4, radius = 0.5, range = 1.7, damageType = "混元", scale = 0.8 },
    flame_core =        { name = "烈焰火灵核", life = 130, outerAttack = 10, attackInterval = 1.9, moveSpeed = 3.2, radius = 0.55, range = 1.8, damageType = "阳性", scale = 0.85 },
    frost_core =        { name = "寒霜冰灵核", life = 130, outerAttack = 10, attackInterval = 1.9, moveSpeed = 3.2, radius = 0.55, range = 1.8, damageType = "阴性", scale = 0.85 },
    thunder_core =      { name = "雷霆雷灵核", life = 125, outerAttack = 11, attackInterval = 1.9, moveSpeed = 3.2, radius = 0.55, range = 1.8, damageType = "混元", scale = 0.85 },
    arrow_einherjar =   { name = "箭灵卫", life = 95,  outerAttack = 9,  attackInterval = 1.5, moveSpeed = 3.8, radius = 0.5, range = 6.0, damageType = "物理", scale = 0.8 },
    ghost_blade =       { name = "幽刃剑灵", life = 105, outerAttack = 12, attackInterval = 1.4, moveSpeed = 4.4, radius = 0.5, range = 1.8, damageType = "毒素", scale = 0.8 },
}

-- 库内 TLIDB 召唤/哨卫/智械通用精研 → 召唤单位模板
M.LibrarySummonMap = {
    Summon_Machine_Guard = "machine_guard",
    Summon_Spider_Tank = "spider_tank",
    Summon_Grim_Phantom = "grim_phantom",
    Flame_Core = "flame_core",
    Frost_Core = "frost_core",
    Thunder_Core = "thunder_core",
    Arrow_Einherjar = "arrow_einherjar",
    Ghost_Blade_Einherjar = "ghost_blade",
}

-- 本地技能模板（元素之灵/智械/模组化/贯注）：
-- kind = "通用精研"（可装配精研槽）；召唤类带 summonArchetype；贯注类走 TechniqueEffects buff 映射
M.SummonSkills = {
    {
        id = "Summon_Fire_Spirit",
        name = "烈焰之灵",
        sourceName = "召唤火焰之灵",
        kind = "通用精研",
        supportType = "召唤",
        sourceTags = { "召唤", "持续", "火焰" },
        cooldown = 6,
        castTime = 1,
        description = "召唤一名烈焰之灵作战（本地模板）：自动索敌，施放火焰法门攻击，火焰伤害视为阳性。",
        summonArchetype = "flame_spirit",
    },
    {
        id = "Summon_Ice_Spirit",
        name = "寒冰之灵",
        sourceName = "召唤寒冰之灵",
        kind = "通用精研",
        supportType = "召唤",
        sourceTags = { "召唤", "持续", "冰冷" },
        cooldown = 6,
        castTime = 1,
        description = "召唤一名寒冰之灵作战（本地模板）：自动索敌，冰霜法门攻击，冰冷伤害视为阴性。",
        summonArchetype = "ice_spirit",
    },
    {
        id = "Summon_Rock_Spirit",
        name = "磐石之灵",
        sourceName = "召唤磐石之灵",
        kind = "通用精研",
        supportType = "召唤",
        sourceTags = { "召唤", "持续", "物理" },
        cooldown = 7,
        castTime = 1,
        description = "召唤一名磐石之灵作战（本地模板）：血厚防坚，以钝击伤敌（物理）。",
        summonArchetype = "rock_spirit",
    },
    {
        id = "Summon_Storm_Spirit",
        name = "雷霆之灵",
        sourceName = "召唤雷霆之灵",
        kind = "通用精研",
        supportType = "召唤",
        sourceTags = { "召唤", "持续", "闪电" },
        cooldown = 6,
        castTime = 1,
        description = "召唤一名雷霆之灵作战（本地模板）：雷法攻击，闪电伤害视为混元。",
        summonArchetype = "storm_spirit",
    },
    {
        id = "Summon_Toxin_Spirit",
        name = "腐化之灵",
        sourceName = "召唤腐化之灵",
        kind = "通用精研",
        supportType = "召唤",
        sourceTags = { "召唤", "持续", "腐蚀" },
        cooldown = 6,
        castTime = 1,
        description = "召唤一名腐化之灵作战（本地模板）：腐蚀法门攻击，视为毒素伤害。",
        summonArchetype = "toxin_spirit",
    },
    {
        id = "Synthetic_Troop",
        name = "机关智械",
        sourceName = "智械",
        kind = "通用精研",
        supportType = "召唤/智械",
        sourceTags = { "召唤", "持续", "智械" },
        cooldown = 6,
        castTime = 1,
        description = "召唤一名机关守卫作战（本地模板）：机括傀儡，力大耐打（物理）。",
        summonArchetype = "synth_troop",
    },
    {
        id = "Modularization",
        name = "机关模组",
        sourceName = "模组化",
        kind = "通用精研",
        supportType = "召唤/智械",
        sourceTags = { "召唤", "持续", "智械" },
        cooldown = 6,
        castTime = 1,
        description = "将随行机关重编为战斗模组（本地模板）：召唤机关守卫协同作战（物理）。",
        summonArchetype = "synth_troop",
    },
    {
        id = "Infusion_Erosion",
        name = "蚀骨贯注",
        sourceName = "侵蚀贯注",
        kind = "通用精研",
        supportType = "贯注",
        sourceTags = { "贯注", "腐蚀" },
        cooldown = 8,
        castTime = 1,
        description = "贯注之力：短时间内使自身毒素伤害显著提升（本地模板，按技法映射生效）。",
    },
    {
        id = "Infusion_Frost",
        name = "寒冰贯注",
        sourceName = "寒冰贯注",
        kind = "通用精研",
        supportType = "贯注",
        sourceTags = { "贯注", "冰冷" },
        cooldown = 8,
        castTime = 1,
        description = "贯注之力：短时间内使自身冰冷（阴性）伤害显著提升（本地模板）。",
    },
    {
        id = "Infusion_Flame",
        name = "熔火贯注",
        sourceName = "熔火贯注",
        kind = "通用精研",
        supportType = "贯注",
        sourceTags = { "贯注", "火焰" },
        cooldown = 8,
        castTime = 1,
        description = "贯注之力：短时间内使自身火焰（阳性）伤害显著提升（本地模板）。",
    },
    {
        id = "Infusion_Sharp",
        name = "锐利贯注",
        sourceName = "锐利贯注",
        kind = "通用精研",
        supportType = "贯注",
        sourceTags = { "贯注", "物理" },
        cooldown = 8,
        castTime = 1,
        description = "贯注之力：短时间内使自身物理伤害显著提升（本地模板）。",
    },
    {
        id = "Infusion_Thunder",
        name = "雷霆贯注",
        sourceName = "雷霆贯注",
        kind = "通用精研",
        supportType = "贯注",
        sourceTags = { "贯注", "闪电" },
        cooldown = 8,
        castTime = 1,
        description = "贯注之力：短时间内使自身闪电（混元）伤害显著提升（本地模板）。",
    },
}

-- 全部可装配召唤/贯注技能（本地模板 + 库内召唤系技法 id 引用视图在 main 组装）
M.ById = {}
for _, s in ipairs(M.SummonSkills) do
    M.ById[s.id] = s
end

---@param archetypeId string
function M.GetArchetype(archetypeId)
    return M.Archetypes[archetypeId]
end

return M
