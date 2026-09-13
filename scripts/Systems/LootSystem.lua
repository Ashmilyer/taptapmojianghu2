-- 《默江湖》掉落系统
-- 规则（用户确认）：
--   * 击杀普通怪 20% 掉落；首领必掉 1 件（首领战奖励更高）。
--   * 掉落底材等级区间跟随当前地图难度：difficulty=1 → 需求等级 ≤ 20。
--   * 掉落物 = 图鉴底材 + 1~2 条可解释词缀（首领 2 条）。
--   * 词缀来源 AffixFullPool（全量可解析词缀，按底材类别与等级匹配），数值 roll 后真实生效。

local EquipmentCatalog = require("Data.EquipmentCatalog")
local ItemFactory = require("Systems.ItemFactory")
local LegendGearData = require("Data.LegendGearData")

local M = {}

M.NormalDropChance = 0.2    -- 普通怪掉落率 20%
M.BossDropCount = 2         -- 首领掉 2 件
M.NormalAffixMax = 2        -- 普通怪掉落词缀 ≤2
M.LegendDropChance = 0.1    -- 首领额外传奇掉落率 10%

-- 地图可掉落最大底材等级：难度系数 × 20 封顶
function M.MaxLevelForMap(map)
    local difficulty = (map and map.difficulty) or 1.0
    return math.floor(difficulty * 20)
end

-- 按类别从图鉴筛选可用底材（requiredLevel ≤ maxLevel，词缀文本须干净且能解析）
local function collectByCategory(category, maxLevel)
    local catItems = {}
    for _, item in ipairs(EquipmentCatalog.Items) do
        if item.category == category
            and item.requiredLevel <= maxLevel
            and item.requiredLevel >= 1 then
            table.insert(catItems, item)
        end
    end
    return catItems
end

-- 从底材中抽取一条（等级权重向 bracket 内随机）
local function pickCatalogItem(category, maxLevel)
    local catItems = collectByCategory(category, maxLevel)
    if #catItems == 0 then return nil end
    -- 按需求等级给权重：等级越高权重略高，接近地图上限更常见
    local weighted = {}
    for _, item in ipairs(catItems) do
        local w = 1 + (item.requiredLevel / math.max(1, maxLevel)) * 2.0
        for _ = 1, math.floor(w + 0.5) do
            table.insert(weighted, item)
        end
    end
    return weighted[math.random(1, #weighted)]
end

-- 掉落类别选取：武器类（外攻/内攻）权重 3，防具 2，饰品 1
local slotWeights = {
    outer = { "One-Handed_Sword", "One-Handed_Axe", "One-Handed_Hammer", "Two-Handed_Sword", "Two-Handed_Axe", "Two-Handed_Hammer", "Claw", "Dagger", "Bow", "Crossbow", "Musket", "Pistol", "Fire_Cannon" },
    inner = { "Wand", "Rod", "Scepter", "Cane", "Tin_Staff", "Cudgel" },
    armor = { "STR_Helmet", "DEX_Helmet", "INT_Helmet", "STR_Chest_Armor", "DEX_Chest_Armor", "INT_Chest_Armor", "STR_Gloves", "DEX_Gloves", "INT_Gloves", "STR_Boots", "DEX_Boots", "INT_Boots", "STR_Shield", "DEX_Shield", "INT_Shield" },
    jewelry = { "Necklace", "Ring", "Belt" },
}

local function randomCategory()
    local groups = {}
    for _ = 1, 3 do table.insert(groups, "outer") end
    for _ = 1, 2 do table.insert(groups, "inner") end
    for _ = 1, 2 do table.insert(groups, "armor") end
    table.insert(groups, "jewelry")
    local group = groups[math.random(1, #groups)]
    local list = slotWeights[group]
    return list[math.random(1, #list)]
end

-- 掉落一件装备（首领时 affixCount=2）
-- @param map table 当前地图
-- @param isBoss boolean
-- @return table|nil 运行时装备对象
function M.RollDrop(map, isBoss)
    local maxLevel = M.MaxLevelForMap(map)
    -- 尝试不同类别，直到抽到可用底材
    local guard = 0
    while guard < 30 do
        guard = guard + 1
        local category = randomCategory()
        local catalogItem = pickCatalogItem(category, maxLevel)
        if catalogItem then
            local affixCount = nil
            if isBoss then
                affixCount = 2
            elseif math.random() < 0.35 then
                affixCount = 2
            else
                affixCount = 1
            end
            return ItemFactory.CreateDrop(catalogItem, affixCount)
        end
    end
    return nil
end

function M.RollBossLegend(map)
    if math.random() > M.LegendDropChance then return nil end
    local maxLevel = M.MaxLevelForMap(map)
    local candidates = {}
    for _, legend in ipairs(LegendGearData.Legends) do
        if legend.variant ~= "corroded" and (legend.requiredLevel or 1) <= maxLevel then
            local catalogItem = nil
            for _, item in ipairs(EquipmentCatalog.Items) do
                if item.id == legend.catalogId then catalogItem = item break end
            end
            if catalogItem then
                candidates[#candidates + 1] = { legend = legend, catalog = catalogItem }
            end
        end
    end
    if #candidates == 0 then return nil end
    local chosen = candidates[math.random(1, #candidates)]
    local item = ItemFactory.CreateLegend(chosen.catalog, chosen.legend.affixTexts)
    if item then
        item.legendId = chosen.legend.id
        item.legendVariant = chosen.legend.variant
    end
    return item
end
-- 普通怪击杀后的掉落判定（返回装备对象或 nil）
function M.RollNormalDrop(map)
    if math.random() > M.NormalDropChance then return nil end
    return M.RollDrop(map, false)
end

function M.GetSellValue(item)
    if not item or item.legendId then return 0 end
    local level = item.requiredLevel or 1
    local affixes = #(item.affixTexts or {})
    return math.max(1, level * 8 + affixes * level * 4)
end

function M.GetSalvageValue(item)
    if not item or item.legendId then return 0 end
    local level = item.requiredLevel or 1
    local affixes = #(item.affixTexts or {})
    return math.max(1, math.floor(level / 2) + affixes * 2)
end
-- 首领击杀掉落（必掉多件）
function M.RollBossDrops(map)
    local drops = {}
    for i = 1, M.BossDropCount do
        local item = M.RollDrop(map, true)
        if item then table.insert(drops, item) end
    end
    return drops
end

-- 完整进度自动保存

return M
