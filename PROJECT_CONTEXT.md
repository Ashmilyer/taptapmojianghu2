# 项目上下文

最后更新：2026-09-13 22:07:00
记忆版本：18

## QUICK_INDEX
> 本区是每次任务开始优先读取的快速索引。

### 当前入口
- scripts/main.lua

### 代码托管
- 远程仓库：https://github.com/Ashmilyer/taptapmojianghu2.git（分支 main）
- 提交者：Ashmilyer <Ashmilyer@users.noreply.github.com>
- 最近推送：9f74f12 上传默江湖游戏代码与资源（81 个文件，41755 行）
- 上传范围：scripts/、assets/、.project/、项目记忆文件、.gitignore
- 不上传：dist/、.build/、.cli/、.emmylua/、logs/、.tmp/、save.json、screenshots/、game_material/、引擎知识目录
- 认证方式：HTTPS + fine-grained PAT，需 Contents: Read and write；Token 不写入 .git/config

### 当前架构
- 项目类型：单机 2D 俯视角空间挂机战斗原型
- 运行模式：单机
- UI 系统：urhox-libs/UI（Yoga UI）；逐件绘制模式：11 个独立装备格围绕角色立绘，背包固定 40 个独立格，每个格子含图标、品质边框、名称/等级；完整浮层包括背包/装备、招式、专属精研、换图、暂停/主菜单
- 战斗表现：俯视战场（约2/3屏，背景图 + 圆形头像单位槽 + 血条）；自动索敌/走位/出手；五类敌人（近战/远程/重甲/毒伤/召唤祭司）；远程保持距离，毒伤5秒持续效果，祭司8秒召唤援军；首领70%/40%阶段切换、召唤援军、范围攻击1.2秒预警；战斗反馈浮动伤害/暴击/毒伤数字
- 角色属性：根骨、灵巧、元气
- 战斗术语：生命、内力、真气、物理/阳性/阴性/混元/毒素
- 召唤系统：召唤物独立单位（上限 1+summonCountBonus，随技法冷却自动重召，自动索敌普攻，可承担敌人仇恨）；召唤物伤害/攻速/移速/数量上限词缀真实生效（AffixSummonPool 77 条）；本地模板 12（元素之灵×5/智械/模组化/贯注×5）
- 装备系统：11个装备位置；TLIDB 武器数据映射为武侠兵器；外攻武器提供外攻点伤，内攻武器保留网站法术附加点伤
- 掉落/词缀：击杀掉落（普通20%、首领必掉2件）；掉落底材=图鉴底材+1~2条可解释词缀；词缀真实生效（点伤/%伤害/攻速/主属性/生命护甲/抗性）；背包容量40
- 词缀机制：AffixFullPool 全量池 2061 条可解析词缀参与掉落（按底材类别+词缀 level≤物品等级过滤）；除常用词缀外还支持暴击伤害%/移速%/技能范围%/冷却回复%/生命护盾返还%/抗性穿透%/全属性/泛伤害%/元素抗性%/「该装备」本地百分比
- 装备图鉴 UI：装备浮层四页签（穿戴与背包 / 底材图鉴652 / 词缀池4282全量浏览按分类过滤 / 传奇图鉴）
- 传奇装备：LegendGearData 314 件 TLIDB 传奇（基础 + 腐蚀双版本共 627 条目，图鉴第四页签）；试装入库 = ItemFactory.CreateLegend 按固定词缀生成（可解析词缀掷值生效 1485 条/特殊句展示 1604 条），穿戴体验不开放掉落；武侠名保留原译（仅 9 条定向改西式词）
- 技能分类：62外攻招式 / 56内攻招式 / 85通用精研 + 12 本地召唤/智械/贯注模板 / 20辅助功法 / 293专属精研（0 未绑定）
- 专属精研：招式级强化宝石（TLIDB 华贵/崇高辅助技能）；外攻/内攻各 1 精研槽，装备后该招式伤害独立乘区 ×(1+bonus/100)，基底 bonus=20；精研浮层按招式列其可用专属精研（RefinesByTarget），点击装备/卸下；换招式自动卸下；245 条已绑定、48 条未绑定（召唤之灵/智械/贯注 base 未接入）仅浏览不入装配；变体机制句保留 details（逐条精修数值后续 RefineEffects 表）
- 通用精研（原通用技法）：技法槽 ×2（技能栏「精研一/二」），战斗中按冷却自动释放；31 条已手工映射（TechniqueEffects：防护减伤/激发增益/灵药回复/战吼/诅咒易伤）；位移/哨卫/召唤/智械等 54 条未接入（行标「未接入原型」可装配不参战）
- 辅助功法：功法槽 ×2（技能栏「功法一/二」），常驻被动装备即生效；SkillAuraData 每级效果值（L20÷20），功法 L1（升级预留）；AuraSystem 聚合 → AttributeSystem.Build 三参并入；魔力封印占用内力上限，双 50% 功法封印至 0
- 招式等级：上限 20 级（1→20），20 级后通过其他增幅手段突破（待设计）
- 存档：完整进度自动保存（每60秒 + 换图/退出），File+cjson 存 save.json（背包/穿戴/金币经验/地图/技能槽/击杀波次）
- 成长系统：1—100级总经验表；每级根骨/灵巧/元气 +1，生命上限 +10、内力上限 +5、真气上限 +1；升级恢复三项资源；HUD 显示等级、经验条、当前经验/下一级经验
- 地图系统：三张地图独立解锁（荒山古径推荐等级1、青石峡推荐等级20、云顶古战场推荐等级40）；地图 UI 显示推荐等级与解锁条件；青石峡/云顶普通敌人经验分别为190706/2018334
- 掉落经济：首领额外10%传奇掉落概率；普通/首领掉落接入背包；装备支持穿戴、出售、分解与一键整理；传奇装备不可出售、不可分解；材料数量显示；装备详情包含比较信息
- 伤害公式：(基础点伤+附加点伤)×(1+普通伤害加成之和)×各额外伤害加成独立乘区
- 寻怪规则：基础15秒；移动速度基础5.0 m/s，每+10%减1%寻怪时间；位移每次减1秒；最低2秒
- 构建入口：main.lua

