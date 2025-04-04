-- Carregar a Rayfield UI Library com o link correto
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Criar a Janela Principal
local Window = Rayfield:CreateWindow({
    Name = "Pinto Hub",
    LoadingTitle = "Pinto Hub",
    LoadingSubtitle = "by PintoTeam",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "PintoHubConfig",
        FileName = "PintoHubSettings"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
    KeySystem = false
})

-- Variáveis de Controle
local ESPEnabled = false
local AimbotEnabled = false
local AimbotKey = Enum.KeyCode.E -- Tecla padrão
local AimbotMode = "Hold" -- Modo padrão
local AimbotActive = false

-- Criar a Aba Principal
local MainTab = Window:CreateTab("Funções", 4483345998)

-- Seção para ESP
local ESPSection = MainTab:CreateSection("ESP")

-- Toggle para o ESP
local ESPToggle = MainTab:CreateToggle({
    Name = "Ativar ESP",
    CurrentValue = false,
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

-- Seção para Aimbot
local AimbotSection = MainTab:CreateSection("Aimbot")

-- Toggle para o Aimbot
local AimbotToggle = MainTab:CreateToggle({
    Name = "Ativar Aimbot",
    CurrentValue = false,
    Flag = "Aimbot_Toggle",
    Callback = function(Value)
        AimbotEnabled = Value
        if not AimbotEnabled then
            AimbotActive = false
            StopAimbot()
        end
    end
})

-- Keybind para o Aimbot
local AimbotKeybind = MainTab:CreateKeybind({
    Name = "Tecla do Aimbot",
    CurrentKeybind = "E",
    HoldToInteract = false,
    Flag = "AimbotKeybind",
    Callback = function(Keybind)
        AimbotKey = Enum.KeyCode[Keybind]
    end
})

-- Dropdown para o Modo do Aimbot
local AimbotModeDropdown = MainTab:CreateDropdown({
    Name = "Modo do Aimbot",
    Options = {"Hold", "Toggle"},
    CurrentOption = AimbotMode,
    Flag = "AimbotMode",
    Callback = function(Option)
        AimbotMode = Option
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
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            ESPObjects[player] = highlight
        end
    end
    
    -- Monitor para novos jogadores
    game:GetService("Players").PlayerAdded:Connect(function(player)
        if ESPEnabled and player ~= game.Players.LocalPlayer then
            player.CharacterAdded:Connect(function(character)
                if ESPEnabled then
                    task.wait(1) -- Esperar que o personagem carregue completamente
                    local highlight = Instance.new("Highlight")
                    highlight.Adornee = character
                    highlight.Parent = game.CoreGui
                    highlight.FillColor = Color3.fromRGB(255, 0, 0)
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.5
                    highlight.OutlineTransparency = 0
                    ESPObjects[player] = highlight
                end
            end)
        end
    end)
end

function DisableESP()
    for player, highlight in pairs(ESPObjects) do
        if highlight and highlight.Parent then
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
        if player ~= LocalPlayer and player.Character and 
           player.Character:FindFirstChild("HumanoidRootPart") and 
           player.Character:FindFirstChild("Humanoid") and 
           player.Character.Humanoid.Health > 0 then
            
            local pos = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            if pos.Z > 0 then -- Verificar se o jogador está na frente da câmera
                local distance = (Vector2.new(pos.X, pos.Y) - Vector2.new(Mouse.X, Mouse.Y)).magnitude
                if distance < shortestDistance then
                    closestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end
    return closestPlayer
end

function StartAimbot()
    if AimbotConnection then return end
    
    AimbotConnection = RunService.RenderStepped:Connect(function()
        if AimbotActive and AimbotEnabled then
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
    if input.KeyCode == AimbotKey and AimbotEnabled then
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
    if input.KeyCode == AimbotKey and AimbotMode == "Hold" and AimbotEnabled then
        AimbotActive = false
        StopAimbot()
    end
end)

-- Tratamento de remoção de jogadores
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if ESPObjects[player] and ESPObjects[player].Parent then
        ESPObjects[player]:Destroy()
        ESPObjects[player] = nil
    end
end)

-- Configuração de notificação quando o script é carregado
Rayfield:Notify({
    Title = "Pinto Hub",
    Content = "Script carregado com sucesso!",
    Duration = 6.5,
    Image = 4483345998,
    Actions = {
        Ignore = {
            Name = "OK",
            Callback = function()
                print("O usuário reconheceu a notificação")
            end
        }
    }
})
