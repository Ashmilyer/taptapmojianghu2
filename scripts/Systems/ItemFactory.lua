-- 《默江湖》装备物品工厂
-- 把图鉴底材(EquipmentCatalog) + 掉落词缀(AffixFullPool)组合成运行时装备对象。
-- 运行时装备对象与 EquipmentData 对象字段兼容（base/outerPointDamage 等），
-- 现有 EquipmentSystem.Aggregate / AttributeSystem.Build 可直接聚合生效。
--
-- 对象结构：
-- {
--   uid,                 -- 运行时唯一实例 id
--   catalogId, name, sourceName, category, slot, weaponKind, hand, requiredLevel,
--   base = { armor={min,max}, ... },                 -- 防具/饰品属性
--   outerPointDamage = { [type]={min,max} },         -- 外攻武器攻击点伤
--   innerAdditionalPointDamage = { [type]={min,max} }, -- 内攻武器法术附加点伤
--   rawAttackDamage = { [type]={min,max} },          -- 拂尘/武杖的武器攻击（保留不转内攻点伤）
--   baseAttackSpeed, baseCritValue,
--   affixTexts = { "附加词缀展示文本(已roll数值)" },
--   bonuses = { physical, elemental, toxin, melee, ranged, skill, inner,
--               attackSpeedPct, castSpeedPct, critValuePct },   -- 普通加算%加成
-- }

local EquipmentCatalog = require("Data.EquipmentCatalog")
local AffixFullPool = require("Data.AffixFullPool")
local AffixSummonPool = require("Data.AffixSummonPool")
local AffixParser = require("Systems.AffixParser")

local M = {}
M.uidCounter = 0

function M.NextUid(prefix)
    M.uidCounter = M.uidCounter + 1
    return (prefix or "it") .. "_" .. M.uidCounter
end

-- 深拷贝一张装备对象表（避免引用游戏数据源表）
function M.Clone(tbl)
    local out = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            out[k] = M.Clone(v)
        else
            out[k] = v
        end
    end
    return out
end

function M.NewBonuses()
    return {
        physical = 0.0, elemental = 0.0, toxin = 0.0,
        melee = 0.0, ranged = 0.0, skill = 0.0, inner = 0.0, dot = 0.0,
        attackSpeedPct = 0, castSpeedPct = 0, critValuePct = 0,
        -- 机制类词缀（普通加算%）
        critDamagePct = 0,          -- 暴击伤害%（加算到基础暴伤 150%）
        moveSpeedPct = 0,           -- 移动速度%（乘基础移速）
        skillRangePct = 0,          -- 技能范围%
        cooldownRecoveryPct = 0,    -- 冷却回复速度%
        returnLifePct = 0,          -- 生命返还%（命中回复）
        returnQiPct = 0,            -- 护盾返还%（命中回真气）
        allDamagePct = 0,           -- 泛伤害%（全伤害普通加算，并入 skillDamage 通道）
        elementResistPct = 0,       -- 元素抗性%（阳/阴/混元三系）
        summonDamagePct = 0,        -- 召唤物伤害%（百分数值，作用于召唤物攻击）
        summonAttackSpeedPct = 0,   -- 召唤物攻击/施法速度%
        summonMoveSpeedPct = 0,     -- 召唤物移动速度%
        summonCountBonus = 0,       -- 召唤物/哨卫/英灵数量上限 +N
        pierce = {                  -- 抗性穿透%（0-100，普通加算；减法结算时生效）
            yang = 0, yin = 0, hunyuan = 0, toxin = 0,
        },
    }
end

-- 从图鉴条目构造运行时装备对象（底材）
-- @param catalogItem table EquipmentCatalog.Items[i]
-- @param uid string|nil
function M.FromCatalog(catalogItem, uid)
    if not catalogItem then return nil end
    local cat = EquipmentCatalog.Categories[catalogItem.category]
    if not cat then return nil end

    local item = {
        uid = uid or M.NextUid(),
        catalogId = catalogItem.id,
        name = catalogItem.name,
        sourceName = catalogItem.sourceName,
        category = catalogItem.category,
        slot = cat.slot,
        weaponKind = cat.kind,
        hand = catalogItem.hand,
        requiredLevel = catalogItem.requiredLevel,
        base = {},
        affixTexts = {},
        bonuses = M.NewBonuses(),
    }
    M.ApplyBaseAffixes(item, catalogItem.baseAffixes)
    return item
end

