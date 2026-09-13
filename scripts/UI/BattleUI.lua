-- ============================================================================
-- 《默江湖》挂机试炼 - 俯视战场 UI
-- 布局：顶部信息条 / 中部俯视战场(约占 2/3 屏) / 底部 HUD + 技能栏
-- 战场单位 = 圆形图标槽位（absolute 定位，main 每帧调用 UpdateField 更新）
-- 浮层：招式总览（可选取换招）、地图选择、装备/背包/图鉴（三页签）
-- ============================================================================
local UI = require("urhox-libs/UI")

local M = {}

local COLORS = {
    background = { 35, 25, 25, 255 },
    panel = { 247, 226, 190, 252 },
    panelAlt = { 255, 239, 207, 255 },
    panelDeep = { 224, 178, 119, 255 },
    panelShadow = { 70, 38, 25, 100 },
    border = { 139, 83, 43, 230 },
    borderLight = { 255, 247, 218, 255 },
    text = { 82, 45, 31, 255 },
    muted = { 139, 92, 57, 255 },
    gold = { 173, 91, 20, 255 },
    goldBright = { 255, 211, 102, 255 },
    life = { 204, 57, 53, 255 },
    innerForce = { 46, 145, 205, 255 },
    qi = { 125, 75, 177, 255 },
    accent = { 55, 137, 92, 255 },
    enemy = { 177, 55, 48, 255 },
    player = { 50, 139, 102, 255 },
    boss = { 190, 117, 25, 255 },
    damage = { 168, 72, 25, 255 },
    slot = { 187, 141, 98, 255 },
    slotInner = { 239, 211, 169, 255 },
    ink = { 61, 38, 27, 255 },
}

local QUALITY_COLORS = {
    [1] = { 181, 181, 181, 255 },
    [2] = { 92, 170, 76, 255 },
    [3] = { 47, 157, 184, 255 },
    [4] = { 168, 73, 184, 255 },
    [5] = { 213, 148, 31, 255 },
    [6] = { 205, 55, 42, 255 },
}

local function qualityColor(item)
    local count = #(item and item.affixTexts or {})
    return QUALITY_COLORS[math.min(6, math.max(1, count + 1))]
end

local function makeFrame(props)
    props = props or {}
    props.backgroundColor = props.backgroundColor or COLORS.panel
    props.borderRadius = props.borderRadius or 16
    props.borderWidth = props.borderWidth or 2
    props.borderColor = props.borderColor or COLORS.border
    props.boxShadow = props.boxShadow or {
        { x = 0, y = 5, blur = 12, spread = 0, color = COLORS.panelShadow },
    }
    return UI.Panel(props)
end

local function makeSectionTitle(text, accentColor)
    return UI.Panel {
        width = "100%",
        height = 34,
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = 12,
        borderRadius = 10,
        backgroundGradient = {
            type = "linear",
            direction = "to-right",
            from = accentColor or COLORS.panelDeep,
            to = { 255, 224, 170, 255 },
        },
        children = {
            UI.Label {
                text = text,
                fontSize = 16,
                fontWeight = "bold",
                fontColor = COLORS.ink,
                textStroke = { width = 1, color = { 255, 245, 215, 180 } },
            },
        },
    }
end

local function makeGlyphBox(glyph, color, size)
    size = size or 44
    return UI.Panel {
        width = size,
        height = size,
        borderRadius = math.floor(size * 0.22),
        borderWidth = 2,
        borderColor = color or COLORS.border,
        backgroundGradient = {
            type = "radial",
            from = { 255, 250, 226, 255 },
            to = { 205, 158, 108, 255 },
        },
        alignItems = "center",
        justifyContent = "center",
        children = {
            UI.Label {
                text = glyph,
                fontSize = math.floor(size * 0.48),
                fontWeight = "bold",
                fontColor = color or COLORS.gold,
                textAlign = "center",
            },
        },
    }
end

local function makePill(text, color, width)
    return UI.Panel {
        width = width or "auto",
        height = 24,
        paddingHorizontal = 9,
        borderRadius = 12,
        backgroundColor = color or COLORS.panelDeep,
        alignItems = "center",
        justifyContent = "center",
        children = {
            UI.Label { text = text, fontSize = 10, fontWeight = "bold", fontColor = COLORS.ink },
        },
    }
end

local function makeLabel(text, size, color)
    return UI.Label {
        text = text,
        fontSize = size,
        fontColor = color or COLORS.text,
        flexShrink = 1,
    }
end

local function makeModalFrame(id, width, height)
    return UI.Panel {
        id = id,
        width = width,
        height = height,
        flexDirection = "column",
        gap = 10,
        padding = 16,
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom",
            from = { 255, 244, 216, 255 },
            to = { 239, 199, 143, 255 },
        },
        borderRadius = 20,
        borderWidth = 3,
        borderColor = COLORS.border,
        boxShadow = {
            { x = 0, y = 8, blur = 20, spread = 0, color = { 44, 24, 15, 150 } },
            { x = 0, y = 0, blur = 0, spread = 1, color = COLORS.borderLight, inset = true },
        },
    }
end

local function makeModalHeader(title, subtitle, closeId, onClose)
    return UI.Panel {
        width = "100%",
        height = 58,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "spaceBetween",
        paddingHorizontal = 14,
        borderRadius = 14,
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom",
            from = { 255, 206, 116, 255 },
            to = { 218, 135, 54, 255 },
        },
        borderWidth = 2,
        borderColor = { 157, 83, 28, 255 },
        children = {
            UI.Panel {
                flexDirection = "column",
                gap = 1,
                flexShrink = 1,
                children = {
                    UI.Label { text = title, fontSize = 22, fontWeight = "bold", fontColor = { 92, 44, 20, 255 }, textStroke = { width = 1, color = { 255, 242, 198, 220 } } },
                    UI.Label { text = subtitle or "", fontSize = 10, fontColor = { 115, 62, 35, 255 }, flexShrink = 1 },
                },
            },
            UI.Button {
                id = closeId,
                text = "×",
                width = 42,
                height = 42,
                fontSize = 28,
                fontWeight = "bold",
                textColor = { 118, 44, 25, 255 },
                backgroundColor = { 255, 230, 175, 255 },
                hoverBackgroundColor = { 255, 246, 210, 255 },
                pressedBackgroundColor = { 225, 164, 81, 255 },
                borderRadius = 21,
                borderWidth = 2,
                borderColor = { 157, 83, 28, 255 },
                onClick = onClose,
            },
        },
    }
end

local function makeTab(id, text, active, onClick)
    return UI.Button {
        id = id,
        text = text,
        variant = active and "primary" or "secondary",
        height = 42,
        flexGrow = 1,
        fontSize = 14,
        fontWeight = "bold",
        borderRadius = 12,
        borderWidth = 2,
        borderColor = active and { 173, 91, 20, 255 } or { 194, 145, 94, 255 },
        backgroundColor = active and { 255, 208, 105, 255 } or { 247, 222, 181, 255 },
        hoverBackgroundColor = { 255, 233, 170, 255 },
        pressedBackgroundColor = { 228, 171, 82, 255 },
        textColor = COLORS.ink,
        onClick = onClick,
    }
end

local function makeInfoCard(title, value, color)
    return UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        minHeight = 56,
        padding = 8,
        gap = 2,
        borderRadius = 12,
        backgroundColor = { 255, 238, 202, 220 },
        borderWidth = 1,
        borderColor = { 201, 145, 86, 210 },
        children = {
            UI.Label { text = title, fontSize = 10, fontColor = COLORS.muted },
            UI.Label { text = value, fontSize = 17, fontWeight = "bold", fontColor = color or COLORS.gold, flexShrink = 1 },
        },
    }
