local EquipmentSystem = require("Systems.EquipmentSystem")

local M = {}

local function Clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function Number(range)
    return EquipmentSystem.ToNumber(range)
end

local function AddFixedRange(total, range)
    if range then
        total.min = total.min + range.min
        total.max = total.max + range.max
    end
end

-- 构建角色派生属性。
-- @param character table 基础角色
-- @param loadout table 装备栏（含 bonuses）
-- @param auraAddon table|nil 辅助功法聚合（AuraSystem.Aggregate 输出）
function M.Build(character, loadout, auraAddon)
    local equipment = EquipmentSystem.Aggregate(loadout)
    local levelBonus = character.levelBonus or {}
    local rootBone = character.rootBone + (levelBonus.rootBone or 0) + Number(equipment.rootBone)
    local dexterity = character.dexterity + (levelBonus.dexterity or 0) + Number(equipment.dexterity)
    local vitality = character.vitality + (levelBonus.vitality or 0) + Number(equipment.vitality)

    -- 掉落词缀（普通加算 %；词缀值如 22 → +22% → 0.22）
    local bonuses = equipment.bonuses
    local function pct(v)
        return (v or 0.0) / 100.0
    end

    -- ===== 功法加成合并（addon.bonuses 与装备 bonuses 同构，普通加算） =====
    local aura = auraAddon or {}
    local ab = aura.bonuses
    if ab then
        for _, channel in ipairs({ "physical", "elemental", "toxin", "melee", "ranged", "skill", "inner", "dot" }) do
            bonuses[channel] = bonuses[channel] + (ab[channel] or 0.0)
        end
        bonuses.attackSpeedPct = bonuses.attackSpeedPct + (ab.attackSpeedPct or 0.0)
        bonuses.castSpeedPct = bonuses.castSpeedPct + (ab.castSpeedPct or 0.0)
        bonuses.critValuePct = bonuses.critValuePct + (ab.critValuePct or 0.0)
        bonuses.moveSpeedPct = bonuses.moveSpeedPct + (ab.moveSpeedPct or 0.0)
    end

    -- 功法 flat 加成（护甲/闪避/真气/生命/内力基础值）
    local ba = aura.baseAdd
    local armorFlat = (ba and ba.armor) or 0.0
    local dodgeFlat = (ba and ba.dodgeValue) or 0.0
    local qiFlat = (ba and ba.qi) or 0.0
    local lifeFlat = (ba and ba.life) or 0.0
    local innerForceFlat = (ba and ba.innerForce) or 0.0
    -- 功法百分比乘区（作用于总量）
    local mp = aura.multPct
    local armorMult = 1.0 + pct((mp and mp.armor) or 0.0)
    local dodgeMult = 1.0 + pct((mp and mp.dodgeValue) or 0.0)
    local qiMult = 1.0 + pct((mp and mp.qi) or 0.0)

    -- 泛伤害%（全伤害普通加算 → 并入技能伤害通道，技能伤害对所有招式生效）
    local allDamage = pct(bonuses.allDamagePct)
    -- 元素抗性%（阳/阴/混元三系普通加算）
    local elementResist = pct(bonuses.elementResistPct)

    -- 功法抗性加算（resAdd 值=百分数，0.5 → +0.5% 抗性）
    local res = aura.resAdd
    local yangResExtra = pct((res and res.yang) or 0.0)
    local yinResExtra = pct((res and res.yin) or 0.0)
    local hunyuanResExtra = pct((res and res.hunyuan) or 0.0)
    local toxinResExtra = pct((res and res.toxin) or 0.0)

    -- 内力占用（魔力封印 → 内力百分比，作用于内力上限）
    local sealPct = (aura.manaSealPctSum or 0.0)
    if sealPct > 100.0 then sealPct = 100.0 end

    local innerForceMax = (character.baseInnerForce + vitality * 0.5 + Number(equipment.innerForce) + innerForceFlat) * (1.0 - sealPct / 100.0)
    local qiMax = (vitality * 0.2 + Number(equipment.qi) + qiFlat) * qiMult

    return {
        lifeMax = character.baseLife + (levelBonus.life or 0.0) + rootBone * 0.5 + Number(equipment.life) + lifeFlat,
        innerForceMax = (character.baseInnerForce + (levelBonus.innerForce or 0.0) + vitality * 0.5 + Number(equipment.innerForce) + innerForceFlat) * (1.0 - sealPct / 100.0),
        qiMax = (vitality * 0.2 + (levelBonus.qi or 0.0) + Number(equipment.qi) + qiFlat) * qiMult,
        outerAttack = character.baseOuterAttack,
        innerAttack = character.baseInnerAttack,
        armor = (character.baseArmor + Number(equipment.armor) + armorFlat) * armorMult,
        dodgeValue = (Number(equipment.dodgeValue) + dodgeFlat) * dodgeMult,
        dodgeSources = { character.baseDodge, dexterity * 0.002 },
        critValue = Number(equipment.critValue),
        outerCritValue = equipment.outerCritValue,
        innerCritValue = equipment.innerCritValue,
        outerWeaponAttackSpeed = Number(equipment.outerWeaponAttackSpeed) * (1.0 + pct(bonuses.attackSpeedPct)),
        innerWeaponAttackSpeed = Number(equipment.innerWeaponAttackSpeed) * (1.0 + pct(bonuses.castSpeedPct)),
        attackSpeed = Number(equipment.outerWeaponAttackSpeed),
        castSpeed = character.baseCastSpeed + pct(bonuses.castSpeedPct),
        -- 暴击值%加成通道：普通加算之和、额外独立乘区。
        critValuePercentBonus = (character.critValuePercentBonus or 0.0) + pct(bonuses.critValuePct),
        extraCritValueBonuses = character.extraCritValueBonuses or {},
        -- 基础暴击伤害 150%（暴击时伤害 = 总伤害 × 暴击倍率；暴击伤害%词缀加算）
        critDamageMultiplier = 1.5,
        critDamagePct = bonuses.critDamagePct or 0.0,
        meleeDamage = rootBone * 0.002 + pct(bonuses.melee),
        rangedDamage = pct(bonuses.ranged),
        skillDamage = (character.skillDamage or 0.0) + pct(bonuses.skill) + allDamage,
        physicalDamage = (character.physicalDamage or 0.0) + pct(bonuses.physical),
        elementalDamage = (character.elementalDamage or 0.0) + pct(bonuses.elemental),
        toxinDamage = (character.toxinDamage or 0.0) + pct(bonuses.toxin),
        innerDamage = (character.innerDamage or 0.0) + pct(bonuses.inner),
        -- 机制类通道
        movementSpeed = (character.movementSpeed or 0.0) * (1.0 + pct(bonuses.moveSpeedPct)),
        cooldownRecovery = (character.cooldownRecovery or 0.0) + pct(bonuses.cooldownRecoveryPct),
        -- 召唤物通道（值 = 百分比数值，如 60 表示召唤物伤害 +60%；count 为 +N 上限）
        summonDamagePct = bonuses.summonDamagePct or 0.0,
        summonAttackSpeedPct = bonuses.summonAttackSpeedPct or 0.0,
        summonMoveSpeedPct = bonuses.summonMoveSpeedPct or 0.0,
        summonCountBonus = bonuses.summonCountBonus or 0.0,
        returnLifePct = bonuses.returnLifePct or 0.0,
        returnQiPct = bonuses.returnQiPct or 0.0,
        skillRangePct = bonuses.skillRangePct or 0.0,
        yangResistance = character.yangResistance + Number(equipment.yangResistance) * 0.01 + elementResist + yangResExtra,
        yinResistance = character.yinResistance + Number(equipment.yinResistance) * 0.01 + elementResist + yinResExtra,
        hunyuanResistance = character.hunyuanResistance + Number(equipment.hunyuanResistance) * 0.01 + elementResist + hunyuanResExtra,
        toxinResistance = character.toxinResistance + Number(equipment.toxinResistance) * 0.01 + toxinResExtra,
        -- 功法每秒自然回复
        lifeRegen = (aura.regen and aura.regen.life) or 0.0,
        innerForceRegen = (aura.regen and aura.regen.innerForce) or 0.0,
        outerPointDamageByType = equipment.outerPointDamageByType,
        innerAdditionalPointDamageByType = equipment.innerAdditionalPointDamageByType,
        equipment = equipment,
        rootBone = rootBone,
        dexterity = dexterity,
        vitality = vitality,
        pierce = {
            yang = pct((bonuses.pierce and bonuses.pierce.yang) or 0.0),
            yin = pct((bonuses.pierce and bonuses.pierce.yin) or 0.0),
            hunyuan = pct((bonuses.pierce and bonuses.pierce.hunyuan) or 0.0),
            toxin = pct((bonuses.pierce and bonuses.pierce.toxin) or 0.0),
        },
    }
