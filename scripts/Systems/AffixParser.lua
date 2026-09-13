-- 《默江湖》词缀解析器
-- 把 TLIDB 词缀展示文本解析为结构化属性（只覆盖常用属性，供掉落 roll 与换装生效）。
-- 术语映射：火焰→阳性 冰冷→阴性 闪电→混元 腐蚀→毒素
--          力量→根骨 敏捷→灵巧 智慧→元气 护盾→真气 魔力→内力
--
-- ⚠️ Lua string pattern 不支持 `|` 分支：本文件所有匹配均为并列独立 match。
--
-- modifier：
--   flatDamage    { scope="attack"|"spell"|"base", damageType, bands }   点伤附加
--   flatSpeed     { target="attackSpeed"|"castSpeed", value }            基础速度
--   flatCrit      { value }                                              基础暴击值
--   flatAttribute { field, bands }                                       主属性
--   flatStat      { stat, bands }                                        生命/护盾/护甲/闪避
--   percentResist { damageType, bands }                                  抗性% 普通加算
--   percentDamage { channel, bands }                                     伤害% 普通加算
--   percentSpeed  { target="attackSpeed"|"castSpeed"|"both", bands }
--   percentCrit   { bands }
-- bands = { low={min,max}, high={min,max} }

local M = {}

M.DamageTypeMap = {
    ["物理"] = "物理",
    ["火焰"] = "阳性",
    ["冰冷"] = "阴性",
    ["闪电"] = "混元",
    ["腐蚀"] = "毒素",
}

M.AttributeMap = {
    ["力量"] = "rootBone",
    ["敏捷"] = "dexterity",
    ["智慧"] = "vitality",
}

M.PercentTargets = {
    ["物理伤害"] = "physical",
    ["元素伤害"] = "elemental",
    ["火焰伤害"] = "elemental",
    ["冰冷伤害"] = "elemental",
    ["闪电伤害"] = "elemental",
    ["腐蚀伤害"] = "toxin",
    ["毒素伤害"] = "toxin",
    ["近战伤害"] = "melee",
    ["远程伤害"] = "ranged",
    ["技能伤害"] = "skill",
    ["法术伤害"] = "skill",
    ["内攻伤害"] = "inner",
    ["持续伤害"] = "dot",
    ["异常伤害"] = "dot",
    ["攻击物理伤害"] = "physical",
    ["法术腐蚀伤害"] = "toxin",
    ["加剧效果"] = "dot",
    ["物理"] = "physical",
    ["元素"] = "elemental",
    ["火焰"] = "elemental",
    ["冰冷"] = "elemental",
    ["闪电"] = "elemental",
    ["腐蚀"] = "toxin",
}

function M.Clean(text)
    if not text then return "" end
    return text:gsub("&ndash;", "-"):gsub("&mdash;", "-")
        :gsub("–", "-"):gsub("—", "-")
        :gsub("^%s+", ""):gsub("%s+$", "")
end

-- 解析区间文本 → {min,max}
function M.ParseRange(text)
    if not text then return nil end
    local cleaned = M.Clean(text)
    local minS, maxS = cleaned:match("%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)")
    if not minS then
        minS, maxS = cleaned:match("(%d+%.?%d*)%s*-%s*(%d+%.?%d*)")
    end
    if minS and maxS then
        return { min = tonumber(minS), max = tonumber(maxS) }
    end
    local single = cleaned:match("(%d+%.?%d*)")
    if single then
        local v = tonumber(single)
        return { min = v, max = v }
    end
    return nil
end

-- 双档 "(a-b) - (c-d)"；单档 low=high
function M.ParseBands(text)
    if not text then return nil end
    local cleaned = M.Clean(text)
    local lowA, lowB, highA, highB = cleaned:match(
        "%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)%s*-%s*%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)"
    )
    if lowA then
        return {
            low = { min = tonumber(lowA), max = tonumber(lowB) },
            high = { min = tonumber(highA), max = tonumber(highB) },
        }
    end
    local sA, sB = cleaned:match("%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)")
    if sA then
        local r = { min = tonumber(sA), max = tonumber(sB) }
        return { low = r, high = r }
    end
    local plain = M.ParseRange(cleaned)
    if plain then
        return { low = plain, high = plain }
    end
    return nil
end

