local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Espera o jogo carregar completamente
if not game:IsLoaded() then game.Loaded:Wait() end

-- Sistema de GUI Super Seguro (Tenta CoreGui, se falhar vai pro PlayerGui)
local guiParent
pcall(function() 
    local core = game:GetService("CoreGui")
    if core then guiParent = core end
end)
if not guiParent then
    guiParent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Limpa versões anteriores
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
main.Size = UDim2.fromOffset(250, 200)
main.Position = UDim2.new(0, 20, 0.5, -100)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true 
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Lumber Farm (Seguro)"
title.Parent = main

local autoChop = false
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, -20, 0, 35)
autoBtn.Position = UDim2.new(0, 10, 0, 40)
autoBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 14
autoBtn.TextColor3 = Color3.new(1, 1, 1)
autoBtn.Text = "Auto Coletar: OFF"
autoBtn.Parent = main
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 6)

autoBtn.MouseButton1Click:Connect(function()
    autoChop = not autoChop
    autoBtn.Text = autoChop and "Auto Coletar: ON" or "Auto Coletar: OFF"
    autoBtn.BackgroundColor3 = autoChop and Color3.fromRGB(40, 150, 70) or Color3.fromRGB(150, 40, 40)
end)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -20, 0, 20)
statusLbl.Position = UDim2.new(0, 10, 0, 85)
statusLbl.BackgroundTransparency = 1
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 12
statusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLbl.Text = "Status: Aguardando..."
statusLbl.Parent = main

local function setStatus(txt)
    if statusLbl then statusLbl.Text = "Status: " .. txt end
end

----------------------------------------------------------------
-- Lógica do Jogo (Machados e Árvores)
----------------------------------------------------------------
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

local function isFree(tree)
    local o = tree:FindFirstChild("Owner")
    return (not o) or o.Value == nil or o.Value == LocalPlayer
end

local foundTrees = {}

local function addESP(tree, part, labelText, color)
    if not part then return end
    local hl = Instance.new("Highlight")
    hl.Adornee = tree
    hl.FillColor = color
    hl.FillTransparency = 0.5
    hl.Parent = espFolder

    local bb = Instance.new("BillboardGui")
    bb.Adornee = part
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(100, 30)
    bb.StudsOffset = Vector3.new(0, 5, 0)
    bb.Parent = espFolder

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.fromScale(1, 1)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = color
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 12
    txt.Text = labelText
    txt.Parent = bb

    foundTrees[tree] = {part = part}
    
    tree.AncestryChanged:Connect(function(_, parent)
        if not parent then
            hl:Destroy()
            bb:Destroy()
            foundTrees[tree] = nil
        end
    end)
end

-- Escaneia madeiras raras
for _, v in ipairs(workspace:GetDescendants()) do
    if v:IsA("StringValue") and v.Name == "TreeClass" then
        if v.Value == "Spooky" or v.Value == "SpookyNeon" then
            local tree = v.Parent
            task.spawn(function()
                local part = tree:WaitForChild("WoodSection", 3)
                if part then
                    addESP(tree, part, v.Value, Color3.fromRGB(255, 140, 0))
                end
            end)
        end
    end
end

----------------------------------------------------------------
-- Loop do Auto Farm
----------------------------------------------------------------
task.spawn(function()
    while task.wait(0.5) do
        if autoChop then
            local plot = getPlot()
            local axe = getAxe()
            local hrp = getHRP()

            if not plot then
                setStatus("Você não tem um terreno (Plot)!")
            elseif not axe then
                setStatus("Equipe ou pegue um machado!")
            elseif not hrp then
                setStatus("Carregando personagem...")
            else
                local targetTree = nil
                local targetPart = nil

                for tree, data in pairs(foundTrees) do
                    if tree.Parent and isFree(tree) then
                        targetTree = tree
                        targetPart = data.part
                        break
                    end
                end

                if targetTree and targetPart then
                    setStatus("Cortando " .. targetTree.Name .. "...")
                    
                    -- Teleporta e tenta cortar
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
                    setStatus("Nenhuma árvore livre encontrada.")
                end
            end
        else
            setStatus("Pausado.")
        end
    end
end)
