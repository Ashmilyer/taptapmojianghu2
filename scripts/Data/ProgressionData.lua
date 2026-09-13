-- 《默江湖》角色成长经验表：等级 1-100
local M = {}

M.MaxLevel = 100
M.TotalExperience = {
    0, 525, 1760, 3781, 7184, 12186, 19324, 29377, 43181, 61693,
    85990, 117506, 157384, 207736, 269997, 346462, 439268, 551295, 685171, 843709,
    1030734, 1249629, 1504995, 1800847, 2142652, 2535122, 2984677, 3496798, 4080655, 4742836,
    5490247, 6334393, 7283446, 8348398, 9541110, 10874351, 12361842, 14018289, 15859432, 17905634,
    20171471, 22679999, 25456123, 28517857, 31897771, 35621447, 39721017, 44225461, 49176560, 54607467,
    60565335, 67094245, 74247659, 82075627, 90631041, 99984974, 110197515, 121340161, 133497202, 146749362,
    161191120, 176922628, 194049893, 212684946, 232956711, 255001620, 278952403, 304972236, 333233648, 363906163,
    397194041, 433312945, 472476370, 514937180, 560961898, 610815862, 664824416, 723298169, 786612664, 855129128,
    929261318, 1009443795, 1096169525, 1189918242, 1291270350, 1400795257, 1519130326, 1646943474, 1784977296, 1934009687,
    2094900291, 2268549086, 2455921256, 2658074992, 2876116901, 3111280300, 3364828162, 3638186694, 3932818530, 4250334444,
}

function M.GetLevel(totalExperience)
    local level = 1
    for i = 1, #M.TotalExperience do
        if totalExperience >= M.TotalExperience[i] then
            level = i
        else
            break
        end
    end
    return math.min(level, M.MaxLevel)
end

function M.GetNextTotalExperience(level)
    if level >= M.MaxLevel then return M.TotalExperience[M.MaxLevel] end
    return M.TotalExperience[level + 1]
end

function M.GetRequiredExperience(level)
    if level >= M.MaxLevel then return 0 end
    return M.TotalExperience[level + 1] - M.TotalExperience[level]
end

function M.GetLevelBonuses(level)
    local safeLevel = math.max(1, math.min(M.MaxLevel, level or 1))
    local gained = safeLevel - 1
    return {
        rootBone = gained,
        dexterity = gained,
        vitality = gained,
        life = gained * 10,
        innerForce = gained * 5,
        qi = gained,
    }
end

function M.GetProgress(totalExperience)
    local level = M.GetLevel(totalExperience)
    local current = M.TotalExperience[level]
    local nextTotal = M.GetNextTotalExperience(level)
    if level >= M.MaxLevel then return level, current, current, 1.0 end
    local span = nextTotal - current
    return level, current, nextTotal, math.max(0.0, math.min(1.0, (totalExperience - current) / span))
end

return M