-- 词缀前缀数值："+N" / "+N-M" / "+(N-M)" → bands
local function parsePrefixBands(text)
    local b1a, b1b, b2a, b2b = text:match(
        "^%+%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)%s*-%s*%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)"
    )
    if b1a then
        return {
            low = { min = tonumber(b1a), max = tonumber(b1b) },
            high = { min = tonumber(b2a), max = tonumber(b2b) },
        }
    end
    local a1, b1 = text:match("^%+%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)")
    if a1 then
        local r = { min = tonumber(a1), max = tonumber(b1) }
        return { low = r, high = r }
    end
    local s1 = text:match("^%+(%d+%.?%d*)")
    if s1 then
        local v = tonumber(s1)
        return { low = { min = v, max = v }, high = { min = v, max = v } }
    end
    return nil
end

-- ============================================================================
-- 分支解析（每个分支尝试后立刻 return，避免 | 分支）
-- ============================================================================

-- 1) 点伤附加：攻击附加 / 法术附加 / 该装备附加 X-Y 点X伤害
local function parsePointAdd(text, scopeText)
    if not text:find(scopeText, 1, true) then return nil end
    if not text:find("点", 1, true) then return nil end
    -- 伤害类型
    local dt
    if text:find("点物理伤害", 1, true) then dt = "物理" end
    if text:find("点火焰伤害", 1, true) then dt = "阳性" end
    if text:find("点冰冷伤害", 1, true) then dt = "阴性" end
    if text:find("点闪电伤害", 1, true) then dt = "混元" end
    if text:find("点腐蚀伤害", 1, true) then dt = "毒素" end
    if not dt then return nil end
    local scope = scopeText == "法术附加" and "spell" or "attack"
    -- 尝试双档 + 单档
    local bandText = text:match(
        "%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)%s*-%s*%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)"
    )
    local bands
    if bandText then
        bands = M.ParseBands(bandText)
    else
        local loA, loB = text:match("%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)")
        if loA then
            local v = tonumber(loA)
            local v2 = tonumber(loB)
            bands = {
                low = { min = v, max = v },
                high = { min = v2, max = v2 },
            }
        else
            local pa, pb = text:match("(%d+%.?%d*)%s*-%s*(%d+%.?%d*)")
            if pa then
                local v = tonumber(pa)
                local v2 = tonumber(pb)
                bands = {
                    low = { min = v, max = v },
                    high = { min = v2, max = v2 },
                }
            end
        end
    end
    if not bands then return nil end
    return {
        kind = "flatDamage",
        scope = scope,
        damageType = dt,
        bands = bands,
    }
end

-- 2) 武器基础攻击点伤："6 - 6 物理伤害"
local function parseBaseDamage(text)
    local numA, numB = text:match("^(%d+%.?%d*)%s*-%s*(%d+%.?%d*)%s*%S+伤害$")
    if not numA then return nil end
    local dt
    if text:find("物理伤害", 1, true) then dt = "物理" end
    if text:find("火焰伤害", 1, true) then dt = "阳性" end
    if text:find("冰冷伤害", 1, true) then dt = "阴性" end
    if text:find("闪电伤害", 1, true) then dt = "混元" end
    if text:find("腐蚀伤害", 1, true) then dt = "毒素" end
    if not dt then return nil end
    local v = tonumber(numA)
    local v2 = tonumber(numB)
    return {
        kind = "flatDamage",
        scope = "base",
        damageType = dt,
        bands = { low = { min = v, max = v }, high = { min = v2, max = v2 } },
    }
end

-- 3) 基础速度："1.5 攻击速度" / "1.2 施法速度"
local function parseFlatSpeed(text)
    local v = text:match("^([%d.]+)%s*攻击速度$")
    if v then
        return { kind = "flatSpeed", target = "attackSpeed", value = tonumber(v) }
    end
    v = text:match("^([%d.]+)%s*施法速度$")
    if v then
        return { kind = "flatSpeed", target = "castSpeed", value = tonumber(v) }
    end
    return nil
end

-- 4) 基础暴击值："500 暴击值"
local function parseFlatCrit(text)
    local v = text:match("^([%d.]+)%s*暴击值$")
    if v then return { kind = "flatCrit", value = tonumber(v) } end
    return nil
end

