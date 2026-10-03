local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

if not game:IsLoaded() then game.Loaded:Wait() end

-- Configurações globais
if getgenv().slot == nil then getgenv().slot = 1 end

local guiParent
pcall(function() 
    local core = game:GetService("CoreGui")
    if core then guiParent = core end
end)
if not guiParent then
    guiParent = LocalPlayer:WaitForChild("PlayerGui")
end

for _, v in pairs(guiParent:GetChildren()) do
    if v.Name == "TreeTP_Mobile" or v.Name == "TreeESP" then
        v:Destroy()
    end
end

local espFolder = Instance.new("Folder")
espFolder.Name = "TreeESP"
espFolder.Parent = guiParent

local gui = Instance.new("ScreenGui")
gui.Name = "TreeTP_Mobile"
gui.ResetOnSpawn = false
gui.Parent = guiParent

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(260, 380)
main.Position = UDim2.new(0, 20, 0.5, -190)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true 
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 30)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Lumber Farm (Auto Plot)"
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

-- Status
local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -20, 0, 20)
statusLbl.Position = UDim2.new(0, 10, 0, 35)
statusLbl.BackgroundTransparency = 1
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 11
statusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLbl.Text = "Status: Iniciando..."
statusLbl.Parent = main

local function setStatus(txt)
    if statusLbl then statusLbl.Text = "Status: " .. txt end
end

-- Botão Auto Coletar
local autoChop = false
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, -20, 0, 28)
autoBtn.Position = UDim2.new(0, 10, 0, 60)
autoBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 12
autoBtn.TextColor3 = Color3.new(1, 1, 1)
autoBtn.Text = "Auto Coletar: OFF"
autoBtn.Parent = main
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 6)

autoBtn.MouseButton1Click:Connect(function()
    autoChop = not autoChop
    autoBtn.Text = autoChop and "Auto Coletar: ON" or "Auto Coletar: OFF"
    autoBtn.BackgroundColor3 = autoChop and Color3.fromRGB(40, 150, 70) or Color3.fromRGB(150, 40, 40)
end)

-- Botão Resgatar Machados Caídos
local rescueBtn = Instance.new("TextButton")
rescueBtn.Size = UDim2.new(1, -20, 0, 28)
rescueBtn.Position = UDim2.new(0, 10, 0, 92)
rescueBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
rescueBtn.BorderSizePixel = 0
rescueBtn.Font = Enum.Font.GothamBold
rescueBtn.TextSize = 11
rescueBtn.TextColor3 = Color3.new(1, 1, 1)
rescueBtn.Text = "Resgatar Machados do Chão"
rescueBtn.Parent = main
Instance.new("UICorner", rescueBtn).CornerRadius = UDim.new(0, 6)

rescueBtn.MouseButton1Click:Connect(function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local count = 0
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Tool") or (obj:IsA("Model") and (obj.Name:lower():find("axe") or obj:FindFirstChild("ToolName"))) then
            pcall(function()
                obj:PivotTo(hrp.CFrame + Vector3.new(math.random(-3, 3), 2, math.random(-3, 3)))
                count = count + 1
            end)
        end
    end
    setStatus("Machados resgatados: " .. count)
end)

-- Botão Server Hop
local hopBtn = Instance.new("TextButton")
hopBtn.Size = UDim2.new(1, -20, 0, 28)
hopBtn.Position = UDim2.new(0, 10, 0, 124)
hopBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 160)
hopBtn.BorderSizePixel = 0
hopBtn.Font = Enum.Font.GothamBold
hopBtn.TextSize = 11
hopBtn.TextColor3 = Color3.new(1, 1, 1)
hopBtn.Text = "Server Hop"
hopBtn.Parent = main
Instance.new("UICorner", hopBtn).CornerRadius = UDim.new(0, 6)

hopBtn.MouseButton1Click:Connect(function()
    setStatus("Trocando de servidor...")
    pcall(function()
        local response = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
        if response then
            local data = HttpService:JSONDecode(response)
            if data and data.data then
                for _, s in ipairs(data.data) do
                    if s.playing < s.maxPlayers and tostring(s.id) ~= tostring(game.JobId) then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, tostring(s.id), LocalPlayer)
                        return
                    end
                end
            end
        end
    end)
end)

-- Lista de Árvores com TP Separado
local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(10, 160)
list.Size = UDim2.new(1, -20, 1, -170)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = main
local layout = Instance.new("UIListLayout", list)
layout.Padding = UDim.new(0, 5)

