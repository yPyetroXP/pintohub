local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success then
    warn("Falha ao carregar Rayfield:", Rayfield)
    return
end

-- Recursos globais para gerenciar conexões e objetos
local Resources = {
    Connections = {},
    ESPObjects = {},
    Aimbot = {
        Connection = nil,
        Active = false,
        Target = nil
    }
}

-- Serviços
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Configurações centralizadas
local Settings = {
    ESP = {
        Enabled = false,
        FillColor = Color3.fromRGB(255, 0, 0),
        OutlineColor = Color3.fromRGB(255, 255, 255),
        FillTransparency = 0.5,
        OutlineTransparency = 0,
        TeamCheck = false
    },
    Aimbot = {
        Enabled = false,
        Key = Enum.KeyCode.E,
        KeySecondary = Enum.KeyCode.Q, -- Tecla secundária para aimbot
        Mode = "Hold",
        Smoothness = 0.5,
        FOV = 400,
        TeamCheck = false,
        VisibleCheck = false,
        AimPart = "Head",
        FOVVisible = true,
        DrawFOVColor = Color3.fromRGB(255, 255, 255)
    },
    Hitbox = {
        Enabled = false,
        Size = 10,
        TeamCheck = true,
        Visible = false,
        Color = Color3.fromRGB(255, 0, 0),
        Transparency = 0.5
    }
}

-- Variáveis globais (referenciando Settings)
local ESPEnabled = Settings.ESP.Enabled
local AimbotEnabled = Settings.Aimbot.Enabled
local AimbotKey = Settings.Aimbot.Key
local AimbotKeySecondary = Settings.Aimbot.KeySecondary
local AimbotMode = Settings.Aimbot.Mode

-- Controle de delay para logs
local lastTargetLogTime = 0
local lastNoTargetLogTime = 0
local targetLogCooldown = 1
local noTargetLogCooldown = 5

-- Verificar biblioteca Drawing
if not Drawing then
    warn("[Erro] Biblioteca 'Drawing' não disponível.")
    return
end

-- Elementos visuais do Aimbot
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Thickness = 1
FOVCircle.Radius = Settings.Aimbot.FOV
FOVCircle.Filled = false
FOVCircle.Transparency = 0.7
FOVCircle.Color = Settings.Aimbot.DrawFOVColor

-- Funções Auxiliares

-- Atualiza o círculo de FOV na tela
local function UpdateFOVCircle()
    if not FOVCircle then return end
    FOVCircle.Visible = AimbotEnabled and Settings.Aimbot.FOVVisible
    FOVCircle.Radius = Settings.Aimbot.FOV
    FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
    FOVCircle.Color = Settings.Aimbot.DrawFOVColor
end

-- Converte uma tecla (string ou EnumItem) em um Enum.KeyCode válido
local function getValidKeybind(key)
    if type(key) == "string" then
        local cleanedKey = key:gsub("%s+", ""):upper()
        if Enum.KeyCode[cleanedKey] then return Enum.KeyCode[cleanedKey] end
    elseif typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
        return key
    end
    return Enum.KeyCode.E
end

-- Mescla duas tabelas, priorizando os valores da tabela carregada
local function mergeTables(default, loaded)
    local result = {}
    for k, v in pairs(default) do
        if loaded[k] ~= nil then
            if typeof(v) == "table" then
                result[k] = mergeTables(v, loaded[k])
            else
                result[k] = loaded[k]
            end
        else
            result[k] = v
        end
    end
    return result
end

-- Limpa o nome do perfil para evitar caracteres inválidos
local function sanitizeProfileName(name)
    return name:gsub("[^%w%s]", ""):sub(1, 50)
end

-- Detecta partes do corpo suportadas no modelo do personagem
local function GetSupportedAimParts(character)
    local supportedParts = {"Head"}
    if character:FindFirstChild("HumanoidRootPart") then
        table.insert(supportedParts, "HumanoidRootPart")
    end
    if character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") then
        table.insert(supportedParts, character:FindFirstChild("Torso") and "Torso" or "UpperTorso")
    end
    return supportedParts
end

-- Funções do ESP