-- 数值 roll 一次（bands.low/high；随机取整）返回 {min,max}
-- 规则：双档（点伤 min档/max档）→ min 在 low 档取、max 在 high 档取；
--       单档（如 % 词缀 20–24%）→ 区间内随机一个单值。
function M.RollOnce(bands)
    local lo, hi = bands.low, bands.high
    local function pick(b)
        return b.min + math.floor((b.max - b.min + 1) * math.random())
    end
    local isSingle = (lo == hi)
        or (lo.min == hi.min and lo.max == hi.max)
    if isSingle then
        local v = pick(lo)
        return { min = v, max = v }
    end
    local mn = pick(lo)
    local mx = pick(hi)
    if mx < mn then mn, mx = mx, mn end
    return { min = mn, max = mx }
end

-- 应用 modifier（mod.bands 未 roll）——只做结构合并；RollAffixes 负责先 roll
function M.ApplyModifier(item, mod)
    if not mod then return end
    local kind = mod.kind

    if kind == "flatSpeed" then
        if mod.target == "attackSpeed" then
            item.baseAttackSpeed = mod.value
        elseif mod.target == "castSpeed" then
            item.baseCastSpeed = mod.value
        end
        return
    end

    if kind == "flatCrit" then
        item.baseCritValue = mod.value
        return
    end

    local bands = mod.bands
    if not bands then return end

    if kind == "flatDamage" then
        local mn = bands.low.min
        local mx = bands.high.max
        if mx < mn then mx = mn end
        local range = { min = mn, max = mx }
        local target
        if mod.scope == "spell" then
            item.innerAdditionalPointDamage = item.innerAdditionalPointDamage or {}
            target = item.innerAdditionalPointDamage
        elseif mod.scope == "base" then
            -- 武器底材攻击点伤：内攻武器（拂尘/武杖等）保留为 rawAttackDamage
            if item.weaponKind == "内攻" then
                item.rawAttackDamage = item.rawAttackDamage or {}
                target = item.rawAttackDamage
            else
                item.outerPointDamage = item.outerPointDamage or {}
                target = item.outerPointDamage
            end
        else -- attack 附加：内攻武器的攻击词缀 → rawAttackDamage；否则叠加到外攻点伤
            if item.weaponKind == "内攻" then
                item.rawAttackDamage = item.rawAttackDamage or {}
                target = item.rawAttackDamage
            else
                item.outerPointDamage = item.outerPointDamage or {}
                target = item.outerPointDamage
            end
        end
        local cur = target[mod.damageType]
        if cur then
            -- 同类点伤叠加（底材 + 附加词缀合并）
            cur.min = cur.min + range.min
            cur.max = cur.max + range.max
        else
            target[mod.damageType] = range
        end
        return
    end

    if kind == "flatAttribute" then
        local v = bands.low.min -- 固定值（主属性词缀为单个整数）
        local cur = item.base[mod.field]
        if cur then
            cur.min = cur.min + v
            cur.max = cur.max + v
        else
            item.base[mod.field] = { min = v, max = v }
        end
        return
    end

    if kind == "flatStat" then
        local v = bands.low.min
        local cur = item.base[mod.stat]
        if cur then
            cur.min = cur.min + v
            cur.max = cur.max + v
        else
            item.base[mod.stat] = { min = v, max = v }
        end
        return
    end

    if kind == "percentResist" then
        local field = mod.damageType == "阳性" and "yangResistance"
            or mod.damageType == "阴性" and "yinResistance"
            or mod.damageType == "混元" and "hunyuanResistance"
            or mod.damageType == "毒素" and "toxinResistance"
        if field then
            local v = bands.low.min
            local cur = item.base[field]
            if cur then
                cur.min = cur.min + v
                cur.max = cur.max + v
            else
                item.base[field] = { min = v, max = v }
            end
        end
        return
    end

    if kind == "percentDamage" then
        local v = bands.low.min
        if item.bonuses[mod.channel] ~= nil then
            item.bonuses[mod.channel] = item.bonuses[mod.channel] + v
        end
        return
    end

    if kind == "percentSpeed" then
        local v = bands.low.min
        if mod.target == "attackSpeed" or mod.target == "both" then
            item.bonuses.attackSpeedPct = item.bonuses.attackSpeedPct + v
        end
        if mod.target == "castSpeed" or mod.target == "both" then
            item.bonuses.castSpeedPct = item.bonuses.castSpeedPct + v
        end
        return
    end

    if kind == "percentCrit" then
        item.bonuses.critValuePct = item.bonuses.critValuePct + bands.low.min
        return
    end

    -- ============ 召唤物词缀（百分数值，作用于召唤物） ============
    if kind == "percentSummonDamage" then
        item.bonuses.summonDamagePct = item.bonuses.summonDamagePct + bands.low.min
        return
    end
    if kind == "percentSummonAttackSpeed" then
        item.bonuses.summonAttackSpeedPct = item.bonuses.summonAttackSpeedPct + bands.low.min
        return
    end
    if kind == "percentSummonMoveSpeed" then
        item.bonuses.summonMoveSpeedPct = item.bonuses.summonMoveSpeedPct + bands.low.min
        return
    end
    if kind == "flatSummonCount" then
        item.bonuses.summonCountBonus = item.bonuses.summonCountBonus + (mod.value or 0)
        return
    end

    -- ============ 机制类（普通加算% 通道） ============
    if kind == "percentCritDamage" then
        item.bonuses.critDamagePct = item.bonuses.critDamagePct + bands.low.min
        return
    end
    if kind == "percentMoveSpeed" then
        item.bonuses.moveSpeedPct = item.bonuses.moveSpeedPct + bands.low.min
        return
    end
    if kind == "percentSkillRange" then
        item.bonuses.skillRangePct = item.bonuses.skillRangePct + bands.low.min
        return
    end
    if kind == "percentCooldownRecovery" then
        item.bonuses.cooldownRecoveryPct = item.bonuses.cooldownRecoveryPct + bands.low.min
        return
    end
    if kind == "percentReturn" then
        local v = bands.low.min
        if mod.target == "life" or mod.target == "both" then
            item.bonuses.returnLifePct = item.bonuses.returnLifePct + v
        end
        if mod.target == "qi" or mod.target == "both" then
            item.bonuses.returnQiPct = item.bonuses.returnQiPct + v
        end
        return
    end
    if kind == "percentAllDamage" then
        item.bonuses.allDamagePct = item.bonuses.allDamagePct + bands.low.min
        return
    end
    if kind == "percentElementResist" then
        item.bonuses.elementResistPct = item.bonuses.elementResistPct + bands.low.min
        return
    end
    if kind == "percentPierce" then
        local v = bands.low.min
        local p = item.bonuses.pierce
        if mod.pierceType == "yang" then p.yang = p.yang + v end
        if mod.pierceType == "yin" then p.yin = p.yin + v end
        if mod.pierceType == "hunyuan" then p.hunyuan = p.hunyuan + v end
        if mod.pierceType == "toxin" then p.toxin = p.toxin + v end
        if mod.pierceType == "element" then
            p.yang = p.yang + v
            p.yin = p.yin + v
            p.hunyuan = p.hunyuan + v
        end
        if mod.pierceType == "elementToxin" then
            p.yang = p.yang + v
            p.yin = p.yin + v
            p.hunyuan = p.hunyuan + v
            p.toxin = p.toxin + v
        end
        return
    end
    if kind == "flatAllAttributes" then
        -- 全属性：根骨/灵巧/元气各 +N
        for _, field in ipairs({ "rootBone", "dexterity", "vitality" }) do
            local v = bands.low.min
            local cur = item.base[field]
            if cur then
                cur.min = cur.min + v
                cur.max = cur.max + v
            else
                item.base[field] = { min = v, max = v }
            end
        end
        return
    end
    -- 该装备本地百分比加成（作用于本件装备字段）
    if kind == "percentLocal" then
        local v = bands.low.min
        if mod.target == "physicalDamage" then
            -- 放大该武器各类型点伤
            for dt, r in pairs(item.outerPointDamage or {}) do
                r.min = math.floor(r.min * (1.0 + v / 100.0) + 0.5)
                r.max = math.max(r.min, math.floor(r.max * (1.0 + v / 100.0) + 0.5))
            end
        elseif mod.target == "elementalDamage" then
            for dt, r in pairs(item.innerAdditionalPointDamage or {}) do
                r.min = math.floor(r.min * (1.0 + v / 100.0) + 0.5)
                r.max = math.max(r.min, math.floor(r.max * (1.0 + v / 100.0) + 0.5))
            end
        elseif mod.target == "attackSpeed" then
            item.baseAttackSpeed = (item.baseAttackSpeed or 1.0) * (1.0 + v / 100.0)
        elseif mod.target == "critValue" then
            item.baseCritValue = (item.baseCritValue or 0) * (1.0 + v / 100.0)
        elseif mod.target == "armor" then
            local r = item.base.armor
            if r then
                r.min = math.floor(r.min * (1.0 + v / 100.0) + 0.5)
                r.max = math.max(r.min, math.floor(r.max * (1.0 + v / 100.0) + 0.5))
            end
        elseif mod.target == "dodgeValue" then
            local r = item.base.dodgeValue
            if r then
                r.min = math.floor(r.min * (1.0 + v / 100.0) + 0.5)
                r.max = math.max(r.min, math.floor(r.max * (1.0 + v / 100.0) + 0.5))
            end
        end
        return
    end
