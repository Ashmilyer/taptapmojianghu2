-- 《默江湖》俯视角空间战斗模拟器（纯逻辑，不依赖 UI）
-- 战场采用米制坐标系：worldW x worldH 的逻辑战场
-- 单位：player / enemy / boss；圆形实体（x, y, radius）
-- 状态机：searching(寻怪) → fighting(波次) → boss(击杀满后刷 Boss) → 循环
-- 寻怪保留移动速度/位移技能减免语义：GetSearchTime(movementSpeed, blinkCount)
-- 通用技法：额外主动槽，按冷却自动释放；buff 类临时修改 attributes，到期还原。

local DamageSystem = require("Systems.DamageSystem")
local AttributeSystem = require("Systems.AttributeSystem")
local IdleSystem = require("Systems.IdleSystem")
local TechniqueEffects = require("Systems.TechniqueEffects")
local SkillSummonData = require("Data.SkillSummonData")

local M = {}

M.WorldWidth = 16.0   -- 战场逻辑宽度（米）
M.WorldHeight = 9.0   -- 战场逻辑高度（米）
M.BaseMoveSpeed = 5.0 -- 角色基础移动速度 m/s（用户确认）
M.ReviveDelay = 3.0
M.MaxEnemies = 6      -- 场上同时敌人数量上限（安全网）

--- 创建模拟器
---@param map table 地图数据（MapData.Maps[i]）
---@param attributes table 角色派生属性（AttributeSystem.Build）
---@param skills table 当前可用招式列表（GameData.Skills）
---@param skillSpace table id->空间字段（SkillSpaceData.Space 或内联）
function M.Create(map, attributes, skills, skillSpace)
    local sim = {
        map = map,
        attributes = attributes,
        skills = skills,
        skillSpace = skillSpace or {},
        skillIndex = 1,
        state = "searching",       -- searching / fighting / boss / defeated
        searchElapsed = 0.0,
        searchTime = 15.0,
        wave = 1,
        killCount = 0,             -- 本循环累计击杀普通怪
        totalKills = 0,
        defeatedCount = 0,
        gold = 0,
        experience = 0,
        reviveTimer = 0.0,
        combatElapsed = 0.0,
        playerAttackTimer = 0.0,
        player = nil,
        units = {},                -- 敌人/boss
        unitIdCounter = 0,
        logSink = nil,             -- function(msg)
        onKill = nil,              -- function(unit) 击杀回调（掉落 hook）
        onBossDefeated = nil,       -- function(unit, reward)
        nextIsBoss = false,
        -- 通用技法：技法 = 主动增益型技能（激发/防护/灵药/战吼/诅咒等）。
        -- main 组装 sim.techniqueSlots = { { skill = 技法对象, timer = 0.0 } }，每槽独立冷却。
        techniqueSlots = {},
        techniqueBuffs = {},       -- { { field=attributes字段, amount=数值, remain=剩余秒, original=原值 } }
        poisonEffects = {},         -- { damage, remain, tickTimer, sourceName }
        combatFeedback = {},        -- { text, x, y, color, remain, kind }
        bossWarning = nil,          -- { type, remain, x, y, radius }
        bossPhase = 0,
        summons = {},              -- 召唤物单位（kind="summon"），独立于敌人 units
    }
    setmetatable(sim, { __index = M })
    sim.player = M.CreatePlayerUnit(sim)
    sim:StartSearch()
    return sim
end

function M.CreatePlayerUnit(sim)
    local a = sim.attributes
    return {
        id = "player",
        kind = "player",
        name = "无名侠客",
        x = M.WorldWidth * 0.3,
        y = M.WorldHeight * 0.5,
        radius = 0.55,
        life = a.lifeMax,
        maxLife = a.lifeMax,
        innerForce = a.innerForceMax,
        maxInnerForce = a.innerForceMax,
        qi = a.qiMax,
        maxQi = a.qiMax,
        speed = (a.movementSpeed or M.BaseMoveSpeed),   -- m/s（Character.movementSpeed 为基础值）
        attackTimer = 0.0,
        facing = 0.0,
        alive = true,
    }
end