-- Configura o ESP (highlight) para um jogador
local function SetupESP(player)
    if not player then return end

    local success, result = pcall(function()
        if not player.Character then return end
        if Settings.ESP.TeamCheck and player.Team == LocalPlayer.Team then return end

        local function createHighlight(character)
            if Resources.ESPObjects[player] and Resources.ESPObjects[player].Parent then
                Resources.ESPObjects[player]:Destroy()
            end
            local highlight = Instance.new("Highlight")
            highlight.Adornee = character
            highlight.Parent = game.CoreGui
            highlight.FillColor = Settings.ESP.FillColor
            highlight.OutlineColor = Settings.ESP.OutlineColor
            highlight.FillTransparency = Settings.ESP.FillTransparency
            highlight.OutlineTransparency = Settings.ESP.OutlineTransparency
            Resources.ESPObjects[player] = highlight
        end

        table.insert(Resources.Connections, player.CharacterAdded:Connect(function(character)
            task.wait(1)
            if ESPEnabled and (not Settings.ESP.TeamCheck or player.Team ~= LocalPlayer.Team) then
                createHighlight(character)
            end
        end))
        createHighlight(player.Character)
    end)

    if not success then
        warn("[ESP] Erro ao configurar ESP para jogador:", player and player.Name or "nil", result)
    end
end

-- Ativa o ESP para todos os jogadores
function EnableESP()
    DisableESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then SetupESP(player) end
    end
end

-- Desativa o ESP e remove todos os highlights
function DisableESP()
    for _, highlight in pairs(Resources.ESPObjects) do
        if highlight and highlight.Parent then highlight:Destroy() end
    end
    Resources.ESPObjects = {}
end

-- Funções do Aimbot

-- Verifica se um jogador é um alvo válido para o aimbot
-- Retorna true se o jogador for válido, false caso contrário
local function IsPlayerValid(player)
    if not AimbotEnabled or player == LocalPlayer then return false end
    if not player.Character then return false end
    
    local character = player.Character
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    local targetPart = character:FindFirstChild(Settings.Aimbot.AimPart)
    if not targetPart then return false end
    
    if Settings.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then return false end
    
    if Settings.Aimbot.VisibleCheck then
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        local origin = Camera.CFrame.Position
        local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
        local raycastResult = workspace:Raycast(origin, direction, raycastParams)
        if raycastResult and raycastResult.Instance then
            local hitModel = raycastResult.Instance:FindFirstAncestorOfClass("Model")
            if hitModel ~= character then return false end
        end
    end
    
    return true
end

-- Encontra o jogador mais próximo do mouse dentro do FOV
local function GetClosestPlayerToMouse()
    local closestPlayer = nil
    local shortestDistance = Settings.Aimbot.FOV
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    
    for _, player in pairs(Players:GetPlayers()) do
        if IsPlayerValid(player) then
            local targetPart = player.Character:FindFirstChild(Settings.Aimbot.AimPart)
            if targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if distance < shortestDistance then
                        closestPlayer = player
                        shortestDistance = distance
                        local currentTime = tick()
                        if currentTime - lastTargetLogTime >= targetLogCooldown then
                            lastTargetLogTime = currentTime
                        end
                    end
                end
            end
        end
    end
    
    if not closestPlayer then
        local currentTime = tick()
        if currentTime - lastNoTargetLogTime >= noTargetLogCooldown then
            lastNoTargetLogTime = currentTime
        end
    end
    return closestPlayer
end

