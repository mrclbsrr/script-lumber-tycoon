getgenv().webhook = getgenv().webhook or "webhook here"
if getgenv().stayOnFind == nil then getgenv().stayOnFind = true end
if getgenv().autoHop == nil then getgenv().autoHop = true end       -- trocar de server se nao achar nada
if getgenv().autoSlot == nil then getgenv().autoSlot = true end     -- carregar slot sozinho se nao tiver plot
if getgenv().slot == nil then getgenv().slot = 1 end                -- numero do slot
if getgenv().trackPlanted == nil then getgenv().trackPlanted = false end -- true = tambem marcar arvores plantadas

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

repeat task.wait() until game:IsLoaded()

----------------------------------------------------------------
-- Server hop (igual ao original)
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
    writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
end

local SCRIPT_URL = "https://raw.githubusercontent.com/mrclbsrr/script-lumber-tycoon/refs/heads/main/spooky_esp.lua"
local queued = false

-- reexecuta o script automaticamente no proximo servidor
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
local hopCallback = nil  -- a GUI define isso para mudar o texto do botao
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
                { name = "**Auto Claimer**", value = '```lua\nloadstring(game:HttpGet("https://pastebin.com/raw/uaK9gH1s"))()```', inline = false },
                { name = "**Teleport Script**", value = "```lua\n" .. tpScript .. "```", inline = false },
            },
        }},
    }

    local req = http_request or request or HttpPost or (syn and syn.request)
    pcall(req, {
        Url = getgenv().webhook,
        Body = HttpService:JSONEncode(data),
        Method = "POST",
        Headers = { ["content-type"] = "application/json" },
    })
end

----------------------------------------------------------------
-- ESP
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

----------------------------------------------------------------
-- Machados do inventario + dano por machado
----------------------------------------------------------------
local RS = game:GetService("ReplicatedStorage")
if getgenv().axeDamage == nil then getgenv().axeDamage = 5 end -- fallback

local axeDamages = {}        -- [nome do machado] = dano escolhido por voce
local selectedAxeName = nil  -- machado escolhido na lista

local function isAxe(t)
    if not t:IsA("Tool") then return false end
    if t.Name:lower():find("axe") then return true end
    local tn = t:FindFirstChild("ToolName")
    return tn ~= nil and tostring(tn.Value):lower():find("axe") ~= nil
end

-- machados na mao (Character) e na mochila (Backpack), sem repetir nomes
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

-- dano padrao: lido do jogo (AxeClasses); se falhar, usa getgenv().axeDamage
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
-- GUI de teleporte (um botao por arvore)
----------------------------------------------------------------
local UserInputService = game:GetService("UserInputService")
local treeButtons = {}  -- [tree] = TextButton

local gui = Instance.new("ScreenGui")
gui.Name = "TreeTP"
gui.ResetOnSpawn = false
gui.Parent = espFolder.Parent

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(270, 340)
main.Position = UDim2.new(0, 20, 0.5, -170)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -34, 0, 30)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Arvores (0)"
title.Parent = main

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.fromOffset(30, 30)
toggle.Position = UDim2.new(1, -30, 0, 0)
toggle.BackgroundTransparency = 1
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 18
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Text = "-"
toggle.Parent = main

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(0, 126)
list.Size = UDim2.new(1, 0, 1, -126)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = main

local autoChop = getgenv().autoChopStart == true
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, -12, 0, 26)
autoBtn.Position = UDim2.fromOffset(6, 32)
autoBtn.BorderSizePixel = 0
autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 12
autoBtn.TextColor3 = Color3.new(1, 1, 1)
autoBtn.Parent = main
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 6)

local function refreshAutoBtn()
    getgenv().autoChopOn = autoChop
    autoBtn.Text = autoChop and "Auto Coletar -> Plot: ON" or "Auto Coletar -> Plot: OFF"
    autoBtn.BackgroundColor3 = autoChop and Color3.fromRGB(40, 150, 70) or Color3.fromRGB(150, 40, 40)
end
local function setStatus(text) autoBtn.Text = text end
refreshAutoBtn()

autoBtn.MouseButton1Click:Connect(function()
    autoChop = not autoChop
    refreshAutoBtn()
end)

-- linha do machado: [seletor v] [dano]
local axeSelect = Instance.new("TextButton")
axeSelect.Size = UDim2.new(1, -98, 0, 26)
axeSelect.Position = UDim2.fromOffset(6, 62)
axeSelect.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
axeSelect.BorderSizePixel = 0
axeSelect.Font = Enum.Font.GothamBold
axeSelect.TextSize = 12
axeSelect.TextColor3 = Color3.new(1, 1, 1)
axeSelect.TextTruncate = Enum.TextTruncate.AtEnd
axeSelect.Parent = main
Instance.new("UICorner", axeSelect).CornerRadius = UDim.new(0, 6)