end

-- 暴击伤害倍率 = 基础 150% + 暴击伤害%词缀（普通加算）
function M.GetCritDamageMultiplier(attributes)
    return 1.5 + (attributes.critDamagePct or 0.0) / 100.0
end

function M.GetDodgeRate(attributes)
    local missProduct = 1.0
    for _, source in ipairs(attributes.dodgeSources) do
        local safeSource = Clamp(source, 0.0, 0.999)
        missProduct = missProduct * (1.0 - safeSource)
    end
    return 1.0 - missProduct
end

function M.GetSkillMainAttributeBonus(attributes, skill)
    if skill.mainAttribute == "根骨" then
        return attributes.rootBone * 0.005
    elseif skill.mainAttribute == "灵巧" then
        return attributes.dexterity * 0.005
    elseif skill.mainAttribute == "元气" then
        return attributes.vitality * 0.005
    end
    return 0.0
end

-- 基础暴击值：外攻招式来自武器聚合，内攻招式来自招式自身（内攻武器暴击值本轮不叠加）。
---@param attributes table
---@param skill table
---@return number
function M.GetBaseCritValue(attributes, skill)
    if skill.kind == "外攻招式" then
        return attributes.outerCritValue or 0.0
    end
    return skill.baseCrit or 0.0
end

-- 最终暴击值 = 基础暴击值 × (1 + 所有暴击值%加成之和) × 各额外暴击值%独立乘区。
---@param attributes table
---@param skill table
---@return number
function M.GetFinalCritValue(attributes, skill)
    local base = M.GetBaseCritValue(attributes, skill)
    local value = base * (1.0 + (attributes.critValuePercentBonus or 0.0))
    for _, extraBonus in ipairs(attributes.extraCritValueBonuses or {}) do
        value = value * (1.0 + extraBonus)
    end
    return value
end

-- 暴击几率 = 最终暴击值 / 100（结果为百分比数值，例如 500/100 = 5 表示 5%）。
-- 返回 0~1 概率值供判定使用：5% → 0.05。
---@param attributes table
---@param skill table
---@return number
function M.GetCritChance(attributes, skill)
    local finalValue = M.GetFinalCritValue(attributes, skill)
    local critPercent = finalValue / 100.0
    if critPercent < 0.0 then return 0.0 end
    if critPercent > 100.0 then return 1.0 end
    return critPercent / 100.0
end

return M
