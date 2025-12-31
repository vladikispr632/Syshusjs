-- ============================================
-- СЕРВЕРНАЯ СИСТЕМА АДМИНИСТРИРОВАНИЯ
-- Разместить в ServerScriptService
-- ============================================

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Создаем RemoteEvents для связи клиент-сервер
local AdminRemote = Instance.new("RemoteEvent")
AdminRemote.Name = "AdminRemote"
AdminRemote.Parent = ReplicatedStorage

local AdminEffects = Instance.new("RemoteEvent")
AdminEffects.Name = "AdminEffects"
AdminEffects.Parent = ReplicatedStorage

-- Список админов (настройте под себя)
local ADMIN_LIST = {
    ["ВашНикнейм"] = true,  -- Замените на ваш Roblox ник
    ["Admin1"] = true,
    ["Admin2"] = true
}

-- База данных банов (в реальной игре используйте DataStore)
local bannedPlayers = {}

-- Функция проверки прав администратора
local function isAdmin(player)
    return ADMIN_LIST[player.Name] == true or player.UserId == 1234567  -- Ваш UserId
end

-- Функция создания эффекта кика
local function createKickEffect(player)
    local character = player.Character
    if not character then return end
    
    -- Эффект телепортации/исчезновения
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        -- Создаем частицы
        local particles = Instance.new("ParticleEmitter")
        particles.Texture = "rbxassetid://2425631116"
        particles.Color = ColorSequence.new(Color3.fromRGB(255, 50, 50))
        particles.Size = NumberSequence.new(0.5)
        particles.Lifetime = NumberRange.new(1, 2)
        particles.Rate = 100
        particles.Speed = NumberRange.new(5, 10)
        particles.Parent = rootPart
        
        -- Звук телепортации
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://911846833"
        sound.Volume = 0.7
        sound.Parent = rootPart
        sound:Play()
        
        -- Анимация исчезновения
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                game:GetService("TweenService"):Create(
                    part,
                    TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Transparency = 1}
                ):Play()
            end
        end
        
        -- Удаляем через секунду
        delay(1, function()
            if character and character.Parent then
                character:Destroy()
            end
        end)
    end
end

-- Функция создания эффекта бана
local function createBanEffect(player)
    local character = player.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        -- Огненный эффект бана
        local fire = Instance.new("Fire")
        fire.Size = 10
        fire.Heat = 15
        fire.Color = Color3.fromRGB(255, 100, 50)
        fire.SecondaryColor = Color3.fromRGB(255, 200, 100)
        fire.Parent = rootPart
        
        -- Эффект клетки
        local cage = Instance.new("Part")
        cage.Size = Vector3.new(10, 10, 10)
        cage.CFrame = rootPart.CFrame
        cage.Transparency = 0.3
        cage.Color = Color3.fromRGB(255, 50, 50)
        cage.Material = Enum.Material.Neon
        cage.Anchored = true
        cage.CanCollide = true
        cage.Parent = workspace
        
        -- Звук бана
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://278549476"
        sound.Volume = 1
        sound.Parent = rootPart
        sound:Play()
        
        -- Сообщение для всех игроков
        game:GetService("Chat"):Chat(
            game:GetService("Workspace"),
            player.Name .. " был забанен администрацией!",
            Enum.ChatColor.Red
        )
        
        -- Удаление через 3 секунды
        delay(3, function()
            if character and character.Parent then
                character:Destroy()
            end
            cage:Destroy()
        end)
    end
end

-- Обработчик команд от админ-панели
AdminRemote.OnServerEvent:Connect(function(player, action, targetPlayerName, reason)
    -- Проверяем права
    if not isAdmin(player) then
        warn("Неавторизованная попытка админ-действия от " .. player.Name)
        return
    end
    
    local targetPlayer = Players:FindFirstChild(targetPlayerName)
    if not targetPlayer then
        AdminEffects:FireClient(player, "Error", "Игрок не найден!")
        return
    end
    
    if action == "Kick" then
        -- Отправляем эффекты всем игрокам
        for _, plr in ipairs(Players:GetPlayers()) do
            AdminEffects:FireClient(plr, "KickEffect", targetPlayerName)
        end
        
        -- Создаем эффект на сервере
        createKickEffect(targetPlayer)
        
        -- Кикаем через 1.5 секунды (после эффекта)
        delay(1.5, function()
            targetPlayer:Kick("Кикнут администратором " .. player.Name .. 
                            (reason and (": " .. reason) or ""))
        end)
        
    elseif action == "Ban" then
        -- Добавляем в список банов
        bannedPlayers[targetPlayer.UserId] = {
            Name = targetPlayer.Name,
            Time = os.time(),
            Admin = player.Name,
            Reason = reason or "Нарушение правил"
        }
        
        -- Отправляем эффекты всем
        for _, plr in ipairs(Players:GetPlayers()) do
            AdminEffects:FireClient(plr, "BanEffect", targetPlayerName)
        end
        
        -- Создаем эффект бана
        createBanEffect(targetPlayer)
        
        -- Баним через 3 секунды
        delay(3, function()
            targetPlayer:Kick("Забанен администратором " .. player.Name .. 
                            (reason and (". Причина: " .. reason) or ""))
        end)
        
    elseif action == "TempBan" then
        -- Временный бан (например, на 5 минут)
        bannedPlayers[targetPlayer.UserId] = {
            Name = targetPlayer.Name,
            Time = os.time(),
            Duration = 300, -- 5 минут в секундах
            Admin = player.Name,
            Reason = reason or "Временное нарушение"
        }
        targetPlayer:Kick("Временный бан на 5 минут. Причина: " .. (reason or "Нарушение правил"))
    end
    
    -- Логируем действие
    print("[АДМИН] " .. player.Name .. " -> " .. action .. " -> " .. targetPlayerName .. 
          (reason and (" (" .. reason .. ")") or ""))
end)

-- Проверка банов при входе
Players.PlayerAdded:Connect(function(player)
    if bannedPlayers[player.UserId] then
        local banData = bannedPlayers[player.UserId]
        
        -- Проверка на истечение срока временного бана
        if banData.Duration then
            if os.time() - banData.Time >= banData.Duration then
                bannedPlayers[player.UserId] = nil
                print("[АДМИН] Срок бана истек для " .. player.Name)
                return
            end
        end
        
        player:Kick("Вы забанены в этой игре. Причина: " .. 
                   (banData.Reason or "Нарушение правил"))
    end
end)

-- Команда разбана (только для админов)
game:GetService("TextChatService").TextChannels.RBXGeneral.OnIncomingMessage = function(message)
    local player = message.Player
    local text = message.Text:lower()
    
    if text:sub(1, 6) == "/unban" and isAdmin(player) then
        local targetName = text:sub(8)
        for userId, banData in pairs(bannedPlayers) do
            if banData.Name:lower():find(targetName:lower(), 1, true) then
                bannedPlayers[userId] = nil
                AdminEffects:FireClient(player, "Message", "Игрок " .. banData.Name .. " разбанен")
                return false
            end
        end
    end
end

print("Серверная система администрирования загружена")
