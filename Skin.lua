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

function S.Window(frame, header, close)
    if not S.enabled then return end
    -- Keep the old backdrop for tiny mode: a full title border cannot fit in 28px.
    local backdrop = frame:GetBackdrop()
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
    function S.Layout(tiny)
        if tiny then
            rock:Hide()
            chrome:Hide()
            frame:SetBackdrop(backdrop)
            frame:SetBackdropColor(0.03, 0.03, 0.05, 0.90)
            frame:SetBackdropBorderColor(0.20, 0.22, 0.28, 1)
        else
            frame:SetBackdrop(nil)
            rock:Show()
            chrome:Show()
        end
    end
    S.Layout(DungeonClearDB.tinyMode)
end