-- Atualiza o aimbot a cada frame
function AimbotUpdate()
    if not AimbotEnabled then 
        Resources.Aimbot.Target = nil
        return 
    end
    
    UpdateFOVCircle()
    
    if AimbotMode == "Hold" and not UserInputService:IsKeyDown(AimbotKey) and not UserInputService:IsKeyDown(AimbotKeySecondary) then
        Resources.Aimbot.Active = false
        if Resources.Aimbot.Target then
            Rayfield:Notify({
                Title = "Aimbot",
                Content = "Alvo perdido.",
                Duration = 2,
                Image = "x-circle"
            })
        end
        Resources.Aimbot.Target = nil
        return
    end
    
    if not Resources.Aimbot.Active then return end
    
    local target = Resources.Aimbot.Target
    local currentTime = tick()
    if not target or not IsPlayerValid(target) or (currentTime - lastTargetLogTime > 2) then
        target = GetClosestPlayerToMouse()
        if target and target ~= Resources.Aimbot.Target then
            Rayfield:Notify({
                Title = "Aimbot",
                Content = "Travado em: " .. target.Name,
                Duration = 2,
                Image = "target"
            })
        elseif not target and Resources.Aimbot.Target then
            Rayfield:Notify({
                Title = "Aimbot",
                Content = "Alvo perdido.",
                Duration = 2,
                Image = "x-circle"
            })
        end
        Resources.Aimbot.Target = target
        if target then
            lastTargetLogTime = currentTime
        end
    end
    
    if target and target.Character then
        local targetPart = target.Character:FindFirstChild(Settings.Aimbot.AimPart)
        if targetPart then
            local currentCFrame = Camera.CFrame
            local targetPosition = targetPart.Position
            local targetCFrame = CFrame.new(currentCFrame.Position, targetPosition)
            Camera.CFrame = currentCFrame:Lerp(targetCFrame, Settings.Aimbot.Smoothness)
        else
            warn("[Aimbot] Parte do alvo não encontrada:", Settings.Aimbot.AimPart)
        end
    end
end

-- Funções do Expand Hitbox

-- Expande a hitbox de um jogador
local function ExpandPlayerHitbox(player)
    if not player or player == LocalPlayer then return end
    if Settings.Hitbox.TeamCheck and player.Team == LocalPlayer.Team then return end
    if not player.Character then return end

    local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        humanoidRootPart.Size = Vector3.new(Settings.Hitbox.Size, Settings.Hitbox.Size, Settings.Hitbox.Size)
        humanoidRootPart.Transparency = Settings.Hitbox.Visible and Settings.Hitbox.Transparency or 1
        humanoidRootPart.BrickColor = BrickColor.new(Settings.Hitbox.Color)
        humanoidRootPart.CanCollide = false
    end
end

-- Restaura a hitbox original de um jogador
local function RestorePlayerHitbox(player)
    if not player or not player.Character then return end
    local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        humanoidRootPart.Size = Vector3.new(2, 2, 1)
        humanoidRootPart.Transparency = 0
        humanoidRootPart.CanCollide = true
    end
end

-- Ativa a expansão de hitbox para todos os jogadores
function EnableHitboxExpansion()
    if not Settings.Hitbox.Enabled then
        for _, player in pairs(Players:GetPlayers()) do
            RestorePlayerHitbox(player)
        end
        return
    end
    for _, player in pairs(Players:GetPlayers()) do
        ExpandPlayerHitbox(player)
    end
end

-- Configura a expansão de hitbox para um jogador
local function SetupHitbox(player)
    if not player or player == LocalPlayer then return end
    table.insert(Resources.Connections, player.CharacterAdded:Connect(function(character)
        task.wait(1)
        if Settings.Hitbox.Enabled then
            ExpandPlayerHitbox(player)
        end
    end))
    if Settings.Hitbox.Enabled then
        ExpandPlayerHitbox(player)
    end
end

-- Limpa todos os recursos (conexões, ESP, aimbot, hitbox)
local function CleanupResources()
    for _, connection in pairs(Resources.Connections) do
        if connection then connection:Disconnect() end
    end
    Resources.Connections = {}
    for _, highlight in pairs(Resources.ESPObjects) do
        if highlight and highlight.Parent then highlight:Destroy() end
    end
    Resources.ESPObjects = {}
    if Resources.Aimbot.Connection then
        Resources.Aimbot.Connection:Disconnect()
        Resources.Aimbot.Connection = nil
    end
    Resources.Aimbot.Active = false
    Resources.Aimbot.Target = nil
    if Settings.Hitbox.Enabled then
        for _, player in pairs(Players:GetPlayers()) do
            RestorePlayerHitbox(player)
        end
    end
end

-- Criação da UI com Lucide Icons
local Window = Rayfield:CreateWindow({
    Name = "Pinto Hub",
    LoadingTitle = "Pinto Hub",
    LoadingSubtitle = "by PintoTeam",
    ConfigurationSaving = {Enabled = false, FolderName = "PintoHubConfig", FileName = "PintoHubSettings"},
    Discord = {Enabled = false, Invite = "", RememberJoins = true},
    KeySystem = false,
    Icon = "rocket" -- Lucide Icon
})