-- 5) 主属性固定/范围
local function parseAttribute(text)
    if not text:match("^%+") then return nil end
    local field
    if text:find("力量$", 1) then field = "rootBone" end
    if text:find("敏捷$", 1) then field = "dexterity" end
    if text:find("智慧$", 1) then field = "vitality" end
    -- 武侠名
    if text:find("根骨$", 1) then field = "rootBone" end
    if text:find("灵巧$", 1) then field = "dexterity" end
    if text:find("元气$", 1) then field = "vitality" end
    if not field then return nil end
    -- 只接受数字紧跟属性名（+3 力量 / +(15-20) 敏捷）
    if not text:match("^%+%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)%s*") 
        and not text:match("^%+(%d+%.?%d*)%s*") then
        return nil
    end
    local bands = parsePrefixBands(text)
    if not bands then return nil end
    return { kind = "flatAttribute", field = field, bands = bands }
end

-- 6) 资源上限
local function parseMaxResource(text)
    if not text:match("^%+") then return nil end
    local stat
    if text:find("最大生命", 1, true) then stat = "life" end
    if text:find("最大护盾", 1, true) then stat = "qi" end
    if text:find("最大魔力", 1, true) then stat = "innerForce" end
    if not stat then return nil end
    local bands = parsePrefixBands(text)
    if not bands then return nil end
    return { kind = "flatStat", stat = stat, bands = bands }
end

-- 7) 该装备护甲/闪避/护盾（防具底材）与全局护甲/闪避
local function parseFlatDefense(text)
    if not text:match("^%+") then return nil end
    local stat
    if text:find("该装备护甲值", 1, true) then stat = "armor" end
    if text:find("该装备护甲", 1, true) then stat = "armor" end
    if text:find("该装备闪避值", 1, true) then stat = "dodgeValue" end
    if text:find("该装备护盾", 1, true) then stat = "qi" end
    if text:find("护甲值$", 1) then stat = "armor" end
    if text:find("闪避值$", 1) then stat = "dodgeValue" end
    if not stat then return nil end
    -- 排除 % 词缀（那是 percentStat）
    if text:find("%", 1, true) then return nil end
    local bands = parsePrefixBands(text)
    if not bands then return nil end
    return { kind = "flatStat", stat = stat, bands = bands }
end

-- 8) 抗性词缀
local function parseResist(text)
    if not text:match("^%+") then return nil end
    -- 穿透类词缀（含"穿透"字样）交给 parseMechanicPercent 的 percentPierce 处理
    if text:find("穿透", 1, true) then return nil end
    local dt
    if text:find("火焰抗性", 1, true) then dt = "阳性" end
    if text:find("冰冷抗性", 1, true) then dt = "阴性" end
    if text:find("闪电抗性", 1, true) then dt = "混元" end
    if text:find("腐蚀抗性", 1, true) then dt = "毒素" end
    if not dt then return nil end
    local bands = parsePrefixBands(text)
    if not bands then return nil end
    return { kind = "percentResist", damageType = dt, bands = bands }
end

-- 9) %伤害加算："+(20-24)% 物理伤害" / "+(20-24)% 火焰伤害" 等
-- 目标词必须出现在 % 之后且位于行尾（避免误伤抗性/速度/暴击/技能范围等）
local DAMAGE_SUFFIXES = {
    "物理伤害", "元素伤害", "火焰伤害", "冰冷伤害", "闪电伤害", "腐蚀伤害", "毒素伤害",
    "近战伤害", "远程伤害", "技能伤害", "法术伤害", "内攻伤害", "持续伤害", "异常伤害",
    "攻击物理伤害", "法术腐蚀伤害",
}
local function parsePercentDamage(text)
    if not text:match("^%+") then return nil end
    if text:find("该装备", 1, true) then return nil end
    local bands = parsePrefixBands(text)
    if not bands then return nil end
    -- 需要先出现一个 %
    if not text:find("%", 1, true) then return nil end
    for _, suffix in ipairs(DAMAGE_SUFFIXES) do
        if text:find(suffix, 1, true) then
            -- 校验：该后缀应靠近行尾，且 % 在它之前
            local pctPos = text:find("%", 1, true)
            local suffixPos = text:find(suffix, 1, true)
            if suffixPos > pctPos then
                local channel = M.PercentTargets[suffix]
                if not channel then
                    if suffix:find("元素", 1, true) then channel = "elemental" end
                    if suffix:find("火焰", 1, true) or suffix:find("冰冷", 1, true) or suffix:find("闪电", 1, true) then channel = "elemental" end
                    if suffix:find("物理", 1, true) then channel = "physical" end
                    if suffix:find("腐蚀", 1, true) or suffix:find("毒素", 1, true) then channel = "toxin" end
                    if suffix:find("近战", 1, true) then channel = "melee" end
                    if suffix:find("远程", 1, true) then channel = "ranged" end
                    if suffix:find("技能", 1, true) or suffix:find("法术", 1, true) then channel = "skill" end
                    if suffix:find("内攻", 1, true) then channel = "inner" end
                    if suffix:find("持续", 1, true) or suffix:find("异常", 1, true) then channel = "dot" end
                end
                if channel then
                    return { kind = "percentDamage", channel = channel, bands = bands }
                end
            end
        end
    end
    return nil
