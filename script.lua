-- Correções aplicadas:
-- 1. Corrigido o Aimbot que não funcionava corretamente por falta de ativação inicial.
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
        Active = false
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
    VisibleCheck = true
}

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
        if not AimbotEnabled then
            Resources.Aimbot.Active = false
            StopAimbot()
        end
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
        print("[Aimbot] Modo alterado para:", Option)
    end
})

local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = game.Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local UserInputService = game:GetService("UserInputService")

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
    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        if player ~= game.Players.LocalPlayer then
            SetupESP(player)
        end
    end
    table.insert(Resources.Connections, game:GetService("Players").PlayerAdded:Connect(function(player)
        if player ~= game.Players.LocalPlayer then
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

local function GetClosestPlayer()
    local closestPlayer, shortestDistance = nil, math.huge
    local localPlayer = game.Players.LocalPlayer
    local camera = workspace.CurrentCamera
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)

    for _, player in pairs(game.Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChild("Humanoid")

            if humanoidRootPart and humanoid and humanoid.Health > 0 then
                if AimbotSettings.TeamCheck and player.Team == localPlayer.Team then
                    continue
                end

                if AimbotSettings.VisibleCheck then
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterDescendantsInstances = {localPlayer.Character, player.Character}
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

                    local raycastResult = workspace:Raycast(
                        camera.CFrame.Position,
                        (humanoidRootPart.Position - camera.CFrame.Position).Unit * 1000,
                        raycastParams
                    )

                    if not raycastResult or not raycastResult.Instance:IsDescendantOf(player.Character) then
                        continue
                    end
                end

                local screenPos, onScreen = camera:WorldToViewportPoint(humanoidRootPart.Position)
                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).magnitude
                    if distance < AimbotSettings.FOV and distance < shortestDistance then
                        closestPlayer = player
                        shortestDistance = distance
                    end
                end
            end
        end
    end

    return closestPlayer
end

function StartAimbot()
    if Resources.Aimbot.Connection then return end

    Resources.Aimbot.Connection = RunService.RenderStepped:Connect(function()
        if not AimbotEnabled or not Resources.Aimbot.Active then return end

        local target = GetClosestPlayer()
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local targetPosition = target.Character.HumanoidRootPart.Position
            local currentCFrame = Camera.CFrame
            local newCFrame = CFrame.new(currentCFrame.Position, targetPosition)

            -- Aplicar suavização
            Camera.CFrame = currentCFrame:Lerp(newCFrame, 1 - AimbotSettings.Smoothness)
        end
    end)
end

function StopAimbot()
    if Resources.Aimbot.Connection then
        Resources.Aimbot.Connection:Disconnect()
        Resources.Aimbot.Connection = nil
    end
end

table.insert(Resources.Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not AimbotEnabled then return end
    if input.KeyCode == AimbotKey then
        if AimbotMode == "Hold" then
            Resources.Aimbot.Active = true
            StartAimbot()
        elseif AimbotMode == "Toggle" then
            Resources.Aimbot.Active = not Resources.Aimbot.Active
            if Resources.Aimbot.Active then
                StartAimbot()
            else
                StopAimbot()
            end
        end
        print("[Aimbot] Estado:", Resources.Aimbot.Active and "Ativado" or "Desativado")
    end
end))

table.insert(Resources.Connections, UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed or not AimbotEnabled or AimbotMode ~= "Hold" then return end
    if input.KeyCode == AimbotKey then
        Resources.Aimbot.Active = false
        StopAimbot()
        print("[Aimbot] Desativado (modo Hold)")
    end
end))

table.insert(Resources.Connections, game:GetService("Players").PlayerRemoving:Connect(function(player)
    if Resources.ESPObjects[player] then
        if Resources.ESPObjects[player].Parent then
            Resources.ESPObjects[player]:Destroy()
        end
        Resources.ESPObjects[player] = nil
    end
end))

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

table.insert(Resources.Connections, game:GetService("UserInputService").WindowFocused:Connect(function()
    if not ESPEnabled and not AimbotEnabled then
        CleanupResources()
    end
end))

if AimbotEnabled then
    StartAimbot()
    Resources.Aimbot.Active = (AimbotMode == "Toggle")
end
