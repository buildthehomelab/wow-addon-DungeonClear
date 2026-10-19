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
-- Left-click opens the window; right-click holds the controls the tiny bar had.

local OT = D and D.ObjectiveTracker
local TANK_ICON = "Interface\\Icons\\Ability_Warrior_DefensiveStance"
local PULL_MODES = { { 0, "Leeroy" }, { 1, "Advanced" }, { 2, "Dynamic" } }
local status, actions

local function trackerReady()
    return OT and OT.enabled and OT.AddCollector and OT.Refresh
        and DungeonClearDB and DungeonClearDB.trackerBlock ~= false
end

-- True while the block is in the tracker, so the tiny bar can step aside for it.
function S.TrackerShowing()
    return (trackerReady() and status and status.on) and true or false
end

local function blockMenu()
    if not status then return {} end
    local send = actions.send
    local entries = {
        { text = status.paused and "Resume" or "Pause", func = function()
            send("pause", status.paused and "resume" or "pause")
        end },
        { text = "Skip Boss", func = function() send("skip") end },
        { text = "Pull Mode", isTitle = true },
    }
    for _, mode in ipairs(PULL_MODES) do
        local value, label = mode[1], mode[2]
        entries[#entries + 1] = { text = label, checked = function() return status and status.pullMode == value end,
            func = function() send("pull", actions.pullCommand(value)) end }
    end
    entries[#entries + 1] = { text = "Stop Clearing", func = function() send("off") end }
    entries[#entries + 1] = { text = "Open Dungeon Clear", func = actions.open }
    return entries
end

local function collect(blocks)
    if not S.TrackerShowing() then return end
    local lines = { { text = status.action } }
    if status.boss then
        lines[#lines + 1] = { text = "Next boss: |cffffd100" .. status.boss .. "|r" }
    end
    lines[#lines + 1] = { text = "Pull: " .. status.pull }
    -- First, the way retail stacks its dungeon block above the quests.
    table.insert(blocks, 1, {
        kind = "dungeonclear", title = GetRealZoneText() or "Dungeon Clear", icon = TANK_ICON,
        lines = lines, menu = blockMenu,
        onClick = function(_, button) if button ~= "RightButton" then actions.open() end end,
    })
end

-- `callbacks`: send(cmd, param), open(), pullCommand(mode) and relayout() from DungeonClear.lua.
function S.BindTracker(callbacks)
    actions = callbacks
    if OT and OT.AddCollector then OT.AddCollector(collect) end
end

-- Called with every STATUS. `info` = { on, paused, action, boss, pull, pullMode }; nil when off.
function S.Status(info)
    local wasShowing = S.TrackerShowing()
    status = info
    if trackerReady() then OT.Refresh() end
    if wasShowing ~= S.TrackerShowing() and actions and actions.relayout then actions.relayout() end
end
