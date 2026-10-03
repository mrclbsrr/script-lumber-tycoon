getgenv().webhook = getgenv().webhook or ""
if getgenv().stayOnFind == nil then getgenv().stayOnFind = true end
if getgenv().autoHop == nil then getgenv().autoHop = true end        
if getgenv().autoSlot == nil then getgenv().autoSlot = true end      
if getgenv().slot == nil then getgenv().slot = 1 end                 

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

repeat task.wait() until game:IsLoaded()

----------------------------------------------------------------
-- Server Hop Simplificado (Mobile Safe)
----------------------------------------------------------------
local hopping = false
local hopCallback = nil 

local function startHop()
    if hopping then return end
    hopping = true
    if hopCallback then hopCallback() end

    task.spawn(function()
        while task.wait(1) do
            pcall(function()
                local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
                local response = game:HttpGet(url)
                if response then
                    local site = HttpService:JSONDecode(response)
                    if site and site.data then
                        for _, v in pairs(site.data) do
                            if v.playing < v.maxPlayers and tostring(v.id) ~= tostring(game.JobId) then
                                TeleportService:TeleportToPlaceInstance(game.PlaceId, tostring(v.id), LocalPlayer)
                                task.wait(5)
                            end
                        end
                    end
                end
            end)
        end
    end)
end

----------------------------------------------------------------
-- Webhook
----------------------------------------------------------------
local function sendWebhook(username, title, desc, cf)
    local wh = getgenv().webhook
    if not wh or wh == "" or wh == "webhook here" then return end
    
    local tpScript = "game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(" .. tostring(cf) .. ")"

    local data = {
        username = username,
        embeds = {{
            title = title,
            description = desc,
            type = "rich",
            fields = {
                { name = "**Teleport Script**", value = "```lua\n" .. tpScript .. "