### 任务关键词定位
| 用户可能说 | 优先读取文件 | 关键定义 | 注意事项 |
|-----------|-------------|----------|----------|
| 角色属性 / 根骨 / 灵巧 / 元气 | scripts/Data/GameData.lua、scripts/Systems/AttributeSystem.lua | Character、Build、GetDodgeRate | 闪避使用非线性乘算；不要改回力量/敏捷/智慧 |
| 外攻 / 内攻 / 招式 / 伤害 | scripts/Data/GameData.lua、scripts/Data/EquipmentData.lua、scripts/Systems/DamageSystem.lua | Skills、Weapons、CalculatePlayerDamage | 外攻点伤=武器点伤总和；内攻基础点伤来自招式+法术附加；招式伤害倍率在 SkillBattleStats |
| 技能库 / 招式总览 / 换招 / 选取招式 | scripts/Data/SkillData.lua、scripts/Data/SkillBattleStats.lua、scripts/main.lua | OuterSkills、InnerSkills、GeneralSkills、SkillBattleStats、BuildEquippedSkill、EquipSkill | 外攻/内攻各1槽可换；辅助类已改名为「通用精研」勿再用 SupportSkills/通用技法 |
| 召唤类技能 / 召唤物 / 元素之灵 / 贯注 | scripts/Data/SkillSummonData.lua、scripts/Systems/BattleSim.lua、scripts/Systems/ItemFactory.lua | SummonSkills、Archetypes、LibrarySummonMap、TrySummon、SummonUpdate | 元素之灵/智械/模组化为本地模板（TLIDB 无页）；召唤物上限=1+summonCountBonus；精研一/二槽技能可装配其专属精研 |
| 专属精研 / 精研槽 / 华贵 / 崇高 / 招式强化 | scripts/Data/SkillRefineData.lua、scripts/main.lua、scripts/UI/BattleUI.lua、scripts/Systems/DamageSystem.lua | RefineSkills、RefinesByTarget、refineEquip_、SyncRefineBonus、refineBonusPct、EquipRefineSlot | 精研只能装配到 refineTargetId 匹配的招式；数值=基底 bonus 20% 独立乘区（变体机制未精修）；未绑定48条不入装配；存档 refineOuterId/refineInnerId |
| 通用精研 / 精研槽 / 主动增益 / 自动释放 | scripts/Systems/TechniqueEffects.lua、scripts/Systems/BattleSim.lua、scripts/main.lua | Effects、HasEffect、techniqueSlots、EquipTechnique、pendingTechniqueSlot_ | 精研槽×2按冷却自动释放；未映射技法是静默跳过非报错；buff 单位：damageReducePct/critDamagePct 存百分数其余存小数 |
| 辅助功法 / 功法槽 / 光环 / 常驻被动 | scripts/Data/SkillAuraData.lua、scripts/Systems/AuraSystem.lua、scripts/Systems/AttributeSystem.lua、scripts/main.lua | AuraSkills、Aggregate、Build(…,auraAddon)、EquipAura、pendingAuraSlot_ | 功法每级效果值=L20÷20，默认L1；功法聚合 stat 通道名走 STAT_BONUS_CHANNEL（meleeDamage→melee）；魔力封印占用内力上限 |
| 战场 / 空间战斗 / 俯视 / 波次 / 首领 / BOSS | scripts/Systems/BattleSim.lua、scripts/UI/BattleUI.lua、scripts/main.lua | Create、Update、SpawnWave、SpawnBoss、onKill | 击杀回调 onKill 挂掉落；换装后调 sim:ApplyAttributes 同步 |
| 地图 / 难度 | scripts/Data/MapData.lua | Maps、enemy、boss、difficulty | 单图「荒山古径」；掉落等级=max(1,难度×20) |
| 技能空间字段 | scripts/Data/SkillSpaceData.lua | Space（shape/range/radius/angle/targetCount） | 118 参战技能空间字段完整 |
| 寻怪 / 移速 / 位移 | scripts/Systems/IdleSystem.lua、scripts/Systems/BattleSim.lua | GetSearchTime、StartSearch | 基础移速5.0 m/s；寻怪减时规则不变 |
| 暴击 / 暴击值 / 暴击几率 / 暴击伤害 | scripts/Systems/AttributeSystem.lua、scripts/Data/GameData.lua | GetFinalCritValue、GetCritChance、baseCrit | 外攻读武器、内攻读招式baseCrit；掉落词缀+%暴击值走 critValuePercentBonus |
| 装备 / 武器 / 装备栏 / 11槽 | scripts/Data/EquipmentData.lua、scripts/Systems/EquipmentSystem.lua、scripts/Systems/Inventory.lua、scripts/main.lua | Slots、CreateDefaultLoadout、Aggregate、EquipFromBag、UnequipSlot、ResolveSlotKey | 换装经 Inventory 操作 GameData.Loadout；戒指自动进空位否则替换 ring1 |
| 传奇装备 / 传奇图鉴 / 腐蚀版 / 试用 | scripts/Data/LegendGearData.lua、scripts/Systems/ItemFactory.lua、scripts/main.lua | Legends、CreateLegend、RefreshLegendPanel、TryLegendItem | 627 条目（314 基础 + 313 腐蚀）；词缀可解析生效/特殊句 legendTexts 展示；试用入库不入掉落 |
| 掉落 / 掉落装备 / 词缀 roll | scripts/Systems/LootSystem.lua、scripts/Systems/ItemFactory.lua、scripts/Data/AffixFullPool.lua | RollDrop、CreateDrop、RollAffixes | 全量池 2061 条按类别+level 过滤；词缀 level 需 ≤ 物品等级 |
| 词缀 / 词缀解析 / 生效 | scripts/Systems/AffixParser.lua | ParseEffect、ParseBands、FormatRolledEffect | ⚠️ Lua pattern 不支持 | 分支，全部用并列匹配；%检测用 find("%",1,true) 不能用 "%%"；机制词缀走 bonuses 新通道 |
| 图鉴 / 底材浏览 / 词缀浏览 | scripts/Data/EquipmentCatalog.lua、scripts/Data/AffixData.lua、scripts/main.lua、scripts/UI/BattleUI.lua | catalogBody、affixBody、RefreshCatalogPanel、RefreshAffixPanel | 装备浮层三页签；词缀池默认只渲染前300行，选分类看全量 |
| 背包 / 容量 / 拾取 | scripts/Systems/Inventory.lua | Count、IsFull、Add、RemoveAt | 容量40 |
| 存档 / 读档 / 保存进度 | scripts/Systems/Inventory.lua、scripts/main.lua | Save、Load、SaveNow、LoadSave | save.json 相对路径；File+cjson；禁止 io 库 |
| UI / HUD / 面板 / 血条 / 装备面板 | scripts/UI/BattleUI.lua | BuildRoot、SetText、SetBar、equipOverlay | Yoga UI；暖色完整面板；equipOverlay 内容由 main.RefreshEquipmentPanel 动态重建；招式/精研/换图浮层同一视觉规范 |
| 图鉴 / 底材 / 词缀池 / 传奇图鉴 | scripts/Data/EquipmentCatalog.lua、scripts/Data/AffixData.lua、scripts/Data/LegendGearData.lua、scripts/main.lua、scripts/UI/BattleUI.lua | catalogBody、affixBody、legendBody、RefreshCatalogPanel、RefreshAffixPanel、RefreshLegendPanel | 装备浮层四页签；词缀池默认只渲染前300行，选分类看全量；传奇图鉴默认预览260行 |
| 资源 / 角色图 / 战斗背景 | assets/image、assets/Fonts | 新挂机战斗素材 | 旧水墨、战棋格和旧视频已清理 |