local dmgBox = Instance.new("TextBox")
dmgBox.Size = UDim2.fromOffset(80, 26)
dmgBox.Position = UDim2.new(1, -86, 0, 62)
dmgBox.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
dmgBox.BorderSizePixel = 0
dmgBox.Font = Enum.Font.GothamBold
dmgBox.TextSize = 12
dmgBox.TextColor3 = Color3.new(1, 1, 1)
dmgBox.PlaceholderText = "dano"
dmgBox.ClearTextOnFocus = false
dmgBox.Text = ""
dmgBox.Parent = main
Instance.new("UICorner", dmgBox).CornerRadius = UDim.new(0, 6)

local dropdown = Instance.new("ScrollingFrame")
dropdown.Position = UDim2.fromOffset(6, 90)
dropdown.Size = UDim2.new(1, -12, 0, 0)
dropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
dropdown.BorderSizePixel = 0
dropdown.ScrollBarThickness = 3
dropdown.CanvasSize = UDim2.new()
dropdown.AutomaticCanvasSize = Enum.AutomaticSize.Y
dropdown.Visible = false
dropdown.ZIndex = 10
dropdown.Parent = main
Instance.new("UICorner", dropdown).CornerRadius = UDim.new(0, 6)
local ddLayout = Instance.new("UIListLayout", dropdown)
ddLayout.Padding = UDim.new(0, 2)

local lastSig = ""
local function refreshAxeUI(force)
    local axes = listAxes()
    local current = getAxe()
    selectedAxeName = current and current.Name or nil

    local names = {}
    for _, t in ipairs(axes) do table.insert(names, t.Name) end
    local sig = table.concat(names, ",") .. "|" .. tostring(selectedAxeName)
    if sig == lastSig and not force then return end
    lastSig = sig

    axeSelect.Text = current and ("Machado: " .. current.Name .. " v") or "Machado: (nenhum) v"
    if current and not dmgBox:IsFocused() then
        dmgBox.Text = tostring(getAxeDamage(current))
    elseif not current then
        dmgBox.Text = ""
    end

    for _, c in ipairs(dropdown:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, t in ipairs(axes) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 24)
        b.BackgroundColor3 = (t.Name == selectedAxeName) and Color3.fromRGB(70, 110, 200)
            or Color3.fromRGB(55, 55, 65)
        b.BorderSizePixel = 0
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        b.TextColor3 = Color3.new(1, 1, 1)
        b.ZIndex = 11
        b.Text = t.Name .. "  (dano " .. tostring(getAxeDamage(t)) .. ")"
        b.Parent = dropdown
        b.MouseButton1Click:Connect(function()
            selectedAxeName = t.Name
            dropdown.Visible = false
            refreshAxeUI(true)
        end)
    end
    dropdown.Size = UDim2.new(1, -12, 0, math.min(#axes, 5) * 26 + 2)
end

axeSelect.MouseButton1Click:Connect(function()
    refreshAxeUI(true)
    if #listAxes() == 0 then dropdown.Visible = false return end
    dropdown.Visible = not dropdown.Visible
end)

dmgBox.FocusLost:Connect(function()
    local n = tonumber(dmgBox.Text)
    local cur = getAxe()
    if cur and n and n > 0 then
        axeDamages[cur.Name] = n
    end
    refreshAxeUI(true)
end)

refreshAxeUI(true)
task.spawn(function()
    while task.wait(2) do refreshAxeUI(false) end
end)

-- linha 3: [Server Hop] [Auto Slot] [# do slot]
local function styleBtn(b)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
end

local hopBtn = Instance.new("TextButton")
hopBtn.Size = UDim2.fromOffset(96, 26)
hopBtn.Position = UDim2.fromOffset(6, 92)
hopBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
hopBtn.Text = "Server Hop"
styleBtn(hopBtn)
hopBtn.Parent = main
hopBtn.MouseButton1Click:Connect(function() startHop() end)
hopCallback = function()
    hopBtn.Text = "Hopping..."
    hopBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
end
if hopping then hopCallback() end

local autoSlotBtn = Instance.new("TextButton")
autoSlotBtn.Size = UDim2.fromOffset(100, 26)
autoSlotBtn.Position = UDim2.fromOffset(106, 92)
styleBtn(autoSlotBtn)
autoSlotBtn.Parent = main
local function refreshSlotBtn()
    local on = getgenv().autoSlot
    autoSlotBtn.Text = on and "Auto Slot: ON" or "Auto Slot: OFF"
    autoSlotBtn.BackgroundColor3 = on and Color3.fromRGB(40, 150, 70) or Color3.fromRGB(150, 40, 40)
end
refreshSlotBtn()
autoSlotBtn.MouseButton1Click:Connect(function()
    getgenv().autoSlot = not getgenv().autoSlot
    refreshSlotBtn()
end)

local slotBox = Instance.new("TextBox")
slotBox.Size = UDim2.fromOffset(54, 26)
slotBox.Position = UDim2.fromOffset(210, 92)
slotBox.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
slotBox.PlaceholderText = "slot"
slotBox.ClearTextOnFocus = false
slotBox.Text = tostring(getgenv().slot)
styleBtn(slotBox)
slotBox.Parent = main
slotBox.FocusLost:Connect(function()
    local n = tonumber(slotBox.Text)
    if n and n >= 1 then
        getgenv().slot = math.floor(n)
    end
    slotBox.Text = tostring(getgenv().slot)
end)

local layout = Instance.new("UIListLayout", list)
layout.Padding = UDim.new(0, 4)
local pad = Instance.new("UIPadding", list)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)

local collapsed = false
toggle.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    list.Visible = not collapsed
    autoBtn.Visible = not collapsed
    axeSelect.Visible = not collapsed
    dmgBox.Visible = not collapsed
    hopBtn.Visible = not collapsed
    autoSlotBtn.Visible = not collapsed
    slotBox.Visible = not collapsed
    if collapsed then dropdown.Visible = false end
    main.Size = collapsed and UDim2.fromOffset(270, 30) or UDim2.fromOffset(270, 340)
    toggle.Text = collapsed and "+" or "-"
end)

-- arrastar pela barra de titulo
do
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function updateCount()
    local n = 0
    for _ in pairs(treeButtons) do n = n + 1 end
    title.Text = "Arvores (" .. n .. ")"
end

local function removeButton(tree)
    local b = treeButtons[tree]
    if b then b:Destroy() treeButtons[tree] = nil end
    updateCount()
end

local function addButton(tree, info, part)
    if treeButtons[tree] then return end
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = info.color
    btn.BackgroundTransparency = 0.25
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextStrokeTransparency = 0.5
    btn.Text = info.label
    btn.LayoutOrder = (info.label == "SPOOKY NEON") and 0 or 1
    btn.Parent = list
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and part.Parent then
            hrp.CFrame = part.CFrame + Vector3.new(0, 6, 0)
        end
    end)

    treeButtons[tree] = btn
    updateCount()
