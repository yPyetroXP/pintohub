-- Correções aplicadas:
-- 1. Refeito o sistema Aimbot completamente para garantir funcionamento correto
-- 2. Adicionada a opção de "Check Team" no menu ESP, respeitando a configuração no SetupESP.

local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success then
    warn("Falha ao carregar Rayfield:", Rayfield)
    return
end

local Resources = {
    Connections = {},
    ESPObjects = {},
    Aimbot = {
        Connection = nil,
        Active = false,
        Target = nil
    }
}

local function CleanupResources()
    for _, connection in pairs(Resources.Connections) do
        if connection then
            connection:Disconnect()
        end
    end
    Resources.Connections = {}

    for player, highlight in pairs(Resources.ESPObjects) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    Resources.ESPObjects = {}

    if Resources.Aimbot.Connection then
        Resources.Aimbot.Connection:Disconnect()
        Resources.Aimbot.Connection = nil
    end
    Resources.Aimbot.Active = false
    Resources.Aimbot.Target = nil
end

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

local ESPEnabled = false
local AimbotEnabled = false
local AimbotKey = Enum.KeyCode.E
local AimbotMode = "Hold"

local ESPSettings = {
    FillColor = Color3.fromRGB(255, 0, 0),
    OutlineColor = Color3.fromRGB(255, 255, 255),
    FillTransparency = 0.5,
    OutlineTransparency = 0,
    TeamCheck = false
}

local AimbotSettings = {
    Smoothness = 0.5,
    FOV = 100,
    TeamCheck = true,
    VisibleCheck = true,
    AimPart = "Head",  -- Nova opção para escolher parte do corpo
    FOVVisible = true, -- Nova opção para mostrar círculo de FOV
    DrawFOVColor = Color3.fromRGB(255, 255, 255) -- Cor do círculo de FOV
}

-- Serviços
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Elementos visuais do Aimbot
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Thickness = 1
FOVCircle.NumSides = 30
FOVCircle.Radius = AimbotSettings.FOV
FOVCircle.Filled = false
FOVCircle.Transparency = 0.7
FOVCircle.Color = AimbotSettings.DrawFOVColor

local function UpdateFOVCircle()
    if not FOVCircle then return end
    
    FOVCircle.Visible = AimbotEnabled and AimbotSettings.FOVVisible
    FOVCircle.Radius = AimbotSettings.FOV
    FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
    FOVCircle.Color = AimbotSettings.DrawFOVColor
end

local function getValidKeybind(key)
    if type(key) == "string" then
        local cleanedKey = key:gsub("%s+", ""):upper()
        if Enum.KeyCode[cleanedKey] then
            return Enum.KeyCode[cleanedKey]
        end
    elseif typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
        return key
    end
    return Enum.KeyCode.E
end

local MainTab = Window:CreateTab("Funções", 4483345998)

local ESPSection = MainTab:CreateSection("ESP")

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

local ESPTeamCheckToggle = MainTab:CreateToggle({
    Name = "Check Team no ESP",
    CurrentValue = false,
    Flag = "ESP_TeamCheck",
    Callback = function(Value)
        ESPSettings.TeamCheck = Value
        if ESPEnabled then
            EnableESP()
        end
    end
})

local DestroyButton = MainTab:CreateButton({
    Name = "Destruir Interface",
    Callback = function()
        CleanupResources()
        if FOVCircle then
            FOVCircle:Remove()
        end
        Rayfield:Destroy()
        print("Interface destruída.")
    end
})

local AimbotSection = MainTab:CreateSection("Aimbot")

local AimbotToggle = MainTab:CreateToggle({
    Name = "Ativar Aimbot",
    CurrentValue = false,
    Flag = "Aimbot_Toggle",
    Callback = function(Value)
        AimbotEnabled = Value
        if AimbotEnabled then
            RunService:BindToRenderStep("AimbotUpdate", Enum.RenderPriority.Last.Value, AimbotUpdate)
            print("[Aimbot] Ativado")
        else
            RunService:UnbindFromRenderStep("AimbotUpdate")
            Resources.Aimbot.Active = false
            Resources.Aimbot.Target = nil
            print("[Aimbot] Desativado")
        end
        
        FOVCircle.Visible = AimbotEnabled and AimbotSettings.FOVVisible
    end
})