### 活跃文件摘要
- scripts/main.lua：入口、地图选择、BattleSim 驱动、战场 HUD 刷新、招式总览（可选取换招）、专属精研装配浮层、装备浮层四页签动态构建、击杀掉落 hook、自动存档
- scripts/Data/GameData.lua：角色、默认两招式（流云剑式/青冥内息）、默认装备栏引用
- scripts/Data/SkillData.lua：TLIDB 全量 203 技能库（62外攻/56内攻/85通用精研，含 growth 表）
- scripts/Data/SkillAuraData.lua：20 条辅助功法（光环；每级效果值 L20÷20；manaSeal 内力占用；stats 通道表）
- scripts/Data/SkillRefineData.lua：293 条华贵/崇高专属精研（0 未绑定；bonus=20；details 全文）
- scripts/Data/SkillSummonData.lua：12 本地召唤/智械/贯注模板 + 14 召唤单位 archetype
- scripts/Data/AffixSummonPool.lua：召唤词缀补充池 77 条
- scripts/Data/SkillBattleStats.lua：118 参战技能 L1 战斗数值（自动生成：外攻 damageMultiplier、内攻 baseInnerAttack/damageMultiplier）
- scripts/Data/SkillSpaceData.lua：118 参战技能空间字段（shape/range/radius/angle/targetCount）
- scripts/Data/ProgressionData.lua：1—100级经验表、等级/进度/升级奖励计算；每级根骨/灵巧/元气、生命/内力/真气上限成长
- scripts/Data/MapData.lua：三张地图、推荐等级、独立首领解锁条件和各地图敌人经验
- scripts/Data/EquipmentData.lua：TLIDB 武器/防具一级数据、武侠兵器映射和装备位置
- scripts/Data/LegendGearData.lua：314 件 TLIDB 传奇（627 条目基础+腐蚀；武侠名+sourceName 原译；catalogId/category/slot；quote/affixTexts）
- scripts/Data/EquipmentCatalog.lua：TLIDB 全量 652 各等级底材图鉴（分类/需求等级/基础词缀/武侠名+sourceName）
- scripts/Data/AffixData.lua：TLIDB 全量 4282 词缀池（类型/来源/Tier/Level/Weight/效果原文）
- scripts/Data/AffixFullPool.lua：全量可掉落词缀池（自动生成 2061 条，带需求等级；可被 AffixParser 解析的单段语义词缀）
- scripts/Systems/BattleSim.lua：俯视空间战斗模拟（寻怪/波次/首领/索敌/走位/范围命中/onKill 掉落钩子/ApplyAttributes/返还回复/冷却回复/有效技能范围/通用技法自动释放与 buff 管理/ApplyPlayerDamage 减伤入口）
- scripts/Systems/AuraSystem.lua：辅助功法聚合（Aggregate → bonuses/baseAdd/multPct/resAdd/regen/manaSealPctSum）
- scripts/Systems/TechniqueEffects.lua：通用技法手工映射表（31 条）与 HasEffect
- scripts/Systems/EquipmentSystem.lua：装备区间保留、装备属性聚合和中值代表值（含词缀 bonuses 全通道聚合与 pierce 表）
- scripts/Systems/AttributeSystem.lua：三大属性和装备后派生属性计算、闪避非线性计算、词缀%加成全通道、GetCritDamageMultiplier、Build(character, loadout, auraAddon) 功法合并
- scripts/Systems/DamageSystem.lua：外攻/内攻伤害与抗性计算（招式伤害倍率、抗性穿透）、词缀点伤总和
- scripts/Systems/AffixParser.lua：词缀文本 → 结构化 modifier（点伤/速度/暴击/主属性/生命护盾护甲闪避/抗性/%伤害/%速度/%暴击值 + 暴击伤害%/移速%/技能范围%/冷却回复%/返还%/穿透%/全属性/泛伤害/元素抗性/该装备本地%）
- scripts/Systems/ItemFactory.lua：底材+词缀 → 运行时装备对象（uid/点伤/攻速/暴击/base/bonuses 全通道/affixTexts）；CreateLegend 传奇固定词缀构造
- scripts/Systems/LootSystem.lua：普通/首领掉落 roll、首领额外传奇10%概率、出售/分解价值计算与传奇保护
- scripts/Systems/Inventory.lua：背包（容量40）、11槽换装、出售/分解/排序、存档读写（File+cjson save.json）
- scripts/UI/BattleUI.lua：Yoga UI 俯视战场（圆形单位槽）、HUD、技能栏双行（功法/精研槽+外攻内攻+精研入口）、招式总览四页签浮层、专属精研装配浮层（_buildRefineOverlay）、地图/装备四页签浮层（含传奇图鉴）
- assets/image/侠客头像_20260908025115.png：玩家圆形头像
- assets/image/山魈头像_20260908025116.png：敌人/首领圆形头像
- assets/image/挂机战斗场景_20260907042337.png：俯视战场背景
- assets/Fonts/NotoSansSC-Black.ttf：中文 UI 字体