end

local tracked = {}   -- [tree] = { part, label, name }
local found = {}     -- [tree] = { class, size, cframe, unowned }

local function woodSize(part)
    return math.floor(part.Size.Y * part.Size.X * part.Size.Z * 100) / 100
end

local function removeESP(tree)
    local t = tracked[tree]
    if not t then return end
    for _, inst in ipairs(t.instances) do inst:Destroy() end
    tracked[tree] = nil
    removeButton(tree)
end

local function addESP(tree, info, part)
    if tracked[tree] then return end

    local hl = Instance.new("Highlight")
    hl.Adornee = tree
    hl.FillColor = info.color
    hl.FillTransparency = 0.5
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = espFolder

    local bb = Instance.new("BillboardGui")
    bb.Adornee = part
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(180, 44)
    bb.StudsOffset = Vector3.new(0, 8, 0)
    bb.MaxDistance = math.huge
    bb.ResetOnSpawn = false
    bb.Parent = espFolder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = info.color
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Text = info.label
    label.Parent = bb

    tracked[tree] = {
        instances = { hl, bb },
        part = part,
        label = label,
        name = info.label,
    }
    addButton(tree, info, part)

    tree.AncestryChanged:Connect(function(_, parent)
        if not parent then removeESP(tree) end
    end)
end

-- atualiza distancia/tamanho nas etiquetas
task.spawn(function()
    while task.wait(0.25) do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        for tree, t in pairs(tracked) do
            if t.part and t.part.Parent then
                local dist = hrp and math.floor((hrp.Position - t.part.Position).Magnitude) or 0
                local ov = tree:FindFirstChild("Owner")
                local tag = (ov and ov.Value) and ("de " .. tostring(ov.Value)) or "livre"
                t.label.Text = string.format("%s [%s]\nTam: %s | %dm", t.name, tag, woodSize(t.part), dist)
                local b = treeButtons[tree]
                if b then
                    b.Text = string.format("%s [%s] | %s | %dm", t.name, tag, woodSize(t.part), dist)
                end
            end
        end
    end
end)