-- Aba Funções
local MainTab = Window:CreateTab("Funções", "zap") -- Lucide Icon
local ESPSection = MainTab:CreateSection("ESP")

local ESPToggle = MainTab:CreateToggle({
    Name = "Ativar ESP",
    Info = "Destaca jogadores através de paredes",
    CurrentValue = false,
    Flag = "ESP_Toggle",
    Callback = function(Value)
        ESPEnabled = Value
        Settings.ESP.Enabled = Value
        if ESPEnabled then EnableESP() else DisableESP() end
    end
})

local ESPTeamCheckToggle = MainTab:CreateToggle({
    Name = "Check Team no ESP",
    Info = "Ignora jogadores do mesmo time",
    CurrentValue = false,
    Flag = "ESP_TeamCheck",
    Callback = function(Value)
        Settings.ESP.TeamCheck = Value
        if ESPEnabled then EnableESP() end
    end
})

local DestroyButton = MainTab:CreateButton({
    Name = "Destruir Interface",
    Callback = function()
        Rayfield:Notify({
            Title = "Confirmação",
            Content = "Tem certeza que deseja destruir a interface?",
            Duration = 5,
            Image = "alert-triangle",
            Actions = {
                Confirm = {
                    Name = "Sim",
                    Callback = function()
                        if Rayfield:GetFlag("AutoSave") then
                            local profileName = sanitizeProfileName(ProfileNameInput.CurrentValue)
                            if profileName ~= "" and profileName ~= "Nenhum perfil encontrado" then
                                local configData = {
                                    AimbotSettings = Settings.Aimbot,
                                    ESPSettings = Settings.ESP,
                                    HitboxSettings = Settings.Hitbox,
                                    AimbotEnabled = AimbotEnabled,
                                    ESPEnabled = ESPEnabled,
                                    HitboxEnabled = Settings.Hitbox.Enabled,
                                    AimbotKey = AimbotKey.Name,
                                    AimbotMode = AimbotMode
                                }
                                local configFolder = "PintoHubConfig"
                                if not isfolder(configFolder) then makefolder(configFolder) end
                                writefile(configFolder .. "/" .. profileName .. ".json", game:GetService("HttpService"):JSONEncode(configData))
                                Rayfield:Notify({
                                    Title = "Sucesso",
                                    Content = "Configurações salvas automaticamente: " .. profileName,
                                    Duration = 3,
                                    Image = "check-circle"
                                })
                            end
                        end
                        CleanupResources()
                        if FOVCircle then FOVCircle:Remove() end
                        Rayfield:Destroy()
                    end
                },
                Ignore = {
                    Name = "Não",
                    Callback = function() end
                }
            }
        })
    end
})

local RejoinButton = MainTab:CreateButton({
    Name = "Rejoin",
    Info = "Reconecta ao mesmo servidor",
    Callback = function()
        local placeId = game.PlaceId
        local jobId = game.JobId
        TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
    end
})

local TestCameraButton = MainTab:CreateButton({
    Name = "Testar Câmera",
    Info = "Testa o movimento da câmera para frente",
    Callback = function()
        local currentCFrame = Camera.CFrame
        local targetCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + Vector3.new(0, 0, -10))
        Camera.CFrame = targetCFrame
    end
})

local AimbotSection = MainTab:CreateSection("Aimbot")

local AimbotToggle = MainTab:CreateToggle({
    Name = "Ativar Aimbot",
    Info = "Mira automaticamente nos jogadores",
    CurrentValue = false,
    Flag = "Aimbot_Toggle",
    Callback = function(Value)
        AimbotEnabled = Value
        Settings.Aimbot.Enabled = Value
        if AimbotEnabled then
            RunService:BindToRenderStep("AimbotUpdate", Enum.RenderPriority.Last.Value, AimbotUpdate)
        else
            RunService:UnbindFromRenderStep("AimbotUpdate")
            Resources.Aimbot.Active = false
            Resources.Aimbot.Target = nil
        end
        FOVCircle.Visible = AimbotEnabled and Settings.Aimbot.FOVVisible
    end
})