end

-- 10) %速度 / %暴击值："+(6-8)% 攻击速度" 等
local function parsePercentSpeedCrit(text)
    if not text:match("^%+") then return nil end
    if text:find("该装备", 1, true) then return nil end
    if not text:find("%", 1, true) then return nil end
    local bands = parsePrefixBands(text)
    if not bands then return nil end
    if text:find("攻击与施法速度", 1, true) then
        return { kind = "percentSpeed", target = "both", bands = bands }
    end
    if text:find("攻击速度", 1, true) then
        return { kind = "percentSpeed", target = "attackSpeed", bands = bands }
    end
    if text:find("施法速度", 1, true) then
        return { kind = "percentSpeed", target = "castSpeed", bands = bands }
    end
    if text:find("暴击值$", 1) then
        return { kind = "percentCrit", bands = bands }
    end
    return nil
end

-- 11) 机制类 % 词缀（暴击伤害/移速/返还/技能范围/冷却回复/穿透/伤害/元素抗性/全属性/该装备本地加成）
-- 这类词缀在 TLIDB 中真实存在且可按项目既有语义生效，走对应普通加算通道。
local function parseMechanicPercent(text)
    if not text:match("^%+") then return nil end
    if not text:find("%", 1, true) then return nil end
    local bands = parsePrefixBands(text)
    if not bands then return nil end

    -- 暴击伤害
    if text:find("暴击伤害", 1, true) then
        return { kind = "percentCritDamage", bands = bands }
    end
    -- 移动速度
    if text:find("移动速度", 1, true) then
        return { kind = "percentMoveSpeed", bands = bands }
    end
    -- 技能范围
    if text:find("技能范围", 1, true) then
        return { kind = "percentSkillRange", bands = bands }
    end
    -- 冷却回复速度
    if text:find("冷却回复速度", 1, true) then
        return { kind = "percentCooldownRecovery", bands = bands }
    end
    -- 生命返还与护盾返还（组合）
    if text:find("生命返还与护盾返还", 1, true) then
        return { kind = "percentReturn", target = "both", bands = bands }
    end
    if text:find("生命返还", 1, true) then
        return { kind = "percentReturn", target = "life", bands = bands }
    end
    if text:find("护盾返还", 1, true) then
        return { kind = "percentReturn", target = "qi", bands = bands }
    end
    -- 抗性穿透（元素/火焰/冰冷/闪电/腐蚀；护甲减伤穿透对玩家攻击无目标，不生效仅展示）
    if text:find("抗性穿透", 1, true) or text:find("穿透", 1, true) then
        local pierceType
        if text:find("火焰穿透", 1, true) then pierceType = "yang" end
        if text:find("冰冷穿透", 1, true) then pierceType = "yin" end
        if text:find("闪电穿透", 1, true) then pierceType = "hunyuan" end
        if text:find("腐蚀抗性穿透", 1, true) then pierceType = "toxin" end
        if text:find("元素和腐蚀抗性穿透", 1, true) then pierceType = "elementToxin" end
        if text:find("元素", 1, true) and text:find("抗性穿透", 1, true) then
            if not pierceType then pierceType = "element" end
        end
        if pierceType then
            return { kind = "percentPierce", pierceType = pierceType, bands = bands }
        end
    end
    -- 泛伤害：行尾恰为「伤害」且非穿透/加深/减免类（其余带类型前缀已被 percentDamage 处理）
    if text:match("伤害$") then
        if not text:find("穿透", 1, true)
            and not text:find("加深", 1, true)
            and not text:find("减免", 1, true)
            and not text:find("收割", 1, true) then
            return { kind = "percentAllDamage", bands = bands }
        end
    end
    return nil
