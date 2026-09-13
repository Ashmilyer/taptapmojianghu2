-- 《默江湖》地图数据：难度由手动选择地图决定
local M = {}

local function EnemyTypes()
    return {
        { id = "melee", name = "山魈", role = "melee", lifeMult = 1.0, attackMult = 1.0, moveMult = 1.0, range = 1.6 },
        { id = "ranged", name = "山魈术士", role = "ranged", lifeMult = 0.72, attackMult = 0.82, moveMult = 0.85, range = 5.5, damageType = "阳性" },
        { id = "heavy", name = "重甲山魈", role = "heavy", lifeMult = 2.5, attackMult = 1.45, moveMult = 0.58, range = 1.8, armorMult = 3.5 },
        { id = "poison", name = "毒雾山魈", role = "poison", lifeMult = 1.15, attackMult = 0.92, moveMult = 0.9, range = 2.0, damageType = "毒素" },
        { id = "summoner", name = "召唤祭司", role = "summoner", lifeMult = 1.35, attackMult = 0.7, moveMult = 0.72, range = 4.5, damageType = "阴性", summonInterval = 8.0 },
    }
end

local function BossPhases()
    return { 0.7, 0.4 }
end

M.Maps = {
    {
        id = "huangshan", name = "荒山古径", bg = "image/挂机战斗场景_20260907042337.png",
        difficulty = 1.0, unlockBosses = 0,
        description = "山魈出没的荒山古道，初入江湖者的试炼地。",
        enemy = {
            name = "山魈", level = 1, maxLife = 180, outerAttack = 8, attackInterval = 3.0, armor = 2,
            yangResistance = 0.1, yinResistance = 0.1, hunyuanResistance = 0.1, toxinResistance = 0.1,
            rewardGold = 12, rewardExperience = 525, moveSpeed = 2.2, attackRange = 1.6, radius = 0.5,
        },
        enemyTypes = EnemyTypes(), bossPhases = BossPhases(),
        boss = { name = "山魈王", level = 1, maxLifeMultiplier = 8, attackMultiplier = 3, attackInterval = 2.2, rewardGoldMultiplier = 10, rewardExperienceMultiplier = 8, scale = 1.6, radius = 0.8 },
        bossKillTarget = 100, waveSize = 4,
    },
    {
        id = "qingshi", name = "青石峡", bg = "image/挂机战斗场景_20260907042337.png",
        difficulty = 1.8, unlockBosses = 1,
        description = "青石断崖间毒雾弥漫，击败荒山首领后方可进入。",
        enemy = {
            name = "青石猿", level = 20, maxLife = 520, outerAttack = 22, attackInterval = 2.7, armor = 8,
            yangResistance = 0.18, yinResistance = 0.12, hunyuanResistance = 0.15, toxinResistance = 0.22,
            rewardGold = 45, rewardExperience = 190706, moveSpeed = 2.5, attackRange = 1.7, radius = 0.55,
        },
        enemyTypes = EnemyTypes(), bossPhases = BossPhases(),
        boss = { name = "青石猿王", level = 20, maxLifeMultiplier = 8, attackMultiplier = 3, attackInterval = 2.0, rewardGoldMultiplier = 10, rewardExperienceMultiplier = 8, scale = 1.7, radius = 0.85 },
        bossKillTarget = 100, waveSize = 4,
    },
    {
        id = "yunding", name = "云顶古战场", bg = "image/挂机战斗场景_20260907042337.png",
        difficulty = 3.0, unlockBosses = 3,
        description = "古战场残魂不散，击败三位地图首领后开放。",
        enemy = {
            name = "战场残魂", level = 40, maxLife = 1400, outerAttack = 58, attackInterval = 2.4, armor = 18,
            yangResistance = 0.25, yinResistance = 0.25, hunyuanResistance = 0.2, toxinResistance = 0.18,
            rewardGold = 120, rewardExperience = 2018334, moveSpeed = 2.8, attackRange = 1.8, radius = 0.6,
        },
        enemyTypes = EnemyTypes(), bossPhases = BossPhases(),
        boss = { name = "古战场将军", level = 40, maxLifeMultiplier = 8, attackMultiplier = 3, attackInterval = 1.8, rewardGoldMultiplier = 10, rewardExperienceMultiplier = 8, scale = 1.8, radius = 0.9 },
        bossKillTarget = 100, waveSize = 5,
    },
}

function M.GetDefaultMapId()
    return M.Maps[1].id
end

---@param mapId string
function M.FindById(mapId)
    for _, map in ipairs(M.Maps) do
        if map.id == mapId then return map end
    end
    return nil
end

function M.IsUnlocked(mapId, defeatedBosses)
    local map = M.FindById(mapId)
    return map ~= nil and (defeatedBosses or 0) >= (map.unlockBosses or 0)
end

return M
