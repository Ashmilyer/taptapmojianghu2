-- 寻怪/位移时间规则
-- 基础移动速度 5.0 m/s；移动速度每 +10%（相对基础）减少 1% 寻怪时间；
-- 每个位移技能额外减少 1 秒；最低 2 秒。
local M = {}

M.BaseMoveSpeed = 5.0
M.BaseSearchTime = 15.0
M.MinSearchTime = 2.0
M.SpeedReductionPerTenPercent = 0.01
M.BlinkReductionSeconds = 1.0

---@param movementSpeed number 实际移动速度 m/s
---@param blinkCount integer 本次寻怪期间使用位移技能次数
function M.GetSearchTime(movementSpeed, blinkCount)
    local bonus = (movementSpeed / M.BaseMoveSpeed) - 1.0
    local speedReduction = math.floor(bonus / 0.1) * M.SpeedReductionPerTenPercent
    local reduced = M.BaseSearchTime * (1.0 - speedReduction)
    reduced = reduced - (blinkCount or 0) * M.BlinkReductionSeconds
    if reduced < M.MinSearchTime then
        return M.MinSearchTime
    end
    if reduced > M.BaseSearchTime then
        return M.BaseSearchTime
    end
    return reduced
end

function M.GetMovementSpeedLabel(movementSpeed)
    local bonus = (movementSpeed / M.BaseMoveSpeed) - 1.0
    return string.format("%+.0f%%", bonus * 100.0)
end

return M