local function handleTreeClass(v)
    if not (v:IsA("StringValue") and v.Name == "TreeClass") then return end
    local info = TARGETS[v.Value]
    if not info then return end
    local tree = v.Parent
    if not tree or tracked[tree] then return end
    -- por padrao so marca madeira JA DROPADA (workspace.LogModels);
    -- arvores plantadas so entram com getgenv().trackPlanted = true
    local lf = workspace:FindFirstChild("LogModels")
    local dropped = lf ~= nil and tree.Parent == lf
    if not dropped and not getgenv().trackPlanted then return end

    task.spawn(function()
        local part = tree:WaitForChild("WoodSection", 5)
        if not part or not part:IsA("BasePart") then return end
        addESP(tree, info, part)

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

----------------------------------------------------------------
-- Auto Chop + levar madeira para o plot
-- (nomes de remotes/argumentos baseados no LT2; podem mudar com updates)
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

-- madeira "livre" = sem dono (Owner vazio). Madeira de jogadores presentes nao e coletada.
local function isFree(tree)
    local o = tree:FindFirstChild("Owner")
    return o ~= nil and o.Value == nil
end

-- carrega o slot escolhido (nomes de remotes do LT2; podem mudar com updates)
local function loadSlot()
    if getPlot() then return true end
    local LS = RS:FindFirstChild("LoadSaveRequests")
    if not LS then return false end
    local slot = math.floor(tonumber(getgenv().slot) or 1)
    pcall(function() LS.ClientMayLoad:InvokeServer(LocalPlayer) end)
    local ok = pcall(function() LS.RequestLoad:InvokeServer(slot, LocalPlayer) end)
    if not ok then
        pcall(function() LS.RequestLoad:FireServer(slot, LocalPlayer) end)
    end
    local t0 = tick()
    while tick() - t0 < 30 do
        if getPlot() then return true end
        task.wait(1)
    end
    return false
end

local function ensurePlot()
    local plot = getPlot()
    if plot then return plot end
    if not getgenv().autoSlot then return nil end
    setStatus("Carregando slot " .. tostring(getgenv().slot) .. "...")
    if loadSlot() then return getPlot() end
    return nil
end

-- getAxe / getAxeDamage (machado escolhido na lista) ficam definidos mais acima

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

local function deliverLog(log, plotPos)
    local hrp = getHRP()
    local part = log:FindFirstChild("WoodSection") or log.PrimaryPart
    if not (hrp and part and part.Parent) then return end
    hrp.CFrame = part.CFrame + Vector3.new(0, 4, 0)
    task.wait(0.2)
    local target = CFrame.new(plotPos + Vector3.new(math.random(-8, 8), 6, math.random(-8, 8)))
    for _ = 1, 20 do
        if not log.Parent then break end
        pcall(function() RS.Interaction.ClientIsDragging:FireServer(log) end)
        log:PivotTo(target)
        task.wait(0.05)
    end
end

local function processTree(tree)
    local plot = ensurePlot()
    if not plot then setStatus("Sem plot! (falha ao carregar slot)") task.wait(3) return end
    local origin = plot:FindFirstChild("OriginSquare")
    if not origin then return end
    local plotPos = origin.Position

    -- madeira JA DROPADA: so pegar e levar pro plot (nao precisa de machado)
    local lf = workspace:FindFirstChild("LogModels")
    if lf and tree.Parent == lf then
        if not isFree(tree) then return end
        setStatus("Pegando " .. (tracked[tree] and tracked[tree].name or "tora") .. "...")
        deliverLog(tree, plotPos)
        local hrp3 = getHRP()
        if hrp3 then hrp3.CFrame = CFrame.new(plotPos + Vector3.new(0, 6, 12)) end
        found[tree] = nil
        return
    end

    local axe = getAxe()
    if not axe then setStatus("Sem machado!") task.wait(3) return end
    local hrp, char = getHRP()
    if not hrp then return end
    if axe.Parent ~= char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:EquipTool(axe) task.wait(0.3) end
    end

    local section = baseSection(tree)
    if not section then return end
    local dmg = getAxeDamage(axe)

    -- coletar toras novas que ficarem com o meu Owner
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

    setStatus("Cortando " .. (tracked[tree] and tracked[tree].name or "arvore") .. "...")
    hrp.CFrame = CFrame.new(section.Position + Vector3.new(5, 3, 0))
    task.wait(0.3)

    local t0 = tick()
    while autoChop and tree.Parent and #logs == 0 and tick() - t0 < 30 do
        chopOnce(tree, section, axe, dmg)
        task.wait(0.22)
    end
    task.wait(2) -- esperar galhos/pedacos cairem

    if conn then conn:Disconnect() end

    setStatus("Levando pro plot... (" .. #logs .. ")")
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
                    if not ok then warn("[AutoColetar] " .. tostring(err)) end
                    busy = false
                    refreshAutoBtn()
                    if data.tries >= 3 then found[tree] = nil end
                end
            end
            -- nada livre para coletar: troca de servidor (se autoHop estiver ligado)
            if not didWork and getgenv().autoHop then startHop() end
        end
    end
end)

-- tempo para o ESP/scan terminar antes de decidir
task.wait(5)
scanDone = true

----------------------------------------------------------------
-- Decisao: avisar no webhook e ficar / trocar de servidor
----------------------------------------------------------------
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