end

-- 把底材基础词缀文本行应用到装备
function M.ApplyBaseAffixes(item, lines)
    for _, line in ipairs(lines or {}) do
        local mods = AffixParser.ParseEffect(line)
        for _, mod in ipairs(mods) do
            if mod.bands then
                mod.bands = {
                    low = { min = mod.bands.low.min, max = mod.bands.low.max },
                    high = { min = mod.bands.high.min, max = mod.bands.high.max },
                }
            end
            M.ApplyModifier(item, mod)
        end
    end
end

-- roll 掉落附加词缀 1~2 条并应用，文本用 roll 后数值渲染
-- 词缀从 AffixFullPool 全量池按底材类别抽取，level 需 ≤ 物品等级（无 level 词缀不限）
-- @param item table
-- @param rollCount integer|nil 期望词缀数量
function M.RollAffixes(item, rollCount)
    if not item then return end
    local pool = {}
    for _, entry in ipairs(AffixFullPool.Pools[item.category] or {}) do
        pool[#pool + 1] = entry
    end
    for _, entry in ipairs(AffixSummonPool.Pools[item.category] or {}) do
        pool[#pool + 1] = entry
    end
    if #pool == 0 then return end
    -- 先按物品等级过滤可用词缀
    local candidates = {}
    for _, entry in ipairs(pool) do
        if not entry.level or entry.level <= (item.requiredLevel or 1) then
            table.insert(candidates, entry.effect)
        end
    end
    if #candidates == 0 then return end
    local count = rollCount or (math.random() < 0.5 and 1 or 2)
    count = math.min(count, #candidates)

    local used = {}
    for _ = 1, count do
        for _guard = 1, 20 do
            local effect = candidates[math.random(1, #candidates)]
            if not used[effect] then
                used[effect] = true
                local mods = AffixParser.ParseEffect(effect)
                if #mods > 0 then
                    local rolledText = effect
                    for _, mod in ipairs(mods) do
                        if mod.bands then
                            local roll = M.RollOnce(mod.bands)
                            if roll.min == roll.max then
                                mod.bands = {
                                    low = { min = roll.min, max = roll.min },
                                    high = { min = roll.min, max = roll.min },
                                }
                            else
                                mod.bands = {
                                    low = { min = roll.min, max = roll.min },
                                    high = { min = roll.max, max = roll.max },
                                }
                            end
                            rolledText = AffixParser.FormatRolledEffect(rolledText, roll)
                        end
                        M.ApplyModifier(item, mod)
                    end
                    table.insert(item.affixTexts, rolledText)
                end
                break
            end
        end
    end
end

-- 生成一次掉落物品（底材 + 词缀）
-- @param catalogItem table 选中的底材
-- @param affixCount integer|nil 附加词缀条数（默认随机 1-2）
-- @return table 装备对象
function M.CreateDrop(catalogItem, affixCount)
    local item = M.FromCatalog(catalogItem)
    if not item then return nil end
    M.RollAffixes(item, affixCount)
    return item
end

-- 生成传奇装备物品（底材 + 固定传奇词缀文本）
-- 词缀区间按 RollOnce 掷值（掉落实例感）；AffixParser 能解析者真实生效；
-- 无法解析的特殊句（负面/机制/长句）保留到 item.legendTexts 仅展示。
-- @param catalogItem table EquipmentCatalog 底材条目
-- @param affixTexts string[] 传奇词缀文本（如 "+(100&ndash;130)% 该装备物理伤害"）
-- @param uid string|nil
-- @return table 装备对象（含 affixTexts 已 roll 生效词缀 / legendTexts 特殊句）
function M.CreateLegend(catalogItem, affixTexts, uid)
    local item = M.FromCatalog(catalogItem, uid)
    if not item then return nil end
    item.legendTexts = {}
    for _, text in ipairs(affixTexts or {}) do
        local mods = AffixParser.ParseEffect(text)
        if #mods > 0 then
            local rolledText = text
            for _, mod in ipairs(mods) do
                if mod.bands then
                    local roll = M.RollOnce(mod.bands)
                    if roll.min == roll.max then
                        mod.bands = {
                            low = { min = roll.min, max = roll.min },
                            high = { min = roll.min, max = roll.min },
                        }
                    else
                        mod.bands = {
                            low = { min = roll.min, max = roll.min },
                            high = { min = roll.max, max = roll.max },
                        }
                    end
                    rolledText = AffixParser.FormatRolledEffect(rolledText, roll)
                end
                M.ApplyModifier(item, mod)
            end
            table.insert(item.affixTexts, rolledText)
        else
            table.insert(item.legendTexts, text)
        end
    end
    return item
end

return M
