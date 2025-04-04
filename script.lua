-- Carregar a Orion UI Library
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shlexware/Orion/main/source')))()

-- Criar a Janela Principal
local Window = OrionLib:MakeWindow({
    Name = "Pinto Hub",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "PintoHubConfig"
})

-- Variáveis de Controle
local ESPEnabled = false
local AimbotEnabled = false

-- Criar a Aba Principal
local Tab = Window:MakeTab({
    Name = "Funções",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Adicionar Toggle para o ESP
Tab:AddToggle({
    Name = "Ativar ESP",
    Default = false,
    Save = true,
    Flag = "ESP_Toggle",
    Callback = function(Value)
        ESPEnabled = Value
        if ESPEnabled then
            EnableESP()
        else
            DisableESP()
        end
    end    
})

-- Adicionar Toggle para o Aimbot
Tab:AddToggle({
    Name = "Ativar Aimbot",
    Default = false,
    Save = true,
    Flag = "Aimbot_Toggle",
    Callback = function(Value)
        AimbotEnabled = Value
        if AimbotEnabled then
            EnableAimbot()
        else
            DisableAimbot()
        end
    end    
})

-- Funções do ESP
local ESPObjects = {}

function EnableESP()
    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        if player ~= game.Players.LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local highlight = Instance.new("Highlight")
            highlight.Adornee = player.Character
            highlight.Parent = game.CoreGui
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            ESPObjects[player] = highlight
        end
    end
end

function DisableESP()
    for player, highlight in pairs(ESPObjects) do
        if highlight then
            highlight:Destroy()
        end
    end
    ESPObjects = {}
end

-- Funções do Aimbot
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = game.Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local AimbotConnection

function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge

    for _, player in pairs(game:GetService("Players"):GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            local distance = (Vector2.new(pos.X, pos.Y) - Vector2.new(Mouse.X, Mouse.Y)).magnitude
            if distance < shortestDistance then
                closestPlayer = player
                shortestDistance = distance
            end
        end
    end
    return closestPlayer
end

function EnableAimbot()
    AimbotConnection = RunService.RenderStepped:Connect(function()
        if AimbotEnabled then
            local target = GetClosestPlayer()
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Character.HumanoidRootPart.Position)
            end
        end
    end)
end

function DisableAimbot()
    if AimbotConnection then
        AimbotConnection:Disconnect()
        AimbotConnection = nil
    end
end

-- Atualizar ESP Quando Jogadores Entram ou Saem
game:GetService("Players").PlayerAdded:Connect(function(player)
    if ESPEnabled then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = player.Character or player.CharacterAdded:Wait()
        highlight.Parent = game.CoreGui
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        ESPObjects[player] = highlight
    end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        ESPObjects[player]:Destroy()
        ESPObjects[player] = nil
    end
end)

-- Iniciar a Interface da Orion Library
OrionLib:Init()
