-- Optional DragonUI integration. Keep the original UI when its helpers are absent.
DungeonClearSkin = {}
local S = DungeonClearSkin
local D = _G.DragonUI
local N = _G.DragonUI_NineSlice or _G.NineSliceUtils
local F = D and D.ForeverUI
local CP = D and D.CharacterPanel
local windowLayout = N and N.GetLayout and N.GetLayout("NoPortraitFrameTemplate")
local insetLayout = N and N.GetLayout and N.GetLayout("InsetFrameTemplate")
S.enabled = D and D._dir and N and N.ApplyLayout and windowLayout and insetLayout

function S.CreateFrame(kind, name, parent, template)
    local control = CreateFrame(kind, name, parent, template)
    if S.enabled then
        if template == "UIPanelButtonTemplate" and D.SkinRedButton then
            D.SkinRedButton(control)
        elseif template == "UICheckButtonTemplate" then
            if F and F.SkinCheckButton then F.SkinCheckButton(control)
            elseif CP and CP.SkinCheckbox then CP.SkinCheckbox(control) end
        elseif template == "OptionsSliderTemplate" and F and F.SkinSlider then
            F.SkinSlider(control, { steppers = false })
        elseif template == "FauxScrollFrameTemplate" or template == "UIPanelScrollFrameTemplate" then
            if F and F.SkinScrollBar then F.SkinScrollBar(control)
            elseif CP and CP.ReskinScrollBar then
                CP.ReskinScrollBar(control, control, -7, 18, -7, true)
            end
        end
    end
    return control
end

local function tile(frame, file)
    local texture = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    texture:SetTexture(D._dir .. "UI\\" .. file, "REPEAT", "REPEAT")
    texture:SetHorizTile(true)
    texture:SetVertTile(true)
    texture:SetAllPoints(frame)
    return texture
end

function S.Inset(frame)
    if not S.enabled then return end
    frame:SetBackdrop(nil)
    tile(frame, "ui-background-marble")
    N.ApplyLayout(frame, insetLayout)
end

-- The tiny bar as a professions-style card: marble under the small filigree trim. The trim pieces
-- are the window's own ARTWORK regions so the bar's dots and text (OVERLAY) stay on top of them.
local function buildPill(frame)
    local layout = N.GetLayout and N.GetLayout("SmallInsetFrameTemplate") or insetLayout
    local marble = tile(frame, "ui-background-marble")
    local anchor = CreateFrame("Frame", nil, frame)
    anchor:SetAllPoints(frame)
    anchor:EnableMouse(false)
    local pieces = { marble }
    for _, key in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
            "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }) do
        local piece = frame:CreateTexture(nil, "ARTWORK")
        anchor[key] = piece
        pieces[#pieces + 1] = piece
    end
    N.ApplyLayout(anchor, layout)
    return function(shown)
        for _, piece in ipairs(pieces) do
            if shown then piece:Show() else piece:Hide() end
        end
    end
end

function S.Window(frame, header, close)
    if not S.enabled then return end
    local showPill = buildPill(frame)
    local rock = tile(frame, "ui-background-rock")
    rock:ClearAllPoints()
    rock:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -21)
    rock:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    local chrome = CreateFrame("Frame", nil, frame)
    chrome:SetAllPoints(frame)
    chrome:SetFrameLevel(frame:GetFrameLevel() + 30)
    chrome:EnableMouse(false)
    N.ApplyLayout(chrome, windowLayout)
    -- Title text must sit above the title-bar art.
    local title = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -5)
    title:SetText("Dungeon Clear")
    header:SetAlpha(0)
    close:SetFrameLevel(chrome:GetFrameLevel() + 5)
    if CP and CP.ModernizeCloseButton then
        CP.ModernizeCloseButton(close, chrome, 1, 0)
    end
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 0)
    -- A full title border cannot fit in the tiny bar's 28px, so it wears the small card instead.
    frame:SetBackdrop(nil)
    function S.Layout(tiny)
        showPill(tiny)
        if tiny then
            rock:Hide()
            chrome:Hide()
        else
            rock:Show()
            chrome:Show()
        end
    end
    S.Layout(DungeonClearDB.tinyMode)
