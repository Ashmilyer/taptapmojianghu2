-- 《默江湖》通用技法战斗效果映射（手工逐条确认）
-- 技法 = TLIDB 主动辅助技能（激发/防护/灵药/战吼/诅咒等）
-- 效果字段：
--   kind = "buff"（持续增益）| "recover"（瞬时回复）
--   channel：buff 支持 skillDamage/meleeDamage/rangedDamage/physicalDamage/elementalDamage/
--            toxinDamage/innerDamage/critValuePct/critDamagePct/damageReducePct
--            recover 支持 life/innerForce（value = 上限百分比）
--   value：百分比数值（如 16 = +16%）；damageReducePct 表示受伤减免%
--   duration：buff 持续秒
-- 说明：技法由战斗循环按冷却自动释放。未完成手工映射或原型不支持的机制（召唤/哨卫/
-- 位移/格挡/闪避值/投射物数量等）不在此表 → 不参战，仅浏览。

local M = {}

M.Effects = {
    -- ============ 防护类 ============
    ["Defensive_Buffer"] = { kind = "buff", channel = "damageReducePct", value = 12.0, duration = 5.0 },  -- 缓冲防御：受物理元素伤害-12%
    ["Delayed_Pain"] = { kind = "buff", channel = "damageReducePct", value = 15.3, duration = 5.0 },     -- 痛觉延迟：受伤缓冲
    ["Frost_Shield"] = { kind = "buff", channel = "damageReducePct", value = 13.8, duration = 5.0 },     -- 寒冰盾：物理火焰减伤
    ["Reform"] = { kind = "buff", channel = "damageReducePct", value = 7.5, duration = 6.0 },            -- 重整阵势
    ["Safeguard_Ring"] = { kind = "buff", channel = "damageReducePct", value = 8.0, duration = 4.0 },    -- 绝境护身阵：阵内-8%受到伤害

    -- ============ 激发类（伤害增益） ============
    ["Aim"] = { kind = "buff", channel = "rangedDamage", value = 16.0, duration = 6.0 },                 -- 瞄准：远程/射线+16%
    ["Arcane_Circle"] = { kind = "buff", channel = "skillDamage", value = 2.35, duration = 6.0 },        -- 秘法阵：法术伤害
    ["Blazing_Spin"] = { kind = "buff", channel = "critValuePct", value = 435.0, duration = 6.0 },       -- 烈焰飞旋：暴击值（原型映射为暴击值%加成）
    ["Bulls_Rage"] = { kind = "buff", channel = "meleeDamage", value = 17.5, duration = 6.0 },           -- 公牛之怒：近战+17.5%
    ["Frost_Release"] = { kind = "buff", channel = "skillDamage", value = 81.0, duration = 5.0 },        -- 寒潮缓释：下5次技能+81%（原型取持续增益）
    ["Mana_Boil"] = { kind = "buff", channel = "skillDamage", value = 10.0, duration = 8.0 },            -- 魔力沸腾：法术+10%
    ["Secret_Origin_Unleash"] = { kind = "buff", channel = "skillDamage", value = 5.5, duration = 6.0 }, -- 秘源开脉：额外+5.5%法术伤害
    ["Burst_of_Anger"] = { kind = "buff", channel = "physicalDamage", value = 7.1, duration = 6.0 },     -- 怒火狂飙：额外+7.1%攻击伤害（原型取物理伤通道）
    ["Gold_Rush"] = { kind = "buff", channel = "physicalDamage", value = 6.0, duration = 6.0 },          -- 聚石碎金：每影响敌人+6%伤害（取基础值）
    ["Withering_Payback"] = { kind = "buff", channel = "toxinDamage", value = 20.0, duration = 6.0 },    -- 凋零奉还：额外+20%腐蚀伤害
    ["Fixate"] = { kind = "buff", channel = "physicalDamage", value = 1.1, duration = 6.0 },             -- 聚神凝气：每标记敌人+1.1%伤害（取基础值）

    -- ============ 灵药/回复类 ============
    ["Compound_Tonic"] = { kind = "recover", channel = "life", value = 39.0 },                           -- 复合药水：回39%最大生命
    ["Life_Tonic"] = { kind = "recover", channel = "life", value = 41.0 },                               -- 生命药水
    ["Mana_Tonic"] = { kind = "recover", channel = "innerForce", value = 41.0 },                         -- 魔力药水
    ["Thirst_Dew"] = { kind = "buff", channel = "critValuePct", value = 92.0, duration = 3.0 },          -- 止渴回气：+92%暴击值（取暴击值项）

    -- ============ 战吼类（增益自身伤害；value 取文案每影响一个敌人的基础值） ============
    ["Charging_Warcry"] = { kind = "buff", channel = "meleeDamage", value = 4.0, duration = 3.0 },      -- 冲锋战吼
    ["Commanding_Warcry"] = { kind = "buff", channel = "skillDamage", value = 4.1, duration = 3.0 },    -- 统帅战吼
    ["Fearless_Warcry"] = { kind = "buff", channel = "meleeDamage", value = 4.0, duration = 3.0 },      -- 狂猛战吼
    ["Resurrection_Warcry"] = { kind = "recover", channel = "life", value = 20.0 },                     -- 复苏战吼（含回复部分）
    ["Raging_Warcry"] = { kind = "buff", channel = "meleeDamage", value = 4.0, duration = 3.0 },        -- 暴怒战吼

    -- ============ 诅咒类（简化：改为对自身对应系伤害增益，代表技能对敌易伤） ============
    ["Biting_Cold"] = { kind = "buff", channel = "elementalDamage", value = 20.0, duration = 4.0 },      -- 蚀骨之寒（冰冷易伤）
    ["Electrocute"] = { kind = "buff", channel = "elementalDamage", value = 20.0, duration = 4.0 },      -- 感电（闪电易伤）
    ["Corruption"] = { kind = "buff", channel = "toxinDamage", value = 20.0, duration = 4.0 },           -- 邪恶侵蚀（腐蚀易伤）
    ["Scorch"] = { kind = "buff", channel = "elementalDamage", value = 20.0, duration = 4.0 },           -- 炽热灼魂（火焰易伤）
    ["Vulnerability"] = { kind = "buff", channel = "physicalDamage", value = 20.0, duration = 4.0 },     -- 破绽显露（物理易伤）
    ["Timid"] = { kind = "buff", channel = "skillDamage", value = 20.0, duration = 4.0 },                -- 丧胆怯战（击中易伤→技能伤害通道）

    -- ============ 贯注类（本地模板：短时对应系伤害提升；元素按 阳/阴/混元→elemental） ============
    ["Infusion_Erosion"] = { kind = "buff", channel = "toxinDamage", value = 20.0, duration = 6.0 },     -- 蚀骨贯注
    ["Infusion_Frost"] = { kind = "buff", channel = "elementalDamage", value = 20.0, duration = 6.0 },   -- 寒冰贯注
    ["Infusion_Flame"] = { kind = "buff", channel = "elementalDamage", value = 20.0, duration = 6.0 },   -- 熔火贯注
    ["Infusion_Sharp"] = { kind = "buff", channel = "physicalDamage", value = 20.0, duration = 6.0 },    -- 锐利贯注
    ["Infusion_Thunder"] = { kind = "buff", channel = "elementalDamage", value = 20.0, duration = 6.0 }, -- 雷霆贯注
}

-- 是否已映射（可参战）
function M.HasEffect(skillId)
    return M.Effects[skillId] ~= nil
end

return M
