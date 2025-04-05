-- Correções aplicadas:
-- 1. Substituído movimento do mouse por manipulação da câmera
-- 2. Adicionado delay nas logs de alvo para evitar lag
-- 3. Mantido botão Rejoin e teste de câmera
-- 4. Adicionada aba de Configurações para salvar e carregar perfis

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
        if connection then connection:Disconnect() end
    end
    Resources.Connections = {}
    for player, highlight in pairs(Resources.ESPObjects) do
        if highlight and highlight.Parent then highlight:Destroy() end
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
    ConfigurationSaving = {Enabled = true, FolderName = "PintoHubConfig", FileName = "PintoHubSettings"},
    Discord = {Enabled = false, Invite = "", RememberJoins = true},
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
    FOV = 400,
    TeamCheck = false,
    VisibleCheck = false,
    AimPart = "Head",
    FOVVisible = true,
    DrawFOVColor = Color3.fromRGB(255, 255, 255)
}

-- Serviços
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Controle de delay para logs
local lastTargetLogTime = 0
local targetLogCooldown = 1 -- Delay de 1 segundo entre logs de alvo

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
        if Enum.KeyCode[cleanedKey] then return Enum.KeyCode[cleanedKey] end
    elseif typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
        return key
    end
    return Enum.KeyCode.E
end

-- Aba Funções
local MainTab = Window:CreateTab("Funções", 4483345998)
local ESPSection = MainTab:CreateSection("ESP")

local ESPToggle = MainTab:CreateToggle({
    Name = "Ativar ESP",
    CurrentValue = false,
    Flag = "ESP_Toggle",
    Callback = function(Value)
        ESPEnabled = Value
        if ESPEnabled then EnableESP() else DisableESP() end
    end
})

local ESPTeamCheckToggle = MainTab:CreateToggle({
    Name = "Check Team no ESP",
    CurrentValue = false,
    Flag = "ESP_TeamCheck",
    Callback = function(Value)
        ESPSettings.TeamCheck = Value
        if ESPEnabled then EnableESP() end
    end
})

local DestroyButton = MainTab:CreateButton({
    Name = "Destruir Interface",
    Callback = function()
        CleanupResources()
        if FOVCircle then FOVCircle:Remove() end
        Rayfield:Destroy()
        print("Interface destruída.")
    end
})

local RejoinButton = MainTab:CreateButton({
    Name = "Rejoin",
    Callback = function()
        local placeId = game.PlaceId
        local jobId = game.JobId
        print("[Pinto Hub] Tentando reconectar ao servidor:", jobId)
        TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
    end
})