-- Funções utilitárias do jogo
local function getAxe()
    local function findIn(container)
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") and (t.Name:lower():find("axe") or (t:FindFirstChild("ToolName") and tostring(t.ToolName.Value):lower():find("axe"))) then
                return t
            end
        end
    end
    return findIn(LocalPlayer.Character) or findIn(LocalPlayer:FindFirstChild("Backpack"))
end

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

local function loadSlot()
    if getPlot() then return true end
    local LS = RS:FindFirstChild("LoadSaveRequests")
    if not LS then return false end
    pcall(function() LS.ClientMayLoad:InvokeServer(LocalPlayer) end)
    task.wait(0.5)
    pcall(function() LS.RequestLoad:InvokeServer(getgenv().slot or 1, LocalPlayer) end)
    task.wait(2)
    return getPlot() ~= nil
end

local function isFree(tree)
    local o = tree:FindFirstChild("Owner")
    return (not o) or o.Value == nil or o.Value == LocalPlayer
end

local foundTrees = {}

local function addButton(tree, labelText, part, color)
    if tree:FindFirstChild("UIBtn") then return end
    
    local btn = Instance.new("TextButton")
    btn.Name = "UIBtn"
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.3
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = "TP: " .. labelText
    btn.Parent = list
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        local hrp = getHRP()
        if hrp and part and part.Parent then
            hrp.CFrame = part.CFrame + Vector3.new(0, 5, 0)
            setStatus("Teleportado para " .. labelText)
        end
    end)

    foundTrees[tree] = {part = part, button = btn, name = labelText}
    
    tree.AncestryChanged:Connect(function(_, parent)
        if not parent then
            btn:Destroy()
            foundTrees[tree] = nil
        end
    end)
end

-- Escaneia árvores especiais
for _, v in ipairs(workspace:GetDescendants()) do
    if v:IsA("StringValue") and v.Name == "TreeClass" then
        if v.Value == "Spooky" or v.Value == "SpookyNeon" then
            local tree = v.Parent
            task.spawn(function()
                local part = tree:WaitForChild("WoodSection", 3)
                if part then
                    addButton(tree, v.Value, part, Color3.fromRGB(255, 140, 0))
                end
            end)
        end
    end
end

workspace.DescendantAdded:Connect(function(v)
    if v:IsA("StringValue") and v.Name == "TreeClass" then
        if v.Value == "Spooky" or v.Value == "SpookyNeon" then
            local tree = v.Parent
            task.spawn(function()
                local part = tree:WaitForChild("WoodSection", 3)
                if part then
                    addButton(tree, v.Value, part, Color3.fromRGB(255, 140, 0))
                end
            end)
        end
    end
end)

-- Minimizador da GUI
local collapsed = false
toggle.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    autoBtn.Visible = not collapsed
    rescueBtn.Visible = not collapsed
    hopBtn.Visible = not collapsed
    list.Visible = not collapsed
    statusLbl.Visible = not collapsed
    main.Size = collapsed and UDim2.fromOffset(260, 30) or UDim2.fromOffset(260, 380)
    toggle.Text = collapsed and "+" or "-"
end)

-- **Resgate Automático de Plot na Inicialização**
task.spawn(function()
    setStatus("Verificando terreno...")
    if not getPlot() then
        setStatus("Resgatando seu plot...")
        loadSlot()
    end
    setStatus("Pronto")
end)

-- Loop do Auto Farm seguro
task.spawn(function()
    while task.wait(1) do
        if autoChop then
            local plot = getPlot()
            if not plot then
                setStatus("Carregando Slot...")
                loadSlot()
            else
                local axe = getAxe()
                local hrp = getHRP()

                if not axe then
                    setStatus("Equipe um machado!")
                else
                    local targetTree, targetPart = nil, nil
                    for tree, data in pairs(foundTrees) do
                        if tree.Parent and isFree(tree) then
                            targetTree = tree
                            targetPart = data.part
                            break
                        end
                    end

                    if targetTree and targetPart then
                        setStatus("Cortando...")
                        hrp.CFrame = targetPart.CFrame + Vector3.new(3, 3, 0)
                        
                        local cutEvent = targetTree:FindFirstChild("CutEvent")
                        if cutEvent then
                            pcall(function()
                                RS.Interaction.RemoteProxy:FireServer(cutEvent, {
                                    tool = axe,
                                    faceVector = Vector3.new(1, 0, 0),
                                    height = 0.3,
                                    sectionId = 1,
                                    hitPoints = 5,
                                    cooldown = 0.2,
                                    cuttingClass = "Axe"
                                })
                            end)
                        end
                    else
                        setStatus("Nenhuma árvore livre.")
                    end
                end
            end
        else
            setStatus("Pausado.")
        end
    end
end)
