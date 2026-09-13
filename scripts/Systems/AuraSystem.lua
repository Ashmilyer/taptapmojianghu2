-- 《默江湖》辅助功法（光环）系统
-- 功法 = 常驻被动：装备后持续生效，占用内力（魔力封印→内力占用）。
-- 每级数值 = SkillAuraData.stats（value = L20/20），功法默认 L1（level 字段为后续升级预留）。
-- 输出一个 addon 结构供 AttributeSystem.Build 合并：
--   addon.bonuses   → 与装备 bonuses 同构（百分比通道，普通加算）
--   addon.baseAdd   → { armor/dodgeValue/qi 的 flat 值 }
--   addon.multPct   → { armor/dodgeValue/qi 的百分比乘区 }
--   addon.resAdd    → { yang/yin/hunyuan 抗性加算（值=百分数，如 0.5 表示 +0.5%）}
--   addon.regen     → { life/innerForce 每秒自然回复 }
--   manaSealPctSum  → 内力占用%（用于后续资源检查）

local SkillAuraData = require("Data.SkillAuraData")

local M = {}

local function NewAddon()
    return {
        bonuses = {
            physical = 0.0, elemental = 0.0, toxin = 0.0,
            melee = 0.0, ranged = 0.0, skill = 0.0, inner = 0.0, dot = 0.0,
            attackSpeedPct = 0, castSpeedPct = 0, critValuePct = 0,
            moveSpeedPct = 0,
        },
        baseAdd = { armor = 0.0, dodgeValue = 0.0, qi = 0.0, life = 0.0, innerForce = 0.0 },
        multPct = { armor = 0.0, dodgeValue = 0.0, qi = 0.0 },
        resAdd = { yang = 0.0, yin = 0.0, hunyuan = 0.0, toxin = 0.0 },
        regen = { life = 0.0, innerForce = 0.0 },
        manaSealPctSum = 0.0,
    }
end

local function parseSeal(text)
    if not text then return 0.0 end
    local v = text:match("([%d.]+)%%")
    return v and tonumber(v) or 0.0
end

-- 伤害通道名 → addon.bonuses 键（与装备 bonuses 同构；AttributeSystem 统一 /100）
local STAT_BONUS_CHANNEL = {
    physicalDamage = "physical",
    elementalDamage = "elemental",
    toxinDamage = "toxin",
    meleeDamage = "melee",
    rangedDamage = "ranged",
    skillDamage = "skill",
    innerDamage = "inner",
    dotDamage = "dot",
    critValuePct = "critValuePct",
    moveSpeedPct = "moveSpeedPct",
}

-- 聚合一组功法（每个为 SkillAuraData 对象或 nil）
-- @param auras table[] 长度 2（功法槽）
-- @param level number|nil 功法等级（默认 1）
-- @return table addon
function M.Aggregate(auras, level)
    local addon = NewAddon()
    level = level or 1
    for _, aura in ipairs(auras or {}) do
        if aura then
            addon.manaSealPctSum = addon.manaSealPctSum + parseSeal(aura.manaSeal)
            for _, st in ipairs(aura.stats or {}) do
                local value = st.value * level
                local stat = st.stat
                local kind = st.kind
                if kind == "%" then
                    local bonusKey = STAT_BONUS_CHANNEL[stat]
                    if bonusKey then
                        addon.bonuses[bonusKey] = addon.bonuses[bonusKey] + value
                    elseif stat == "yangRes" then addon.resAdd.yang = addon.resAdd.yang + value
                    elseif stat == "yinRes" then addon.resAdd.yin = addon.resAdd.yin + value
                    elseif stat == "hunyuanRes" then addon.resAdd.hunyuan = addon.resAdd.hunyuan + value
                    elseif stat == "toxinRes" then addon.resAdd.toxin = addon.resAdd.toxin + value
                    elseif stat == "armorPct" then addon.multPct.armor = addon.multPct.armor + value
                    elseif stat == "dodgePct" then addon.multPct.dodgeValue = addon.multPct.dodgeValue + value
                    elseif stat == "qiPct" then addon.multPct.qi = addon.multPct.qi + value
                    end
                elseif kind == "flat" then
                    if stat == "armorFlat" then addon.baseAdd.armor = addon.baseAdd.armor + value
                    elseif stat == "dodgeFlat" then addon.baseAdd.dodgeValue = addon.baseAdd.dodgeValue + value
                    elseif stat == "qiFlat" then addon.baseAdd.qi = addon.baseAdd.qi + value
                    elseif stat == "lifeFlat" then addon.baseAdd.life = addon.baseAdd.life + value
                    elseif stat == "lifeRegen" then addon.regen.life = addon.regen.life + value
                    elseif stat == "innerForceRegen" then addon.regen.innerForce = addon.regen.innerForce + value
                    end
                end
            end
        end
    end
    return addon
end

function M.GetAuraById(auraId)
    return SkillAuraData.ById[auraId]
end

return M