local TestCameraButton = MainTab:CreateButton({
    Name = "Testar Câmera",
    Callback = function()
        print("[Teste] Rotacionando câmera para frente")
        local currentCFrame = Camera.CFrame
        local targetCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + Vector3.new(0, 0, -10))
        Camera.CFrame = targetCFrame
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
            print("[Aimbot] Ativado globalmente")
        else
            RunService:UnbindFromRenderStep("AimbotUpdate")
            Resources.Aimbot.Active = false
            Resources.Aimbot.Target = nil
            print("[Aimbot] Desativado globalmente")
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
    end
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
    end
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

-- Nova Aba de Configurações
local ConfigTab = Window:CreateTab("Configurações", 4483362458)
local ConfigSection = ConfigTab:CreateSection("Gerenciar Configurações")

-- Função para obter a lista de perfis salvos
local function GetSavedProfiles()
    local configFolder = "PintoHubConfig"
    if not isfolder(configFolder) then
        return {"Nenhum perfil encontrado"}
    end
    local files = listfiles(configFolder)
    local profiles = {}
    for _, file in ipairs(files) do
        local profileName = file:match(configFolder .. "/(.+)%.json$")
        if profileName then
            table.insert(profiles, profileName)
        end
    end
    if #profiles == 0 then
        return {"Nenhum perfil encontrado"}
    end
    return profiles
end

-- Campo de texto para nome do perfil
local ProfileNameInput = ConfigTab:CreateInput({
    Name = "Nome do Perfil",
    Info = "Digite o nome do perfil para salvar ou carregar",
    PlaceholderText = "MeuPerfil",
    CurrentValue = "",
    Flag = "ProfileName",
    Callback = function(Value)
        print("[Config] Nome do perfil definido para:", Value)
    end
})

-- Dropdown para listar perfis salvos
local ProfileDropdown = ConfigTab:CreateDropdown({
    Name = "Perfis Salvos",
    Options = GetSavedProfiles(),
    CurrentOption = "Nenhum perfil encontrado",
    Flag = "ProfileDropdown",
    Callback = function(Option)
        ProfileNameInput:Set(Option) -- Atualiza o campo de texto com o perfil selecionado
        print("[Config] Perfil selecionado:", Option)
    end
})

-- Botão para salvar configurações
local SaveConfigButton = ConfigTab:CreateButton({
    Name = "Salvar Configurações",
    Callback = function()
        local profileName = ProfileNameInput.CurrentValue
        if profileName == "" or profileName == "Nenhum perfil encontrado" then
            Rayfield:Notify({
                Title = "Erro",
                Content = "Por favor, insira um nome válido para o perfil!",
                Duration = 3,
                Image = 4483362458
            })
            return
        end

        -- Salva as configurações atuais
        local configData = {
            AimbotSettings = AimbotSettings,
            ESPSettings = ESPSettings,
            AimbotEnabled = AimbotEnabled,
            ESPEnabled = ESPEnabled,
            AimbotKey = AimbotKey.Name,
            AimbotMode = AimbotMode
        }

        local configFolder = "PintoHubConfig"
        if not isfolder(configFolder) then
            makefolder(configFolder)
        end

        writefile(configFolder .. "/" .. profileName .. ".json", game:GetService("HttpService"):JSONEncode(configData))
        Rayfield:Notify({
            Title = "Sucesso",
            Content = "Configurações salvas como: " .. profileName,
            Duration = 3,
            Image = 4483362458
        })

        -- Atualiza o dropdown com os perfis salvos
        ProfileDropdown:Refresh(GetSavedProfiles(), profileName)
    end
})

-- Botão para carregar configurações
local LoadConfigButton = ConfigTab:CreateButton({
    Name = "Carregar Configurações",
    Callback = function()
        local profileName = ProfileNameInput.CurrentValue
        local configFolder = "PintoHubConfig"
        local filePath = configFolder .. "/" .. profileName .. ".json"

        if not isfile(filePath) then
            Rayfield:Notify({
                Title = "Erro",
                Content = "Perfil não encontrado: " .. profileName,
                Duration = 3,
                Image = 4483362458
            })
            return
        end

        local configData = game:GetService("HttpService"):JSONDecode(readfile(filePath))

        -- Carrega as configurações
        AimbotSettings = configData.AimbotSettings or AimbotSettings
        ESPSettings = configData.ESPSettings or ESPSettings
        AimbotEnabled = configData.AimbotEnabled or AimbotEnabled
        ESPEnabled = configData.ESPEnabled or ESPEnabled
        AimbotKey = Enum.KeyCode[configData.AimbotKey] or AimbotKey
        AimbotMode = configData.AimbotMode or AimbotMode

        -- Atualiza os elementos da interface
        AimbotToggle:Set(AimbotEnabled)
        ESPToggle:Set(ESPEnabled)
        AimbotKeybind:Set(AimbotKey.Name)
        AimbotModeDropdown:Set(AimbotMode)
        AimbotPartDropdown:Set(AimbotSettings.AimPart)
        AimbotFOVSlider:Set(AimbotSettings.FOV)
        AimbotSmoothnessSlider:Set(AimbotSettings.Smoothness * 10)
        AimbotTeamCheckToggle:Set(AimbotSettings.TeamCheck)
        AimbotVisibleCheckToggle:Set(AimbotSettings.VisibleCheck)
        AimbotFOVVisibleToggle:Set(AimbotSettings.FOVVisible)
        ESPTeamCheckToggle:Set(ESPSettings.TeamCheck)

        Rayfield:Notify({
            Title = "Sucesso",
            Content = "Configurações carregadas de: " .. profileName,
            Duration = 3,
            Image = 4483362458
        })
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
        if player ~= LocalPlayer then SetupESP(player) end
    end
    table.insert(Resources.Connections, Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then SetupESP(player) end
    end))
end

function DisableESP()
    for player, highlight in pairs(Resources.ESPObjects) do
        if highlight and highlight.Parent then highlight:Destroy() end
    end
    Resources.ESPObjects = {}
end

local function IsPlayerValid(player)
    if player == LocalPlayer then return false end
    if not player.Character then return false end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    local targetPart = player.Character:FindFirstChild(AimbotSettings.AimPart)
    if not targetPart then 
        print("[Aimbot] Parte do corpo não encontrada:", AimbotSettings.AimPart)
        return false 
    end
    
    if AimbotSettings.TeamCheck and player.Team == LocalPlayer.Team then return false end
    if AimbotSettings.VisibleCheck then
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        local origin = Camera.CFrame.Position
        local direction = (targetPart.Position - origin)
        local raycastResult = workspace:Raycast(origin, direction, raycastParams)
        if raycastResult and raycastResult.Instance then
            local hitModel = raycastResult.Instance:FindFirstAncestorOfClass("Model")
            if hitModel ~= player.Character then return false end
        end
    end
    
    return true
end

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
                        local currentTime = tick()
                        if currentTime - lastTargetLogTime >= targetLogCooldown then
                            print("[Aimbot] Alvo encontrado:", player.Name, "Distância:", distance)
                            lastTargetLogTime = currentTime
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

function AimbotUpdate()
    UpdateFOVCircle()
    
    if not AimbotEnabled then return end
    
    if AimbotMode == "Hold" and not UserInputService:IsKeyDown(AimbotKey) then
        Resources.Aimbot.Active = false
        Resources.Aimbot.Target = nil
        return
    end
    
    if not Resources.Aimbot.Active then return end
    
    local target = Resources.Aimbot.Target
    if not target or not IsPlayerValid(target) then
        target = GetClosestPlayerToMouse()
        Resources.Aimbot.Target = target
    end
    
    if target and target.Character then
        local targetPart = target.Character:FindFirstChild(AimbotSettings.AimPart)
        if targetPart then
            local currentCFrame = Camera.CFrame
            local targetPosition = targetPart.Position
            local targetCFrame = CFrame.new(currentCFrame.Position, targetPosition)
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CFrame = currentCFrame:Lerp(targetCFrame, 1 - AimbotSettings.Smoothness)
            print("[Aimbot] Câmera ajustada para alvo:", target.Name)
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not AimbotEnabled then return end
    
    if input.KeyCode == AimbotKey then
        if AimbotMode == "Toggle" then
            Resources.Aimbot.Active = not Resources.Aimbot.Active
            Resources.Aimbot.Target = nil
            print("[Aimbot] Estado Toggle:", Resources.Aimbot.Active and "Ativado" or "Desativado")
        elseif AimbotMode == "Hold" then
            Resources.Aimbot.Active = true
            Resources.Aimbot.Target = nil
            print("[Aimbot] Ativado (Hold)")
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed or not AimbotEnabled then return end
    if AimbotMode == "Hold" and input.KeyCode == AimbotKey then
        Resources.Aimbot.Active = false
        Resources.Aimbot.Target = nil
        print("[Aimbot] Desativado (Hold)")
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if Resources.ESPObjects[player] then
        if Resources.ESPObjects[player].Parent then Resources.ESPObjects[player]:Destroy() end
        Resources.ESPObjects[player] = nil
    end
    if Resources.Aimbot.Target == player then Resources.Aimbot.Target = nil end
end)

Rayfield:Notify({
    Title = "Pinto Hub",
    Content = "Script carregado com sucesso!",
    Duration = 6.5,
    Image = 4483345998,
    Actions = {Ignore = {Name = "OK", Callback = function() print("O usuário reconheceu a notificação") end}}
})

RunService:BindToRenderStep("FOVUpdate", Enum.RenderPriority.Camera.Value + 1, UpdateFOVCircle)

game:GetService("UserInputService").WindowFocused:Connect(function()
    if not ESPEnabled and not AimbotEnabled then CleanupResources() end
end)