local AimbotKeybind = MainTab:CreateKeybind({
    Name = "Tecla do Aimbot",
    Info = "Tecla primária para ativar o aimbot (padrão: E)",
    CurrentKeybind = "E",
    HoldToInteract = false,
    Flag = "AimbotKeybind",
    Callback = function(Keybind)
        AimbotKey = getValidKeybind(Keybind)
        Settings.Aimbot.Key = AimbotKey
    end
})

local AimbotKeybindSecondary = MainTab:CreateKeybind({
    Name = "Tecla Secundária do Aimbot",
    Info = "Tecla secundária para ativar o aimbot (padrão: Q)",
    CurrentKeybind = "Q",
    HoldToInteract = false,
    Flag = "AimbotKeybindSecondary",
    Callback = function(Keybind)
        AimbotKeySecondary = getValidKeybind(Keybind)
        Settings.Aimbot.KeySecondary = AimbotKeySecondary
    end
})

local AimbotModeDropdown = MainTab:CreateDropdown({
    Name = "Modo do Aimbot",
    Info = "Hold: Segura a tecla para ativar; Toggle: Ativa/desativa com um toque",
    Options = {"Hold", "Toggle"},
    CurrentOption = AimbotMode,
    Flag = "AimbotMode",
    Callback = function(Option)
        AimbotMode = Option
        Settings.Aimbot.Mode = Option
        Resources.Aimbot.Active = false
    end
})