### 非活跃对象摘要
- 永久废弃：旧水墨叙事、旧战棋、旧 UI 编辑器、旧视频和旧角色资源、旧固定回合战斗 UI（立绘对撞式战斗舞台）
- 临时搁置：技能等级/升级、星宿观想/羽化词条（绝学类暂不设计）、词缀完整 4282 条解析（仅常用词缀参战）、离线收益、通用精研中位移/护盾/格挡类效果接入（UI 标「未接入原型」）、功法等级升级、专属精研变体机制逐条精修、传奇掉落开放（当前仅图鉴+试用入库）、传奇特殊句逐条精修、召唤物数值随地图平衡调整
- 禁用但无替代方案：多人模式
- 暂时保留：隐藏浮层内 ScrollView 首次布局会输出 Zero height warning；不影响 Lua/资源/截图验证，后续如需消除应调整浮层父级确定高度，而不是给 ScrollView 添加无效最小高度

### 历史决策索引
| 关键词 | 日志文件 | 条目ID |
|-------|----------|--------|
| 召唤类技能/召唤物/召唤词缀/48精研关联 | DECISIONS_LOG.md | D-20260908-008 |
| 全量传奇装备/传奇图鉴/腐蚀版 | DECISIONS_LOG.md | D-20260908-007 |
| 华贵/崇高专属精研/通用精研改名 | DECISIONS_LOG.md | D-20260908-006 |
| 通用技法/辅助功法/功法槽/技法槽 | DECISIONS_LOG.md | D-20260908-005 |
| 招式等级20级上限/突破增幅 | DECISIONS_LOG.md | D-20260908-003 |
| 图鉴UI/词缀全池/机制扩展 | DECISIONS_LOG.md | D-20260908-004 |
| 掉落/背包/换装/换招 | DECISIONS_LOG.md | D-20260908-002 |
| 新挂机战斗架构 | DECISIONS_LOG.md | D-20260907-001 |
| 旧项目整体替换 | DECISIONS_LOG.md | D-20260907-001 |
| 暴击值/暴击机制 | DECISIONS_LOG.md | D-20260907-005 |
| 全量技能库/招式总览 | DECISIONS_LOG.md | D-20260907-006 |
| 全量底材图鉴/词缀池 | DECISIONS_LOG.md | D-20260907-007 |
| 俯视空间战斗/波次/首领/地图难度 | DECISIONS_LOG.md | D-20260908-001 |

--- QUICK_INDEX_END ---

## DETAILS
当前版本为可运行的自动战斗 + 掉落装备 + 背包换装 + 招式换招原型。数据扩展优先在 Data 层；战斗/掉落在 Systems 层；界面在 UI 层。改 Lua 后 LSP 无 Error 再调官方 build。
