-- Run from the repository root with Lua 5.1. Optional argument: addon folder.
local addonDir = arg[1] or "DungeonClear"
local objects, calls = {}, {}
local function object()
    local o = { shown = true, level = 1 }
    function o:SetBackdrop(v) self.backdrop = v end
    function o:GetBackdrop() return self.backdrop end
    function o:CreateTexture() return object() end
    function o:CreateFontString() return object() end
    function o:GetFrameLevel() return self.level end
    function o:SetFrameLevel(v) self.level = v end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    setmetatable(o, { __index = function() return function() end end })
    objects[#objects + 1] = o
    return o
end
function CreateFrame() return object() end
local function loadSkin(dragon, nine)
    DragonUI, DragonUI_NineSlice, NineSliceUtils = dragon, nine, nil
    DungeonClearDB = {}
    dofile(addonDir .. '/Skin.lua')
    return DungeonClearSkin
end
local S = loadSkin(nil, nil)
assert(not S.enabled)
local frame, header, close = object(), object(), object()
frame.backdrop = { original = true }
S.Window(frame, header, close)
S.Inset(frame)
assert(frame.backdrop.original)
assert(not S.Layout)
S = loadSkin({ _dir = 'test' }, {})
assert(not S.enabled)
local function mark(name) return function() calls[name] = (calls[name] or 0) + 1 end end
local D = { _dir = 'test', SkinRedButton = mark('button'),
    CharacterPanel = { ModernizeCloseButton = mark('close') },
    ForeverUI = { SkinCheckButton = mark('check'), SkinSlider = mark('slider'), SkinScrollBar = mark('scroll') } }
local N = { GetLayout = function(name) return name end, ApplyLayout = mark('layout') }
S = loadSkin(D, N)
assert(S.enabled)
S.Window(frame, header, close)
assert(rawget(frame, "backdrop") == nil and calls.close == 1)
S.Layout(true)
assert(rawget(frame, "backdrop") == nil)
S.Layout(false)
assert(rawget(frame, "backdrop") == nil)
local pane = object()
pane.backdrop = {}
S.Inset(pane)
assert(rawget(pane, "backdrop") == nil)
for _, template in ipairs({'UIPanelButtonTemplate', 'UICheckButtonTemplate', 'OptionsSliderTemplate',
        'FauxScrollFrameTemplate', 'UIPanelScrollFrameTemplate'}) do
    S.CreateFrame('Frame', nil, frame, template)
end
assert(calls.button == 1 and calls.check == 1 and calls.slider == 1 and calls.scroll == 2)
-- Older DragonUI: no ForeverUI; button and panel skins still work.
D.ForeverUI = nil
D.CharacterPanel.SkinCheckbox = mark('oldCheck')
D.CharacterPanel.ReskinScrollBar = mark('oldScroll')
S = loadSkin(D, N)
S.CreateFrame('CheckButton', nil, frame, 'UICheckButtonTemplate')
S.CreateFrame('ScrollFrame', nil, frame, 'FauxScrollFrameTemplate')
assert(calls.oldCheck == 1 and calls.oldScroll == 1)
-- Tracker block: absent tracker never claims the status; an enabled one lists it first.
function GetRealZoneText() return 'Blackrock Depths' end
local where, partySize = { false }, 0
function IsInInstance() return where[1], where[2] end
function GetNumRaidMembers() return 0 end
function GetNumPartyMembers() return partySize end
local sent, opened, relayouts, started = {}, 0, 0, 0
local binds = { send = function(c, p) sent[#sent + 1] = c .. ':' .. tostring(p) end,
    start = function() started = started + 1 end,
    pullCommand = function(m) return ({ [0] = 'off', [1] = 'on', [2] = 'dynamic' })[m] end,
    relayout = function() relayouts = relayouts + 1 end, open = function() opened = opened + 1 end }
S.BindTracker(binds)
S.Status({ on = true, action = 'x', pull = 'Dynamic', pullMode = 2 })
assert(S.TrackerShowing() == false)
local collector, refreshed = nil, 0
D.ObjectiveTracker = { enabled = true, AddCollector = function(c) collector = c end,
    Refresh = function() refreshed = refreshed + 1 end }
S = loadSkin(D, N)
S.BindTracker(binds)
S.Status({ on = true, paused = false, action = 'Plotting', boss = 'Gerstahn', pull = 'Dynamic', pullMode = 2 })
assert(S.TrackerShowing() and refreshed == 1 and relayouts == 1)
local blocks = { { kind = 'quest' } }
collector(blocks)
assert(blocks[1].kind == 'dungeonclear' and blocks[1].title == 'Blackrock Depths' and #blocks[1].lines == 3)
local menu = blocks[1].menu()
menu[1].func(); menu[2].func(); menu[4].func()
assert(sent[1] == 'pause:pause' and sent[2] == 'skip:nil' and sent[3] == 'pull:off')
assert(menu[6].checked() == true)
blocks[1].onClick(nil, 'LeftButton')
assert(opened == 1)
-- Running: pause and stop on the title row, the pull dot on the pull line (cycles Dynamic -> Leeroy).
local buttons = blocks[1].buttons
assert(#buttons == 3 and buttons[1].icon:find('PauseButton') and not buttons[1].line and not buttons[2].line)
assert(buttons[3].line == 3)
buttons[1].onClick(); buttons[2].onClick(); buttons[3].onClick()
assert(sent[4] == 'pause:pause' and sent[5] == 'off:nil' and sent[6] == 'pull:off')
S.Status({ on = true, paused = true, action = 'Paused', pull = 'Leeroy', pullMode = 0 })
blocks = {}
collector(blocks)
assert(#blocks[1].lines == 2 and blocks[1].buttons[1].icon:find('NextPage') and blocks[1].buttons[3].line == 2)
blocks[1].buttons[1].onClick()
assert(sent[7] == 'pause:resume')
S.Status(nil)
assert(not S.TrackerShowing() and relayouts == 2)
blocks = {}
collector(blocks)
assert(#blocks == 0)
-- Off in a grouped dungeon: an idle block with start and the pull dot; solo or outside, nothing.
where[1], where[2] = true, 'party'
S.Status({ on = false, pull = 'Advanced', pullMode = 1 })
assert(not S.TrackerShowing())
partySize = 4
S.Refresh()
assert(S.TrackerShowing() and relayouts == 3)
blocks = {}
collector(blocks)
assert(#blocks[1].lines == 2 and #blocks[1].buttons == 2 and blocks[1].buttons[2].line == 2)
blocks[1].buttons[1].onClick(); blocks[1].buttons[2].onClick()
assert(started == 1 and sent[8] == 'pull:dynamic')
menu = blocks[1].menu()
assert(menu[1].text == 'Start Clearing' and menu[4].checked() == true and menu[#menu].text == 'Open Dungeon Clear')
menu[1].func()
assert(started == 2)
where[1] = false
S.Refresh()
assert(not S.TrackerShowing() and relayouts == 4)
DungeonClearDB.trackerBlock = false
S.Status({ on = true, action = 'x', pull = 'y', pullMode = 0 })
assert(not S.TrackerShowing())
print('Skin smoke test passed: absent, incomplete, current and legacy DragonUI; tiny/full transitions; tracker block, controls and idle block.')