local supportedAimParts = GetSupportedAimParts(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
local AimbotPartDropdown = MainTab:CreateDropdown({
    Name = "Parte do Corpo",
    Info = "Parte do corpo para mirar",
    Options = supportedAimParts,
    CurrentOption = Settings.Aimbot.AimPart,
    Flag = "AimbotPart",
    Callback = function(Option)
        Settings.Aimbot.AimPart = Option
    end
})

local AimbotFOVSlider = MainTab:CreateSlider({
    Name = "FOV do Aimbot",
    Info = "Tamanho do campo de visão para detectar alvos",
    Range = {10, 400},
    Increment = 5,
    Suffix = "px",
    CurrentValue = Settings.Aimbot.FOV,
    Flag = "AimbotFOV",
    Callback = function(Value)
        Settings.Aimbot.FOV = Value
        FOVCircle.Radius = Value
    end
})

local AimbotSmoothnessSlider = MainTab:CreateSlider({
    Name = "Suavização do Aimbot",
    Info = "Controla a velocidade de movimento da câmera (0 = instantâneo, 10 = muito lento)",
    Range = {0, 10},
    Increment = 0.1,
    Suffix = "",
    CurrentValue = Settings.Aimbot.Smoothness * 10,
    Flag = "AimbotSmoothness",
    Callback = function(Value)
        Settings.Aimbot.Smoothness = Value / 10
    end
})

local AimbotTeamCheckToggle = MainTab:CreateToggle({
    Name = "Check Team no Aimbot",
    Info = "Ignora jogadores do mesmo time",
    CurrentValue = Settings.Aimbot.TeamCheck,
    Flag = "AimbotTeamCheck",
    Callback = function(Value)
        Settings.Aimbot.TeamCheck = Value
    end
})

local AimbotVisibleCheckToggle = MainTab:CreateToggle({
    Name = "Check Visibilidade",
    Info = "Mira apenas em jogadores visíveis (não bloqueados por paredes)",
    CurrentValue = Settings.Aimbot.VisibleCheck,
    Flag = "AimbotVisibleCheck",
    Callback = function(Value)
        Settings.Aimbot.VisibleCheck = Value
    end
})

local AimbotFOVVisibleToggle = MainTab:CreateToggle({
    Name = "Mostrar Círculo FOV",
    Info = "Exibe o círculo de FOV na tela",
    CurrentValue = Settings.Aimbot.FOVVisible,
    Flag = "AimbotFOVVisible",
    Callback = function(Value)
        Settings.Aimbot.FOVVisible = Value
        FOVCircle.Visible = AimbotEnabled and Value
    end
})

-- Seção Expand Hitbox
local HitboxSection = MainTab:CreateSection("Expand Hitbox")

local HitboxToggle = MainTab:CreateToggle({
    Name = "Ativar Expand Hitbox",
    Info = "Aumenta o tamanho da hitbox dos jogadores",
    CurrentValue = false,
    Flag = "Hitbox_Toggle",
    Callback = function(Value)
        Settings.Hitbox.Enabled = Value
        EnableHitboxExpansion()
    end
})

local HitboxSizeSlider = MainTab:CreateSlider({
    Name = "Tamanho da Hitbox",
    Info = "Tamanho da hitbox expandida",
    Range = {5, 20},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = Settings.Hitbox.Size,
    Flag = "Hitbox_Size",
    Callback = function(Value)
        Settings.Hitbox.Size = Value
        if Settings.Hitbox.Enabled then EnableHitboxExpansion() end
    end
})

local HitboxTeamCheckToggle = MainTab:CreateToggle({
    Name = "Check Team",
    Info = "Ignora jogadores do mesmo time",
    CurrentValue = Settings.Hitbox.TeamCheck,
    Flag = "Hitbox_TeamCheck",
    Callback = function(Value)
        Settings.Hitbox.TeamCheck = Value
        if Settings.Hitbox.Enabled then EnableHitboxExpansion() end
    end
})

local HitboxVisibleToggle = MainTab:CreateToggle({
    Name = "Mostrar Hitbox",
    Info = "Torna a hitbox expandida visível",
    CurrentValue = Settings.Hitbox.Visible,
    Flag = "Hitbox_Visible",
    Callback = function(Value)
        Settings.Hitbox.Visible = Value
        if Settings.Hitbox.Enabled then EnableHitboxExpansion() end
    end
})

local HitboxColorPicker = MainTab:CreateColorPicker({
    Name = "Cor da Hitbox",
    Info = "Cor da hitbox expandida (se visível)",
    Color = Settings.Hitbox.Color,
    Flag = "Hitbox_Color",
    Callback = function(Value)
        Settings.Hitbox.Color = Value
        if Settings.Hitbox.Enabled then EnableHitboxExpansion() end
    end
})

-- Aba Configurações
local ConfigTab = Window:CreateTab("Configurações", "settings") -- Lucide Icon
local ConfigSection = ConfigTab:CreateSection("Gerenciar Configurações")

local function GetSavedProfiles()
    local configFolder = "PintoHubConfig"
    if not isfolder(configFolder) then return {"Nenhum perfil encontrado"} end
    local files = listfiles(configFolder)
    local profiles = {}
    for _, file in ipairs(files) do
        local profileName = file:match(configFolder .. "/(.+)%.json$")
        if profileName then table.insert(profiles, profileName) end
    end
    return #profiles > 0 and profiles or {"Nenhum perfil encontrado"}
end

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

local ProfileDropdown = ConfigTab:CreateDropdown({
    Name = "Perfis Salvos",
    Info = "Selecione um perfil salvo para carregar",
    Options = GetSavedProfiles(),
    CurrentOption = "Nenhum perfil encontrado",
    Flag = "ProfileDropdown",
    Callback = function(Option)
        ProfileNameInput:Set(Option)
        print("[Config] Perfil selecionado:", Option)
    end
})

local SaveConfigButton = ConfigTab:CreateButton({
    Name = "Salvar Configurações",
    Info = "Salva as configurações atuais no perfil especificado",
    Callback = function()
        local profileName = sanitizeProfileName(ProfileNameInput.CurrentValue)
        if profileName == "" or profileName == "Nenhum perfil encontrado" then
            Rayfield:Notify({
                Title = "Erro",
                Content = "Por favor, insira um nome válido para o perfil!",
                Duration = 3,
                Image = "alert-circle"
            })
            return
        end

        local configData = {
            AimbotSettings = Settings.Aimbot,
            ESPSettings = Settings.ESP,
            HitboxSettings = Settings.Hitbox,
            AimbotEnabled = AimbotEnabled,
            ESPEnabled = ESPEnabled,
            HitboxEnabled = Settings.Hitbox.Enabled,
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
            Image = "check-circle"
        })

        ProfileDropdown:Refresh(GetSavedProfiles(), profileName)
    end
})