end

local function makeListSurface(id, width)
    return UI.Panel {
        id = id,
        width = width or "100%",
        flexGrow = 1,
        flexBasis = 0,
        padding = 8,
        gap = 6,
        borderRadius = 14,
        backgroundColor = { 255, 247, 226, 220 },
        borderWidth = 2,
        borderColor = { 201, 145, 86, 220 },
    }
end

local ITEM_GLYPHS = {
    ["外攻武器"] = "剑",
    ["内攻武器"] = "杖",
    ["副手"] = "盾",
    ["头部"] = "盔",
    ["胸甲"] = "甲",
    ["手部"] = "手",
    ["足部"] = "靴",
    ["腰部"] = "带",
    ["项链"] = "链",
    ["戒指"] = "戒",
}

local EQUIP_SLOT_LAYOUT = {
    outerWeapon = { left = 2, top = 48 },
    innerWeapon = { right = 2, top = 48 },
    offHand = { left = 2, top = 116 },
    head = { right = 2, top = 116 },
    chest = { left = 2, top = 184 },
    gloves = { right = 2, top = 184 },
    boots = { left = 2, top = 252 },
    belt = { right = 2, top = 252 },
    necklace = { left = 2, top = 320 },
    ring1 = { right = 2, top = 320 },
    ring2 = { right = 2, top = 388 },
}

local function equipmentGlyph(key)
    local names = {
        outerWeapon = "外攻武器", innerWeapon = "内攻武器", offHand = "副手",
        head = "头部", chest = "胸甲", gloves = "手部", boots = "足部",
        belt = "腰部", necklace = "项链", ring1 = "戒指", ring2 = "戒指",
    }
    return ITEM_GLYPHS[names[key]] or "物"
end

local function equipmentSlotName(key)
    local names = {
        outerWeapon = "外攻", innerWeapon = "内攻", offHand = "副手",
        head = "头部", chest = "胸甲", gloves = "手部", boots = "足部",
        belt = "腰部", necklace = "项链", ring1 = "戒一", ring2 = "戒二",
    }
    return names[key] or key
end

local function itemQualityColor(item)
    local count = #(item and item.affixTexts or {})
    return QUALITY_COLORS[math.min(6, math.max(1, count + 1))]
end

local function compactItemName(item)
    if not item then return "空" end
    local name = item.name or "无名物"
    if #name > 10 then return string.sub(name, 1, 9) .. "…" end
    return name
end

local function makeItemIcon(item, glyph, size, quality)
    local color = quality or itemQualityColor(item)
    return UI.Panel {
        width = size, height = size,
        borderRadius = math.floor(size * 0.18),
        borderWidth = 3,
        borderColor = color,
        backgroundGradient = {
            type = "radial",
            from = { 255, 250, 226, 255 },
            to = { 191, 143, 92, 255 },
        },
        alignItems = "center", justifyContent = "center",
        boxShadow = { { x = 0, y = 2, blur = 4, spread = 0, color = { 57, 29, 18, 100 } } },
        children = {
            UI.Label { text = glyph, fontSize = math.floor(size * 0.43), fontWeight = "bold", fontColor = color, textAlign = "center" },
        },
    }
end

