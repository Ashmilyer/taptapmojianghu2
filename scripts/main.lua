-- ============================================================================
-- 《默江湖》挂机试炼 - 俯视空间战斗入口
-- 流程：选择地图(难度) → 寻怪(移速/位移减免) → 波次战斗(自动索敌/走位/出手)
--       → 累计击杀普通怪 100 → 首领战 → 循环
-- 装备：击杀掉落 → 背包(容量40) → 11 槽换装 → 词缀真实生效
-- 招式：外攻/内攻双槽可从 118 招式换招参战
-- 存档：完整进度自动保存（背包/穿戴/金币经验/地图/技能/击杀进度）
-- ============================================================================
local GameData = require("Data.GameData")
local SkillData = require("Data.SkillData")
local SkillBattleStats = require("Data.SkillBattleStats")
local SkillAuraData = require("Data.SkillAuraData")
local SkillRefineData = require("Data.SkillRefineData")
local LegendGearData = require("Data.LegendGearData")
local SkillSummonData = require("Data.SkillSummonData")
local EquipmentCatalog = require("Data.EquipmentCatalog")
local AffixData = require("Data.AffixData")
local MapData = require("Data.MapData")
local ProgressionData = require("Data.ProgressionData")
local SkillSpaceData = require("Data.SkillSpaceData")
local AttributeSystem = require("Systems.AttributeSystem")
local AuraSystem = require("Systems.AuraSystem")
local DamageSystem = require("Systems.DamageSystem")
local TechniqueEffects = require("Systems.TechniqueEffects")
local BattleSim = require("Systems.BattleSim")
local LootSystem = require("Systems.LootSystem")
local ItemFactory = require("Systems.ItemFactory")
local Inventory = require("Systems.Inventory")
local UI = require("urhox-libs/UI")
local BattleUI = require("UI.BattleUI")

local CONFIG = {
    Title = "默江湖 · 挂机试炼",
    MaxLogLines = 6,
    AutoSaveInterval = 60.0,
}

---@type Widget|nil
local root_ = nil
---@type table
local attributes_ = {}
---@type table|nil
local sim_ = nil
---@type string
local currentMapId_ = MapData.GetDefaultMapId()
local paused_ = false
---@type string[]
local logLines_ = {}
---@type number
local autosaveTimer_ = 0.0
local currentLibraryKind_ = "外攻招式"
---@type string|nil
local equippedSelectedKey_ = nil
local currentEquipPage_ = "equip"
local catalogCategory_ = nil    -- 当前图鉴分类（EquipmentCatalog category id）
local affixCategory_ = nil      -- 当前词缀池分类
local playerLevel_ = 1
local defeatedBosses_ = 0
local salvageMaterials_ = 0
local selectedBagUid_ = nil
local menuVisible_ = false

-- 技能槽：槽 1 = 外攻招式，槽 2 = 内攻招式
---@type table
local skillSlots_ = { GameData.Skills[1], GameData.Skills[2] }
-- 功法槽（常驻被动辅助功法）：槽 1/2，存 SkillAuraData 对象或 nil
---@type table[]
local auraSlots_ = { nil, nil }
-- 技法槽（主动增益通用技法）：槽 1/2，存 SkillData 通用技法对象或 nil
---@type table[]
local techniqueSlots_ = { nil, nil }
-- 招式总览中当前选中的目标槽（功法/技法），点击行时装入对应槽
local pendingAuraSlot_ = 1
local pendingTechniqueSlot_ = 1
-- 专属精研槽：1/2 = 外攻/内攻招式精研；3/4 = 精研一/二槽技能精研
---@type table[]
local refineEquip_ = { nil, nil, nil, nil }

-- 函数前向声明（模块内部互相调用，先声明后赋值）
local RefreshHud, ChangeMap, SaveNow, LoadSave, HandleKill
local RefreshSkillButtons, EquipSkill, EquipAura, EquipTechnique, RefreshSkillLibrary, OpenSkillLibrary, CloseSkillLibrary
local OpenMapOverlay, CloseMapOverlay, RefreshEquipmentPanel, OpenEquipment, CloseEquipment
local OpenRefinePanel, CloseRefinePanel, RefreshRefinePanel, EquipRefineSlot
local OnSlotClicked, OnBagItemClicked, AfterLoadoutChanged
local SellSelectedItem, SalvageSelectedItem, SortInventory, WearSelectedItem
local RefreshCatalogPanel, RefreshAffixPanel, RefreshLegendPanel, TryLegendItem, HandleBossDefeated, ApplyExperienceLevel

local function FormatNumber(value)
    return string.format("%.1f", value)
end

local function AddLog(message)
    table.insert(logLines_, 1, message)
    while #logLines_ > CONFIG.MaxLogLines do
        table.remove(logLines_)
    end
    if root_ then
        BattleUI.SetText(root_, "combatLog", table.concat(logLines_, "\n"))
    end
    print("[挂机战斗] " .. message)
end

-- ============================================================================
-- 招式运行时包裹：为 SkillData 招式补充战斗所需字段
--   tags（近战/远程判定）、mainAttribute（主属性加成）、baseCrit
-- ============================================================================
local function BuildEquippedSkill(original)
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = v
    end
    local stats = SkillBattleStats.Stats[copy.id]
    if stats then
        copy.damageMultiplier = stats.damageMultiplier or copy.damageMultiplier
        copy.baseInnerAttack = stats.baseInnerAttack or copy.baseInnerAttack
    end
    if not copy.tags then
        local rangeTag = "近战"
        for _, t in ipairs(copy.sourceTags or {}) do
            if t == "远程" or t == "投射物" or t == "直射" then
                rangeTag = "远程"
                break
            end
        end
        copy.tags = { copy.kind == "内攻招式" and "内攻" or "外攻", rangeTag }
    end
    if not copy.mainAttribute and copy.mainAttributes and #copy.mainAttributes > 0 then
        copy.mainAttribute = copy.mainAttributes[1]
    end
    if copy.baseCrit == nil then
        copy.baseCrit = copy.kind == "内攻招式" and 500 or 0
    end
    return copy
end

local function GetSkillById(skillId)
    if not skillId then return nil end
    local original = SkillData.ById[skillId] or SkillSummonData.ById[skillId]
    if original then return BuildEquippedSkill(original) end
    return nil
end

-- ============================================================================
-- 招式专属精研：装配的精研给对应招式提供独立伤害乘区（refineBonusPct）
-- ============================================================================
local function GetRefineSlotSkill(slotIndex)
    if slotIndex <= 2 then
        return skillSlots_[slotIndex]
    end
    local tech = techniqueSlots_[slotIndex - 2]
    return tech and (tech.skill or tech) or nil
end

local function SyncRefineBonus(slotIndex)
    local skill = GetRefineSlotSkill(slotIndex)
    local refine = refineEquip_[slotIndex]
    if skill then
        if refine and refine.refineTargetId == skill.id then
            skill.refineBonusPct = (refine.bonus or 0.0) / 100.0
        else
            skill.refineBonusPct = nil
        end
    end
end

-- ============================================================================
-- 属性 / 地图 / 模拟器
-- ============================================================================
local function RefreshAttributes()
    -- 功法常驻加成并入属性（默认 L1；功法等级为后续升级预留）
    local auraAddon = AuraSystem.Aggregate(auraSlots_, 1)
    local equipment = GameData.Character.levelBonus or {}
    local levelBonus = ProgressionData.GetLevelBonuses(playerLevel_)
    GameData.Character.levelBonus = levelBonus
    attributes_ = AttributeSystem.Build(GameData.Character, GameData.Loadout, auraAddon)
end

local function GetMap()
    return MapData.FindById(currentMapId_)
end