local LoadConfigButton = ConfigTab:CreateButton({
    Name = "Carregar Configurações",
    Info = "Carrega as configurações do perfil especificado",
    Callback = function()
        local profileName = sanitizeProfileName(ProfileNameInput.CurrentValue)
        local configFolder = "PintoHubConfig"
        local filePath = configFolder .. "/" .. profileName .. ".json"

        if not isfile(filePath) then
            Rayfield:Notify({
                Title = "Erro",
                Content = "Perfil não encontrado: " .. profileName,
                Duration = 3,
                Image = "alert-circle"
            })
            return
        end

        local success, configData = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile(filePath))
        end)
        if not success then
            Rayfield:Notify({
                Title = "Erro",
                Content = "Falha ao carregar o perfil: " .. profileName .. " (arquivo corrompido)",
                Duration = 3,
                Image = "alert-circle"
            })
            return
        end

        Settings.Aimbot = mergeTables(Settings.Aimbot, configData.AimbotSettings or {})
        Settings.ESP = mergeTables(Settings.ESP, configData.ESPSettings or {})
        Settings.Hitbox = mergeTables(Settings.Hitbox, configData.HitboxSettings or {})
        AimbotEnabled = configData.AimbotEnabled or AimbotEnabled
        ESPEnabled = configData.ESPEnabled or ESPEnabled
        Settings.Hitbox.Enabled = configData.HitboxEnabled or Settings.Hitbox.Enabled
        AimbotKey = getValidKeybind(configData.AimbotKey) or AimbotKey
        AimbotMode = configData.AimbotMode or AimbotMode

        AimbotToggle:Set(AimbotEnabled)
        ESPToggle:Set(ESPEnabled)
        HitboxToggle:Set(Settings.Hitbox.Enabled)
        AimbotKeybind:Set(AimbotKey.Name)
        AimbotModeDropdown:Set(AimbotMode)
        AimbotPartDropdown:Set(Settings.Aimbot.AimPart)
        AimbotFOVSlider:Set(Settings.Aimbot.FOV)
        AimbotSmoothnessSlider:Set(Settings.Aimbot.Smoothness * 10)
        AimbotTeamCheckToggle:Set(Settings.Aimbot.TeamCheck)
        AimbotVisibleCheckToggle:Set(Settings.Aimbot.VisibleCheck)
        AimbotFOVVisibleToggle:Set(Settings.Aimbot.FOVVisible)
        ESPTeamCheckToggle:Set(Settings.ESP.TeamCheck)
        HitboxSizeSlider:Set(Settings.Hitbox.Size)
        HitboxTeamCheckToggle:Set(Settings.Hitbox.TeamCheck)
        HitboxVisibleToggle:Set(Settings.Hitbox.Visible)
        HitboxColorPicker:Set(Settings.Hitbox.Color)

        ProfileDropdown:Set(profileName)

        Rayfield:Notify({
            Title = "Sucesso",
            Content = "Configurações carregadas de: " .. profileName,
            Duration = 3,
            Image = "check-circle"
        })
    end
})

local DeleteConfigButton = ConfigTab:CreateButton({
    Name = "Deletar Perfil",
    Info = "Deleta o perfil especificado",
    Callback = function()
        local profileName = sanitizeProfileName(ProfileNameInput.CurrentValue)
        local filePath = "PintoHubConfig/" .. profileName .. ".json"
        if not isfile(filePath) then
            Rayfield:Notify({
                Title = "Erro",
                Content = "Perfil não encontrado: " .. profileName,
                Duration = 3,
                Image = "alert-circle"
            })
            return
        end

        Rayfield:Notify({
            Title = "Confirmação",
            Content = "Tem certeza que deseja deletar o perfil: " .. profileName .. "?",
            Duration = 5,
            Image = "alert-triangle",
            Actions = {
                Confirm = {
                    Name = "Sim",
                    Callback = function()
                        delfile(filePath)
                        Rayfield:Notify({
                            Title = "Sucesso",
                            Content = "Perfil deletado: " .. profileName,
                            Duration = 3,
                            Image = "trash-2"
                        })
                        ProfileDropdown:Refresh(GetSavedProfiles(), "Nenhum perfil encontrado")
                    end
                },
                Ignore = {
                    Name = "Não",
                    Callback = function() end
                }
            }
        })
    end
})

