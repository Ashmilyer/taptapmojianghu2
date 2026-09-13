-- 《默江湖》背包与装备栏管理
-- 背包：容量上限（默认 40），拾取、移除、检查。
-- 装备栏：11 槽（外攻武器/内攻武器/副手/头部/胸甲/手部/足部/腰部/项链/戒指一/戒指二）
-- 存档：完整进度（背包 + 穿戴 + 金币经验 + 地图 + 技能槽 + 击杀进度）。
-- 使用 File + cjson 相对路径 "save.json"（引擎项目隔离沙箱）。

local EquipmentCatalog = require("Data.EquipmentCatalog")
local ItemFactory = require("Systems.ItemFactory")

local M = {}
M.Capacity = 40
M.SaveFile = "save.json"

-- 槽位中文名 → loadout key（与 GameData.Loadout / EquipmentData.CreateDefaultLoadout 一致）
M.SlotToKey = {
    ["外攻武器"] = "outerWeapon",
    ["内攻武器"] = "innerWeapon",
    ["副手"] = "offHand",
    ["头部"] = "head",
    ["胸甲"] = "chest",
    ["手部"] = "gloves",
    ["足部"] = "boots",
    ["腰部"] = "belt",
    ["项链"] = "necklace",
}

-- 戒指两槽 key 列表
M.RingKeys = { "ring1", "ring2" }

M.SlotDisplay = {
    "外攻武器", "内攻武器", "副手", "头部", "胸甲", "手部", "足部", "腰部", "项链", "戒指一", "戒指二",
}

-- 单槽装备 key 顺序（戒指单独处理）
M.LoadoutKeys = { "outerWeapon", "innerWeapon", "offHand", "head", "chest", "gloves", "boots", "belt", "necklace", "ring1", "ring2" }

-- 运行时状态（main 负责初始化与绑定 loadout 引用）
M.bag = {}          -- 数组：运行时装备对象
M.loadout = nil     -- 引用 GameData.Loadout（11 键）

function M.Init(loadoutRef)
    M.loadout = loadoutRef or {}
    M.bag = {}
end

-- ============================================================================
-- 背包
-- ============================================================================
function M.Count()
    return #M.bag
end

function M.IsFull()
    return #M.bag >= M.Capacity
end

-- 拾取一件装备；满则返回 false
function M.Add(item)
    if not item then return false end
    if M.IsFull() then return false end
    table.insert(M.bag, item)
    return true
end

function M.RemoveAt(index)
    if index < 1 or index > #M.bag then return nil end
    local item = M.bag[index]
    table.remove(M.bag, index)
    return item
end

function M.FindByUid(uid)
    for i, item in ipairs(M.bag) do
        if item.uid == uid then return i, item end
    end
    return nil
end

function M.RemoveByUid(uid)
    local i, item = M.FindByUid(uid)
    if i then return M.RemoveAt(i) end
    return nil
end

function M.SortBag()
    table.sort(M.bag, function(a, b)
        local aq = a.legendId and 99 or #(a.affixTexts or {})
        local bq = b.legendId and 99 or #(b.affixTexts or {})
        if aq ~= bq then return aq > bq end
        local al = a.requiredLevel or 1
        local bl = b.requiredLevel or 1
        if al ~= bl then return al > bl end
        return (a.name or "") < (b.name or "")
    end)
end


-- ============================================================================
-- 装备栏操作
-- 返回 (成功, 被换下装备或 nil)
-- ============================================================================

-- 依据 item 的 slot 得到目标 loadout key；戒指自动选空位（无空位替换 ring1）
function M.ResolveSlotKey(item)
    if not item then return nil end
    local slot = item.slot
    if slot == "戒指" then
        for _, key in ipairs(M.RingKeys) do
            if not M.loadout[key] then return key end
        end
        return M.RingKeys[1]
    end
    return M.SlotToKey[slot]
end

-- 换装：把背包物品穿到其对应槽；槽中原装备回到背包
function M.EquipFromBag(uid)
    local i, item = M.FindByUid(uid)
    if not i then return false, nil end
    local key = M.ResolveSlotKey(item)
    if not key then return false, nil end

    local swapped = M.loadout[key]
    M.loadout[key] = item
    table.remove(M.bag, i)
    -- 若背包未满，被换下的回到背包末尾（穿戴不被挤掉）
    if swapped and not M.IsFull() then
        table.insert(M.bag, swapped)
    end
    return true, swapped