function M.CreateEnemyUnit(sim, kind, x, y, typeDef)
    local map = sim.map
    local tmpl = map.enemy
    local isBoss = kind == "boss"
    local def = typeDef or { role = "melee", lifeMult = 1.0, attackMult = 1.0, moveMult = 1.0, range = tmpl.attackRange or 1.6 }
    local scale = isBoss and (map.boss.scale or 1.6) or 1.0
    local difficulty = map.difficulty or 1.0
    local name = isBoss and (map.boss.name or (tmpl.name .. "王")) or (def.name or tmpl.name)
    local level = isBoss and (map.boss.level or tmpl.level + 1) or (tmpl.level + (def.levelOffset or 0))
    local maxLife = tmpl.maxLife * difficulty * (def.lifeMult or 1.0)
    local outerAttack = tmpl.outerAttack * difficulty * (def.attackMult or 1.0)
    local rewardGold = tmpl.rewardGold
    local rewardExperience = tmpl.rewardExperience
    if isBoss then
        maxLife = tmpl.maxLife * difficulty * (map.boss.maxLifeMultiplier or 8)
        outerAttack = tmpl.outerAttack * difficulty * (map.boss.attackMultiplier or 3)
        rewardGold = rewardGold * (map.boss.rewardGoldMultiplier or 10)
        rewardExperience = rewardExperience * (map.boss.rewardExperienceMultiplier or 8)
    end
    sim.unitIdCounter = sim.unitIdCounter + 1
    local unit = {
        id = "u" .. sim.unitIdCounter, kind = kind, role = isBoss and "boss" or (def.role or "melee"),
        name = name, level = level, x = x, y = y,
        radius = (tmpl.radius or 0.5) * scale, life = maxLife, maxLife = maxLife,
        outerAttack = outerAttack, armor = (tmpl.armor or 0) * (def.armorMult or 1.0),
        yangResistance = tmpl.yangResistance or 0.1, yinResistance = tmpl.yinResistance or 0.1,
        hunyuanResistance = tmpl.hunyuanResistance or 0.1, toxinResistance = tmpl.toxinResistance or 0.1,
        attackInterval = isBoss and (map.boss.attackInterval or 2.2) or (tmpl.attackInterval / (def.attackSpeedMult or 1.0)),
        moveSpeed = isBoss and (tmpl.moveSpeed or 2.2) * 0.8 or (tmpl.moveSpeed or 2.2) * (def.moveMult or 1.0),
        attackRange = isBoss and (tmpl.attackRange or 1.6) * scale or (def.range or tmpl.attackRange or 1.6),
        damageType = def.damageType or "物理", rewardGold = rewardGold, rewardExperience = rewardExperience,
        scale = scale, alive = true, attackTimer = 0.0,
        summonInterval = def.summonInterval or 0.0, summonTimer = 0.0,
        poisonDamage = (def.role == "poison") and (outerAttack * 0.22) or 0.0,
        poisonDuration = def.role == "poison" and 5.0 or 0.0,
        phase = isBoss and 1 or 0, phaseAnnounced = {}, specialTimer = 0.0,
        warningTimer = 0.0, warningDuration = 1.2, warningType = nil,
        rangedCooldown = 0.0,
        isReinforcement = false,
    }
    return unit
end

function M:AddFeedback(text, x, y, color, kind)
    table.insert(self.combatFeedback, { text = text, x = x, y = y, color = color, remain = 1.0, kind = kind or "damage" })
end

function M:UpdateFeedback(dt)
    local active = {}
    for _, entry in ipairs(self.combatFeedback) do
        entry.remain = entry.remain - dt
        entry.y = entry.y - 0.55 * dt
        if entry.remain > 0.0 then table.insert(active, entry) end
    end
    self.combatFeedback = active
end

function M:GetFeedback()
    return self.combatFeedback
end

function M:Log(msg)
    if self.logSink then
        self.logSink(msg)
    end
end

function M:GetCurrentSkill()
    return self.skills[self.skillIndex]
end

function M:GetSkillSpace(skill)
    if not skill then return nil end
    if skill.space then return skill.space end
    return self.skillSpace[skill.id]
end

-- 技能范围%词缀加成后的有效空间（普通加算：range/radius × (1 + skillRangePct/100)）
function M:GetEffectiveSpace(skill)
    local space = self:GetSkillSpace(skill)
    if not space then return nil end
    local mult = 1.0 + ((self.attributes.skillRangePct or 0.0) / 100.0)
    if mult <= 1.0001 then return space end
    return {
        shape = space.shape,
        range = (space.range or 0.0) * mult,
        radius = space.radius and (space.radius * mult) or nil,
        angle = space.angle,
        targetCount = space.targetCount,
    }
end

function M:GetSearchTime()
    local a = self.attributes
    local blinkCount = 0
    return IdleSystem.GetSearchTime(a.movementSpeed or 0.0, blinkCount)
end

function M:StartSearch()
    self.state = "searching"
    self.searchElapsed = 0.0
    self.searchTime = self:GetSearchTime()
    self:Log("开始寻怪，预计 " .. string.format("%.1f", self.searchTime) .. " 秒")
end

