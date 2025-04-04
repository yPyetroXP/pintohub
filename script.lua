-- Carregar a Orion UI Library
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()

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
local AimbotKey = Enum.KeyCode.E -- Tecla padrão
local AimbotMode = "Hold" -- Modo padrão
local AimbotActive = false

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

-- Adicionar Seletor de Tecla (Keybind) para o Aimbot
Tab:AddBind({
    Name = "Tecla do Aimbot",
    Default = AimbotKey,
    Hold = false,
    Save = true,
    Flag = "AimbotKeybind",
    Callback = function(Key)
        AimbotKey = Key
    end
})

-- Adicionar Menu de Seleção para o Modo do Aimbot
Tab:AddDropdown({
    Name = "Modo do Aimbot",
    Default = AimbotMode,
    Options = {"Hold", "Toggle"},
    Save = true,
    Flag = "AimbotMode",
    Callback = function(Mode)
        AimbotMode = Mode
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

function StartAimbot()
    AimbotConnection = RunService.RenderStepped:Connect(function()
        if AimbotActive then
            local target = GetClosestPlayer()
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Character.HumanoidRootPart.Position)
            end
        end
    end)
end

function StopAimbot()
    if AimbotConnection then
        AimbotConnection:Disconnect()
        AimbotConnection = nil
    end
end

-- Lógica de Ativação do Aimbot com Keybind e Modo
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == AimbotKey then
        if AimbotMode == "Hold" then
            AimbotActive = true
            StartAimbot()
        elseif AimbotMode == "Toggle" then
            AimbotActive = not AimbotActive
            if AimbotActive then
                StartAimbot()
            else
                StopAimbot()
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == AimbotKey and AimbotMode == "Hold" then
        AimbotActive = false
        StopAimbot()
    end
end)

-- Inicializar a Interface
OrionLib:Init()
