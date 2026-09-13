local M = {}

local function NewRange()
    return { min = 0.0, max = 0.0 }
end

local function Mid(range)
    if not range then return 0.0 end
    return (range.min + range.max) * 0.5
end

local function AddRange(total, range)
    if range then
        total.min = total.min + range.min
        total.max = total.max + range.max
    end
end

local function AddDamage(target, damageTable)
    if not damageTable then return end
    for damageType, range in pairs(damageTable) do
        target[damageType] = (target[damageType] or 0.0) + Mid(range)
    end
end

function M.GetRangeText(range)
    if not range then return "—" end
    return string.format("%g～%g", range.min, range.max)
end

function M.GetWeaponRangeText(range)
    if not range then return "—" end
    return M.GetRangeText(range)
end

function M.ToNumber(range)
    return Mid(range)
end

function M.Aggregate(loadout)
    local result = {
        life = NewRange(), innerForce = NewRange(), qi = NewRange(), armor = NewRange(),
        dodgeValue = NewRange(), critValue = NewRange(), rootBone = NewRange(),
        dexterity = NewRange(), vitality = NewRange(), yangResistance = NewRange(),
        yinResistance = NewRange(), hunyuanResistance = NewRange(), toxinResistance = NewRange(),
        outerWeaponAttackSpeed = NewRange(), innerWeaponAttackSpeed = NewRange(),
        outerCritValue = 0.0, innerCritValue = 0.0,
        outerPointDamageByType = {}, innerAdditionalPointDamageByType = {},
        -- 掉落词缀的百分比加成（普通加算通道，值=百分比数值如 22 表示 +22%）
        bonuses = {
            physical = 0.0, elemental = 0.0, toxin = 0.0,
            melee = 0.0, ranged = 0.0, skill = 0.0, inner = 0.0, dot = 0.0,
            attackSpeedPct = 0.0, castSpeedPct = 0.0, critValuePct = 0.0,
            critDamagePct = 0.0, moveSpeedPct = 0.0, skillRangePct = 0.0,
            cooldownRecoveryPct = 0.0, returnLifePct = 0.0, returnQiPct = 0.0,
            allDamagePct = 0.0, elementResistPct = 0.0,
            summonDamagePct = 0.0, summonAttackSpeedPct = 0.0, summonMoveSpeedPct = 0.0,
            summonCountBonus = 0.0,
            pierce = { yang = 0.0, yin = 0.0, hunyuan = 0.0, toxin = 0.0 },
        },
    }

    for _, equipment in pairs(loadout) do
        local base = equipment.base
        if base then
            AddRange(result.life, base.life)
            AddRange(result.innerForce, base.innerForce)
            AddRange(result.qi, base.qi)
            AddRange(result.armor, base.armor)
            AddRange(result.dodgeValue, base.dodgeValue)
            AddRange(result.critValue, base.critValue)
            AddRange(result.rootBone, base.rootBone)
            AddRange(result.dexterity, base.dexterity)
            AddRange(result.vitality, base.vitality)
            AddRange(result.yangResistance, base.yangResistance)
            AddRange(result.yinResistance, base.yinResistance)
            AddRange(result.hunyuanResistance, base.hunyuanResistance)
            AddRange(result.toxinResistance, base.toxinResistance)
        end
        if equipment.weaponKind == "外攻" then
            AddDamage(result.outerPointDamageByType, equipment.outerPointDamage)
            if equipment.baseAttackSpeed then
                AddRange(result.outerWeaponAttackSpeed, { min = equipment.baseAttackSpeed, max = equipment.baseAttackSpeed })
            end
            result.outerCritValue = result.outerCritValue + (equipment.baseCritValue or 0.0)
        elseif equipment.weaponKind == "内攻" then
            -- 只读取网站实际的“法术附加”；攻击附加保留在 rawAttackDamage，不转为内攻点伤。
            AddDamage(result.innerAdditionalPointDamageByType, equipment.innerAdditionalPointDamage)
            result.innerCritValue = result.innerCritValue + (equipment.baseCritValue or 0.0)
            if equipment.baseAttackSpeed then
                AddRange(result.innerWeaponAttackSpeed, { min = equipment.baseAttackSpeed, max = equipment.baseAttackSpeed })
            end
        end

        -- 掉落词缀（modifiers 提供的普通加算百分比）
        local bonuses = equipment.bonuses
        if bonuses then
            for _, channel in ipairs({ "physical", "elemental", "toxin", "melee", "ranged", "skill", "inner", "dot" }) do
                local v = bonuses[channel]
                if v and v ~= 0 then
                    result.bonuses[channel] = result.bonuses[channel] + v
                end
            end
            if bonuses.attackSpeedPct and bonuses.attackSpeedPct ~= 0 then
                result.bonuses.attackSpeedPct = result.bonuses.attackSpeedPct + bonuses.attackSpeedPct
            end
            if bonuses.castSpeedPct and bonuses.castSpeedPct ~= 0 then
                result.bonuses.castSpeedPct = result.bonuses.castSpeedPct + bonuses.castSpeedPct
            end
            if bonuses.critValuePct and bonuses.critValuePct ~= 0 then
                result.bonuses.critValuePct = result.bonuses.critValuePct + bonuses.critValuePct
            end
            -- 机制类词缀聚合（普通加算%，值即百分比数值）
            if bonuses.critDamagePct then
                result.bonuses.critDamagePct = result.bonuses.critDamagePct + bonuses.critDamagePct
            end
            if bonuses.moveSpeedPct then
                result.bonuses.moveSpeedPct = result.bonuses.moveSpeedPct + bonuses.moveSpeedPct
            end
            if bonuses.summonDamagePct then
                result.bonuses.summonDamagePct = result.bonuses.summonDamagePct + bonuses.summonDamagePct
            end
            if bonuses.summonAttackSpeedPct then
                result.bonuses.summonAttackSpeedPct = result.bonuses.summonAttackSpeedPct + bonuses.summonAttackSpeedPct
            end
            if bonuses.summonMoveSpeedPct then
                result.bonuses.summonMoveSpeedPct = result.bonuses.summonMoveSpeedPct + bonuses.summonMoveSpeedPct
            end
            if bonuses.summonCountBonus then
                result.bonuses.summonCountBonus = result.bonuses.summonCountBonus + bonuses.summonCountBonus
            end
            if bonuses.skillRangePct then
                result.bonuses.skillRangePct = result.bonuses.skillRangePct + bonuses.skillRangePct
            end
            if bonuses.cooldownRecoveryPct then
                result.bonuses.cooldownRecoveryPct = result.bonuses.cooldownRecoveryPct + bonuses.cooldownRecoveryPct
            end
            if bonuses.returnLifePct then
                result.bonuses.returnLifePct = result.bonuses.returnLifePct + bonuses.returnLifePct
            end
            if bonuses.returnQiPct then
                result.bonuses.returnQiPct = result.bonuses.returnQiPct + bonuses.returnQiPct
            end
            if bonuses.allDamagePct then
                result.bonuses.allDamagePct = result.bonuses.allDamagePct + bonuses.allDamagePct
            end
            if bonuses.elementResistPct then
                result.bonuses.elementResistPct = result.bonuses.elementResistPct + bonuses.elementResistPct
            end
            if bonuses.pierce then
                for _, k in ipairs({ "yang", "yin", "hunyuan", "toxin" }) do
                    result.bonuses.pierce[k] = result.bonuses.pierce[k] + (bonuses.pierce[k] or 0)
                end
            end
        end
    end

    return result
end

return M