end

-- 12) 元素抗性（全元素抗性）："+(3-5)% 元素抗性"
local function parseElementResist(text)
    if not text:match("^%+") then return nil end
    if not text:find("元素抗性", 1, true) then return nil end
    if text:find("元素抗性上限", 1, true) then return nil end
    if text:find("穿透", 1, true) then return nil end
    local bands = parsePrefixBands(text)
    if not bands then return nil end
    return { kind = "percentElementResist", bands = bands }
end

-- 13) 全属性："+(a-b) 全属性"（= 根骨/灵巧/元气 各 +N）
local function parseAllAttributes(text)
    if not text:find("全属性", 1, true) then return nil end
    local bands = parsePrefixBands(text)
    if not bands then return nil end
    return { kind = "flatAllAttributes", bands = bands }
end

-- 14) "该装备"本地百分比加成（%该装备物理伤害/攻击速度/暴击值/护甲值等）
local function parseLocalPercent(text)
    if not text:match("^%+") then return nil end
    if not text:find("该装备", 1, true) then return nil end
    if not text:find("%", 1, true) then return nil end
    local bands = parsePrefixBands(text)
    if not bands then return nil end
    -- 该装备物理伤害（点伤放大）
    if text:find("该装备物理伤害", 1, true) then
        return { kind = "percentLocal", target = "physicalDamage", bands = bands }
    end
    if text:find("该装备元素伤害", 1, true) then
        return { kind = "percentLocal", target = "elementalDamage", bands = bands }
    end
    if text:find("该装备攻击速度", 1, true) then
        return { kind = "percentLocal", target = "attackSpeed", bands = bands }
    end
    if text:find("该装备攻击暴击值", 1, true) then
        return { kind = "percentLocal", target = "critValue", bands = bands }
    end
    if text:find("该装备护甲值", 1, true) then
        return { kind = "percentLocal", target = "armor", bands = bands }
    end
    if text:find("该装备闪避值", 1, true) then
        return { kind = "percentLocal", target = "dodgeValue", bands = bands }
    end
    return nil
end

-- ============================================================================
-- 召唤物通道%（召唤物/魔灵/哨卫/英灵/智械 的 伤害/攻击速度/移动速度）
-- ============================================================================
local SUMMON_KEYWORDS = { "召唤物", "魔灵", "哨卫", "英灵", "智械" }
local function parseSummonPercent(text)
    if text:find("该装备", 1, true) then return nil end
    if not text:match("^%+") then return nil end
    if not text:find("%", 1, true) then return nil end
    local hasKey = false
    for _, k in ipairs(SUMMON_KEYWORDS) do
        if text:find(k, 1, true) then
            hasKey = true
            break
        end
    end
    if not hasKey then return nil end
    local bands = parsePrefixBands(text)
    if not bands then return nil end
    if text:find("伤害", 1, true) then
        return { kind = "percentSummonDamage", bands = bands }
    end
    if text:find("移动速度", 1, true) then
        return { kind = "percentSummonMoveSpeed", bands = bands }
    end
    if text:find("攻击速度", 1, true) or text:find("施法速度", 1, true) or text:find("攻击与施法", 1, true) then
        return { kind = "percentSummonAttackSpeed", bands = bands }
    end
    return nil
end

-- 召唤物数量上限：+N 召唤物/哨卫/英灵/智械数量上限（无 %，flat 整数）
local SUMMON_COUNT_WORDS = { "召唤物", "哨卫", "英灵", "智械" }
local function parseSummonFlat(text)
    if not text:match("^%+%d+") then return nil end
    if not text:find("数量上限", 1, true) then return nil end
    local hasKey = false
    for _, k in ipairs(SUMMON_COUNT_WORDS) do
        if text:find(k, 1, true) then
            hasKey = true
            break
        end
    end
    if not hasKey then return nil end
    local v = text:match("^%+(%d+)")
    if not v then return nil end
    return { kind = "flatSummonCount", value = tonumber(v) }
end

