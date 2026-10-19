-- Run from the addon directory with Lua 5.1.
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
    dofile('Skin.lua')
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
assert(frame.backdrop.original)
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
print('Skin smoke test passed: absent, incomplete, current and legacy DragonUI; tiny/full transitions.')