local AutoSaveToggle = ConfigTab:CreateToggle({
    Name = "Salvamento Automático",
    Info = "Salva as configurações automaticamente ao fechar a interface",
    CurrentValue = false,
    Flag = "AutoSave",
    Callback = function(Value)
        -- Apenas armazena o estado no flag, usado no DestroyButton
    end
})

-- Carrega configurações padrão
local function LoadDefaultConfig()
    local defaultConfig = {
        AimbotSettings = Settings.Aimbot,
        ESPSettings = Settings.ESP,
        HitboxSettings = Settings.Hitbox,
        AimbotEnabled = false,
        ESPEnabled = false,
        HitboxEnabled = false,
        AimbotKey = "E",
        AimbotMode = "Hold"
    }

    Settings.Aimbot = mergeTables(Settings.Aimbot, defaultConfig.AimbotSettings or {})
    Settings.ESP = mergeTables(Settings.ESP, defaultConfig.ESPSettings or {})
    Settings.Hitbox = mergeTables(Settings.Hitbox, defaultConfig.HitboxSettings or {})
    AimbotEnabled = defaultConfig.AimbotEnabled
    ESPEnabled = defaultConfig.ESPEnabled
    Settings.Hitbox.Enabled = defaultConfig.HitboxEnabled
    AimbotKey = getValidKeybind(defaultConfig.AimbotKey) or AimbotKey
    AimbotMode = defaultConfig.AimbotMode

    AimbotToggle:Set(AimbotEnabled)
    ESPToggle:Set(ESPEnabled)
    HitboxToggle:Set(Settings.Hitbox.Enabled)
    AimbotKeybind:Set(AimbotKey.Name)
    AimbotModeDropdown:Set(AimbotMode)
    AimbotPartDropdown:Set(Settings.Aimbot.AimPart)
    AimbotFOVSlider:Set(Settings.Aimbot.FOV)
    AimbotSmoothnessSlider:Set(Settings.Aimbot.Smoothness * 10)
    AimbotTeamCheckToggle:Set(Settings.Aimbot.TeamCheck)
    AimbotVisibleCheckToggle:Set(Settings.Aimbot.VisibleCheck)
    AimbotFOVVisibleToggle:Set(Settings.Aimbot.FOVVisible)
    ESPTeamCheckToggle:Set(Settings.ESP.TeamCheck)
    HitboxSizeSlider:Set(Settings.Hitbox.Size)
    HitboxTeamCheckToggle:Set(Settings.Hitbox.TeamCheck)
    HitboxVisibleToggle:Set(Settings.Hitbox.Visible)
    HitboxColorPicker:Set(Settings.Hitbox.Color)
end

-- Carrega configurações padrão ao iniciar
LoadDefaultConfig()

-- Eventos
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not AimbotEnabled then return end
    
    if input.KeyCode == AimbotKey or input.KeyCode == AimbotKeySecondary then
        if AimbotMode == "Toggle" then
            Resources.Aimbot.Active = not Resources.Aimbot.Active
            Resources.Aimbot.Target = nil
        elseif AimbotMode == "Hold" then
            Resources.Aimbot.Active = true
            Resources.Aimbot.Target = nil
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed or not AimbotEnabled then return end
    if AimbotMode == "Hold" and (input.KeyCode == AimbotKey or input.KeyCode == AimbotKeySecondary) then
        Resources.Aimbot.Active = false
        Resources.Aimbot.Target = nil
    end
end)

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then 
        SetupESP(player)
        SetupHitbox(player)
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
    Image = "check",
    Actions = {Ignore = {Name = "OK", Callback = function() print("O usuário reconheceu a notificação") end}}
})

RunService:BindToRenderStep("FOVUpdate", Enum.RenderPriority.Camera.Value + 1, UpdateFOVCircle)

game:GetService("UserInputService").WindowFocused:Connect(function()
    if not ESPEnabled and not AimbotEnabled and not Settings.Hitbox.Enabled then CleanupResources() end
end)
