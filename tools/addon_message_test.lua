-- Run from the repository root with Lua 5.1 (luajit). Optional argument: path to DungeonClear.lua.
-- Loads the addon against a stub 3.3.5a API and checks which "DC" addon messages it acts on.
local path = arg[1] or "DungeonClear/DungeonClear.lua"
local callCount, chat, eventHandlers = 0, {}, {}
local function newObj(name)
    local o = { _name = name }
    local mt = {}
    mt.__index = function(t, k)
        if k == "GetName" then return function() return t._name or "Obj" end end
        if k == "AddMessage" then return function(_, msg) chat[#chat + 1] = msg end end
        if k == "SetScript" then return function(self, what, fn) self["_" .. what] = fn end end
        if k == "RegisterEvent" then return function(self, ev) eventHandlers[ev] = self end end
        if k == "GetWidth" or k == "GetHeight" or k == "GetStringWidth" or k == "GetValue"
            or k == "GetFrameLevel" or k == "GetLeft" or k == "GetTop" or k == "GetNumLines" then
            return function() return 100 end
        end
        if k == "IsShown" or k == "IsVisible" or k == "GetChecked" then return function() return false end end
        if k:match("^%u") then
            return function() callCount = callCount + 1; return newObj() end
        end
        return nil
    end
    mt.__call = function() return newObj() end
    return setmetatable(o, mt)
end
local G = setmetatable({}, { __index = function(_, k)
    local v = rawget(_G, k); if v ~= nil then return v end
    if type(k) == "string" and k:match("^%u") then return newObj(k) end
end })
local env = G
local me, party, raid = "Me", {}, {}
local defs = {
    CreateFrame = function(_, name) local o = newObj(name); if name then rawset(env, name, o) end; return o end,
    DEFAULT_CHAT_FRAME = newObj("ChatFrame1"),
    UIParent = newObj("UIParent"),
    GetTime = function() return 1000 end,
    UnitName = function(u)
        if u == "player" then return me end
        local i = u:match("^party(%d)$"); if i then return party[tonumber(i)] end
        i = u:match("^raid(%d+)$"); if i then return raid[tonumber(i)] end
    end,
    GetNumPartyMembers = function() return #party end,
    GetNumRaidMembers = function() return #raid end,
    IsInInstance = function() return true, "party" end,
    GetAddOnMetadata = function() return "test" end,
    getglobal = function(n) return rawget(env, n) or newObj(n) end,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    hooksecurefunc = function() end,
    UIDropDownMenu_SetSelectedValue = function() end,
    UIDropDownMenu_SetText = function() end,
    UIDropDownMenu_Initialize = function() end,
    SlashCmdList = {}, UISpecialFrames = {},
    GetRealZoneText = function() return "Deadmines" end,
    UnitIsGroupLeader = function() return true end,
    SendAddonMessage = function() end,
    math = math, string = string, table = table, pairs = pairs, ipairs = ipairs, type = type,
    tostring = tostring, tonumber = tonumber, select = select, unpack = unpack, next = next,
    pcall = pcall, error = error, setmetatable = setmetatable, getmetatable = getmetatable,
    rawget = rawget, rawset = rawset, assert = assert, print = print, format = string.format,
    floor = math.floor, max = math.max, min = math.min, wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    tinsert = table.insert, tremove = table.remove, strsub = string.sub, strfind = string.find,
    strlower = string.lower, strupper = string.upper, gsub = string.gsub, strlen = string.len,
}
for k, v in pairs(defs) do rawset(env, k, v) end
local chunk = assert(loadfile(path))
setfenv(chunk, env)
chunk("DungeonClear", {})
local ef = assert(eventHandlers.CHAT_MSG_ADDON, "no CHAT_MSG_ADDON frame")
ef._OnEvent(ef, "ADDON_LOADED", "DungeonClear")

local function fire(msg, channel, sender)
    local prefix, rest = msg:match("^([^\t]*)\t(.*)$")
    local before, beforeCalls = #chat, callCount
    local ok, err = pcall(ef._OnEvent, ef, "CHAT_MSG_ADDON", prefix, rest, channel, sender)
    return ok, err, chat[#chat] ~= nil and #chat > before and chat[#chat] or nil, callCount - beforeCalls
end

party = { "Tankbot" }
-- Legit: from a bot in the party on PARTY.
local ok, err, line = fire("DC\tCHAT\tReached Sneed - continuing.", "PARTY", "Tankbot")
assert(ok, err); assert(line and line:find("Reached Sneed", 1, true), "legit CHAT dropped")
-- Legit: from ourselves (server reply to a command).
ok, err, line = fire("DC\tCHAT\tfrom self", "PARTY", "Me")
assert(ok, err); assert(line and line:find("from self", 1, true), "self CHAT dropped")
-- Attack: whisper from a stranger.
ok, err, line = fire("DC\tCHAT\t|r|cffff2020[GM] verify your account", "WHISPER", "Stranger")
assert(ok, err); assert(not line, "whisper CHAT shown: " .. tostring(line))
-- Attack: stranger on PARTY (not in group).
ok, err, line = fire("DC\tCHAT\tspoof", "PARTY", "Stranger")
assert(ok, err); assert(not line, "non-member CHAT shown")
-- Attack: group member on RAID/WHISPER channel.
ok, err, line = fire("DC\tCHAT\tspoof", "WHISPER", "Tankbot")
assert(ok, err); assert(not line, "member whisper CHAT shown")
-- Group member's hand-made escape codes are shown literally.
ok, err, line = fire("DC\tCHAT\t|r|cffff2020[GM]|Hitem:19019|h[x]|h", "PARTY", "Tankbot")
assert(ok, err); assert(line == "|cff3da6ff[DC] ||r||cffff2020[GM]||Hitem:19019||h[x]||h|r", "not escaped: " .. tostring(line))
-- Stranger STATUS / ERROR / SETTINGS do nothing at all.
local _, _, _, n = fire("DC\tSTATUS\t1\t0\tFake boss\t\t0\tmoving\t\t1\t0", "WHISPER", "Stranger")
assert(n == 0, "stranger STATUS touched the UI (" .. n .. " calls)")
_, _, _, n = fire("DC\tSTATUS\t1\t0\tReal boss\t\t0\tmoving\t\t1\t0", "PARTY", "Tankbot")
assert(n > 0, "legit STATUS ignored")
_, _, line, n = fire("DC\tERROR\tNo tank bot found in your group.", "WHISPER", "Stranger")
assert(n == 0 and not line, "stranger ERROR acted on")
-- SETTINGS without a range must not throw (and is dropped).
ok, err = fire("DC\tSETTINGS\tRestHealthPct\t50\t\t\t1\t0", "PARTY", "Tankbot")
assert(ok, "SETTINGS without range threw: " .. tostring(err))
ok, err = fire("DC\tSETTINGS\tRestHealthPct\t50\t90\t10\t1\t0", "PARTY", "Tankbot")
assert(ok, "SETTINGS min>max threw: " .. tostring(err))
-- Raid: member found via raidN.
party = {}; raid = { "Me", "Healer", "Tankbot" }
ok, err, line = fire("DC\tCHAT\traid ok", "PARTY", "Tankbot")
assert(ok, err); assert(line and line:find("raid ok", 1, true), "raid member CHAT dropped")
_, _, line = fire("DC\tCHAT\tx", "PARTY", "Stranger")
assert(not line, "raid non-member shown")
print("DC addon-message test passed")