end
-- ============================================================================
-- Objective tracker block (DragonUI's tracker; any DragonUI with AddCollector)
-- ============================================================================
-- While a clear runs, what the tank is doing reads like retail's dungeon block at the top of the
-- objectives: the dungeon as the title, the tank's current action, the next boss and the pull mode.
-- Off, in a dungeon or raid with a group, the block stays as a quiet "Not clearing" so the start is
-- one click away. Small icons do the controls (on a DragonUI whose tracker takes block buttons):
-- start or pause/resume and stop on the title row, the pull mode as the tiny bar's dot on its line.
-- Left-click opens the window; right-click holds the same controls as a menu.

local OT = D and D.ObjectiveTracker
local TANK_ICON = "Interface\\Icons\\Ability_Warrior_DefensiveStance"
local PULL_MODES = { { 0, "Leeroy" }, { 1, "Advanced" }, { 2, "Dynamic" } }
-- The Stopwatch's own play/pause pair (Blizzard_TimeManager swaps between exactly these two) and
-- the ready check's red cross for stop.
local PLAY_ICON = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
local PAUSE_ICON = "Interface\\TimeManager\\PauseButton"
local STOP_ICON = "Interface\\RaidFrame\\ReadyCheck-NotReady"
-- The tiny bar's pull dot: dark = Leeroy, green = Advanced, a blue disc = Dynamic.
local PULL_DOTS = {
    [0] = { icon = "Interface\\FriendsFrame\\StatusIcon-Offline", color = { 1, 1, 1 } },
    [1] = { icon = "Interface\\FriendsFrame\\StatusIcon-Online", color = { 1, 1, 1 } },
    [2] = { icon = "Interface\\CharacterFrame\\TempPortraitAlphaMask", color = { 0.30, 0.70, 1.00 },
        texCoord = { -0.35, 1.35, -0.35, 1.35 } },
}
-- A set pull mode reads dimmed until a clear runs on it, as on the tiny bar.
local IDLE_DIM = 0.6
local status, actions

local function trackerReady()
    return OT and OT.enabled and OT.AddCollector and OT.Refresh
        and DungeonClearDB and DungeonClearDB.trackerBlock ~= false
end

local function running()
    return status and status.on
end

-- Somewhere a clear could start: a dungeon or raid, with a group to clear it with.
local function idleHere()
    local inInstance, kind = IsInInstance()
    if not (inInstance and (kind == "party" or kind == "raid")) then return false end
    return (GetNumRaidMembers() or 0) > 0 or (GetNumPartyMembers() or 0) > 0
end

-- True while the block is in the tracker, so the tiny bar can step aside for it.
function S.TrackerShowing()
    return (trackerReady() and (running() or idleHere())) and true or false
end

local function pullMode()
    return status and status.pullMode or 2
end

local function startClear()
    if actions.start then actions.start() else actions.send("on") end
end

local function togglePause()
    actions.send("pause", status.paused and "resume" or "pause")
end

local function cyclePull()
    actions.send("pull", actions.pullCommand((pullMode() + 1) % 3))
end

local function blockMenu()
    local send = actions.send
    local entries = {}
    if running() then
        entries[#entries + 1] = { text = status.paused and "Resume" or "Pause", func = togglePause }
        entries[#entries + 1] = { text = "Skip Boss", func = function() send("skip") end }
    else
        entries[#entries + 1] = { text = "Start Clearing", func = startClear }
    end
    entries[#entries + 1] = { text = "Pull Mode", isTitle = true }
    for _, mode in ipairs(PULL_MODES) do
        local value, label = mode[1], mode[2]
        entries[#entries + 1] = { text = label, checked = function() return pullMode() == value end,
            func = function() send("pull", actions.pullCommand(value)) end }
    end
    if running() then
        entries[#entries + 1] = { text = "Stop Clearing", func = function() send("off") end }
    end
    entries[#entries + 1] = { text = "Open Dungeon Clear", func = actions.open }
    return entries
end

local function tip(title, hint)
    return function(tooltip)
        tooltip:SetText(title)
        tooltip:AddLine(hint, 0.8, 0.8, 0.8, true)
    end
end

local function pullButton(line)
    local dot = PULL_DOTS[pullMode()] or PULL_DOTS[2]
    local dim = running() and 1 or IDLE_DIM
    return { icon = dot.icon, texCoord = dot.texCoord, line = line,
        color = { dot.color[1] * dim, dot.color[2] * dim, dot.color[3] * dim },
        tooltip = tip("Pull Mode", "Click to cycle: Leeroy / Advanced / Dynamic"), onClick = cyclePull }
end

local function collect(blocks)
    if not S.TrackerShowing() then return end
    local lines, buttons
    if running() then
        lines = { { text = status.action } }
        if status.boss then
            lines[#lines + 1] = { text = "Next boss: |cffffd100" .. status.boss .. "|r" }
        end
        lines[#lines + 1] = { text = "Pull: " .. status.pull }
        buttons = {
            status.paused
                and { icon = PLAY_ICON, tooltip = tip("Resume", "Pick the clear back up"), onClick = togglePause }
                or { icon = PAUSE_ICON, tooltip = tip("Pause", "Hold the group where it stands"), onClick = togglePause },
            { icon = STOP_ICON, tooltip = tip("Stop Clearing", "Turn the clear off"),
                onClick = function() actions.send("off") end },
            pullButton(#lines),
        }
    else
        lines = { { text = "|cff999999Not clearing|r" },
            { text = "Pull: " .. (status and status.pull or "|cff808080Dynamic|r") } }
        buttons = {
            { icon = PLAY_ICON, tooltip = tip("Start Clearing", "The tank leads the group through the dungeon"),
                onClick = startClear },
            pullButton(2),
        }
    end
    -- First, the way retail stacks its dungeon block above the quests.
    table.insert(blocks, 1, {
        kind = "dungeonclear", title = GetRealZoneText() or "Dungeon Clear", icon = TANK_ICON,
        lines = lines, buttons = buttons, menu = blockMenu,
        onClick = function(_, button) if button ~= "RightButton" then actions.open() end end,
    })
end

-- `callbacks`: send(cmd, param), start(), open(), pullCommand(mode) and relayout() from DungeonClear.lua.
function S.BindTracker(callbacks)
    actions = callbacks
    if OT and OT.AddCollector then OT.AddCollector(collect) end
end

-- Repaints the block; the tiny bar re-lays out whenever the block comes or goes.
local lastShowing = false
local function repaint()
    if trackerReady() then OT.Refresh() end
    local showing = S.TrackerShowing()
    if showing == lastShowing then return end
    lastShowing = showing
    if actions and actions.relayout then actions.relayout() end
end

-- Called with every STATUS. `info` = { on, paused, action, boss, pull, pullMode }; on = false while off.
function S.Status(info)
    status = info
    repaint()
end

-- Zone and group changes decide whether the idle block belongs in the tracker.
S.Refresh = repaint