end

-- 卸下：装备槽 → 背包（背包满则失败）
function M.UnequipSlot(key)
    local item = M.loadout[key]
    if not item then return false end
    if M.IsFull() then return false end
    M.loadout[key] = nil
    table.insert(M.bag, item)
    return true
end

-- ============================================================================
-- 存档序列化（装备对象为纯表，可直接 cjson）
-- ============================================================================

local function cloneItem(item)
    return ItemFactory.Clone(item)
end

function M.SerializeItem(item)
    return cloneItem(item)
end

function M.DeserializeItem(data)
    if not data or not data.name then return nil end
    return cloneItem(data)
end

-- 装备栏 → 可 JSON 化表
function M.SerializeLoadout()
    local out = {}
    for _, key in ipairs(M.LoadoutKeys) do
        local item = M.loadout[key]
        if item then out[key] = cloneItem(item) end
    end
    return out
end

-- 反序列化到 loadout（引用表直接更新）
function M.DeserializeLoadout(data)
    data = data or {}
    for _, key in ipairs(M.LoadoutKeys) do
        M.loadout[key] = nil
        local d = data[key]
        if d then M.loadout[key] = M.DeserializeItem(d) end
    end
end

function M.SerializeBag()
    local out = {}
    for _, item in ipairs(M.bag) do
        table.insert(out, cloneItem(item))
    end
    return out
end

function M.DeserializeBag(data)
    M.bag = {}
    for _, d in ipairs(data or {}) do
        local item = M.DeserializeItem(d)
        if item then table.insert(M.bag, item) end
    end
end

-- ============================================================================
-- 存档读写（File + cjson）
-- ============================================================================

-- 保存完整进度。state 需提供：mapId, gold, experience, killCount, totalKills,
-- wave, skillOuterId, skillInnerId（可选）
function M.Save(state)
    local payload = {
        version = 1,
        loadout = M.SerializeLoadout(),
        bag = M.SerializeBag(),
        state = {
            mapId = state and state.mapId,
            gold = state and state.gold or 0,
            experience = state and state.experience or 0,
            killCount = state and state.killCount or 0,
            totalKills = state and state.totalKills or 0,
            wave = state and state.wave or 1,
            skillOuterId = state and state.skillOuterId,
            skillInnerId = state and state.skillInnerId,
            playerLevel = state and state.playerLevel or 1,
            defeatedBosses = state and state.defeatedBosses or 0,
            salvageMaterials = state and state.salvageMaterials or 0,
        },
    }
    local file = File(M.SaveFile, FILE_WRITE)
    if not file or not file:IsOpen() then
        print("[存档] 无法写入 " .. M.SaveFile)
        return false
    end
    local ok, json = pcall(cjson.encode, payload)
    if not ok then
        print("[存档] 编码失败")
        file:Close()
        return false
    end
    file:WriteString(json)
    file:Close()
    print("[存档] 已保存（背包 " .. #M.bag .. " 件，金币 " .. (payload.state.gold or 0) .. "）")
    return true
end

-- 读取存档，应用到 Inventory + 返回 state 表（无存档返回 nil）
function M.Load()
    if not fileSystem:FileExists(M.SaveFile) then return nil end
    local file = File(M.SaveFile, FILE_READ)
    if not file or not file:IsOpen() then return nil end
    local json = file:ReadString()
    file:Close()
    local ok, data = pcall(cjson.decode, json)
    if not ok or not data then return nil end

    M.DeserializeLoadout(data.loadout)
    M.DeserializeBag(data.bag)
    local st = data.state or {}
    return {
        mapId = st.mapId,
        gold = st.gold or 0,
        experience = st.experience or 0,
        killCount = st.killCount or 0,
        totalKills = st.totalKills or 0,
        wave = st.wave or 1,
        skillOuterId = st.skillOuterId,
        skillInnerId = st.skillInnerId,
        playerLevel = st.playerLevel or 1,
        defeatedBosses = st.defeatedBosses or 0,
        salvageMaterials = st.salvageMaterials or 0,
    }
end

return M
