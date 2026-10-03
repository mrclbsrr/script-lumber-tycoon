getgenv().webhook = getgenv().webhook or "webhook here"
if getgenv().stayOnFind == nil then getgenv().stayOnFind = true end
if getgenv().autoHop == nil then getgenv().autoHop = true end        -- trocar de server se nao achar nada
if getgenv().autoSlot == nil then getgenv().autoSlot = true end      -- carregar slot sozinho se nao tiver plot
if getgenv().slot == nil then getgenv().slot = 1 end                 -- numero do slot
if getgenv().trackPlanted == nil then getgenv().trackPlanted = false end -- true = tambem marcar arvores plantadas

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

repeat task.wait() until game:IsLoaded()

----------------------------------------------------------------
-- Server hop
----------------------------------------------------------------
local PlaceID = game.PlaceId
local AllIDs = {}
local foundAnything = ""
local actualHour = os.date("!*t").hour

local File = pcall(function()
    AllIDs = HttpService:JSONDecode(readfile("NotSameServers.json"))
end)
if not File then
    table.insert(AllIDs, actualHour)
    pcall(function() writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs)) end)
end

local SCRIPT_URL = "https://raw.githubusercontent.com/mrclbsrr/script-lumber-tycoon/refs/heads/main/spooky_esp.lua"
local queued = false

local function queueReload()
    local q = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
    if not q then return end
    local g = getgenv()
    local pre = string.format(
        "getgenv().webhook=%q getgenv().autoHop=%s getgenv().autoSlot=%s getgenv().slot=%d "
        .. "getgenv().stayOnFind=%s getgenv().trackPlanted=%s getgenv().autoChopStart=%s ",
        tostring(g.webhook), tostring(g.autoHop), tostring(g.autoSlot),
        math.floor(tonumber(g.slot) or 1), tostring(g.stayOnFind),
        tostring(g.trackPlanted), tostring(g.autoChopOn == true))
    pcall(q, pre .. 'loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
end

local function TPReturner()
    local url = "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100"
    if foundAnything ~= "" then url = url .. "&cursor=" .. foundAnything end
    local Site = HttpService:JSONDecode(game:HttpGet(url))
    if Site.nextPageCursor and Site.nextPageCursor ~= "null" then
        foundAnything = Site.nextPageCursor
    end
    local num = 0
    for _, v in pairs(Site.data) do
        local Possible = true
        local ID = tostring(v.id)
        if tonumber(v.maxPlayers) > tonumber(v.playing) then
            for _, Existing in pairs(AllIDs) do
                if num ~= 0 then
                    if ID == tostring(Existing) then Possible = false end
                else
                    if tonumber(actualHour) ~= tonumber(Existing) then
                        pcall(function()
                            delfile("NotSameServers.json")
                            AllIDs = {}
                            table.insert(AllIDs, actualHour)
                        end)
                    end
                end
                num = num + 1
            end
            if Possible then
                table.insert(AllIDs, ID)
                task.wait()
                pcall(function()
                    writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
                    task.wait()
                    if not queued then queued = true queueReload() end
                    TeleportService:TeleportToPlaceInstance(PlaceID, ID, LocalPlayer)
                end)
                task.wait(4)
            end
        end
    end
end

local function Teleport()
    while task.wait() do
        pcall(function()
            TPReturner()
            if foundAnything ~= "" then TPReturner() end
        end)
    end
end

local hopping = false
local hopCallback = nil 
local function startHop()
    if hopping then return end
    hopping = true
    if hopCallback then hopCallback() end
    task.spawn(Teleport)
end

----------------------------------------------------------------
-- Webhook
----------------------------------------------------------------
local function sendWebhook(username, title, desc, cf)
    if not getgenv().webhook or getgenv().webhook == "" or getgenv().webhook == "webhook here" then return end
    
    local joinScript = "```lua\ngame:GetService('TeleportService'):TeleportToPlaceInstance("
        .. game.PlaceId .. ",'" .. game.JobId .. "',game.Players.LocalPlayer)```"
    local tpScript = "game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new("
        .. tostring(cf) .. ")"

    local data = {
        content = "",
        username = username,
        embeds = {{
            title = title,
            description = desc,
            type = "rich",
            footer = { text = os.date("%c", os.time()) },
            fields = {
                { name = "**Join script**", value = joinScript, inline = true },
                { name = "**Teleport Script**", value = "```lua\n" .. tpScript .. "