-- ============================================================================
-- 主入口
-- ============================================================================
function M.ParseEffect(rawText)
    local text = M.Clean(rawText)
    if text == "" then return {} end
    local out = {}

    -- 点伤附加（含攻击附加/法术附加/该装备附加）
    local mod = parsePointAdd(text, "攻击附加")
    if mod then table.insert(out, mod) return out end
    mod = parsePointAdd(text, "法术附加")
    if mod then table.insert(out, mod) return out end
    mod = parsePointAdd(text, "该装备附加")
    if mod then table.insert(out, mod) return out end

    -- 武器基础点伤
    mod = parseBaseDamage(text)
    if mod then table.insert(out, mod) return out end

    -- 基础速度/暴击
    mod = parseFlatSpeed(text)
    if mod then table.insert(out, mod) return out end
    mod = parseFlatCrit(text)
    if mod then table.insert(out, mod) return out end

    -- 主属性
    mod = parseAttribute(text)
    if mod then table.insert(out, mod) return out end

    -- 资源/防具 flat
    mod = parseMaxResource(text)
    if mod then table.insert(out, mod) return out end
    mod = parseFlatDefense(text)
    if mod then table.insert(out, mod) return out end

    -- %伤害
    mod = parsePercentDamage(text)
    if mod then table.insert(out, mod) return out end

    -- 召唤物通道%（先于速度/暴击/泛伤害等通用解析，避免「召唤物攻击与施法速度」被当玩家攻速）
    mod = parseSummonPercent(text)
    if mod then table.insert(out, mod) return out end

    -- 召唤物数量上限（flat 整数）
    mod = parseSummonFlat(text)
    if mod then table.insert(out, mod) return out end

    -- 抗性
    mod = parseResist(text)
    if mod then table.insert(out, mod) return out end

    -- %速度/%暴击值
    mod = parsePercentSpeedCrit(text)
    if mod then table.insert(out, mod) return out end

    -- 该装备本地百分比加成（先于元素抗性/泛伤害判断）
    mod = parseLocalPercent(text)
    if mod then table.insert(out, mod) return out end

    -- 元素抗性（全元素）
    mod = parseElementResist(text)
    if mod then table.insert(out, mod) return out end

    -- 全属性
    mod = parseAllAttributes(text)
    if mod then table.insert(out, mod) return out end

    -- 机制类 %
    mod = parseMechanicPercent(text)
    if mod then table.insert(out, mod) return out end

    return out
end

-- 是否可识别（掉落池过滤）
function M.IsSupportedEffect(text)
    return #M.ParseEffect(text) > 0
end

-- ============================================================================
-- 掉落取值
-- ============================================================================
local function rollBand(band)
    if not band then return 0 end
    if band.max <= band.min then return band.min end
    return math.random(band.min, band.max)
end

-- 一次 roll：返回 { min, max }
function M.RollBands(bands)
    if not bands then return nil end
    local lowVal = rollBand(bands.low)
    local highVal = rollBand(bands.high)
    if highVal < lowVal then highVal = lowVal end
    return { min = lowVal, max = highVal }
end

-- 把 effect 原文中的数字区间替换为 roll 结果（展示用）
-- 双档 "(a-b) - (c-d)" → "X - Y"；单档 "(a-b)" → 单值。
function M.FormatRolledEffect(rawEffect, rolled)
    if not rawEffect then return "" end
    local text = M.Clean(rawEffect)
    -- 双档（点伤等保留范围）
    local cleaned = text:gsub(
        "%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)%s*-%s*%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)",
        tostring(rolled.min) .. " - " .. tostring(rolled.max)
    )
    if cleaned ~= text then return cleaned end
    -- 单档 → 单值（词缀 roll 后应显示确定数值）
    cleaned = text:gsub(
        "%((%d+%.?%d*)%s*-%s*(%d+%.?%d*)%)",
        tostring(rolled.min)
    )
    if cleaned ~= text then return cleaned end
    cleaned = text:gsub(
        "(%d+%.?%d*)%s*-%s*(%d+%.?%d*)",
        tostring(rolled.min) .. " - " .. tostring(rolled.max)
    )
    if cleaned ~= text then return cleaned end
    cleaned = text:gsub("(%d+%.?%d*)", tostring(rolled.min), 1)
    return cleaned
end

return M
