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
                { name = "**Teleport Script**", value = "```lua\n" .. tpScript .. "```", inline = false },
            },
        }},
    }

    local req = http_request or request or HttpPost or (syn and syn.request)
    if req then
        pcall(req, {
            Url = getgenv().webhook,
            Body = HttpService:JSONEncode(data),
            Method = "POST",
            Headers = { ["content-type"] = "application/json" },
        })
    end
end

----------------------------------------------------------------
-- ESP e Variáveis Globais
----------------------------------------------------------------
local TARGETS = {
    Spooky     = { label = "SPOOKY",      color = Color3.fromRGB(255, 140, 0) },
    SpookyNeon = { label = "SPOOKY NEON", color = Color3.fromRGB(0, 255, 120) },
}

local espFolder = Instance.new("Folder")
espFolder.Name = "TreeESP"
local okParent, guiParent = pcall(function()
    return (gethui and gethui()) or game:GetService("CoreGui")
end)
espFolder.Parent = okParent and guiParent or LocalPlayer:WaitForChild("PlayerGui")

local RS = game:GetService("ReplicatedStorage")
if getgenv().axeDamage == nil then getgenv().axeDamage = 5 end

local axeDamages = {}
local selectedAxeName = nil

local function isAxe(t)
    if not t:IsA("Tool") then return false end
    if t.Name:lower():find("axe") then return true end
    local tn = t:FindFirstChild("ToolName")
    return tn ~= nil and tostring(tn.Value):lower():find("axe") ~= nil
end

local function listAxes()
    local result, seen = {}, {}
    local function scan(container)
        if not container then return end
        for _, t in ipairs(container:GetChildren()) do
            if isAxe(t) and not seen[t.Name] then
                seen[t.Name] = true
                table.insert(result, t)
            end
        end
    end
    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChild("Backpack"))
    return result
end

local function defaultAxeDamage(tool)
    local dmg
    pcall(function()
        local tn = tool:FindFirstChild("ToolName")
        local mod = RS.AxeClasses["AxeClass_" .. tostring(tn.Value)]
        dmg = require(mod).new().Damage
    end)
    return dmg or getgenv().axeDamage
end

local function getAxeDamage(tool)
    return axeDamages[tool.Name] or defaultAxeDamage(tool)
end

local function getAxe()
    local axes = listAxes()
    if selectedAxeName then
        for _, t in ipairs(axes) do
            if t.Name == selectedAxeName then return t end
        end
    end
    return axes[1]
end

----------------------------------------------------------------
-- Auto Chop e Entrega no Plot (CORRIGIDO)
----------------------------------------------------------------
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart"), char
end

local function getPlot()
    local props = workspace:FindFirstChild("Properties")
    if not props then return nil end
    for _, p in ipairs(props:GetChildren()) do
        local o = p:FindFirstChild("Owner")
        if o and o.Value == LocalPlayer then return p end
    end
end

local function isFree(tree)
    local o = tree:FindFirstChild("Owner")
    return o ~= nil and o.Value == nil
end

local function loadSlot()
    if getPlot() then return true end
    local LS = RS:FindFirstChild("LoadSaveRequests")
    if not LS then return false end
    local slot = math.floor(tonumber(getgenv().slot) or 1)
    
    -- Tenta invocar assincronamente para não travar o script
    task.spawn(function() pcall(function() LS.ClientMayLoad:InvokeServer(LocalPlayer) end) end)
    task.wait(0.5)
    pcall(function() LS.RequestLoad:InvokeServer(slot, LocalPlayer) end)
    
    local t0 = tick()
    while tick() - t0 < 15 do
        if getPlot() then return true end
        task.wait(1)
    end
    return false
end

local function ensurePlot()
    local plot = getPlot()
    if plot then return plot end
    if not getgenv().autoSlot then return nil end
    if loadSlot() then return getPlot() end
    return nil
end

local function baseSection(tree)
    local best
    for _, c in ipairs(tree:GetChildren()) do
        if c.Name == "WoodSection" and c:IsA("BasePart") then
            local id = c:FindFirstChild("ID")
            if id and id.Value == 1 then return c end
            best = best or c
        end
    end
    return best
end

local function chopOnce(tree, section, axe, dmg)
    local cutEvent = tree:FindFirstChild("CutEvent")
    if not cutEvent then return end
    local id = section:FindFirstChild("ID")
    RS.Interaction.RemoteProxy:FireServer(cutEvent, {
        tool = axe,
        faceVector = Vector3.new(1, 0, 0),
        height = 0.3,
        sectionId = id and id.Value or 1,
        hitPoints = dmg,
        cooldown = 0.21,
        cuttingClass = "Axe",
    })
end

-- CORREÇÃO: Função melhorada de mover toras
local function deliverLog(log, plotPos)
    local hrp = getHRP()
    local part = log:FindFirstChild("WoodSection") or log.PrimaryPart
    if not (hrp and part and part.Parent) then return end
    
    local target = CFrame.new(plotPos + Vector3.new(math.random(-8, 8), 5, math.random(-8, 8)))
    
    for _ = 1, 25 do
        if not log.Parent then break end
        -- O remote precisa do BasePart e não do Modelo
        pcall(function() RS.Interaction.ClientIsDragging:FireServer(part) end)
        
        -- Mover a madeira
        log:PivotTo(target)
        -- O jogador precisa estar perto da madeira durante o arraste para não perder o Network Ownership
        hrp.CFrame = target + Vector3.new(0, 4, 0) 
        
        task.wait(0.05)
    end