-- 把技法槽（通用技法主动技能）组装为 sim 技法槽位（每槽独立冷却）
local function RebuildSimTechniqueSlots()
    if not sim_ then return end
    sim_.techniqueSlots = {}
    for _, tech in ipairs(techniqueSlots_) do
        if tech then
            sim_.techniqueSlots[#sim_.techniqueSlots + 1] = { skill = tech, timer = 0.0 }
        end
    end
end

local function CreateSim()
    local map = GetMap()
    if not map then
        print("[挂机战斗] 地图不存在: " .. currentMapId_)
        return nil
    end
    local sim = BattleSim.Create(map, attributes_, skillSlots_, SkillSpaceData.Space)
    sim.auraAddon = AuraSystem.Aggregate(auraSlots_, 1)
    sim.logSink = function(msg) AddLog(msg) end
    sim.onKill = function(unit) HandleKill(unit) end
    sim.onBossDefeated = function(unit, reward) HandleBossDefeated(unit, reward) end
    RebuildSimTechniqueSlots()
    return sim
end

AfterLoadoutChanged = function()
    RefreshAttributes()
    if sim_ then
        sim_:ApplyAttributes(attributes_)
    end
    RefreshHud()
end

ChangeMap = function(mapId)
    SaveNow()
    currentMapId_ = mapId
    sim_ = CreateSim()
    if sim_ and root_ then
        local map = GetMap()
        BattleUI.SetText(root_, "mapLabel", map.name)
        RefreshHud()
    end
end

-- ============================================================================
-- 物品描述
-- ============================================================================
local function ItemBaseSummary(item)
    local lines = {}
    if item.outerPointDamage then
        for dt, range in pairs(item.outerPointDamage) do
            table.insert(lines, string.format("%s %s-%s 点伤", dt, range.min, range.max))
        end
    end
    if item.innerAdditionalPointDamage then
        for dt, range in pairs(item.innerAdditionalPointDamage) do
            table.insert(lines, string.format("%s %s-%s 法术附加", dt, range.min, range.max))
        end
    end
    local statNames = {
        armor = "护甲", dodgeValue = "闪避", qi = "真气", innerForce = "内力",
        life = "生命", rootBone = "根骨", dexterity = "灵巧", vitality = "元气",
        yangResistance = "阳性抗", yinResistance = "阴性抗", hunyuanResistance = "混元抗", toxinResistance = "毒素抗",
    }
    for stat, range in pairs(item.base or {}) do
        local name = statNames[stat] or stat
        if range.min == range.max then
            table.insert(lines, string.format("%s +%s", name, range.min))
        else
            table.insert(lines, string.format("%s +%s-%s", name, range.min, range.max))
        end
    end
    if item.baseAttackSpeed then table.insert(lines, "攻速 " .. item.baseAttackSpeed) end
    if item.baseCritValue then table.insert(lines, "暴击值 " .. item.baseCritValue) end
    for _, text in ipairs(item.affixTexts or {}) do
        table.insert(lines, "◆ " .. text)
    end
    return table.concat(lines, "\n")
end

local function FormatItemDetail(item)
    if not item then return "请选择一件背包装备。" end
    local compare = ""
    local equippedKey = Inventory.ResolveSlotKey(item)
    local equipped = equippedKey and GameData.Loadout[equippedKey] or nil
    if equipped then
        compare = "\n当前槽位：" .. equipped.name .. "\n替换后将自动放回背包。"
    end
    return item.name .. "（" .. (item.sourceName or item.name) .. "）\n"
        .. "类别：" .. (item.slot or "?") .. " · 需求等级 " .. (item.requiredLevel or 1) .. "\n"
        .. ItemBaseSummary(item) .. compare
end

local function FormatItemShort(item)
    if not item then return "" end
    local parts = { "需求等级" .. (item.requiredLevel or 1), item.slot or "?" }
    if #(item.affixTexts or {}) > 0 then
        table.insert(parts, #item.affixTexts .. " 词缀")
    end
    return table.concat(parts, " · ")
end

-- ============================================================================
-- 击杀掉落
-- ============================================================================
HandleKill = function(unit)
    if not sim_ then return end
    local drops
    if unit.kind == "boss" then
        drops = LootSystem.RollBossDrops(sim_.map)
        local legend = LootSystem.RollBossLegend(sim_.map)
        if legend then
            drops[#drops + 1] = legend
            AddLog("传奇装备掉落：「" .. legend.name .. "」")
        end
    else
        local item = LootSystem.RollNormalDrop(sim_.map)
        if item then drops = { item } end
    end
    if not drops then return end
    for _, item in ipairs(drops) do
        if Inventory.Add(item) then
            selectedBagUid_ = item.uid
            AddLog("掉落装备：" .. item.name .. "（" .. FormatItemShort(item) .. "）")
        else
            AddLog("背包已满，" .. item.name .. " 未能拾取")
        end
    end
    if root_ and BattleUI.IsVisible(root_, "equipOverlay") then
        RefreshEquipmentPanel()
    end
    ApplyExperienceLevel()
end

-- ============================================================================
-- 存档
-- ============================================================================
SaveNow = function()
    if not sim_ then
        Inventory.Save(nil)
        return
    end
    Inventory.Save({
        mapId = currentMapId_,
        gold = sim_.gold,
        experience = sim_.experience,
        killCount = sim_.killCount,
        totalKills = sim_.totalKills,
        wave = sim_.wave,
        skillOuterId = skillSlots_[1] and skillSlots_[1].id,
        skillInnerId = skillSlots_[2] and skillSlots_[2].id,
        auraSlot1Id = auraSlots_[1] and auraSlots_[1].id or nil,
        auraSlot2Id = auraSlots_[2] and auraSlots_[2].id or nil,
        techniqueSlot1Id = techniqueSlots_[1] and techniqueSlots_[1].id or nil,
        techniqueSlot2Id = techniqueSlots_[2] and techniqueSlots_[2].id or nil,
        refineOuterId = refineEquip_[1] and refineEquip_[1].id or nil,
        refineInnerId = refineEquip_[2] and refineEquip_[2].id or nil,
        refineT1Id = refineEquip_[3] and refineEquip_[3].id or nil,
        refineT2Id = refineEquip_[4] and refineEquip_[4].id or nil,
        playerLevel = playerLevel_,
        defeatedBosses = defeatedBosses_,
        salvageMaterials = salvageMaterials_,
    })
end

LoadSave = function()
    local state = Inventory.Load()
    if not state then return nil end
    if state.mapId and MapData.FindById(state.mapId) and MapData.IsUnlocked(state.mapId, state.defeatedBosses or 0) then
        currentMapId_ = state.mapId
    end
    playerLevel_ = math.max(1, math.min(ProgressionData.MaxLevel, state.playerLevel or ProgressionData.GetLevel(state.experience or 0)))
    defeatedBosses_ = state.defeatedBosses or 0
    salvageMaterials_ = state.salvageMaterials or 0
    local outer = GetSkillById(state.skillOuterId)
    local inner = GetSkillById(state.skillInnerId)
    if outer and outer.kind == "外攻招式" then skillSlots_[1] = outer end
    if inner and inner.kind == "内攻招式" then skillSlots_[2] = inner end
    -- 功法槽（辅助功法，SkillAuraData.ById）
    local aura1 = SkillAuraData.ById[state.auraSlot1Id]
    local aura2 = SkillAuraData.ById[state.auraSlot2Id]
    if aura1 then auraSlots_[1] = aura1 end
    if aura2 then auraSlots_[2] = aura2 end
    -- 技法槽（通用精研，SkillData.ById）
    local tech1 = GetSkillById(state.techniqueSlot1Id)
    local tech2 = GetSkillById(state.techniqueSlot2Id)
    if tech1 and tech1.kind == "通用精研" then techniqueSlots_[1] = tech1 end
    if tech2 and tech2.kind == "通用精研" then techniqueSlots_[2] = tech2 end
    -- 招式专属精研槽（须匹配当前槽招式）
    local refine1 = SkillRefineData.ById[state.refineOuterId]
    local refine2 = SkillRefineData.ById[state.refineInnerId]
    if refine1 and skillSlots_[1] and refine1.refineTargetId == skillSlots_[1].id then
        refineEquip_[1] = refine1
    end
    if refine2 and skillSlots_[2] and refine2.refineTargetId == skillSlots_[2].id then
        refineEquip_[2] = refine2
    end
    -- 精研一/二槽技法的专属精研
    local t1 = SkillRefineData.ById[state.refineT1Id]
    local t2 = SkillRefineData.ById[state.refineT2Id]
    local techS1 = techniqueSlots_[1] and (techniqueSlots_[1].skill or techniqueSlots_[1])
    local techS2 = techniqueSlots_[2] and (techniqueSlots_[2].skill or techniqueSlots_[2])
    if t1 and techS1 and t1.refineTargetId == techS1.id then
        refineEquip_[3] = t1
    end
    if t2 and techS2 and t2.refineTargetId == techS2.id then
        refineEquip_[4] = t2
    end
    for i = 1, 4 do SyncRefineBonus(i) end
    return state
end

-- ============================================================================
-- HUD 刷新
-- ============================================================================
local function CollectFieldUnits()
    local units = {}
    if not sim_ then return units end
    local p = sim_.player
    table.insert(units, {
        kind = "player", name = p.name, x = p.x, y = p.y,
        radius = p.radius, life = p.life, maxLife = p.maxLife, scale = 1.0,
    })
    -- 召唤物（友方单位，绘制为青绿色调）
    for _, s in ipairs(sim_.summons or {}) do
        if s.alive then
            table.insert(units, {
                kind = "summon", name = s.name, x = s.x, y = s.y,
                radius = s.radius, life = s.life, maxLife = s.maxLife, scale = s.scale or 0.85,
            })
        end
    end
    for _, u in ipairs(sim_.units) do
        if u.alive then
            table.insert(units, {
                kind = u.kind, name = u.name, x = u.x, y = u.y,
                radius = u.radius, life = u.life, maxLife = u.maxLife, scale = u.scale or 1.0,
            })
        end
    end
    return units
end

local function StateText()
    if not sim_ then return "未开始" end
    if sim_.state == "searching" then return "寻怪中" end
    if sim_.state == "fighting" then return "战斗中" end
    if sim_.state == "boss" then return "首领战" end
    if sim_.state == "defeated" then return "侠客倒地" end
    return "未知"
end

RefreshHud = function()
    if not root_ or not sim_ then return end
    local p = sim_.player
    local map = GetMap()

    BattleUI.SetText(root_, "stageLabel", StateText() .. " · 波次 " .. math.max(0, sim_.wave - 1))
    BattleUI.SetText(root_, "killLabel", "击杀 " .. sim_.killCount .. "/" .. (map.bossKillTarget or 100))
    BattleUI.SetText(root_, "goldLabel", "金币 " .. sim_.gold)
    local level, currentExp, nextExp, progress = ProgressionData.GetProgress(sim_.experience)
    BattleUI.SetText(root_, "levelLabel", "等级 " .. level)
    BattleUI.SetBar(root_, "experienceBar", progress, 1)
    BattleUI.SetText(root_, "experienceLabel", level >= ProgressionData.MaxLevel and "经验已满" or ("经验 " .. sim_.experience .. " / " .. nextExp))
    BattleUI.SetText(root_, "stageLabel", StateText() .. " · 波次 " .. math.max(0, sim_.wave - 1) .. " · 推荐等级 " .. (map.enemy.level or 1))

    local stateExtra = ""
    if sim_.state == "searching" then
        stateExtra = "剩余 " .. FormatNumber(math.max(0.0, sim_.searchTime - sim_.searchElapsed)) .. " 秒"
    elseif sim_.state == "defeated" then
        stateExtra = FormatNumber(math.max(0.0, sim_.reviveTimer)) .. " 秒后复活"
    else
        local nearest = sim_:NearestEnemy()
        if nearest then
            stateExtra = "目标 " .. nearest.name .. " " .. FormatNumber(math.max(0.0, nearest.life)) .. "/" .. FormatNumber(nearest.maxLife)
        end
    end
    BattleUI.SetText(root_, "battleStateLabel", StateText() .. " · " .. stateExtra)

    if sim_.state == "searching" then
        BattleUI.SetBar(root_, "searchBar", math.min(sim_.searchElapsed, sim_.searchTime), sim_.searchTime)
    else
        BattleUI.SetBar(root_, "searchBar", 1, 1)
    end
    BattleUI.SetText(root_, "searchLabel", sim_.state == "searching" and FormatNumber(sim_.searchTime) .. "s" or "")

    BattleUI.SetBar(root_, "lifeBar", math.max(0.0, p.life), p.maxLife)
    BattleUI.SetText(root_, "lifeLabel", FormatNumber(p.life) .. "/" .. FormatNumber(p.maxLife))
    BattleUI.SetBar(root_, "innerForceBar", math.max(0.0, p.innerForce), attributes_.innerForceMax)
    BattleUI.SetText(root_, "innerForceLabel", FormatNumber(p.innerForce) .. "/" .. FormatNumber(attributes_.innerForceMax))
    BattleUI.SetBar(root_, "qiBar", math.max(0.0, p.qi), attributes_.qiMax)
    BattleUI.SetText(root_, "qiLabel", FormatNumber(p.qi) .. "/" .. FormatNumber(attributes_.qiMax))

    local field = root_:FindById("battlefield")
    if field then
        local layout = field:GetLayout()
    local fieldRect = { x = 0, y = 0, w = layout.w, h = layout.h }
        BattleUI.UpdateField(root_, CollectFieldUnits(), fieldRect, BattleSim.WorldWidth, BattleSim.WorldHeight)
        BattleUI.UpdateFeedback(root_, sim_.GetFeedback and sim_:GetFeedback() or {}, fieldRect, BattleSim.WorldWidth, BattleSim.WorldHeight)
        BattleUI.UpdateBossWarning(root_, sim_.bossWarning, fieldRect, BattleSim.WorldWidth, BattleSim.WorldHeight)
    end
end

-- ============================================================================
-- 招式总览（可选取换招）
-- ============================================================================
-- UTF-8 安全截断：maxBytes 处不切断多字节序列
local function TruncateUtf8(s, maxBytes)
    if #s <= maxBytes then return s end
    local t = string.sub(s, 1, maxBytes)
    -- 结尾若是不完整多字节序列，回退到完整字符边界
    for i = #t, math.max(1, #t - 3), -1 do
        local b = string.byte(t, i)
        if b < 0x80 then
            -- ASCII 收尾：安全
            return string.sub(t, 1, i) .. "…"
        end
        if b >= 0xC0 then
            -- 找到多字节引导字节，检查该字符是否完整（需 need 字节）
            local need = b >= 0xF0 and 4 or (b >= 0xE0 and 3 or 2)
            local have = #t - i + 1
            if have >= need then
                return string.sub(t, 1, i + need - 1) .. "…"
            end
            return string.sub(t, 1, i - 1) .. "…"
        end
    end
    return "…"
end

local function FormatSkillLine(skill)
    local parts = { skill.name }
    if skill.kind == "通用精研" then
        -- 技法行：supportType + 描述摘要（效果取手工映射表中的文案基准）
        if skill.supportType then table.insert(parts, "[" .. skill.supportType .. "]") end
        if skill.castTime and skill.castTime > 0 then table.insert(parts, "施放 " .. skill.castTime .. "s") end
        if skill.description then
            local desc = string.gsub(skill.description, "[\r\n]+", " ")
            table.insert(parts, TruncateUtf8(desc, 60))
        end
        return table.concat(parts, " · ")
    end
    local stats = SkillBattleStats.Stats[skill.id]
    if stats and stats.damageMultiplier then
        table.insert(parts, "伤害倍率 " .. string.format("%.0f%%", stats.damageMultiplier * 100))
    elseif stats and stats.baseInnerAttack then
        table.insert(parts, "点伤 " .. string.format("%g", stats.baseInnerAttack))
    end
    if skill.damageType then table.insert(parts, skill.damageType) end
    if skill.cost and skill.cost > 0 then table.insert(parts, "内力" .. skill.cost) end
    local sp = SkillSpaceData.Space[skill.id]
    if sp then table.insert(parts, "[" .. sp.shape .. " r" .. sp.range .. "]") end
    return table.concat(parts, " · ")
end

local function ClearChildren(panel)
    while #panel.children > 0 do
        panel:RemoveChild(panel.children[1])
    end
end

local function IsEquippedSkill(skill)
    if not skill then return false end
    return (skillSlots_[1] and skillSlots_[1].id == skill.id)
        or (skillSlots_[2] and skillSlots_[2].id == skill.id)
        or (techniqueSlots_[1] and techniqueSlots_[1].id == skill.id)
        or (techniqueSlots_[2] and techniqueSlots_[2].id == skill.id)
end

local function IsEquippedAura(aura)
    if not aura then return false end
    return (auraSlots_[1] and auraSlots_[1].id == aura.id)
        or (auraSlots_[2] and auraSlots_[2].id == aura.id)
end

EquipSkill = function(skill)
    if not skill then return end
    local slotIndex
    if skill.kind == "外攻招式" then
        slotIndex = 1
    elseif skill.kind == "内攻招式" then
        slotIndex = 2
    else
        AddLog("外攻/内攻槽位只能装配战斗招式：" .. skill.name)
        return
    end
    -- 更换招式后，原招式专属精研不再匹配 → 清空
    if refineEquip_[slotIndex] then
        AddLog("已卸下原招式专属精研「" .. refineEquip_[slotIndex].name .. "」")
        refineEquip_[slotIndex] = nil
    end
    skillSlots_[slotIndex] = BuildEquippedSkill(skill)
    SyncRefineBonus(slotIndex)
    if sim_ then
        sim_.skills = skillSlots_
        sim_.skillIndex = slotIndex
    end
    AddLog("已装备" .. (slotIndex == 1 and "外攻招式：" or "内攻招式：") .. skill.name)
    RefreshSkillButtons()
    CloseSkillLibrary()
end

-- 功法槽位（常驻被动）
EquipAura = function(aura)
    if not aura then return end
    auraSlots_[pendingAuraSlot_] = aura
    RefreshAttributes()
    if sim_ then
        sim_.auraAddon = AuraSystem.Aggregate(auraSlots_, 1)
        sim_:ApplyAttributes(attributes_)
    end
    AddLog("已装备功法" .. (pendingAuraSlot_ == 1 and "一" or "二") .. "：「" .. aura.name .. "」（常驻被动）")
    RefreshSkillButtons()
    CloseSkillLibrary()
end

-- 技法槽位（主动增益，战斗中按冷却自动释放）
EquipTechnique = function(skill)
    if not skill or skill.kind ~= "通用精研" then return end
    techniqueSlots_[pendingTechniqueSlot_] = skill
    RebuildSimTechniqueSlots()
    -- 更换技能后原技法专属精研可能不匹配 → 清理并同步
    local refineSlot = 2 + pendingTechniqueSlot_
    if refineEquip_[refineSlot] and refineEquip_[refineSlot].refineTargetId ~= skill.id then
        refineEquip_[refineSlot] = nil
    end
    SyncRefineBonus(refineSlot)
    if TechniqueEffects.HasEffect(skill.id) then
        AddLog("已装备精研" .. (pendingTechniqueSlot_ == 1 and "一" or "二") .. "：「" .. skill.name .. "」战斗中自动释放")
    else
        AddLog("已装备精研" .. (pendingTechniqueSlot_ == 1 and "一" or "二") .. "：「" .. skill.name .. "」效果暂未接入原型，暂不参战")
    end
    RefreshSkillButtons()
    CloseSkillLibrary()
end

RefreshSkillButtons = function()
    if not root_ then return end
    local outerBtn = root_:FindById("outerSkillButton")
    local innerBtn = root_:FindById("innerSkillButton")
    if outerBtn then outerBtn:SetText("外攻 · " .. (skillSlots_[1] and skillSlots_[1].name or "—")) end
    if innerBtn then innerBtn:SetText("内攻 · " .. (skillSlots_[2] and skillSlots_[2].name or "—")) end
    local a1 = root_:FindById("auraSlot1Button")
    local a2 = root_:FindById("auraSlot2Button")
    if a1 then a1:SetText("功法一 · " .. (auraSlots_[1] and auraSlots_[1].name or "空")) end
    if a2 then a2:SetText("功法二 · " .. (auraSlots_[2] and auraSlots_[2].name or "空")) end
    local t1 = root_:FindById("techniqueSlot1Button")
    local t2 = root_:FindById("techniqueSlot2Button")
    if t1 then t1:SetText("精研一 · " .. (techniqueSlots_[1] and techniqueSlots_[1].name or "空")) end
    if t2 then t2:SetText("精研二 · " .. (techniqueSlots_[2] and techniqueSlots_[2].name or "空")) end
end

-- 功法/技法行文本
local function FormatAuraLine(aura)
    local parts = { aura.name, "每级：" }
    local statNames = {
        meleeDamage = "近战伤", physicalDamage = "物理伤", elementalDamage = "元素伤",
        toxinDamage = "毒素伤", skillDamage = "技伤", dotDamage = "持续伤",
        critValuePct = "暴击值", moveSpeedPct = "移速", armorFlat = "护甲", armorPct = "护甲%",
        dodgeFlat = "闪避值", dodgePct = "闪避%", qiFlat = "真气", qiPct = "真气%",
        lifeRegen = "生命回复/秒", innerForceRegen = "内力回复/秒", lifeFlat = "生命",
        yangRes = "阳抗", yinRes = "阴抗", hunyuanRes = "混元抗", toxinRes = "毒抗",
    }
    local statParts = {}
    for _, st in ipairs(aura.stats or {}) do
        local nm = statNames[st.stat] or st.stat
        local suffix = st.kind == "%" and "%" or ""
        table.insert(statParts, nm .. "+" .. string.format("%g", st.value) .. suffix)
    end
    if #statParts > 0 then table.insert(parts, table.concat(statParts, " ")) end
    if aura.manaSeal then table.insert(parts, "内力占用 " .. aura.manaSeal) end
    return table.concat(parts, " · ")
end

RefreshSkillLibrary = function(kind)
    currentLibraryKind_ = kind or currentLibraryKind_
    if not root_ then return end
    local list
    local title
    if currentLibraryKind_ == "外攻招式" then
        list = SkillData.OuterSkills
        title = "招式总览 · 外攻招式（点击替换外攻槽）"
    elseif currentLibraryKind_ == "内攻招式" then
        list = SkillData.InnerSkills
        title = "招式总览 · 内攻招式（点击替换内攻槽）"
    elseif currentLibraryKind_ == "通用精研" then
        -- TLIDB 通用精研 + 本地召唤/智械/贯注模板
        local merged = {}
        for _, skill in ipairs(SkillData.GeneralSkills) do
            merged[#merged + 1] = skill
        end
        for _, skill in ipairs(SkillSummonData.SummonSkills) do
            merged[#merged + 1] = skill
        end
        list = merged
        title = "通用精研（主动增益/召唤/贯注，战斗自动生效）· 点击装配到精研一/二"
    else
        list = SkillAuraData.AuraSkills
        title = "辅助功法（常驻被动）· 点击装配到功法一/二"
    end
    BattleUI.SetText(root_, "skillLibraryTitle", title)
    BattleUI.SetText(root_, "libraryOuterHint", "外攻：" .. (skillSlots_[1] and skillSlots_[1].name or "—"))
    BattleUI.SetText(root_, "libraryInnerHint", "内攻：" .. (skillSlots_[2] and skillSlots_[2].name or "—"))
    BattleUI.SetText(root_, "libraryAuraHint", "功法：" .. (auraSlots_[1] and auraSlots_[1].name or "—") .. " / " .. (auraSlots_[2] and auraSlots_[2].name or "—"))
    BattleUI.SetText(root_, "libraryTechniqueHint", "技法：" .. (techniqueSlots_[1] and techniqueSlots_[1].name or "—") .. " / " .. (techniqueSlots_[2] and techniqueSlots_[2].name or "—"))

    local listPanel = root_:FindById("skillLibraryList")
    if not listPanel then return end
    ClearChildren(listPanel)
    if currentLibraryKind_ == "辅助功法" then
        for _, aura in ipairs(list) do
            local equipped = IsEquippedAura(aura)
            listPanel:AddChild(UI.Button {
                id = "skillRow_" .. aura.id,
                text = FormatAuraLine(aura),
                variant = equipped and "primary" or "secondary",
                height = 30,
                width = "100%",
                fontSize = 12,
                paddingHorizontal = 8,
                onClick = function() EquipAura(aura) end,
            })
        end
        return
    end
    for _, skill in ipairs(list) do
        local isCombat = skill.kind == "外攻招式" or skill.kind == "内攻招式"
        local isTechnique = skill.kind == "通用精研"
        local mapped = not isTechnique or TechniqueEffects.HasEffect(skill.id)
        local equipped = IsEquippedSkill(skill)
        local text = FormatSkillLine(skill)
        if isTechnique and not mapped then text = text .. "（未接入原型）" end
        listPanel:AddChild(UI.Button {
            id = "skillRow_" .. skill.id,
            text = text,
            variant = equipped and "primary" or (isCombat and "secondary" or (mapped and "secondary" or "danger")),
            height = 30,
            width = "100%",
            fontSize = 12,
            paddingHorizontal = 8,
            onClick = function()
                if isCombat then
                    EquipSkill(skill)
                elseif isTechnique then
                    EquipTechnique(skill)
                end
            end,
        })
    end
end

OpenSkillLibrary = function(kind, slotHint)
    if not root_ then return end
    if kind == "辅助功法" and slotHint then
        pendingAuraSlot_ = slotHint
    elseif kind == "通用精研" and slotHint then
        pendingTechniqueSlot_ = slotHint
    end
    RefreshSkillLibrary(kind)
    BattleUI.SetVisible(root_, "skillLibraryOverlay", true)
end

CloseSkillLibrary = function()
    if root_ then BattleUI.SetVisible(root_, "skillLibraryOverlay", false) end
end

-- ============================================================================
-- 招式专属精研装配浮层（挂在对应招式下）
-- ============================================================================
local function FormatRefineLine(refine)
    -- 取变体机制句（跳过「只能安装在…第N辅助槽」的基底说明）
    local variantText = ""
    for _, d in ipairs(refine.details or {}) do
        if not d:find("只能安装在") and #d > 0 then
            variantText = d
            break
        end
    end
    local parts = { refine.name, "（" .. refine.rarity .. "）" }
    table.insert(parts, "强化伤害 +" .. string.format("%g", refine.bonus or 0) .. "%")
    if variantText and #variantText > 0 then
        table.insert(parts, TruncateUtf8(variantText, 44))
    end
    return table.concat(parts, " · ")
end

-- 装备/卸下某槽技能上的专属精研
EquipRefineSlot = function(slotIndex, refine)
    local skill = GetRefineSlotSkill(slotIndex)
    if not skill then
        AddLog("该槽位未装配技能，请先装配招式或精研")
        return
    end
    if refine.refineTargetId and refine.refineTargetId ~= skill.id then
        AddLog("该精研为其他招式的专属精研：" .. refine.name)
        return
    end
    if refineEquip_[slotIndex] and refineEquip_[slotIndex].id == refine.id then
        refineEquip_[slotIndex] = nil
        AddLog("已卸下「" .. skill.name .. "」专属精研")
    else
        refineEquip_[slotIndex] = refine
        AddLog("已装备「" .. skill.name .. "」专属精研：「" .. refine.name .. "」（"
            .. refine.rarity .. "）强化伤害 +" .. string.format("%g", refine.bonus) .. "%")
    end
    SyncRefineBonus(slotIndex)
    RefreshRefinePanel()
end

local function RefineSlotLabel(slotIndex)
    if slotIndex == 1 then return "外攻 · " end
    if slotIndex == 2 then return "内攻 · " end
    if slotIndex == 3 then return "精研一 · " end
    return "精研二 · "
end

RefreshRefinePanel = function()
    if not root_ then return end
    local function fillColumn(slotIndex)
        local idPrefix = slotIndex == 1 and "refineOuter" or slotIndex == 2 and "refineInner"
            or slotIndex == 3 and "refineTech1" or "refineTech2"
        BattleUI.SetText(root_, idPrefix .. "Title",
            RefineSlotLabel(slotIndex) .. (GetRefineSlotSkill(slotIndex) and GetRefineSlotSkill(slotIndex).name or "—"))
        local listPanel = root_:FindById(idPrefix .. "List")
        if not listPanel then return end
        ClearChildren(listPanel)
        local skill = GetRefineSlotSkill(slotIndex)
        if not skill then
            listPanel:AddChild(UI.Label { text = "该槽位未装配技能", fontSize = 11, fontColor = { 157, 177, 193, 255 } })
            return
        end
        local refines = SkillRefineData.RefinesByTarget[skill.id]
        if not refines or #refines == 0 then
            listPanel:AddChild(UI.Label { text = "该技能暂无对应专属精研", fontSize = 11, fontColor = { 157, 177, 193, 255 } })
            return
        end
        local cur = refineEquip_[slotIndex]
        for _, r in ipairs(refines) do
            local equipped = cur and cur.id == r.id
            listPanel:AddChild(UI.Button {
                id = idPrefix .. "Row_" .. r.id,
                text = FormatRefineLine(r),
                variant = equipped and "primary" or "secondary",
                height = 34,
                width = "100%",
                fontSize = 11,
                paddingHorizontal = 6,
                onClick = function() EquipRefineSlot(slotIndex, r) end,
            })
        end
    end
    fillColumn(1)
    fillColumn(2)
    fillColumn(3)
    fillColumn(4)
end

OpenRefinePanel = function()
    if not root_ then return end
    RefreshRefinePanel()
    BattleUI.SetVisible(root_, "refineOverlay", true)
end

CloseRefinePanel = function()
    if root_ then BattleUI.SetVisible(root_, "refineOverlay", false) end
end

-- ============================================================================
-- 地图选择
-- ============================================================================
local function RefreshMapList()
    if not root_ then return end
    local listPanel = root_:FindById("mapList")
    if not listPanel then return end
    ClearChildren(listPanel)
    for _, map in ipairs(MapData.Maps) do
        local mapId = map.id
        local unlocked = MapData.IsUnlocked(mapId, defeatedBosses_)
        listPanel:AddChild(UI.Button {
            id = "mapItem_" .. mapId,
            text = (unlocked and "[已解锁] " or "[未解锁] ") .. map.name .. "  推荐等级 " .. (map.enemy.level or 1) .. "  难度 x" .. string.format("%.1f", map.difficulty or 1.0) .. "\n" .. (unlocked and map.description or ("击败 " .. map.unlockBosses .. " 次首领后解锁")),
            variant = currentMapId_ == mapId and "primary" or (unlocked and "secondary" or "danger"),
            disabled = not unlocked,
            height = 58,
            width = "100%",
            fontSize = 11,
            whiteSpace = "normal",
            onClick = function()
                if not unlocked then return end
                ChangeMap(mapId)
                CloseMapOverlay()
            end,
        })
    end
end

OpenMapOverlay = function()
    if not root_ then return end
    RefreshMapList()
    BattleUI.SetVisible(root_, "mapOverlay", true)
end

CloseMapOverlay = function()
    if root_ then BattleUI.SetVisible(root_, "mapOverlay", false) end
end

-- ============================================================================
-- 装备与背包浮层
-- ============================================================================
local function SlotDisplayNameForKey(key)
    local names = {
        outerWeapon = "外攻武器", innerWeapon = "内攻武器", offHand = "副手",
        head = "头部", chest = "胸甲", gloves = "手部", boots = "足部",
        belt = "腰部", necklace = "项链", ring1 = "戒指一", ring2 = "戒指二",
    }
    return names[key] or key
end

RefreshEquipmentPanel = function()
    if not root_ then return end
    local slotsPanel = root_:FindById("equipSlots")
    local bagPanel = root_:FindById("equipBagList")
    if not slotsPanel or not bagPanel then return end

    ClearChildren(slotsPanel)
    for _, key in ipairs(Inventory.LoadoutKeys) do
        local item = GameData.Loadout[key]
        slotsPanel:AddChild(BattleUI.MakeEquipmentSlot(
            key,
            item,
            equippedSelectedKey_ == key,
            OnSlotClicked
        ))
    end

    ClearChildren(bagPanel)
    BattleUI.SetText(root_, "equipBagTitle", "背包 " .. Inventory.Count() .. "/" .. Inventory.Capacity)
    BattleUI.SetText(root_, "equipMaterialLabel", "材料 " .. salvageMaterials_)
    for index = 1, Inventory.Capacity do
        bagPanel:AddChild(BattleUI.MakeBagSlot(index, Inventory.bag[index], OnBagItemClicked))
    end

    local selectedItem = equippedSelectedKey_ and GameData.Loadout[equippedSelectedKey_] or nil
    if selectedItem then
        BattleUI.SetText(root_, "equipDetailText", "【" .. SlotDisplayNameForKey(equippedSelectedKey_) .. "】已穿戴\n" .. FormatItemDetail(selectedItem))
    end
end

OnSlotClicked = function(key)
    local item = GameData.Loadout[key]
    if not item then
        equippedSelectedKey_ = key
        BattleUI.SetText(root_, "equipDetailText", "该槽位为空。点击右侧背包装备穿戴。")
        RefreshEquipmentPanel()
        return
    end
    if Inventory.IsFull() then
        AddLog("背包已满，无法卸下 " .. item.name)
        return
    end
    Inventory.UnequipSlot(key)
    AddLog("已卸下 " .. item.name)
    equippedSelectedKey_ = key
    AfterLoadoutChanged()
    RefreshEquipmentPanel()
end

OnBagItemClicked = function(item)
    if not item then return end
    selectedBagUid_ = item.uid
    BattleUI.SetText(root_, "equipDetailText", FormatItemDetail(item))
    RefreshEquipmentPanel()
end

SellSelectedItem = function()
    if not selectedBagUid_ then AddLog("请先选择一件普通装备") return end
    local index, item = Inventory.FindByUid(selectedBagUid_)
    if not index or not item then AddLog("选中的装备已不存在") return end
    local value = LootSystem.GetSellValue(item)
    if value <= 0 then AddLog("传奇装备受保护，不可出售") return end
    Inventory.RemoveAt(index)
    sim_.gold = sim_.gold + value
    AddLog("已出售「" .. item.name .. "」，获得金币 " .. value)
    selectedBagUid_ = nil
    RefreshEquipmentPanel()
end

SalvageSelectedItem = function()
    if not selectedBagUid_ then AddLog("请先选择一件普通装备") return end
    local index, item = Inventory.FindByUid(selectedBagUid_)
    if not index or not item then AddLog("选中的装备已不存在") return end
    local value = LootSystem.GetSalvageValue(item)
    if value <= 0 then AddLog("传奇装备受保护，不可分解") return end
    Inventory.RemoveAt(index)
    salvageMaterials_ = salvageMaterials_ + value
    AddLog("已分解「" .. item.name .. "」，获得材料 " .. value)
    selectedBagUid_ = nil
    RefreshEquipmentPanel()
end

SortInventory = function()
    Inventory.SortBag()
    AddLog("背包已按品质与等级整理")
    RefreshEquipmentPanel()
end

WearSelectedItem = function()
    local selectedItem = selectedBagUid_ and (function()
        local _, item = Inventory.FindByUid(selectedBagUid_)
        return item
    end)()
    if selectedItem then
        local ok, swapped = Inventory.EquipFromBag(selectedItem.uid)
        if ok then
            equippedSelectedKey_ = Inventory.ResolveSlotKey(selectedItem)
            AddLog(swapped and ("换下 " .. swapped.name .. "，穿戴 " .. selectedItem.name) or ("穿戴 " .. selectedItem.name))
            selectedBagUid_ = nil
            AfterLoadoutChanged()
        end
    else
        AddLog("请先选择一件背包装备")
    end
    RefreshEquipmentPanel()
end

OpenEquipment = function()
    if not root_ then return end
    equippedSelectedKey_ = nil
    currentEquipPage_ = "equip"
    RefreshEquipmentPanel()
    RefreshCatalogPanel()
    RefreshAffixPanel()
    BattleUI.ShowEquipmentPage(root_, currentEquipPage_)
    BattleUI.SetVisible(root_, "equipOverlay", true)
end

CloseEquipment = function()
    if root_ then BattleUI.SetVisible(root_, "equipOverlay", false) end
end

-- 装备浮层页签切换回调
local function SwitchEquipmentPage(page)
    currentEquipPage_ = page
    if page == "catalog" then
        RefreshCatalogPanel()
    elseif page == "affix" then
        RefreshAffixPanel()
    elseif page == "legend" then
        RefreshLegendPanel()
    end
    BattleUI.ShowEquipmentPage(root_, page)
end

-- ============================================================================
-- 底材图鉴页（652 全量浏览）
-- ============================================================================
local function SortedCatalogCategories()
    local cats = {}
    for cat in pairs(EquipmentCatalog.Categories) do
        table.insert(cats, cat)
    end
    table.sort(cats)
    return cats
end

-- 分类显示名（wuxia + source 类型）
local function CatalogCatLabel(cat)
    local meta = EquipmentCatalog.Categories[cat]
    if not meta then return cat end
    return meta.name .. " → " .. meta.wuxia .. "（" .. meta.slot .. "）"
end

local function FormatCatalogDetail(catalogItem)
    local lines = {}
    table.insert(lines, catalogItem.name .. "（" .. (catalogItem.sourceName or catalogItem.name) .. "）")
    table.insert(lines, "类别：" .. CatalogCatLabel(catalogItem.category) .. " · 需求等级 " .. (catalogItem.requiredLevel or 1))
    if catalogItem.hand and catalogItem.hand ~= "" then
        table.insert(lines, "持握：" .. catalogItem.hand)
    end
    table.insert(lines, "基础词缀：")
    local baseAffixes = catalogItem.baseAffixes or {}
    if #baseAffixes == 0 then
        table.insert(lines, "（无词缀数据）")
    end
    for _, aff in ipairs(baseAffixes) do
        table.insert(lines, "  ◆ " .. aff)
    end
    return table.concat(lines, "\n")
end

RefreshCatalogPanel = function()
    if not root_ then return end
    local catListPanel = root_:FindById("catalogCatList")
    if not catListPanel then return end

    -- 左侧：分类列表
    ClearChildren(catListPanel)
    for _, cat in ipairs(SortedCatalogCategories()) do
        local count = 0
        for _, item in ipairs(EquipmentCatalog.Items) do
            if item.category == cat then count = count + 1 end
        end
        catListPanel:AddChild(UI.Button {
            id = "catCat_" .. cat,
            text = CatalogCatLabel(cat) .. "（" .. count .. "）",
            variant = catalogCategory_ == cat and "primary" or "secondary",
            height = 28,
            width = "100%",
            fontSize = 10,
            paddingHorizontal = 6,
            onClick = function()
                catalogCategory_ = cat
                RefreshCatalogPanel()
            end,
        })
    end

    -- 中部：该分类物品列表
    local itemListPanel = root_:FindById("catalogItemList")
    ClearChildren(itemListPanel)
    BattleUI.SetText(root_, "catalogItemTitle", catalogCategory_ and CatalogCatLabel(catalogCategory_) or "选择分类查看底材")
    if catalogCategory_ then
        local itemCount = 0
        for _, item in ipairs(EquipmentCatalog.Items) do
            if item.category == catalogCategory_ then
                itemCount = itemCount + 1
            end
        end
        if itemCount == 0 then
            itemListPanel:AddChild(UI.Label { text = "该分类暂无底材数据", fontSize = 11, fontColor = { 157, 177, 193, 255 } })
        end
        for _, item in ipairs(EquipmentCatalog.Items) do
            if item.category == catalogCategory_ then
                itemListPanel:AddChild(UI.Button {
                    id = "catItem_" .. item.id,
                    text = item.name .. "（Lv" .. (item.requiredLevel or 1) .. "）",
                    variant = "secondary",
                    height = 26,
                    width = "100%",
                    fontSize = 10,
                    paddingHorizontal = 6,
                    onClick = function()
                        BattleUI.SetText(root_, "catalogDetailText", FormatCatalogDetail(item))
                    end,
                })
            end
        end
    end
end

-- ============================================================================
-- 词缀池页（4282 全量浏览）
-- ============================================================================
RefreshAffixPanel = function()
    if not root_ then return end
    local catListPanel = root_:FindById("affixCatList")
    if not catListPanel then return end

    -- 左侧：分类列表（含"全部"）
    ClearChildren(catListPanel)
    local function addAffixCat(label, catId)
        catListPanel:AddChild(UI.Button {
            id = "affixCat_" .. (catId or "all"),
            text = label,
            variant = affixCategory_ == catId and "primary" or "secondary",
            height = 28,
            width = "100%",
            fontSize = 10,
            paddingHorizontal = 6,
            onClick = function()
                affixCategory_ = catId
                RefreshAffixPanel()
            end,
        })
    end
    addAffixCat("全部（4282）", nil)
    for _, cat in ipairs(SortedCatalogCategories()) do
        addAffixCat(CatalogCatLabel(cat), cat)
    end

    -- 右侧：词缀列表（默认全部则只渲染前 300 行避免海量节点，选择分类则渲染该类全部）
    local listPanel = root_:FindById("affixList")
    ClearChildren(listPanel)
    BattleUI.SetText(root_, "affixListTitle", affixCategory_ and ("词缀 · " .. CatalogCatLabel(affixCategory_)) or "全量词缀（4282）")
    local shown = 0
    local maxRows = affixCategory_ and 9999 or 300
    for _, affix in ipairs(AffixData.Affixes) do
        if shown >= maxRows then break end
        if not affixCategory_ or affix.category == affixCategory_ then
            local line = "[" .. affix.type .. "] " .. affix.effect
            if affix.level then
                line = line .. "  Lv" .. affix.level
            end
            listPanel:AddChild(UI.Label {
                text = line,
                fontSize = 10,
                fontColor = { 181, 196, 209, 255 },
                lineHeight = 1.3,
                flexShrink = 1,
            })
            shown = shown + 1
        end
    end
    if shown == 0 then
        listPanel:AddChild(UI.Label { text = "该分类暂无词缀数据", fontSize = 11, fontColor = { 157, 177, 193, 255 } })
    elseif not affixCategory_ and shown >= maxRows then
        listPanel:AddChild(UI.Label {
            text = "……（仅预览前 " .. maxRows .. " 条，请在左侧选择分类查看完整列表）",
            fontSize = 10,
            fontColor = { 157, 177, 193, 255 },
        })
    end
end

-- ============================================================================
-- 传奇图鉴页（314 件：基础版 + 腐蚀版 = 627 条目）
-- ============================================================================
local legendSlotFilter_ = nil   -- nil = 全部；否则 "外攻武器" 等部位
---@type table|nil
local legendSelected_ = nil     -- 当前选中的 LegendGearData 条目

local function FindCatalogItemById(itemId)
    for _, item in ipairs(EquipmentCatalog.Items) do
        if item.id == itemId then return item end
    end
    return nil
end

local function FormatLegendDetail(g)
    local lines = {}
    table.insert(lines, "「" .. g.name .. "」" .. (g.variant == "corroded" and "（腐蚀强化版）" or "（基础版）"))
    table.insert(lines, "原译：" .. g.sourceName)
    local catMeta = EquipmentCatalog.Categories[g.category]
    table.insert(lines, "部位：" .. (g.slot or "?") .. " · 底材类：" .. (catMeta and catMeta.name or g.category or "?"))
    table.insert(lines, "需求等级 " .. (g.requiredLevel or "?") .. " · 掉落等级 " .. (g.dropLevel or "?"))
    if g.quote and #g.quote > 0 then
        table.insert(lines, "铭文：" .. g.quote)
    end
    table.insert(lines, "固定词缀：")
    for _, aff in ipairs(g.affixTexts or {}) do
        table.insert(lines, "  ◆ " .. aff)
    end
    table.insert(lines, "")
    table.insert(lines, "「试用入库」将按当前详情生成一件物品：")
    table.insert(lines, "可解析词缀掷值后真实生效；特殊机制句仅展示待精修。")
    return table.concat(lines, "\n")
end

RefreshLegendPanel = function()
    if not root_ then return end
    -- 左侧：部位分类
    local catListPanel = root_:FindById("legendCatList")
    if catListPanel then
        ClearChildren(catListPanel)
        local function addSlot(label, slot)
            catListPanel:AddChild(UI.Button {
                id = "legCat_" .. (slot or "all"),
                text = label,
                variant = legendSlotFilter_ == slot and "primary" or "secondary",
                height = 28,
                width = "100%",
                fontSize = 10,
                paddingHorizontal = 6,
                onClick = function()
                    legendSlotFilter_ = slot
                    RefreshLegendPanel()
                end,
            })
        end
        addSlot("全部（" .. LegendGearData.Count .. "）", nil)
        for _, slot in ipairs(LegendGearData.SlotOrder) do
            local list = LegendGearData.LegendsBySlot[slot]
            addSlot(slot .. "（" .. (list and #list or 0) .. "）", slot)
        end
    end
    -- 中部：传奇列表（行 = 条目，含基础/腐蚀版本）
    local itemListPanel = root_:FindById("legendItemList")
    if itemListPanel then
        ClearChildren(itemListPanel)
        BattleUI.SetText(root_, "legendItemTitle",
            legendSlotFilter_ and ("传奇 · " .. legendSlotFilter_) or "传奇全量（基础 + 腐蚀）")
        local shown = 0
        local maxRows = legendSlotFilter_ and 9999 or 260
        for _, g in ipairs(LegendGearData.Legends) do
            if shown >= maxRows then
                itemListPanel:AddChild(UI.Label {
                    text = "……（条目较多，请按部位筛选）",
                    fontSize = 10,
                    fontColor = { 157, 177, 193, 255 },
                })
                break
            end
            if not legendSlotFilter_ or g.slot == legendSlotFilter_ then
                local sel = legendSelected_ and legendSelected_.id == g.id
                itemListPanel:AddChild(UI.Button {
                    id = "legRow_" .. g.id,
                    text = g.name .. (g.variant == "corroded" and "（腐蚀）" or ""),
                    variant = sel and "primary" or "secondary",
                    height = 26,
                    width = "100%",
                    fontSize = 10,
                    paddingHorizontal = 6,
                    onClick = function()
                        legendSelected_ = g
                        BattleUI.SetText(root_, "legendDetailText", FormatLegendDetail(g))
                    end,
                })
                shown = shown + 1
            end
        end
        if shown == 0 then
            itemListPanel:AddChild(UI.Label { text = "该部位暂无传奇数据", fontSize = 11, fontColor = { 157, 177, 193, 255 } })
        end
    end
end

-- 「试用入库」：按当前选中的传奇详情生成一件物品放入背包（可穿戴体验）
TryLegendItem = function()
    local g = legendSelected_
    if not g then
        AddLog("请先在传奇图鉴中选择一件传奇")
        return
    end
    local catalogItem = FindCatalogItemById(g.catalogId)
    if not catalogItem then
        AddLog("未找到传奇底材：" .. tostring(g.catalogId))
        return
    end
    local item = ItemFactory.CreateLegend(catalogItem, g.affixTexts)
    if not item then
        AddLog("传奇生成失败：" .. g.name)
        return
    end
    if Inventory.Add(item) then
        AddLog("传奇入库：「" .. item.name .. "」（"
            .. (g.variant == "corroded" and "腐蚀版" or "基础版")
            .. " · 生效词缀 " .. #item.affixTexts .. " 条 / 特殊句 " .. #(item.legendTexts or {}) .. " 条）")
        if root_ and BattleUI.IsVisible(root_, "equipOverlay") and currentEquipPage_ == "equip" then
            RefreshEquipmentPanel()
        end
    else
        AddLog("背包已满，传奇未能入库")
    end
end

HandleBossDefeated = function(unit, reward)
    ApplyExperienceLevel()
    defeatedBosses_ = defeatedBosses_ + 1
    AddLog("首领结算：获得经验 " .. reward.experience .. "、金币 " .. reward.gold .. "，继续挂机")
    SaveNow()
end

ApplyExperienceLevel = function()
    if not sim_ then return end
    local oldLevel = playerLevel_
    playerLevel_ = ProgressionData.GetLevel(sim_.experience)
    if playerLevel_ > oldLevel then
        GameData.Character.levelBonus = ProgressionData.GetLevelBonuses(playerLevel_)
        RefreshAttributes()
        sim_:ApplyAttributes(attributes_)
        sim_.player.life = sim_.player.maxLife
        sim_.player.innerForce = sim_.player.maxInnerForce
        sim_.player.qi = sim_.player.maxQi
        AddLog("角色升级：等级 " .. oldLevel .. " → " .. playerLevel_ .. "，状态已恢复")
    end
end

-- ============================================================================
-- 暂停与主菜单
-- ============================================================================
local function UpdatePauseUI()
    if not root_ then return end
    BattleUI.SetVisible(root_, "pauseOverlay", paused_ and not menuVisible_)
    BattleUI.SetVisible(root_, "mainMenuOverlay", menuVisible_)
    BattleUI.SetText(root_, "mainMenuProgress", "等级 " .. playerLevel_ .. " · 首领击败 " .. defeatedBosses_ .. " 次\n当前地图：" .. (GetMap() and GetMap().name or "未知"))
end

local function ShowMainMenu()
    SaveNow()
    paused_ = true
    menuVisible_ = true
    UpdatePauseUI()
end

local function ResumeGame()
    menuVisible_ = false
    paused_ = false
    UpdatePauseUI()
end

local function TogglePause()
    if menuVisible_ then return end
    paused_ = not paused_
    AddLog(paused_ and "已暂停挂机" or "已恢复挂机")
    UpdatePauseUI()
end


-- ============================================================================
-- 生命周期
-- ============================================================================
function Start()
    graphics.windowTitle = CONFIG.Title
    BattleUI.Init()
    RefreshAttributes()

    root_ = BattleUI.BuildRoot {
        onOuterSkill = function() OpenSkillLibrary("外攻招式") end,
        onInnerSkill = function() OpenSkillLibrary("内攻招式") end,
        onAuraSlot1 = function() OpenSkillLibrary("辅助功法", 1) end,
        onAuraSlot2 = function() OpenSkillLibrary("辅助功法", 2) end,
        onTechniqueSlot1 = function() OpenSkillLibrary("通用精研", 1) end,
        onTechniqueSlot2 = function() OpenSkillLibrary("通用精研", 2) end,
        onPause = TogglePause,
        onOpenMainMenu = ShowMainMenu,
        onResume = ResumeGame,
        onMainMenu = ShowMainMenu,
        onMenuMap = OpenMapOverlay,
        onOpenLibrary = function() OpenSkillLibrary(currentLibraryKind_) end,
        onCloseLibrary = CloseSkillLibrary,
        onLibraryCategory = function(kind) RefreshSkillLibrary(kind) end,
        onOpenMap = OpenMapOverlay,
        onCloseMap = CloseMapOverlay,
        onOpenEquipment = OpenEquipment,
        onCloseEquipment = CloseEquipment,
        onEquipmentPage = SwitchEquipmentPage,
        onWearSelected = WearSelectedItem,
        onSellSelected = SellSelectedItem,
        onSalvageSelected = SalvageSelectedItem,
        onSortInventory = SortInventory,
        onLegendTry = TryLegendItem,
        onOpenRefine = OpenRefinePanel,
        onCloseRefine = CloseRefinePanel,
    }

    Inventory.Init(GameData.Loadout)
    local savedState = LoadSave()
    RefreshAttributes()

    sim_ = CreateSim()
    if sim_ then
        if savedState then
            sim_.gold = savedState.gold or 0
            sim_.experience = savedState.experience or 0
            sim_.killCount = savedState.killCount or 0
            sim_.totalKills = savedState.totalKills or 0
            sim_.wave = savedState.wave or 1
            playerLevel_ = savedState.playerLevel or ProgressionData.GetLevel(sim_.experience)
            defeatedBosses_ = savedState.defeatedBosses or 0
        end
        local map = GetMap()
        BattleUI.SetText(root_, "mapLabel", map.name)
        AddLog("地图：" .. map.name .. "，难度系数 x" .. string.format("%.1f", map.difficulty or 1.0))
        AddLog("击败 " .. (map.bossKillTarget or 100) .. " 只普通敌人后，首领将现身")
        AddLog("招式总览：" .. #SkillData.OuterSkills .. " 外攻 / " .. #SkillData.InnerSkills .. " 内攻 / " .. #SkillData.GeneralSkills .. " 通用精研")
        AddLog("功法总览：" .. #SkillAuraData.AuraSkills .. " 辅助功法（常驻被动 ×2 槽）")
        AddLog("击杀掉落装备；点击技能栏换招、「装备」穿戴")
        RefreshSkillButtons()
        RefreshHud()
    end
    SubscribeToEvent("Update", "HandleUpdate")
    print("=== " .. CONFIG.Title .. " started ===")
end

function Stop()
    SaveNow()
    BattleUI.Shutdown()
    root_ = nil
    sim_ = nil
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    if not paused_ and sim_ then
        sim_:Update(timeStep)
    end
    autosaveTimer_ = autosaveTimer_ + timeStep
    if autosaveTimer_ >= CONFIG.AutoSaveInterval then
        autosaveTimer_ = 0.0
        SaveNow()
    end
    RefreshHud()
end