function M.MakeEquipmentSlot(key, item, selected, onClick)
    local pos = EQUIP_SLOT_LAYOUT[key] or { left = 2, top = 2 }
    local children = {
        makeItemIcon(item, equipmentGlyph(key), 42, item and itemQualityColor(item) or { 151, 106, 68, 255 }),
        UI.Label { text = equipmentSlotName(key), fontSize = 8, fontWeight = "bold", fontColor = COLORS.ink, textAlign = "center" },
    }
    if item then
        children[#children + 1] = UI.Label { text = compactItemName(item), fontSize = 7, fontColor = COLORS.muted, textAlign = "center", maxLines = 1 }
    end
    return UI.Panel {
        id = "equipSlot_" .. key,
        position = "absolute",
        left = pos.left, right = pos.right, top = pos.top,
        width = 68, height = 62,
        padding = 2, gap = 1,
        alignItems = "center", justifyContent = "center",
        borderRadius = 8,
        borderWidth = selected and 3 or 2,
        borderColor = selected and { 220, 111, 20, 255 } or { 157, 105, 64, 255 },
        backgroundColor = item and { 255, 235, 189, 235 } or { 190, 149, 108, 210 },
        onClick = function() onClick(key) end,
        children = children,
    }
end

local function bagItemGlyph(item)
    if not item then return "·" end
    if item.slot == "戒指" then return equipmentGlyph("ring1") end
    local slotKeys = {
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
    return equipmentGlyph(slotKeys[item.slot] or "offHand")
end

function M.MakeBagSlot(index, item, onClick)
    local occupied = item ~= nil
    local quality = occupied and itemQualityColor(item) or { 170, 125, 84, 220 }
    local glyph = bagItemGlyph(item)
    local children = {
        makeItemIcon(item, glyph, 42, quality),
        UI.Label { text = occupied and compactItemName(item) or tostring(index), fontSize = occupied and 7 or 9, fontColor = occupied and COLORS.ink or COLORS.muted, textAlign = "center", maxLines = 1 },
    }
    if occupied and item.requiredLevel then
        children[#children + 1] = UI.Label { text = "Lv" .. tostring(item.requiredLevel), fontSize = 7, fontColor = COLORS.gold, textAlign = "center" }
    end
    return UI.Panel {
        id = "equipBagItem_" .. index,
        width = 68, height = 68,
        padding = 2, gap = 1,
        alignItems = "center", justifyContent = "center",
        borderRadius = 9,
        borderWidth = occupied and 3 or 2,
        borderColor = quality,
        backgroundColor = occupied and { 255, 239, 199, 255 } or { 217, 181, 137, 180 },
        onClick = occupied and function() onClick(item) end or nil,
        children = children,
    }
end

local function makeBar(id, value, maxValue, color, height)
    return UI.ProgressBar {
        id = id,
        value = value,
        max = maxValue,
        height = height or 12,
        fillColor = color,
        backgroundColor = { 8, 12, 19, 220 },
        borderRadius = 6,
        showLabel = false,
    }
end

-- 战场单位槽位池（单位数 = 1 玩家 + MaxEnemies + boss 预留）
local UNIT_SLOT_MAX = 9
M.UnitSlots = nil -- [{ widget, avatar, hpBar, nameLabel }]

local function ringColorFor(kind)
    if kind == "boss" then return COLORS.boss end
    if kind == "enemy" then return COLORS.enemy end
    return COLORS.player
end

local function avatarImageFor(kind)
    if kind == "player" then
        return "image/侠客头像_20260908025115.png"
    end
    return "image/山魈头像_20260908025116.png"
end

-- 创建一个战场单位槽位（一个圆形头像 + 底部血条）
local function createUnitSlot(index)
    local avatar = UI.Panel {
        id = "unitAvatar" .. index,
        width = 48,
        height = 48,
        borderRadius = 24,
        borderWidth = 3,
        borderColor = COLORS.player,
        backgroundImage = avatarImageFor("player"),
        backgroundFit = "cover",
    }
    local hpBar = UI.ProgressBar {
        id = "unitHp" .. index,
        value = 1,
        max = 1,
        width = 46,
        height = 5,
        fillColor = COLORS.life,
        backgroundColor = { 72, 32, 25, 220 },
        borderRadius = 2,
        showLabel = false,
    }
    local slot = UI.Panel {
        id = "unitSlot" .. index,
        position = "absolute",
        left = -100,
        top = -100,
        width = 52,
        height = 64,
        flexDirection = "column",
        alignItems = "center",
        pointerEvents = "none",
        visible = false,
        children = {
            avatar,
            UI.Panel {
                flexDirection = "row",
                alignSelf = "center",
                marginTop = 1,
                children = { hpBar },
            },
        },
    }
    return { widget = slot, avatar = avatar, hpBar = hpBar }
end

function M.Init()
    UI.Init {
        theme = "dark",
        fonts = {
            { family = "sans", weights = { normal = "Fonts/NotoSansSC-Black.ttf" } },
        },
        scale = UI.Scale.DEFAULT,
    }
end

function M.BuildRoot(callbacks)
    callbacks = callbacks or {}
    -- 预创建战场槽位
    local slots = {}
    for i = 1, UNIT_SLOT_MAX do
        slots[i] = createUnitSlot(i)
    end
    M.UnitSlots = slots

    local root = UI.Panel {
        id = "gameRoot",
        width = "100%",
        height = "100%",
        flexDirection = "column",
        backgroundColor = COLORS.background,
        children = {
            -- 顶部信息条
            UI.Panel {
                id = "topBar",
                flexDirection = "row",
                justifyContent = "spaceBetween",
                alignItems = "center",
                paddingHorizontal = 18,
                paddingVertical = 10,
                backgroundGradient = {
                    type = "linear",
                    direction = "to-bottom",
                    from = { 255, 209, 119, 255 },
                    to = { 206, 126, 45, 255 },
                },
                borderBottomWidth = 3,
                borderColor = { 125, 65, 28, 255 },
                children = {
                    UI.Panel {
                        flexDirection = "column",
                        gap = 2,
                        flexShrink = 1,
                        children = {
                            UI.Label { id = "mapLabel", text = "荒山古径", fontSize = 19, fontWeight = "bold", fontColor = { 91, 42, 18, 255 }, textStroke = { width = 1, color = { 255, 240, 190, 220 } } },
                            UI.Label { id = "stageLabel", text = "俯视战场 · 寻怪中", fontSize = 11, fontColor = { 112, 60, 31, 255 } },
                            UI.Label { id = "levelLabel", text = "等级 1", fontSize = 13, fontWeight = "bold", fontColor = COLORS.gold },
                            UI.ProgressBar { id = "experienceBar", value = 0, max = 1, width = 150, height = 10, fillGradient = { direction = "to-right", from = { 255, 212, 88, 255 }, to = { 230, 119, 40, 255 } }, backgroundColor = { 98, 51, 28, 220 }, borderRadius = 5, showLabel = false },
                        },
                    },
                    UI.Panel {
                        flexDirection = "row",
                        gap = 14,
                        children = {
                            UI.Label { id = "killLabel", text = "击杀 0/100", fontSize = 14, fontWeight = "bold", fontColor = { 91, 42, 18, 255 } },
                            UI.Label { id = "goldLabel", text = "金币 0", fontSize = 14, fontWeight = "bold", fontColor = { 126, 67, 13, 255 } },
                            UI.Label { id = "experienceLabel", text = "经验 0", fontSize = 12, fontColor = { 112, 60, 31, 255 } },
                        },
                    },
                },
            },
            -- 中部：战场（占剩余大部分）
            UI.Panel {
                id = "battleWrap",
                flexGrow = 1,
                flexBasis = 0,
                flexDirection = "column",
                padding = 6,
                backgroundColor = { 74, 47, 31, 255 },
                children = {
                    UI.Panel {
                        id = "battlefield",
                        flexGrow = 1,
                        flexBasis = 0,
                        position = "relative",
                        overflow = "hidden",
                        backgroundImage = "image/挂机战斗场景_20260907042337.png",
                        backgroundFit = "cover",
                        borderWidth = 3,
                        borderColor = { 172, 105, 49, 255 },
                        borderRadius = 12,
                        children = (function()
                            local cs = {}
                            for i = 1, UNIT_SLOT_MAX do
                                cs[#cs + 1] = slots[i].widget
                            end
                            cs[#cs + 1] = UI.Panel {
                                id = "bossWarning",
                                position = "absolute", left = -1000, top = -1000,
                                width = 80, height = 80,
                                borderRadius = 40, borderWidth = 4,
                                borderColor = { 255, 82, 45, 230 },
                                backgroundColor = { 255, 70, 36, 55 },
                                visible = false, pointerEvents = "none",
                            }
                            cs[#cs + 1] = UI.Panel { id = "combatFeedback", position = "absolute", left = 0, top = 0, width = "100%", height = "100%", pointerEvents = "none" }
                            return cs
                        end)(),
                    },
                },
            },
            -- 底部 HUD
            UI.Panel {
                id = "hudArea",
                flexDirection = "column",
                gap = 3,
                paddingHorizontal = 10,
                paddingVertical = 5,
                backgroundColor = { 14, 21, 31, 255 },
                children = {
                    -- 状态行：目标/状态/寻怪
                    UI.Panel {
                        id = "stateRow",
                        flexDirection = "row",
                        justifyContent = "spaceBetween",
                        alignItems = "center",
                        gap = 8,
                        children = {
                            UI.Label { id = "battleStateLabel", text = "寻怪中…", fontSize = 12, fontColor = COLORS.accent, flexShrink = 1 },
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = 6,
                                width = 220,
                                children = {
                                    makeBar("searchBar", 0, 15, COLORS.gold, 10),
                                    UI.Label { id = "searchLabel", text = "15.0s", fontSize = 10, fontColor = COLORS.muted, flexShrink = 1 },
                                },
                            },
                        },
                    },
                    -- 生命 / 内力 / 真气
                    UI.Panel {
                        id = "resourceRow",
                        flexDirection = "row",
                        gap = 8,
                        alignItems = "center",
                        children = {
                            makeBar("lifeBar", 1, 1, COLORS.life, 14),
                            UI.Label { id = "lifeLabel", text = "55/55", fontSize = 10, fontColor = COLORS.muted, flexShrink = 1 },
                            makeBar("innerForceBar", 1, 1, COLORS.innerForce, 14),
                            UI.Label { id = "innerForceLabel", text = "45/45", fontSize = 10, fontColor = COLORS.muted, flexShrink = 1 },
                            makeBar("qiBar", 1, 1, COLORS.qi, 14),
                            UI.Label { id = "qiLabel", text = "2/2", fontSize = 10, fontColor = COLORS.muted, flexShrink = 1 },
                        },
                    },
                    -- 战斗日志滚动（紧凑）
                    UI.Panel {
                        id = "logWrap",
                        flexDirection = "row",
                        height = 46,
                        borderRadius = 6,
                        borderWidth = 1,
                        borderColor = COLORS.border,
                        backgroundColor = { 8, 12, 18, 180 },
                        children = {
                            UI.ScrollView {
                                id = "combatLogScroll",
                                scrollY = true,
                                flexGrow = 1,
                                flexBasis = 0,
                                children = {
                                    UI.Label {
                                        id = "combatLog",
                                        text = "战斗日志",
                                        fontSize = 11,
                                        fontColor = COLORS.muted,
                                        lineHeight = 1.35,
                                    },
                                },
                            },
                        },
                    },
                },
            },
            -- 技能栏（第一行：功法/技法常驻槽；第二行：主攻外攻/内攻 + 功能按钮）
            UI.Panel {
                id = "skillBar",
                flexDirection = "column",
                gap = 6,
                padding = 8,
                backgroundGradient = {
                    type = "linear",
                    direction = "to-bottom",
                    from = { 255, 219, 145, 255 },
                    to = { 201, 126, 54, 255 },
                },
                borderTopWidth = 3,
                borderColor = { 126, 65, 29, 255 },
                children = {
                    -- 功法（常驻被动）×2 / 技法（主动增益）×2
                    UI.Panel {
                        id = "auxSkillRow",
                        flexDirection = "row",
                        gap = 8,
                        children = {
                            UI.Button {
                                id = "auraSlot1Button",
                                text = "功法一 · 空",
                                variant = "secondary",
                                flexGrow = 1,
                                height = 36,
                                fontSize = 12,
                                fontWeight = "bold",
                                textColor = COLORS.ink,
                                backgroundColor = { 255, 239, 197, 255 },
                                borderColor = { 162, 102, 49, 255 },
                                onClick = callbacks.onAuraSlot1,
                            },
                            UI.Button {
                                id = "auraSlot2Button",
                                text = "功法二 · 空",
                                variant = "secondary",
                                flexGrow = 1,
                                height = 36,
                                fontSize = 12,
                                fontWeight = "bold",
                                textColor = COLORS.ink,
                                backgroundColor = { 255, 239, 197, 255 },
                                borderColor = { 162, 102, 49, 255 },
                                onClick = callbacks.onAuraSlot2,
                            },
                            UI.Button {
                                id = "techniqueSlot1Button",
                                text = "精研一 · 空",
                                variant = "secondary",
                                flexGrow = 1,
                                height = 36,
                                fontSize = 12,
                                fontWeight = "bold",
                                textColor = COLORS.ink,
                                backgroundColor = { 255, 228, 181, 255 },
                                borderColor = { 162, 102, 49, 255 },
                                onClick = callbacks.onTechniqueSlot1,
                            },
                            UI.Button {
                                id = "techniqueSlot2Button",
                                text = "精研二 · 空",
                                variant = "secondary",
                                flexGrow = 1,
                                height = 36,
                                fontSize = 12,
                                fontWeight = "bold",
                                textColor = COLORS.ink,
                                backgroundColor = { 255, 228, 181, 255 },
                                borderColor = { 162, 102, 49, 255 },
                                onClick = callbacks.onTechniqueSlot2,
                            },
                        },
                    },
                    UI.Panel {
                        id = "attackSkillRow",
                        flexDirection = "row",
                        gap = 8,
                        children = {
                            UI.Button {
                                id = "outerSkillButton",
                                text = "外攻 · 流云剑式",
                                variant = "primary",
                                flexGrow = 1,
                                height = 36,
                                fontSize = 12,
                                onClick = callbacks.onOuterSkill,
                            },
                            UI.Button {
                                id = "innerSkillButton",
                                text = "内攻 · 青冥内息",
                                variant = "secondary",
                                flexGrow = 1,
                                height = 36,
                                fontSize = 12,
                                onClick = callbacks.onInnerSkill,
                            },
                            UI.Button {
                                id = "pauseButton",
                                text = "暂停",
                                variant = "danger",
                                width = 76,
                                height = 36,
                                fontSize = 12,
                                onClick = callbacks.onPause,
                            },
                            UI.Button {
                                id = "libraryButton",
                                text = "招式",
                                variant = "secondary",
                                width = 64,
                                height = 36,
                                fontSize = 12,
                                onClick = callbacks.onOpenLibrary,
                            },
                            UI.Button {
                                id = "equipButton",
                                text = "装备",
                                variant = "primary",
                                width = 64,
                                height = 36,
                                fontSize = 12,
                                onClick = callbacks.onOpenEquipment,
                            },
                            UI.Button {
                                id = "refineButton",
                                text = "精研",
                                variant = "secondary",
                                width = 64,
                                height = 36,
                                fontSize = 12,
                                onClick = callbacks.onOpenRefine,
                            },
                            UI.Button {
                                id = "mapButton",
                                text = "换图",
                                variant = "secondary",
                                width = 64,
                                height = 36,
                                fontSize = 12,
                                onClick = callbacks.onOpenMap,
                            },
                        },
                    },
                },
            },
            -- 招式总览浮层
            M._buildLibraryOverlay(callbacks),
            -- 专属精研装配浮层
            M._buildRefineOverlay(callbacks),
            -- 地图选择浮层
            M._buildMapOverlay(callbacks),
            -- 装备与背包/图鉴浮层
            M._buildEquipmentOverlay(callbacks),
            M._buildPauseOverlay(callbacks),
        },
    }
    UI.SetRoot(root)
    return root
end

-- ============================================================================
-- 招式总览浮层：三类标签 + 可选取技能列表（换招）
-- callbacks: onLibraryCategory(kind)、onCloseLibrary
-- ============================================================================
function M._buildLibraryOverlay(callbacks)
    local tabButtons = {}
    local LIB_TABS = { "外攻招式", "内攻招式", "通用精研", "辅助功法" }
    local function selectTab(kind)
        for _, k in ipairs(LIB_TABS) do
            local active = k == kind
            tabButtons[k]:SetVariant(active and "primary" or "secondary")
            tabButtons[k]:SetStyle {
                backgroundColor = active and { 255, 202, 91, 255 } or { 245, 220, 180, 255 },
                borderColor = active and { 166, 82, 22, 255 } or { 194, 145, 94, 255 },
                scale = active and 1.03 or 1.0,
            }
        end
        if callbacks.onLibraryCategory then callbacks.onLibraryCategory(kind) end
    end
    for _, k in ipairs(LIB_TABS) do
        tabButtons[k] = makeTab(nil, k, k == "外攻招式", function() selectTab(k) end)
        tabButtons[k]:SetStyle { transition = "all 0.18s easeOut" }
    end

    local panel = makeModalFrame("skillLibraryPanel", 900, 650)
    panel:AddChild(makeModalHeader("武学秘录", "参悟招式、精研与辅助功法，点击条目即可装配", "libraryCloseButton", callbacks.onCloseLibrary))
    panel:AddChild(UI.Panel {
        flexDirection = "row", gap = 8,
        children = { tabButtons["外攻招式"], tabButtons["内攻招式"], tabButtons["通用精研"], tabButtons["辅助功法"] },
    })
    panel:AddChild(UI.Panel {
        flexDirection = "row", gap = 10,
        children = {
            makeInfoCard("外攻招式", "流云剑式", COLORS.damage),
            makeInfoCard("内攻招式", "青冥内息", COLORS.innerForce),
            makeInfoCard("辅助功法", "双槽常驻", COLORS.accent),
            makeInfoCard("通用精研", "自动施展", COLORS.qi),
        },
    })
    panel:AddChild(UI.Panel {
        flexDirection = "row", gap = 12, flexGrow = 1, flexBasis = 0,
        children = {
            makeFrame {
                width = 610,
                flexDirection = "column",
                gap = 7,
                padding = 10,
                borderRadius = 14,
                backgroundColor = { 255, 244, 217, 245 },
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", justifyContent = "spaceBetween",
                        children = {
                            UI.Label { id = "skillLibraryTitle", text = "招式总览 · 点击招式选取", fontSize = 15, fontWeight = "bold", fontColor = COLORS.ink, flexShrink = 1 },
                            makePill("已收录 223 卷", { 228, 178, 98, 255 }),
                        },
                    },
                    UI.Divider { orientation = "horizontal", thickness = 1, color = { 195, 139, 82, 255 }, spacing = 2 },
                    UI.ScrollView {
                        id = "skillLibraryScroll",
                        scrollY = true,
                        showScrollbar = true,
                        bounces = true,
                        flexGrow = 1,
                        flexBasis = 0,
                        children = {
                            UI.Panel { id = "skillLibraryList", flexDirection = "column", gap = 6, width = "100%" },
                        },
                    },
                },
            },
            makeFrame {
                flexGrow = 1,
                flexShrink = 1,
                flexDirection = "column",
                gap = 10,
                padding = 12,
                borderRadius = 14,
                backgroundColor = { 247, 222, 179, 250 },
                children = {
                    makeSectionTitle("当前装配", { 218, 158, 83, 255 }),
                    UI.Panel {
                        alignItems = "center", gap = 7, paddingVertical = 4,
                        children = {
                            makeGlyphBox("武", COLORS.damage, 70),
                            UI.Label { text = "经脉运转", fontSize = 13, fontWeight = "bold", fontColor = COLORS.gold },
                            UI.Label { text = "外攻与内攻轮转出手\n功法常驻，精研自动施展", fontSize = 10, fontColor = COLORS.muted, textAlign = "center", whiteSpace = "normal", lineHeight = 1.45 },
                        },
                    },
                    UI.Divider { orientation = "horizontal", thickness = 1, color = { 195, 139, 82, 255 }, spacing = 2 },
                    UI.Label { id = "libraryOuterHint", text = "外攻：—", fontSize = 11, fontWeight = "bold", fontColor = COLORS.damage, whiteSpace = "normal" },
                    UI.Label { id = "libraryInnerHint", text = "内攻：—", fontSize = 11, fontWeight = "bold", fontColor = COLORS.innerForce, whiteSpace = "normal" },
                    UI.Label { id = "libraryAuraHint", text = "功法：— / —", fontSize = 10, fontColor = COLORS.accent, whiteSpace = "normal" },
                    UI.Label { id = "libraryTechniqueHint", text = "精研：— / —", fontSize = 10, fontColor = COLORS.qi, whiteSpace = "normal" },
                    UI.Panel {
                        marginTop = "auto", padding = 9, borderRadius = 10,
                        backgroundColor = { 229, 192, 137, 180 },
                        children = {
                            UI.Label { text = "提示：同类招式只占一个槽位，更换招式会自动卸下不匹配的专属精研。", fontSize = 9, fontColor = COLORS.ink, whiteSpace = "normal", lineHeight = 1.4 },
                        },
                    },
                },
            },
        },
    })

    return UI.Panel {
        id = "skillLibraryOverlay",
        position = "absolute", left = 0, top = 0,
        width = "100%", height = "100%", visible = false,
        flexDirection = "row", justifyContent = "center", alignItems = "center",
        backgroundColor = { 25, 15, 10, 205 }, backdropBlur = 5,
        pointerEvents = "auto",
        children = { panel },
    }
end

-- ============================================================================
-- 招式专属精研装配浮层：外攻/内攻招式各一列，列出该招式可用的专属精研
-- 内容由 main.RefreshRefinePanel 动态填充（refineOuterList/refineInnerList）
function M._buildRefineOverlay(callbacks)
    local panel = makeModalFrame("refinePanel", 1040, 680)
    panel:AddChild(makeModalHeader("精研谱", "为当前招式与精研槽装配专属强化，强化伤害独立生效", "refineCloseButton", callbacks.onCloseRefine))
    panel:AddChild(UI.Panel {
        flexDirection = "row", gap = 8,
        children = {
            makeInfoCard("外攻槽", "专属精研", COLORS.damage),
            makeInfoCard("内攻槽", "专属精研", COLORS.innerForce),
            makeInfoCard("精研一", "自动增益", COLORS.qi),
            makeInfoCard("精研二", "自动增益", COLORS.accent),
        },
    })
    panel:AddChild(UI.Panel {
        flexDirection = "row", gap = 10, flexGrow = 1, flexBasis = 0,
        children = {
            makeListSurface("refineOuterColumn", 0),
            makeListSurface("refineInnerColumn", 0),
            makeListSurface("refineTech1Column", 0),
            makeListSurface("refineTech2Column", 0),
        },
    })

    local function addRefineColumn(column, titleId, title, scrollId, listId)
        column:AddChild(UI.Label { id = titleId, text = title, fontSize = 13, fontWeight = "bold", fontColor = COLORS.ink, whiteSpace = "normal" })
        column:AddChild(UI.Divider { orientation = "horizontal", thickness = 1, color = { 195, 139, 82, 255 }, spacing = 1 })
        column:AddChild(UI.ScrollView {
            id = scrollId, scrollY = true, showScrollbar = true, bounces = true,
            flexGrow = 1, flexBasis = 0,
            children = { UI.Panel { id = listId, flexDirection = "column", gap = 6, width = "100%" } },
        })
    end
    addRefineColumn(panel.children[3].children[1], "refineOuterTitle", "外攻 · —", "refineOuterScroll", "refineOuterList")
    addRefineColumn(panel.children[3].children[2], "refineInnerTitle", "内攻 · —", "refineInnerScroll", "refineInnerList")
    addRefineColumn(panel.children[3].children[3], "refineTech1Title", "精研一 · —", "refineTech1Scroll", "refineTech1List")
    addRefineColumn(panel.children[3].children[4], "refineTech2Title", "精研二 · —", "refineTech2Scroll", "refineTech2List")

    return UI.Panel {
        id = "refineOverlay",
        position = "absolute", left = 0, top = 0,
        width = "100%", height = "100%", visible = false,
        flexDirection = "row", justifyContent = "center", alignItems = "center",
        backgroundColor = { 25, 15, 10, 205 }, backdropBlur = 5,
        pointerEvents = "auto",
        children = { panel },
    }
end

local function buildEquipmentMainPage(callbacks)
    callbacks = callbacks or {}
    return UI.Panel {
        id = "equipBody",
        position = "absolute", left = 0, top = 0,
        width = "100%", height = "100%",
        flexDirection = "row", gap = 12,
        children = {
            makeFrame {
                id = "equipLeftCol",
                width = 390,
                flexDirection = "column",
                gap = 8,
                padding = 12,
                backgroundColor = { 255, 239, 207, 245 },
                children = {
                    UI.Panel {
                        flexDirection = "row", justifyContent = "spaceBetween", alignItems = "center",
                        children = {
                            makeSectionTitle("侠客行装", { 229, 177, 103, 255 }),
                        },
                    },
                    UI.Panel {
                        position = "relative",
                        flexGrow = 1,
                        flexBasis = 0,
                        minHeight = 235,
                        borderRadius = 14,
                        backgroundGradient = {
                            type = "radial", from = { 255, 249, 226, 255 }, to = { 224, 185, 132, 255 },
                        },
                        borderWidth = 1,
                        borderColor = { 202, 149, 88, 255 },
                        children = {
                            UI.Panel {
                                position = "absolute", left = 88, right = 88, top = 20, bottom = 14,
                                backgroundImage = "image/侠客角色_20260907042339.png",
                                backgroundFit = "contain",
                                pointerEvents = "none",
                            },
                            UI.Panel {
                                position = "absolute", left = 8, right = 8, top = 8, bottom = 8,
                                children = {
                                    UI.Panel {
                                        position = "relative",
                                        id = "equipSlots",
                                        width = "100%", height = "100%",
                                        flexDirection = "column",
                                    },
                                },
                            },
                        },
                    },
                    UI.Panel {
                        flexDirection = "row", gap = 8,
                        children = {
                            makeInfoCard("根骨", "刚健", COLORS.life),
                            makeInfoCard("灵巧", "迅捷", COLORS.accent),
                            makeInfoCard("元气", "充盈", COLORS.innerForce),
                        },
                    },
                    UI.Panel {
                        id = "equipDetailBox",
                        width = "100%", minHeight = 90,
                        borderRadius = 12, borderWidth = 2, borderColor = { 187, 126, 68, 255 },
                        backgroundColor = { 255, 247, 224, 245 }, padding = 10,
                        children = {
                            UI.Label {
                                id = "equipDetailText",
                                text = "点击背包装备查看详情，再选择穿戴、出售或分解。",
                                fontSize = 10, fontColor = COLORS.text, lineHeight = 1.45,
                                whiteSpace = "normal", maxLines = 5,
                            },
                            UI.Panel {
                                flexDirection = "row", gap = 6, marginTop = 6,
                                children = {
                                    UI.Button { id = "equipWearButton", text = "穿戴", width = 76, height = 32, fontSize = 11, backgroundColor = { 240, 190, 80, 255 }, textColor = COLORS.ink, onClick = callbacks.onWearSelected },
                                    UI.Button { id = "equipSellButton", text = "出售", width = 76, height = 32, fontSize = 11, backgroundColor = { 220, 166, 117, 255 }, textColor = COLORS.ink, onClick = callbacks.onSellSelected },
                                    UI.Button { id = "equipSalvageButton", text = "分解", width = 76, height = 32, fontSize = 11, backgroundColor = { 191, 169, 130, 255 }, textColor = COLORS.ink, onClick = callbacks.onSalvageSelected },
                                },
                            },
                        },
                    },
                },
            },
            makeFrame {
                id = "equipRightCol",
                flexGrow = 1, flexShrink = 1,
                flexDirection = "column", gap = 8, padding = 12,
                backgroundColor = { 255, 237, 202, 245 },
                children = {
                    UI.Panel {
                        flexDirection = "row", justifyContent = "spaceBetween", alignItems = "center",
                        children = {
                            UI.Label { id = "equipBagTitle", text = "背包 0/40", fontSize = 17, fontWeight = "bold", fontColor = COLORS.ink },
                            UI.Panel {
                                flexDirection = "row", gap = 6,
                                children = {
                                    UI.Button { id = "equipSortButton", text = "整理背包", width = 86, height = 32, fontSize = 10, backgroundColor = { 240, 190, 80, 255 }, textColor = COLORS.ink, onClick = callbacks.onSortInventory },
                                    UI.Label { id = "equipMaterialLabel", text = "材料 0", fontSize = 10, fontColor = COLORS.muted },
                                },
                            },
                        },
                    },
                    UI.Divider { orientation = "horizontal", thickness = 1, color = { 190, 132, 75, 255 }, spacing = 1 },
                    UI.ScrollView {
                        id = "equipBagScroll", scrollY = true, showScrollbar = true, bounces = true,
                        flexGrow = 1, flexBasis = 0,
                        children = {
                            UI.Panel {
                                id = "equipBagList",
                                width = "100%",
                                flexDirection = "row", flexWrap = "wrap",
                                rowGap = 8, columnGap = 8,
                            },
                        },
                    },
                    UI.Panel {
                        height = 38, flexDirection = "row", alignItems = "center", justifyContent = "spaceBetween",
                        paddingHorizontal = 10, borderRadius = 10,
                        backgroundColor = { 222, 174, 105, 220 },
                        children = {
                            UI.Label { text = "铜钱  ·  江湖历练所得", fontSize = 11, fontColor = COLORS.ink },
                            UI.Label { text = "整理背包", fontSize = 12, fontWeight = "bold", fontColor = COLORS.gold },
                        },
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 装备与背包浮层：页签 = 穿戴与背包 / 底材图鉴 / 词缀池
-- 内容由 main 动态构建；ShowEquipmentPage 控制当前可见页
-- ============================================================================
function M._buildEquipmentOverlay(callbacks)
    local tabBtns = {}
    local function selectTab(page)
        tabBtns.equip:SetVariant(page == "equip" and "primary" or "secondary")
        tabBtns.catalog:SetVariant(page == "catalog" and "primary" or "secondary")
        tabBtns.affix:SetVariant(page == "affix" and "primary" or "secondary")
        tabBtns.legend:SetVariant(page == "legend" and "primary" or "secondary")
        if callbacks.onEquipmentPage then
            callbacks.onEquipmentPage(page)
        end
    end
    tabBtns.equip = makeTab("equipTabBtn", "穿戴与背包", true, function() selectTab("equip") end)
    tabBtns.catalog = makeTab("catalogTabBtn", "底材图鉴", false, function() selectTab("catalog") end)
    tabBtns.affix = makeTab("affixTabBtn", "词缀池", false, function() selectTab("affix") end)
    tabBtns.legend = makeTab("legendTabBtn", "传奇图鉴", false, function() selectTab("legend") end)

    local panel = makeModalFrame("equipPanel", 1080, 700)
    panel:AddChild(makeModalHeader("行囊与装备", "收纳掉落、整理装备、查看底材与传奇图鉴", "equipCloseButton", callbacks.onCloseEquipment))
    panel:AddChild(UI.Panel {
        flexDirection = "row", gap = 8,
        children = { tabBtns.equip, tabBtns.catalog, tabBtns.affix, tabBtns.legend },
    })
    panel:AddChild(UI.Panel {
        id = "equipContent",
        position = "relative", flexGrow = 1, flexBasis = 0,
        children = {
            buildEquipmentMainPage(callbacks),
                            -- 页2：底材图鉴
                            UI.Panel {
                                id = "catalogBody",
                                position = "absolute",
                                left = 0,
                                top = 0,
                                width = "100%",
                                height = "100%",
                                visible = false,
                                flexDirection = "row",
                                gap = 10,
                                children = {
                                    UI.Panel {
                                        id = "catalogLeftCol",
                                        width = 190,
                                        flexDirection = "column",
                                        gap = 4,
                                        children = {
                                            UI.Label { text = "装备分类", fontSize = 12, fontColor = COLORS.muted },
                                            UI.ScrollView {
                                                id = "catalogCatScroll",
                                                scrollY = true,
                                                showScrollbar = true,
                                
                                                flexGrow = 1,
                                                flexBasis = 0,
                                                children = {
                                                    UI.Panel { id = "catalogCatList", flexDirection = "column", gap = 3, width = "100%" },
                                                },
                                            },
                                        },
                                    },
                                    UI.Panel {
                                        id = "catalogMidCol",
                                        width = 260,
                                        flexDirection = "column",
                                        gap = 4,
                                        children = {
                                            UI.Label { id = "catalogItemTitle", text = "选择分类查看底材", fontSize = 12, fontColor = COLORS.muted },
                                            UI.ScrollView {
                                                id = "catalogItemScroll",
                                                scrollY = true,
                                                showScrollbar = true,
                                
                                                flexGrow = 1,
                                                flexBasis = 0,
                                                children = {
                                                    UI.Panel { id = "catalogItemList", flexDirection = "column", gap = 3, width = "100%" },
                                                },
                                            },
                                        },
                                    },
                                    UI.Panel {
                                        id = "catalogRightCol",
                                        flexGrow = 1,
                                        flexShrink = 1,
                                        flexDirection = "column",
                                        gap = 4,
                                        children = {
                                            UI.Label { id = "catalogDetailTitle", text = "底材详情", fontSize = 12, fontColor = COLORS.muted },
                                            UI.ScrollView {
                                                id = "catalogDetailScroll",
                                                scrollY = true,
                                                showScrollbar = true,
                                
                                                flexGrow = 1,
                                                flexBasis = 0,
                                                children = {
                                                    UI.Label { id = "catalogDetailText", text = "点击左侧分类与中部底材查看基础词缀。", fontSize = 11, fontColor = COLORS.text, lineHeight = 1.5 },
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                            -- 页3：词缀池（全量浏览）
                            UI.Panel {
                                id = "affixBody",
                                position = "absolute",
                                left = 0,
                                top = 0,
                                width = "100%",
                                height = "100%",
                                visible = false,
                                flexDirection = "row",
                                gap = 10,
                                children = {
                                    UI.Panel {
                                        id = "affixLeftCol",
                                        width = 200,
                                        flexDirection = "column",
                                        gap = 4,
                                        children = {
                                            UI.Label { text = "词缀分类", fontSize = 12, fontColor = COLORS.muted },
                                            UI.ScrollView {
                                                id = "affixCatScroll",
                                                scrollY = true,
                                                showScrollbar = true,
                                
                                                flexGrow = 1,
                                                flexBasis = 0,
                                                children = {
                                                    UI.Panel { id = "affixCatList", flexDirection = "column", gap = 3, width = "100%" },
                                                },
                                            },
                                        },
                                    },
                                    UI.Panel {
                                        id = "affixRightCol",
                                        flexGrow = 1,
                                        flexShrink = 1,
                                        flexDirection = "column",
                                        gap = 4,
                                        children = {
                                            UI.Label { id = "affixListTitle", text = "全量词缀（4282）· 选择分类浏览", fontSize = 12, fontColor = COLORS.muted },
                                            UI.ScrollView {
                                                id = "affixListScroll",
                                                scrollY = true,
                                                showScrollbar = true,
                                
                                                flexGrow = 1,
                                                flexBasis = 0,
                                                children = {
                                                    UI.Panel { id = "affixList", flexDirection = "column", gap = 2, width = "100%" },
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                            -- 页4：传奇图鉴（基础 + 腐蚀版条目）
                            UI.Panel {
                                id = "legendBody",
                                position = "absolute",
                                left = 0,
                                top = 0,
                                width = "100%",
                                height = "100%",
                                visible = false,
                                flexDirection = "row",
                                gap = 10,
                                children = {
                                    UI.Panel {
                                        id = "legendLeftCol",
                                        width = 160,
                                        flexDirection = "column",
                                        gap = 4,
                                        children = {
                                            UI.Label { text = "部位", fontSize = 12, fontColor = COLORS.muted },
                                            UI.ScrollView {
                                                id = "legendCatScroll",
                                                scrollY = true,
                                                showScrollbar = true,
                                
                                                flexGrow = 1,
                                                flexBasis = 0,
                                                children = {
                                                    UI.Panel { id = "legendCatList", flexDirection = "column", gap = 3, width = "100%" },
                                                },
                                            },
                                        },
                                    },
                                    UI.Panel {
                                        id = "legendMidCol",
                                        width = 300,
                                        flexDirection = "column",
                                        gap = 4,
                                        children = {
                                            UI.Label { id = "legendItemTitle", text = "选择部位查看传奇", fontSize = 12, fontColor = COLORS.muted },
                                            UI.ScrollView {
                                                id = "legendItemScroll",
                                                scrollY = true,
                                                showScrollbar = true,
                                
                                                flexGrow = 1,
                                                flexBasis = 0,
                                                children = {
                                                    UI.Panel { id = "legendItemList", flexDirection = "column", gap = 3, width = "100%" },
                                                },
                                            },
                                        },
                                    },
                                    UI.Panel {
                                        id = "legendRightCol",
                                        flexGrow = 1,
                                        flexShrink = 1,
                                        flexDirection = "column",
                                        gap = 4,
                                        children = {
                                            UI.Label { id = "legendDetailTitle", text = "传奇详情", fontSize = 12, fontColor = COLORS.muted },
                                            UI.ScrollView {
                                                id = "legendDetailScroll",
                                                scrollY = true,
                                                showScrollbar = true,
                                
                                                flexGrow = 1,
                                                flexBasis = 0,
                                                children = {
                                                    UI.Label { id = "legendDetailText", text = "点击左侧部位与中部传奇查看详情；可「试用入库」穿戴体验。", fontSize = 11, fontColor = COLORS.text, lineHeight = 1.5 },
                                                },
                                            },
                                            UI.Panel {
                                                id = "legendTryRow",
                                                flexDirection = "row",
                                                gap = 8,
                                                alignItems = "center",
                                                children = {
                                                    UI.Button { id = "legendTryButton", text = "试用入库", variant = "primary", width = 120, height = 34, fontSize = 12, onClick = callbacks.onLegendTry },
                                                    UI.Label { id = "legendTryHint", text = "生成一件当前详情传奇放入背包（可穿戴体验）", fontSize = 10, fontColor = COLORS.muted, flexShrink = 1 },
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                        },
            })

    return UI.Panel {
        id = "equipOverlay",
        position = "absolute", left = 0, top = 0,
        width = "100%", height = "100%", visible = false,
        flexDirection = "row", justifyContent = "center", alignItems = "center",
        backgroundColor = { 25, 15, 10, 205 }, backdropBlur = 5,
        pointerEvents = "auto",
        children = { panel },
    }
end

-- 装备浮层页签切换（main 侧保持 visible 一致性）
function M.ShowEquipmentPage(root, page)
    local bodyMap = {
        equip = "equipBody",
        catalog = "catalogBody",
        affix = "affixBody",
        legend = "legendBody",
    }
    for name, id in pairs(bodyMap) do
        local w = root:FindById(id)
        if w then
            w:SetVisible(name == page)
        end
    end
end

-- ============================================================================
-- 地图选择浮层
-- ============================================================================
function M._buildMapOverlay(callbacks)
    local panel = makeModalFrame("mapPanel", 600, 520)
    panel:AddChild(makeModalHeader("江湖地图", "选择挂机试炼所在区域，地图难度决定掉落等级", "mapCloseButton", callbacks.onCloseMap))
    panel:AddChild(UI.Panel {
        flexDirection = "row", gap = 8,
        children = {
            makeInfoCard("当前区域", "荒山古径", COLORS.gold),
            makeInfoCard("掉落等级", "随难度变化", COLORS.accent),
            makeInfoCard("首领进度", "击杀普通敌人", COLORS.damage),
        },
    })
    panel:AddChild(UI.ScrollView {
        id = "mapListScroll", scrollY = true, showScrollbar = true, bounces = true,
        flexGrow = 1, flexBasis = 0,
        children = { UI.Panel { id = "mapList", flexDirection = "column", gap = 8, width = "100%" } },
    })
    panel:AddChild(UI.Panel {
        padding = 8, borderRadius = 10, backgroundColor = { 230, 192, 137, 180 },
        children = { UI.Label { id = "mapDescLabel", text = "地图难度由所选地图决定", fontSize = 10, fontColor = COLORS.ink, whiteSpace = "normal" } },
    })

    return UI.Panel {
        id = "mapOverlay",
        position = "absolute", left = 0, top = 0,
        width = "100%", height = "100%", visible = false,
        flexDirection = "row", justifyContent = "center", alignItems = "center",
        backgroundColor = { 25, 15, 10, 205 }, backdropBlur = 5,
        pointerEvents = "auto",
        children = { panel },
    }
end

function M._buildPauseOverlay(callbacks)
    local pausePanel = makeModalFrame("pausePanel", 420, 300)
    pausePanel:AddChild(makeModalHeader("暂停", "挂机进度已暂停", "pauseCloseButton", callbacks.onResume))
    pausePanel:AddChild(UI.Button { id = "pauseResumeButton", text = "继续挂机", height = 48, fontSize = 16, fontWeight = "bold", backgroundColor = { 255, 208, 105, 255 }, textColor = COLORS.ink, onClick = callbacks.onResume })
    pausePanel:AddChild(UI.Button { id = "pauseMenuButton", text = "返回主菜单", height = 48, fontSize = 16, backgroundColor = { 238, 185, 132, 255 }, textColor = COLORS.ink, onClick = callbacks.onMainMenu })

    local menuPanel = makeModalFrame("mainMenuPanel", 520, 420)
    menuPanel:AddChild(makeModalHeader("默江湖", "挂机试炼 · 当前进度已保存", "mainMenuCloseButton", callbacks.onResume))
    menuPanel:AddChild(UI.Label { id = "mainMenuProgress", text = "继续你的江湖历练", fontSize = 15, fontWeight = "bold", fontColor = COLORS.ink, textAlign = "center", whiteSpace = "normal" })
    menuPanel:AddChild(UI.Button { id = "mainMenuContinueButton", text = "继续游戏", height = 52, fontSize = 17, fontWeight = "bold", backgroundColor = { 255, 208, 105, 255 }, textColor = COLORS.ink, onClick = callbacks.onResume })
    menuPanel:AddChild(UI.Button { id = "mainMenuMapButton", text = "选择地图", height = 48, fontSize = 15, backgroundColor = { 239, 201, 153, 255 }, textColor = COLORS.ink, onClick = callbacks.onMenuMap })
    menuPanel:AddChild(UI.Button { id = "mainMenuExitButton", text = "返回战斗", height = 44, fontSize = 14, backgroundColor = { 220, 170, 117, 255 }, textColor = COLORS.ink, onClick = callbacks.onResume })

    return UI.Panel {
        id = "pauseRootOverlay", position = "absolute", left = 0, top = 0,
        width = "100%", height = "100%", pointerEvents = "box-none",
        children = {
            UI.Panel { id = "pauseOverlay", position = "absolute", left = 0, top = 0, width = "100%", height = "100%", visible = false, flexDirection = "row", justifyContent = "center", alignItems = "center", backgroundColor = { 25, 15, 10, 205 }, pointerEvents = "auto", children = { pausePanel } },
            UI.Panel { id = "mainMenuOverlay", position = "absolute", left = 0, top = 0, width = "100%", height = "100%", visible = false, flexDirection = "row", justifyContent = "center", alignItems = "center", backgroundColor = { 25, 15, 10, 220 }, pointerEvents = "auto", children = { menuPanel } },
        },
    }
end

-- ============================================================================
-- 单位槽位更新（由 main 每帧调用）
-- units: { kind, name, x, y, radius, life, maxLife, scale }
-- fieldRect: { x, y, w, h } 战场像素区域（WorldWidth/WorldHeight 为米）
-- ============================================================================
function M.UpdateField(root, units, fieldRect, worldW, worldH)
    local slots = M.UnitSlots
    if not slots then return end
    worldW = worldW or 16
    worldH = worldH or 9
    local fx = fieldRect.x or 0
    local fy = fieldRect.y or 0
    local fw = fieldRect.w or 800
    local fh = fieldRect.h or 300
    local pxPerM = fw / worldW

    local unitList = {}
    for i = 1, UNIT_SLOT_MAX do
        local slotDef = slots[i]
        local unit = units[i]
        if not unit then
            slotDef.widget:SetVisible(false)
            unitList[i] = nil
        else
            local kind = unit.kind or "enemy"
            local avatarSize = math.max(30, math.floor((unit.radius or 0.5) * 2 * pxPerM * (unit.scale or 1.0)))
            local wrapW = avatarSize + 6
            local wrapH = avatarSize + 12
            local cx = fx + (unit.x / worldW) * fw
            local cy = fy + (unit.y / worldH) * fh
            slotDef.widget:SetVisible(true)
            slotDef.widget:SetStyle({
                left = math.floor(cx - wrapW / 2),
                top = math.floor(cy - wrapH / 2),
                width = wrapW,
                height = wrapH,
            })
            slotDef.avatar:SetStyle({
                width = avatarSize,
                height = avatarSize,
                borderRadius = math.floor(avatarSize / 2),
                borderColor = ringColorFor(kind),
                backgroundImage = avatarImageFor(kind),
            })
            local hpRatio = (unit.maxLife and unit.maxLife > 0) and (math.max(0.0, unit.life or 0.0) / unit.maxLife) or 1.0
            slotDef.hpBar:SetMax(1)
            slotDef.hpBar:SetValue(hpRatio)
            slotDef.hpBar:SetStyle({ width = avatarSize - 4 })
            unitList[i] = unit
        end
    end
    M.LastFieldUnits = unitList
end

function M.UpdateFeedback(root, feedbacks, fieldRect, worldW, worldH)
    local panel = root:FindById("combatFeedback")
    if not panel then return end
    panel:ClearChildren()
    for i, entry in ipairs(feedbacks or {}) do
        local x = (entry.x / (worldW or 16)) * (fieldRect.w or 800)
        local y = (entry.y / (worldH or 9)) * (fieldRect.h or 300)
        local color = entry.kind == "crit" and { 255, 224, 75, 255 } or (entry.color == "poison" and { 93, 210, 91, 255 } or { 255, 245, 226, 255 })
        panel:AddChild(UI.Label {
            id = "combatFeedback_" .. i,
            position = "absolute", left = x - 36, top = y - 24,
            width = 72, height = 24,
            text = entry.text,
            fontSize = entry.kind == "crit" and 16 or 12,
            fontWeight = "bold", textAlign = "center",
            fontColor = color,
            textStroke = { width = 2, color = { 68, 31, 20, 255 } },
            opacity = math.max(0.0, math.min(1.0, entry.remain)),
            pointerEvents = "none",
        })
    end
end

function M.UpdateBossWarning(root, warning, fieldRect, worldW, worldH)
    local panel = root:FindById("bossWarning")
    if not panel then return end
    if not warning or warning.remain <= 0.0 then
        panel:SetVisible(false)
        return
    end
    panel:SetVisible(true)
    local cx = (warning.x / (worldW or 16)) * (fieldRect.w or 800)
    local cy = (warning.y / (worldH or 9)) * (fieldRect.h or 300)
    local diameter = (warning.radius / (worldW or 16)) * (fieldRect.w or 800) * 2.0
    panel:SetStyle({ left = cx - diameter / 2, top = cy - diameter / 2, width = diameter, height = diameter, borderRadius = diameter / 2, opacity = 0.45 + 0.35 * math.sin(warning.remain * 12.0) })
end

function M.SetText(root, id, text)
    local widget = root:FindById(id)
    if widget then
        widget:SetText(text)
    end
end

function M.SetBar(root, id, value, maxValue)
    local widget = root:FindById(id) --[[@as ProgressBar?]]
    if widget then
        widget:SetMax(maxValue)
        widget:SetValue(value)
    end
end

function M.SetVisible(root, id, visible)
    local widget = root:FindById(id)
    if widget then
        widget:SetVisible(visible)
    end
end

function M.IsVisible(root, id)
    local widget = root:FindById(id)
    if widget then
        return widget.visible
    end
    return false
end

function M.Shutdown()
    UI.Shutdown()
    M.UnitSlots = nil
end

return M
