local AttributeSystem = require("Systems.AttributeSystem")
local SkillBattleStats = require("Data.SkillBattleStats")

local M = {}

-- 读取招式战斗字段：优先技能自身，其次 SkillBattleStats（118 参战技能 L1 数值）
---@param skill table
---@param field string
---@return number|nil
function M.GetBattleField(skill, field)
    if skill[field] ~= nil then return skill[field] end
    local stats = skill and SkillBattleStats.Stats[skill.id]
    if stats then return stats[field] end
    return nil
end

-- 招式伤害倍率（外攻 = 武器点伤 × 倍率；内攻点伤型默认 1.0）
---@param skill table
---@return number
function M.GetSkillMultiplier(skill)
    local m = M.GetBattleField(skill, "damageMultiplier")
    if m then return m end
    -- 兼容旧字段 baseOuterAttack=1.0（GameData 默认外攻招式表示 100%）
    if skill.kind == "外攻招式" then
        return skill.baseOuterAttack or 1.0
    end
    return 1.0
end

-- 招式自身点伤（内攻法术基础点伤；外攻无自身点伤）
---@param skill table
---@return number
function M.GetSkillBaseAttack(skill)
    local v = M.GetBattleField(skill, "baseInnerAttack")
    if v then return v end
    return skill.baseInnerAttack or 0.0
end

local function GetResistance(attributes, damageType)
    -- 抗性穿透（普通加算%，从目标抗性中扣除对应类型穿透）
    local pierce = 0.0
    if damageType == "阳性" then
        pierce = (attributes.pierce and attributes.pierce.yang) or 0.0
        return math.max(0.0, attributes.yangResistance - pierce)
    end
    if damageType == "阴性" then
        pierce = (attributes.pierce and attributes.pierce.yin) or 0.0
        return math.max(0.0, attributes.yinResistance - pierce)
    end
    if damageType == "混元" then
        pierce = (attributes.pierce and attributes.pierce.hunyuan) or 0.0
        return math.max(0.0, attributes.hunyuanResistance - pierce)
    end
    if damageType == "毒素" then
        pierce = (attributes.pierce and attributes.pierce.toxin) or 0.0
        return math.max(0.0, attributes.toxinResistance - pierce)
    end
    return 0.0
end

local function GetNormalBonus(attributes, skill)
    local bonus = attributes.skillDamage
    if skill.kind == "外攻招式" then
        if skill.tags[2] == "近战" then bonus = bonus + attributes.meleeDamage end
        if skill.tags[2] == "远程" then bonus = bonus + attributes.rangedDamage end
    else
        bonus = bonus + attributes.innerDamage
    end
    if skill.damageType == "物理" then bonus = bonus + attributes.physicalDamage end
    if skill.damageType == "阳性" or skill.damageType == "阴性" or skill.damageType == "混元" then
        bonus = bonus + attributes.elementalDamage
    end
    if skill.damageType == "毒素" then bonus = bonus + attributes.toxinDamage end
    bonus = bonus + AttributeSystem.GetSkillMainAttributeBonus(attributes, skill)
    return bonus
end

local function GetPointDamage(attributes, skill)
    local pointDamage = 0.0
    if skill.kind == "外攻招式" then
        -- 外攻招式以武器攻击点伤为基准：aggregate 已把各类型点伤取中值汇总
        -- （避免元素型外攻招式与物理武器不匹配导致 0 伤害）
        for _, mid in pairs(attributes.outerPointDamageByType or {}) do
            pointDamage = pointDamage + mid
        end
    else
        pointDamage = M.GetSkillBaseAttack(skill) + (attributes.innerAdditionalPointDamageByType[skill.damageType] or 0.0)
    end
    return pointDamage
end

function M.CalculatePlayerDamage(attributes, skill, isCrit)
    local pointDamage = GetPointDamage(attributes, skill)
    local normalBonus = GetNormalBonus(attributes, skill)
    local extraBonuses = skill.extraDamageBonuses or {}
    local extraMultiplier = 1.0
    for _, extraBonus in ipairs(extraBonuses) do
        extraMultiplier = extraMultiplier * (1.0 + extraBonus)
    end
    -- 用户公式：总伤害 = 点伤 × 招式伤害倍率 × (1+普通%之和) × 各额外独立乘区
    local damage = pointDamage * M.GetSkillMultiplier(skill) * (1.0 + normalBonus) * extraMultiplier
    -- 招式专属精研：额外独立乘区（「被辅助技能额外 +N% 伤害」语义）
    if skill.refineBonusPct and skill.refineBonusPct > 0.0 then
        damage = damage * (1.0 + skill.refineBonusPct)
    end
    if isCrit then
        damage = damage * AttributeSystem.GetCritDamageMultiplier(attributes)
    end
    return damage
end

function M.CalculateEnemyDamage(attributes, enemy)
    local reduction = 100.0 / (100.0 + attributes.armor)
    return enemy.outerAttack * reduction
end

function M.ApplyResistance(damage, attributes, damageType)
    local resistance = GetResistance(attributes, damageType)
    return damage * (1.0 - resistance)
end

return M