-- 在右侧随机生成一波敌人（除 boss 出现轮）
function M:SpawnWave()
    self.wave = self.wave + 1
    -- 清理上一波已死亡单位
    local alive = {}
    for _, u in ipairs(self.units) do
        if u.alive then table.insert(alive, u) end
    end
    self.units = alive
    local waveSize = self.map.waveSize or 4
    local count = math.min(waveSize, M.MaxEnemies)
    local typeDefs = self.map.enemyTypes or {}
    for i = 1, count do
        local x = M.WorldWidth * 0.8 + (math.random() - 0.5) * 2.0
        local y = M.WorldHeight * (0.15 + 0.7 * (i - 1) / math.max(1, count - 1))
        local typeDef = nil
        if #typeDefs > 0 then
            typeDef = typeDefs[((self.wave - 2 + i - 1) % #typeDefs) + 1]
        end
        local unit = M.CreateEnemyUnit(self, "enemy", x, y, typeDef)
        table.insert(self.units, unit)
    end
    self.state = "fighting"
    self.combatElapsed = 0.0
    self.playerAttackTimer = 0.0
    self:Log("第 " .. (self.wave - 1) .. " 波敌人出现（" .. count .. " 只），自动索敌")
end

-- 击杀普通怪满后刷 Boss
function M:SpawnBoss()
    local alive = {}
    for _, u in ipairs(self.units) do
        if u.alive then table.insert(alive, u) end
    end
    self.units = alive
    local x = M.WorldWidth * 0.75
    local y = M.WorldHeight * 0.5
    local boss = M.CreateEnemyUnit(self, "boss", x, y)
    table.insert(self.units, boss)
    self.state = "boss"
    self.combatElapsed = 0.0
    self.playerAttackTimer = 0.0
    self:Log(boss.name .. " 降临！")
end

-- 所有场上敌人存活判定
function M:HasLivingEnemy()
    for _, u in ipairs(self.units) do
        if u.alive then return true end
    end
    return false
end

-- 单位间距离
function M:Dist(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

function M:DistToPlayer(u)
    return self:Dist(self.player, u)
end

function M:NearestEnemy()
    local best = nil
    local bestDist = math.huge
    for _, u in ipairs(self.units) do
        if u.alive then
            local d = self:DistToPlayer(u)
            if d < bestDist then
                bestDist = d
                best = u
            end
        end
    end
    return best, bestDist
end

-- 击杀奖励
function M:OnEnemyDied(unit)
    unit.alive = false
    if unit.kind == "boss" then
        self.killCount = 0          -- 循环重置
        self:Log("击败 " .. unit.name .. "！奖励大幅提升，计数重置，继续狩猎")
    else
        self.killCount = self.killCount + 1
        self.totalKills = self.totalKills + 1
        self.defeatedCount = self.defeatedCount + 1
    end
    self.gold = self.gold + unit.rewardGold
    self.experience = self.experience + unit.rewardExperience
    self:Log("击败 " .. unit.name .. "，获得金币 " .. unit.rewardGold .. "、经验 " .. unit.rewardExperience .. "（累计 " .. self.killCount .. "/" .. self.map.bossKillTarget .. "）")
    -- 掉落钩子（main 挂载：普通 20%，首领必掉）
    if self.onKill then
        self.onKill(unit)
    end
    if unit.kind == "boss" and self.onBossDefeated then
        self.onBossDefeated(unit, {
            gold = unit.rewardGold,
            experience = unit.rewardExperience,
        })
    end
end

-- 波次结束检查：没有活敌 → 进入寻怪（若 killCount 达到阈值则下一波刷 Boss）
function M:CheckWaveEnd()
    if self:HasLivingEnemy() then return end
    if self.state == "defeated" then return end
    if self.killCount >= self.map.bossKillTarget then
        self:Log("已消灭 " .. self.killCount .. " 只敌人，首领即将现身！")
        self:StartSearch()   -- Boss 前也有寻怪间隔
        self.nextIsBoss = true
    else
        self:StartSearch()
        self.nextIsBoss = false
    end
end

-- 玩家出手：判断当前招式能否命中某敌人（空间判定）
-- space.shape:
--   point_melee / point_ranged / multi：目标距离 <= range 视为可命中
--   circle：以玩家为圆心，敌人距离 <= radius 视为可命中（玩家需先接近到 range 内）
--   fan / cone / rect：简化按 <= range 全向命中（角度朝向判定后续实现）
function M:CanHit(unit, skill, space)
    if not space then return false end
    local d = self:DistToPlayer(unit)
    if space.shape == "point_melee" or space.shape == "point_ranged" or space.shape == "multi" then
        return d <= (space.range or 9.0)
    end
    if space.shape == "circle" then
        return d <= (space.radius or 3.0)
    end
    -- fan / cone / rect：简化全向
    return d <= (space.range or 6.0)
end

-- 玩家能否开始施放（需先接近到 range 内）
function M:CanApproach(unit, skill, space)
    if not space then return false end
    local d = self:DistToPlayer(unit)
    if space.shape == "circle" then
        -- 接近到爆炸半径边缘即可
        return d <= (space.range or 6.0)
    end
    return d <= (space.range or 9.0)
end

-- 收集能被当前招式命中的敌人
function M:CollectTargets(space)
    local targets = {}
    -- 单点招式（近战/远程）：只取最近一个目标
    if space.shape == "point_melee" or space.shape == "point_ranged" then
        local nearest, bestDist = self:NearestEnemy()
        if nearest and bestDist <= (space.range or 9.0) then
            return { nearest }
        end
        return targets
    end
    for _, u in ipairs(self.units) do
        if u.alive then
            if space.shape == "circle" then
                -- 以玩家为圆心的范围：radius 内全部命中
                if self:DistToPlayer(u) <= (space.radius or 3.0) then
                    table.insert(targets, u)
                end
            elseif self:CanHit(u, self:GetCurrentSkill(), space) then
                table.insert(targets, u)
            end
        end
    end
    -- multi 限制目标数：取最近 N 个
    if space.shape == "multi" and space.targetCount then
        table.sort(targets, function(a, b)
            return self:DistToPlayer(a) < self:DistToPlayer(b)
        end)
        local n = math.min(#targets, space.targetCount)
        local out = {}
        for i = 1, n do out[i] = targets[i] end
        return out
    end
    return targets
end

-- ============================================================================
-- 通用技法（主动增益/回复）：按冷却自动释放
-- ============================================================================

-- channel → attributes 加算字段（value 为百分比数值，如 16 表示 +16%）
-- 仅映射 attributes 中实际存在的通道；damageReducePct 为受伤减免%（同 /100 语义）
local TECH_FIELD_MAP = {
    skillDamage = "skillDamage",
    meleeDamage = "meleeDamage",
    rangedDamage = "rangedDamage",
    physicalDamage = "physicalDamage",
    elementalDamage = "elementalDamage",
    toxinDamage = "toxinDamage",
    innerDamage = "innerDamage",
    critValuePct = "critValuePercentBonus",
    damageReducePct = "damageReducePct",
    critDamagePct = "critDamagePct",
}

-- attributes 中这些字段存百分数值（12 = 12%），其余通道存小数（0.12 = +12%）
local TECH_PCT_FIELDS = {
    damageReducePct = true,
    critDamagePct = true,
}

-- 对玩家施加伤害（供技法减伤等入口使用）
function M:ApplyPlayerDamage(damage, sourceName, damageType)
    local a = self.attributes
    local reduce = (a.damageReducePct or 0.0) / 100.0
    if reduce > 0.85 then reduce = 0.85 end
    local final = math.max(0.0, damage * (1.0 - reduce))
    self.player.life = math.max(0.0, self.player.life - final)
    self:Log(sourceName .. " 攻击你，" .. string.format("%.1f", final) .. " 点" .. (damageType or "物理") .. "伤害")
    if self.player.life <= 0.0 then
        self.state = "defeated"
        self.reviveTimer = M.ReviveDelay
        self:ClearSummons()
        self:Log("侠客倒地，" .. M.ReviveDelay .. " 秒后自动恢复")
    end
end

-- 还原技法 buff（到期）
function M:RemoveTechniqueBuff(entry)
    local a = self.attributes
    if entry.field then
        a[entry.field] = (a[entry.field] or 0.0) - entry.amount
        if a[entry.field] < 0.0 then a[entry.field] = 0.0 end
    end
    entry.remain = -1
end

-- 释放一次技法（技法效果来自 TechniqueEffects 手工映射；召唤类走召唤路径）
function M:ReleaseTechnique(slotEntry)
    local skill = slotEntry.skill
    if not skill then return end
    local a = self.attributes
    local p = self.player

    -- 召唤类技法（本地模板或库内召唤/哨卫/智械）：按冷却召唤单位
    if self:IsSummonSkill(skill) then
        local refineMult = nil
        if skill.refineBonusPct and skill.refineBonusPct > 0.0 then
            refineMult = 1.0 + skill.refineBonusPct
        end
        self:TrySummon(skill, refineMult)
        return
    end

    local eff = TechniqueEffects.Effects[skill.id]
    if not eff then
        -- 未完成手工映射的技法：静默跳过（不参战，避免按冷却刷日志噪音）
        return
    end

    if eff.kind == "recover" then
        -- 立即回复（value=百分比，按当前上限）
        if eff.channel == "life" then
            local amount = p.maxLife * (eff.value / 100.0)
            p.life = math.min(p.maxLife, p.life + amount)
            self:Log("精研「" .. skill.name .. "」回复 " .. string.format("%.1f", amount) .. " 生命")
        elseif eff.channel == "innerForce" then
            local amount = p.maxInnerForce * (eff.value / 100.0)
            p.innerForce = math.min(p.maxInnerForce, p.innerForce + amount)
            self:Log("精研「" .. skill.name .. "」回复内力 " .. string.format("%.1f", amount))
        end
        return
    end

    if eff.kind == "buff" then
        local field = TECH_FIELD_MAP[eff.channel]
        if field then
            -- 百分数字段直接加值，小数通道除以 100（与 AttributeSystem 输出单位一致）
            local amount = eff.value
            if not TECH_PCT_FIELDS[field] then amount = amount / 100.0 end
            -- 专属精研加持：技法效果独立乘区（skill.refineBonusPct 由 SyncRefineBonus 写入）
            if skill.refineBonusPct and skill.refineBonusPct > 0.0 then
                amount = amount * (1.0 + skill.refineBonusPct)
            end
            -- 记录原值并还原旧技法的同字段加成（先移除已存在的同技法 buff）
            for _, old in ipairs(self.techniqueBuffs) do
                if old.skillId == skill.id then
                    self:RemoveTechniqueBuff(old)
                end
            end
            a[field] = (a[field] or 0.0) + amount
            table.insert(self.techniqueBuffs, {
                skillId = skill.id,
                field = field,
                amount = amount,
                remain = eff.duration or 6.0,
            })
            local label = skill.name
            self:Log("精研「" .. label .. "」激活：+" .. string.format("%g", eff.value) .. "% 增益，持续 " .. string.format("%g", eff.duration or 6.0) .. " 秒")
        end
    end
end

-- 技法更新：冷却倒计时 + buff 到期还原
function M:TechniqueUpdate(dt)
    for _, slot in ipairs(self.techniqueSlots or {}) do
        if slot.skill then
            slot.timer = (slot.timer or 0.0) - dt
            local cd = slot.skill.cooldown or 8.0
            if cd <= 0 then cd = 8.0 end
            if slot.timer <= 0.0 then
                slot.timer = cd
                self:ReleaseTechnique(slot)
            end
        end
    end
    for _, entry in ipairs(self.techniqueBuffs) do
        if entry.remain > 0 then
            entry.remain = entry.remain - dt
            if entry.remain <= 0.0 then
                self:RemoveTechniqueBuff(entry)
            end
        end
    end
end

-- 玩家释放技能
function M:PlayerUseSkill()
    local skill = self:GetCurrentSkill()
    if not skill then return end
    local space = self:GetEffectiveSpace(skill)
    local skillCost = skill.cost or 0
    -- 内攻消耗内力不足自动切外攻
    if skill.kind == "内攻招式" and skillCost > 0 and self.player.innerForce < skillCost then
        self.skillIndex = 1
        skill = self:GetCurrentSkill()
        space = self:GetEffectiveSpace(skill)
        skillCost = skill.cost or 0
        self:Log("内力不足，自动改用外攻招式：" .. skill.name)
    end
    local spaceShape = (space and space.shape) or "point_melee"
    local target = self:NearestEnemy()
    if not target then return end
    -- 多点需要至少一个目标；范围（circle/fan）若范围内无敌人，朝最近敌人走（由移动处理）
    local targets = self:CollectTargets(space or { shape = "point_melee", range = 1.6 })
    if #targets == 0 then return end

    -- 扣内力
    if skill.kind == "内攻招式" and skillCost > 0 then
        self.player.innerForce = math.max(0.0, self.player.innerForce - skillCost)
    end

    for _, u in ipairs(targets) do
        local isCrit = false
        local critChance = AttributeSystem.GetCritChance(self.attributes, skill)
        if critChance > 0.0 and math.random() < critChance then
            isCrit = true
        end
        local damage = DamageSystem.CalculatePlayerDamage(self.attributes, skill, isCrit)
        damage = DamageSystem.ApplyResistance(damage, u, skill.damageType)
        u.life = math.max(0.0, u.life - damage)
        local countInfo = #targets > 1 and ("（命中" .. #targets .. "目标）") or ""
        if isCrit then
            self:Log(skill.name .. "暴击 " .. string.format("%.1f", damage) .. " 点" .. skill.damageType .. "伤害 → " .. u.name .. countInfo)
            self:AddFeedback("暴击 " .. string.format("%.0f", damage), u.x, u.y, "legendary", "crit")
        else
            self:Log(skill.name .. "造成 " .. string.format("%.1f", damage) .. " 点" .. skill.damageType .. "伤害 → " .. u.name .. countInfo)
            self:AddFeedback(string.format("%.0f", damage), u.x, u.y, "damage", "damage")
        end
        -- 生命返还 / 护盾返还词缀（命中回复，按本次伤害百分比）
        self:ApplyReturn(damage)
        if u.life <= 0.0 then
            self:OnEnemyDied(u)
        end
    end
end

-- 生命返还（命中回血）与护盾返还（命中回真气）
function M:ApplyReturn(damage)
    local a = self.attributes
    local p = self.player
    local lifePct = (a.returnLifePct or 0.0) / 100.0
    if lifePct > 0.0 and p.life < p.maxLife then
        p.life = math.min(p.maxLife, p.life + damage * lifePct)
    end
    local qiPct = (a.returnQiPct or 0.0) / 100.0
    if qiPct > 0.0 and p.qi < p.maxQi then
        p.qi = math.min(p.maxQi, p.qi + damage * qiPct)
    end
end

-- ============================================================================
-- 召唤物系统：装配召唤类通用精研（本地模板或库内召唤/哨卫/智械技法）后，
-- 技法按冷却自动 TrySummon；场上召唤物上限 = 1 + summonCountBonus 词缀；
-- 召唤物自动索敌普攻，可被敌人攻击，死亡后随技法冷却自动重召。
-- ============================================================================

-- 该技法/技能是否属于召唤类
function M:IsSummonSkill(skill)
    if not skill then return false end
    if skill.summonArchetype then return true end
    return SkillSummonData.LibrarySummonMap[skill.id] ~= nil
end

-- 场上存活召唤物数量
function M:AliveSummonCount()
    local n = 0
    for _, s in ipairs(self.summons) do
        if s.alive then n = n + 1 end
    end
    return n
end

-- 召唤物上限（基础 1，装备词缀 +N）
function M:SummonCap()
    return 1 + (self.attributes.summonCountBonus or 0)
end

-- 生成一名召唤物（arch = 模板，refineMult = 该技能专属精研独立乘区）
function M:SpawnSummon(archId, skill, refineMult)
    local arch = SkillSummonData.GetArchetype(archId)
    if not arch then return nil end
    local a = self.attributes
    local difficulty = self.map.difficulty or 1.0
    local dmgMult = (1.0 + (a.summonDamagePct or 0.0) / 100.0) * difficulty
    if refineMult then dmgMult = dmgMult * refineMult end
    local speedMult = 1.0 + (a.summonAttackSpeedPct or 0.0) / 100.0
    local moveMult = 1.0 + (a.summonMoveSpeedPct or 0.0) / 100.0
    self.unitIdCounter = self.unitIdCounter + 1
    local p = self.player
    local s = {
        id = "sm" .. self.unitIdCounter,
        kind = "summon",
        archetypeId = archId,
        name = arch.name,
        skillId = skill and skill.id or nil,
        x = p.x + (math.random() - 0.5) * 1.2,
        y = p.y + (math.random() - 0.5) * 1.2,
        radius = arch.radius or 0.5,
        life = arch.life * difficulty,
        maxLife = arch.life * difficulty,
        outerAttack = arch.outerAttack,
        attackInterval = math.max(0.4, (arch.attackInterval or 1.8) / math.max(0.2, speedMult)),
        moveSpeed = (arch.moveSpeed or 3.6) * moveMult,
        attackRange = arch.range or 1.7,
        damageType = arch.damageType or "物理",
        scale = arch.scale or 0.85,
        attackTimer = 0.0,
        alive = true,
    }
    s.x = math.max(s.radius, math.min(M.WorldWidth - s.radius, s.x))
    s.y = math.max(s.radius, math.min(M.WorldHeight - s.radius, s.y))
    table.insert(self.summons, s)
    return s
end

-- 尝试召唤（由技法冷却触发）；已达上限则静默等待
function M:TrySummon(skill, refineMult)
    if self:AliveSummonCount() >= self:SummonCap() then return false end
    local archId = skill.summonArchetype or SkillSummonData.LibrarySummonMap[skill.id]
    if not archId then return false end
    local s = self:SpawnSummon(archId, skill, refineMult)
    if not s then return false end
    local suffix = ""
    if refineMult and refineMult ~= 1.0 then
        suffix = "（受专属精研加持）"
    end
    self:Log("技法「" .. skill.name .. "」召唤「" .. s.name .. "」" .. suffix)
    return true
end

-- 清理死亡召唤物
function M:PruneSummons()
    local alive = {}
    for _, s in ipairs(self.summons) do
        if s.alive then table.insert(alive, s) end
    end
    self.summons = alive
end

-- 敌人就近攻击目标：玩家或存活召唤物（召唤物可承担仇恨）
function M:NearestHostile(u)
    local best = self.player
    local bestDist = self:Dist(u, self.player)
    for _, s in ipairs(self.summons) do
        if s.alive then
            local d = self:Dist(u, s)
            if d < bestDist then
                bestDist = d
                best = s
            end
        end
    end
    return best, bestDist
end

-- 召唤物行为：寻敌 → 接近/普攻；无敌人时跟随玩家
function M:SummonUpdate(s, dt)
    if not s.alive then return end
    local p = self.player
    local enemy, eDist = self:NearestEnemy()
    if not enemy then
        -- 跟随玩家
        local d = self:Dist(s, p)
        if d > 2.0 then
            local dx = (p.x - s.x) / math.max(0.001, d)
            local dy = (p.y - s.y) / math.max(0.001, d)
            s.x = s.x + dx * s.moveSpeed * dt
            s.y = s.y + dy * s.moveSpeed * dt
        end
        return
    end
    if eDist > s.attackRange then
        local dx = (enemy.x - s.x) / math.max(0.001, eDist)
        local dy = (enemy.y - s.y) / math.max(0.001, eDist)
        s.x = s.x + dx * s.moveSpeed * dt
        s.y = s.y + dy * s.moveSpeed * dt
    else
        s.attackTimer = s.attackTimer + dt
        if s.attackTimer >= s.attackInterval then
            s.attackTimer = 0.0
            local dmg = s.outerAttack
            dmg = DamageSystem.ApplyResistance(dmg, enemy, s.damageType)
            enemy.life = math.max(0.0, enemy.life - dmg)
            if enemy.life <= 0.0 then
                self:OnEnemyDied(enemy)
            end
        end
    end
end

function M:SpawnReinforcement(source)
    if #self.units >= M.MaxEnemies + 2 then return nil end
    local x = math.min(M.WorldWidth - 0.8, source.x + 0.8)
    local y = math.max(0.8, math.min(M.WorldHeight - 0.8, source.y + (math.random() - 0.5) * 1.8))
    local def = { role = "melee", name = "祭司护卫", lifeMult = 0.55, attackMult = 0.55, moveMult = 1.0, range = 1.5, attackSpeedMult = 0.9, damageType = "物理" }
    local unit = M.CreateEnemyUnit(self, "enemy", x, y, def)
    unit.isReinforcement = true
    table.insert(self.units, unit)
    self:Log(source.name .. " 召唤祭司护卫")
    return unit
end

function M:UpdateEnemySpecial(unit, dt, target, distance)
    if unit.role == "summoner" then
        unit.summonTimer = unit.summonTimer + dt
        if unit.summonTimer >= unit.summonInterval then
            unit.summonTimer = 0.0
            self:SpawnReinforcement(unit)
        end
    end
    if unit.role == "boss" then
        self:UpdateBossPhase(unit)
        unit.specialTimer = unit.specialTimer + dt
        if unit.warningTimer > 0.0 then
            unit.warningTimer = unit.warningTimer - dt
            if unit.warningTimer <= 0.0 then
                unit.warningTimer = 0.0
                self:BossAreaAttack(unit)
            end
            return true
        end
        if unit.specialTimer >= math.max(2.5, 5.0 - unit.phase * 0.6) then
            unit.specialTimer = 0.0
            unit.warningTimer = unit.warningDuration
            unit.warningType = "boss_area"
            self.bossWarning = { type = "boss_area", remain = unit.warningDuration, x = self.player.x, y = self.player.y, radius = 2.4 + unit.phase * 0.4 }
            self:Log(unit.name .. " 准备施放范围重击，立即躲避！")
            return true
        end
    end
    if unit.role == "ranged" then
        if distance < 3.8 then
            local dx = (unit.x - target.x) / math.max(0.001, distance)
            local dy = (unit.y - target.y) / math.max(0.001, distance)
            unit.x = unit.x + dx * unit.moveSpeed * dt
            unit.y = unit.y + dy * unit.moveSpeed * dt
            return true
        end
        if unit.rangedCooldown > 0.0 then
            unit.rangedCooldown = unit.rangedCooldown - dt
            return true
        end
        unit.rangedCooldown = unit.attackInterval
        self:ApplyEnemyHit(unit, target)
        return true
    end
    return false
end

function M:ApplyEnemyHit(unit, target)
    local damage = DamageSystem.CalculateEnemyDamage(self.attributes, unit)
    if target.kind == "summon" then
        target.life = math.max(0.0, target.life - damage)
        if target.life <= 0.0 then target.alive = false end
        return
    end
    self:ApplyPlayerDamage(damage, unit.name, unit.damageType)
    if unit.role == "poison" then
        table.insert(self.poisonEffects, { damage = unit.poisonDamage, remain = unit.poisonDuration, tickTimer = 0.0, sourceName = unit.name })
        self:Log(unit.name .. " 施加毒伤，持续 " .. unit.poisonDuration .. " 秒")
    end
end

function M:UpdatePoison(dt)
    local active = {}
    for _, effect in ipairs(self.poisonEffects) do
        if effect.remain > 0.0 and self.player.alive ~= false then
            effect.remain = effect.remain - dt
            effect.tickTimer = (effect.tickTimer or 0.0) - dt
            if effect.tickTimer <= 0.0 then
                effect.tickTimer = 1.0
                local damage = effect.damage
                self:ApplyPlayerDamage(damage, effect.sourceName .. "毒伤", "毒素")
                self:AddFeedback("毒 " .. string.format("%.0f", damage), self.player.x, self.player.y, "poison", "damage")
            end
            if effect.remain > 0.0 then table.insert(active, effect) end
        end
    end
    self.poisonEffects = active
end

function M:UpdateBossPhase(unit)
    local ratio = unit.life / math.max(1.0, unit.maxLife)
    local newPhase = 1
    local phases = self.map.bossPhases or { 0.7, 0.4 }
    if ratio <= phases[1] then newPhase = 2 end
    if ratio <= phases[2] then newPhase = 3 end
    if newPhase <= unit.phase then return end
    unit.phase = newPhase
    self.bossPhase = newPhase
    self:Log(unit.name .. " 进入第 " .. newPhase .. " 阶段！")
    if newPhase >= 2 then
        self:SpawnReinforcement(unit)
        self:SpawnReinforcement(unit)
    end
end

function M:BossAreaAttack(unit)
    local warning = self.bossWarning
    self.bossWarning = nil
    if not warning then return end
    local dx = self.player.x - warning.x
    local dy = self.player.y - warning.y
    if math.sqrt(dx * dx + dy * dy) <= warning.radius then
        self:ApplyPlayerDamage(unit.outerAttack * (0.9 + unit.phase * 0.25), unit.name .. "范围重击", "混元")
    else
        self:Log("你避开了 " .. unit.name .. " 的范围重击")
    end
end

-- 主循环内推进召唤物
function M:UpdateSummons(dt)
    self:PruneSummons()
    for _, s in ipairs(self.summons) do
        self:SummonUpdate(s, dt)
    end
end

-- 清空全部召唤物（玩家倒地/重置时）
function M:ClearSummons()
    self.summons = {}
end

-- 敌人追击并攻击最近目标（玩家或召唤物；召唤物可承担仇恨）
function M:EnemyUpdate(unit, dt)
    local target, d = self:NearestHostile(unit)
    if not target then return end
    if self:UpdateEnemySpecial(unit, dt, target, d) then return end
    local stopDist = math.max(unit.attackRange, unit.radius + target.radius + 0.15)
    if d > stopDist then
        local dx = (target.x - unit.x) / math.max(0.001, d)
        local dy = (target.y - unit.y) / math.max(0.001, d)
        unit.x = unit.x + dx * unit.moveSpeed * dt
        unit.y = unit.y + dy * unit.moveSpeed * dt
        -- 边界限制
        unit.x = math.max(unit.radius, math.min(M.WorldWidth - unit.radius, unit.x))
        unit.y = math.max(unit.radius, math.min(M.WorldHeight - unit.radius, unit.y))
    else
        unit.attackTimer = unit.attackTimer + dt
        if unit.attackTimer >= unit.attackInterval then
            unit.attackTimer = 0.0
            if target.kind == "summon" then
                -- 攻击召唤物（无视玩家护甲，直接结算）
                local dmg = unit.outerAttack
                target.life = math.max(0.0, target.life - dmg)
                if target.life <= 0.0 then
                    target.alive = false
                    self:Log(target.name .. " 被击败，将随技法冷却重新召唤")
                end
            else
                self:ApplyEnemyHit(unit, target)
            end
        end
    end
end

-- 玩家移动与出手：先判断能否命中场上敌人，能则出手，否则朝最近敌人移动
function M:PlayerUpdate(dt)
    local skill = self:GetCurrentSkill()
    local space = self:GetEffectiveSpace(skill) or { shape = "point_melee", range = 1.6 }
    local target, dist = self:NearestEnemy()
    if not target then return end

    local targets = self:CollectTargets(space)
    if #targets == 0 then
        -- 无法命中：朝最近敌人移动
        local d = math.max(0.001, dist)
        local dx = (target.x - self.player.x) / d
        local dy = (target.y - self.player.y) / d
        self.player.x = self.player.x + dx * self.player.speed * dt
        self.player.y = self.player.y + dy * self.player.speed * dt
        self.player.x = math.max(self.player.radius, math.min(M.WorldWidth - self.player.radius, self.player.x))
        self.player.y = math.max(self.player.radius, math.min(M.WorldHeight - self.player.radius, self.player.y))
        self.player.facing = math.atan2(dy, dx)
    else
        self.player.facing = math.atan2(target.y - self.player.y, target.x - self.player.x)
        self.playerAttackTimer = self.playerAttackTimer + dt
        local interval = self:GetPlayerAttackInterval(skill)
        if self.playerAttackTimer >= interval then
            self.playerAttackTimer = 0.0
            self:PlayerUseSkill()
        end
    end
end

function M:GetPlayerAttackInterval(skill)
    if not skill then return 1.0 end
    local a = self.attributes
    local cooldownMult = 1.0 + (a.cooldownRecovery or 0.0)
    if skill.kind == "外攻招式" then
        -- 外攻招式优先自己的冷却，其次出招时间（castTime），最后默认 2.5
        local base = skill.cooldown or skill.castTime or 2.5
        if base <= 0 then base = 2.5 end
        return math.max(0.6, base / math.max(1.0, a.outerWeaponAttackSpeed or 1.0) / cooldownMult)
    end
    -- 内攻按施法速度 + 内攻武器攻速 + 冷却回复
    return math.max(
        0.3,
        (skill.castTime or 1.0)
            / math.max(1.0, a.innerWeaponAttackSpeed or 1.0)
            / math.max(1.0, 1.0 + (a.castSpeed or 0.0))
            / cooldownMult
    )
end

-- 换装/属性重算后同步玩家单位（上限按新属性调整，当前值按比例保留）
function M:ApplyAttributes(attributes)
    self.attributes = attributes
    local p = self.player
    if not p then return end
    local ratio = 1.0
    if p.maxLife and p.maxLife > 0 then
        ratio = math.min(1.0, math.max(0.0, p.life or 0.0) / p.maxLife)
    end
    p.maxLife = attributes.lifeMax or p.maxLife
    p.life = p.maxLife * ratio
    p.maxInnerForce = attributes.innerForceMax or p.maxInnerForce
    if p.innerForce > p.maxInnerForce then p.innerForce = p.maxInnerForce end
    p.maxQi = attributes.qiMax or p.maxQi
    if p.qi > p.maxQi then p.qi = p.maxQi end
    p.speed = (attributes.movementSpeed or M.BaseMoveSpeed)
end

-- 主循环
function M:Update(dt)
    if self.state == "searching" then
        self.searchElapsed = self.searchElapsed + dt
        self:UpdateSummons(dt)   -- 召唤物寻怪间隔跟随玩家
        if self.searchElapsed >= self.searchTime then
            if self.nextIsBoss then
                self.nextIsBoss = false
                self:SpawnBoss()
            else
                self:SpawnWave()
            end
        end
        return
    end

    if self.state == "defeated" then
        self.reviveTimer = self.reviveTimer - dt
        if self.reviveTimer <= 0.0 then
            local p = self.player
            p.life = p.maxLife
            p.innerForce = p.maxInnerForce or self.attributes.innerForceMax
            p.qi = p.maxQi or self.attributes.qiMax
            p.attackTimer = 0.0
            -- 复活后保留战场敌人进度继续战斗（挂机惯例，避免 Boss 血量被清空）
            local hasAlive = self:HasLivingEnemy()
            if hasAlive then
                local hasBoss = false
                for _, u in ipairs(self.units) do
                    if u.alive and u.kind == "boss" then hasBoss = true break end
                end
                self.state = hasBoss and "boss" or "fighting"
                self:Log("侠客恢复行动，继续战斗")
            else
                self:Log("侠客恢复行动，重新寻找敌人")
                self:StartSearch()
                self.nextIsBoss = false
            end
        end
        return
    end

    -- fighting / boss
    self.combatElapsed = self.combatElapsed + dt
    -- 辅助功法自然回复（生命/内力每秒）
    self:ApplyRegen(dt)
    -- 通用精研冷却与 buff 到期
    self:TechniqueUpdate(dt)
    self:PlayerUpdate(dt)
    for _, u in ipairs(self.units) do
        if u.alive then
            self:EnemyUpdate(u, dt)
        end
    end
    -- 召唤物行为
    self:UpdateSummons(dt)
    self:UpdatePoison(dt)
    self:UpdateFeedback(dt)
    if self.bossWarning then
        self.bossWarning.remain = math.max(0.0, self.bossWarning.remain - dt)
    end
    self:CheckWaveEnd()
end

-- 功法自然回复（每秒回复值由 attributes.lifeRegen / innerForceRegen 提供）
function M:ApplyRegen(dt)
    local a = self.attributes
    local p = self.player
    if not a or not p then return end
    local lifeRegen = a.lifeRegen or 0.0
    if lifeRegen > 0.0 and p.life < p.maxLife then
        p.life = math.min(p.maxLife, p.life + lifeRegen * dt)
    end
    local innerRegen = a.innerForceRegen or 0.0
    if innerRegen > 0.0 and p.innerForce < p.maxInnerForce then
        p.innerForce = math.min(p.maxInnerForce, p.innerForce + innerRegen * dt)
    end
end

return M