local AimbotKeybind = MainTab:CreateKeybind({
    Name = "Tecla do Aimbot",
    CurrentKeybind = "E",
    HoldToInteract = false,
    Flag = "AimbotKeybind",
    Callback = function(Keybind)
        local newKey = getValidKeybind(Keybind)
        AimbotKey = newKey
        print("[Aimbot] Tecla definida para:", newKey.Name or "E")
    end
})

local AimbotModeDropdown = MainTab:CreateDropdown({
    Name = "Modo do Aimbot",
    Options = {"Hold", "Toggle"},
    CurrentOption = AimbotMode,
    Flag = "AimbotMode",
    Callback = function(Option)
        AimbotMode = Option
        Resources.Aimbot.Active = false
        print("[Aimbot] Modo alterado para:", Option)
    end
})

local AimbotPartDropdown = MainTab:CreateDropdown({
    Name = "Parte do Corpo",
    Options = {"Head", "HumanoidRootPart", "Torso"},
    CurrentOption = AimbotSettings.AimPart,
    Flag = "AimbotPart",
    Callback = function(Option)
        AimbotSettings.AimPart = Option
        print("[Aimbot] Parte do corpo alterada para:", Option)
    end
})

local AimbotFOVSlider = MainTab:CreateSlider({
    Name = "FOV do Aimbot",
    Range = {10, 400},
    Increment = 5,
    Suffix = "px",
    CurrentValue = AimbotSettings.FOV,
    Flag = "AimbotFOV",
    Callback = function(Value)
        AimbotSettings.FOV = Value
        FOVCircle.Radius = Value
        print("[Aimbot] FOV ajustado para:", Value)
    end,
})

local AimbotSmoothnessSlider = MainTab:CreateSlider({
    Name = "Suavização do Aimbot",
    Range = {0, 10},
    Increment = 0.1,
    Suffix = "",
    CurrentValue = AimbotSettings.Smoothness * 10,
    Flag = "AimbotSmoothness",
    Callback = function(Value)
        AimbotSettings.Smoothness = Value / 10
        print("[Aimbot] Suavização ajustada para:", Value / 10)
    end,
})

local AimbotTeamCheckToggle = MainTab:CreateToggle({
    Name = "Check Team no Aimbot",
    CurrentValue = AimbotSettings.TeamCheck,
    Flag = "AimbotTeamCheck",
    Callback = function(Value)
        AimbotSettings.TeamCheck = Value
        print("[Aimbot] Check Team:", Value and "Ativado" or "Desativado")
    end
})

local AimbotVisibleCheckToggle = MainTab:CreateToggle({
    Name = "Check Visibilidade",
    CurrentValue = AimbotSettings.VisibleCheck,
    Flag = "AimbotVisibleCheck",
    Callback = function(Value)
        AimbotSettings.VisibleCheck = Value
        print("[Aimbot] Check Visibilidade:", Value and "Ativado" or "Desativado")
    end
})

local AimbotFOVVisibleToggle = MainTab:CreateToggle({
    Name = "Mostrar Círculo FOV",
    CurrentValue = AimbotSettings.FOVVisible,
    Flag = "AimbotFOVVisible",
    Callback = function(Value)
        AimbotSettings.FOVVisible = Value
        FOVCircle.Visible = AimbotEnabled and Value
        print("[Aimbot] Círculo FOV:", Value and "Visível" or "Oculto")
    end
})

local function SetupESP(player)
    if not player or not player.Character then return end

    if ESPSettings.TeamCheck and player.Team == LocalPlayer.Team then return end

    local function createHighlight(character)
        if Resources.ESPObjects[player] and Resources.ESPObjects[player].Parent then
            Resources.ESPObjects[player]:Destroy()
        end

        local highlight = Instance.new("Highlight")
        highlight.Adornee = character
        highlight.Parent = game.CoreGui
        highlight.FillColor = ESPSettings.FillColor
        highlight.OutlineColor = ESPSettings.OutlineColor
        highlight.FillTransparency = ESPSettings.FillTransparency
        highlight.OutlineTransparency = ESPSettings.OutlineTransparency
        Resources.ESPObjects[player] = highlight
    end

    table.insert(Resources.Connections, player.CharacterAdded:Connect(function(character)
        task.wait(1)
        if ESPEnabled and (not ESPSettings.TeamCheck or player.Team ~= LocalPlayer.Team) then
            createHighlight(character)
        end
    end))

    createHighlight(player.Character)
end