end

----------------------------------------------------------------
-- Processar Arvore / Busca de Objetivos
----------------------------------------------------------------
local tracked = {} 
local found = {}   
local autoChop = getgenv().autoChopStart == true

local function woodSize(part)
    return math.floor(part.Size.Y * part.Size.X * part.Size.Z * 100) / 100
end

local function handleTreeClass(v)
    if not (v:IsA("StringValue") and v.Name == "TreeClass") then return end
    local info = TARGETS[v.Value]
    if not info then return end
    local tree = v.Parent
    if not tree or tracked[tree] then return end
    
    local lf = workspace:FindFirstChild("LogModels")
    local dropped = lf ~= nil and tree.Parent == lf
    if not dropped and not getgenv().trackPlanted then return end

    task.spawn(function()
        local part = tree:WaitForChild("WoodSection", 5)
        if not part or not part:IsA("BasePart") then return end

        local owner = tree:FindFirstChild("Owner")
        found[tree] = {
            class = v.Value,
            size = woodSize(part),
            cframe = part.CFrame,
            unowned = owner ~= nil and owner.Value == nil,
        }
    end)
end

for _, v in ipairs(workspace:GetDescendants()) do
    handleTreeClass(v)
end
workspace.DescendantAdded:Connect(handleTreeClass)

local function processTree(tree)
    local plot = ensurePlot()
    if not plot then task.wait(3) return end
    local origin = plot:FindFirstChild("OriginSquare")
    if not origin then return end
    local plotPos = origin.Position

    local lf = workspace:FindFirstChild("LogModels")
    if lf and tree.Parent == lf then
        if not isFree(tree) then return end
        deliverLog(tree, plotPos)
        local hrp3 = getHRP()
        if hrp3 then hrp3.CFrame = CFrame.new(plotPos + Vector3.new(0, 6, 12)) end
        found[tree] = nil
        return
    end

    local axe = getAxe()
    if not axe then task.wait(3) return end
    local hrp, char = getHRP()
    if not hrp then return end
    if axe.Parent ~= char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:EquipTool(axe) task.wait(0.3) end
    end

    local section = baseSection(tree)
    if not section then return end
    local dmg = getAxeDamage(axe)

    local logs = {}
    local logFolder = workspace:FindFirstChild("LogModels")
    local conn
    if logFolder then
        conn = logFolder.ChildAdded:Connect(function(m)
            task.wait(0.2)
            local o = m:FindFirstChild("Owner")
            if o and o.Value == LocalPlayer then table.insert(logs, m) end
        end)
    end

    hrp.CFrame = CFrame.new(section.Position + Vector3.new(3, 3, 0))
    task.wait(0.5) -- Pausa rápida pro servidor registrar sua posição nova antes de cortar

    local t0 = tick()
    while autoChop and tree.Parent and #logs == 0 and tick() - t0 < 30 do
        chopOnce(tree, section, axe, dmg)
        hrp.CFrame = CFrame.new(section.Position + Vector3.new(3, 3, 0)) -- Previne cair ou ser empurrado
        task.wait(0.22)
    end
    task.wait(2)

    if conn then conn:Disconnect() end

    for _, log in ipairs(logs) do
        if not autoChop then break end
        if log.Parent then deliverLog(log, plotPos) end
    end

    local hrp2 = getHRP()
    if hrp2 then hrp2.CFrame = CFrame.new(plotPos + Vector3.new(0, 6, 12)) end
    found[tree] = nil
end

local scanDone = false

task.spawn(function()
    local busy = false
    while task.wait(1) do
        if autoChop and scanDone and not busy then
            local didWork = false
            for tree, data in pairs(found) do
                if not autoChop then break end
                if not tree.Parent then
                    found[tree] = nil
                elseif isFree(tree) then
                    didWork = true
                    data.tries = (data.tries or 0) + 1
                    busy = true
                    local ok, err = pcall(processTree, tree)
                    if not ok then warn("[AutoColetar] Erro: " .. tostring(err)) end
                    busy = false
                    if data.tries >= 3 then found[tree] = nil end
                end
            end
            if not didWork and getgenv().autoHop then startHop() end
        end
    end
end)

task.wait(5)
scanDone = true

local any = false
for _, data in pairs(found) do
    any = true
    if data.unowned then
        if data.class == "SpookyNeon" then
            sendWebhook("Sinister Finder", "Sinister Wood Found!!!!",
                "Size **" .. data.size .. "** Sinister Wood", data.cframe)
        else
            sendWebhook("Spook Finder", "Spook Wood Found",
                "Size **" .. data.size .. "** Spook Wood", data.cframe)
        end
    end
end

if (not any or not getgenv().stayOnFind) and getgenv().autoHop then
    startHop()
end