function EnableESP()
    DisableESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            SetupESP(player)
        end
    end
    table.insert(Resources.Connections, Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            SetupESP(player)
        end
    end))
end

function DisableESP()
    for player, highlight in pairs(Resources.ESPObjects) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    Resources.ESPObjects = {}
end

-- Função que verifica se um jogador é válido para o Aimbot
local function IsPlayerValid(player)
    if player == LocalPlayer then return false end
    if not player.Character then return false end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    local targetPart = player.Character:FindFirstChild(AimbotSettings.AimPart)
    if not targetPart then return false end
    
    if AimbotSettings.TeamCheck and player.Team == LocalPlayer.Team then return false end
    
    if AimbotSettings.VisibleCheck then
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, player.Character}
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        
        local direction = (targetPart.Position - Camera.CFrame.Position).Unit
        local raycastResult = workspace:Raycast(Camera.CFrame.Position, direction * 1000, raycastParams)
        
        if not raycastResult or not raycastResult.Instance:IsDescendantOf(player.Character) then
            return false
        end
    end
    
    return true
end

-- Função que encontra o jogador mais próximo do mouse dentro do FOV
local function GetClosestPlayerToMouse()
    local closestPlayer = nil
    local shortestDistance = AimbotSettings.FOV
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    
    for _, player in pairs(Players:GetPlayers()) do
        if IsPlayerValid(player) then
            local targetPart = player.Character:FindFirstChild(AimbotSettings.AimPart)
            if targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    
                    if distance < shortestDistance then
                        closestPlayer = player
                        shortestDistance = distance
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

-- Função principal do Aimbot que é executada a cada frame
function AimbotUpdate()
    UpdateFOVCircle()
    
    if not AimbotEnabled or not Resources.Aimbot.Active then
        return
    end
    
    -- Obtém o alvo atual ou encontra um novo
    local target = Resources.Aimbot.Target
    if not target or not IsPlayerValid(target) then
        target = GetClosestPlayerToMouse()
        Resources.Aimbot.Target = target
    end
    
    -- Se tiver um alvo válido, mira nele
    if target and target.Character then
        local targetPart = target.Character:FindFirstChild(AimbotSettings.AimPart)
        if targetPart then
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            
            if onScreen then
                -- Calcula a nova posição do mouse com suavização
                local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                local targetPos = Vector2.new(screenPos.X, screenPos.Y)
                local newPos = mousePos:Lerp(targetPos, 1 - AimbotSettings.Smoothness)
                
                -- Move o mouse para a posição calculada
                mousemoveabs(newPos.X, newPos.Y)
            else
                -- Se o alvo sair da tela, procura um novo alvo
                Resources.Aimbot.Target = nil
            end
        end
    end
end

-- Gerencia eventos de input para ativar/desativar o Aimbot
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not AimbotEnabled then return end
    
    if input.KeyCode == AimbotKey then
        if AimbotMode == "Toggle" then
            Resources.Aimbot.Active = not Resources.Aimbot.Active
            Resources.Aimbot.Target = nil
            print("[Aimbot] " .. (Resources.Aimbot.Active and "Ativado" or "Desativado") .. " (Toggle)")
        elseif AimbotMode == "Hold" then
            Resources.Aimbot.Active = true
            Resources.Aimbot.Target = nil
            print("[Aimbot] Ativado (Hold)")
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed or not AimbotEnabled then return end
    
    if input.KeyCode == AimbotKey and AimbotMode == "Hold" then
        Resources.Aimbot.Active = false
        Resources.Aimbot.Target = nil
        print("[Aimbot] Desativado (Hold)")
    end
end)

-- Limpa recursos quando um jogador sai
Players.PlayerRemoving:Connect(function(player)
    if Resources.ESPObjects[player] then
        if Resources.ESPObjects[player].Parent then
            Resources.ESPObjects[player]:Destroy()
        end
        Resources.ESPObjects[player] = nil
    end
    
    if Resources.Aimbot.Target == player then
        Resources.Aimbot.Target = nil
    end
end)

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

-- Atualização constante do círculo de FOV
RunService:BindToRenderStep("FOVUpdate", Enum.RenderPriority.Camera.Value + 1, UpdateFOVCircle)

-- Limpeza ao fechar o script
game:GetService("UserInputService").WindowFocused:Connect(function()
    if not ESPEnabled and not AimbotEnabled then
        CleanupResources()
    end
end)
