local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Verificando se o "Lobby" está presente no PlayerGui dentro de um tempo limite de 10 segundos
local lobby = nil
local startTime = tick()  -- Marca o tempo de início
while tick() - startTime < 10 do  -- Limite de 10 segundos
    lobby = playerGui:FindFirstChild("Lobby")
    if lobby then
        break  -- Se encontrado, sai do loop
    end
    task.wait(0.1)  -- Aguarda 0.1 segundos antes de tentar novamente
end

if not lobby then
    warn("Lobby não encontrado após 10 segundos.")
    return  -- Sai do script caso não encontre o Lobby
end
-- ================= SERVIÇOS =================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera
local vim = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

-- ================= CONFIG =================
local MIN_LEVEL = 60
local MAX_DEATHS = 6
local CLICK_INTERVAL = 0.8
local MAX_WIN_STREAK = 10
local levelAuthorityLock = false



-- V 1.2 ALT VER HEAD AIMLOCK + REMAKED AUTOSHOOT + HUGE FIXES (BETA)

-- ================= ESTADO =================
local trackedPlayer, trackedHumanoid
local healthConn, charConn
local deathCount = 0
local alreadyDead = false
local tabHeld = false
local executingClick = false
local botEnabled = false
local teleportLoopConnection, aimLockConnection
local myFirstDeath = false


local currentTarget, targetHumanoid, myHumanoid
local attacking = false
local resetFlag = false
local serverOverrideActive = false
local lonePlayerUsername

-- ================= SAVE/LOAD BOT =================
local stateFileName = "BotState.txt"
local function saveBotState(state)
    pcall(function() writefile(stateFileName, tostring(state)) end)
end
local function loadBotState()
    local state = false
    pcall(function()
        if isfile(stateFileName) then
            state = readfile(stateFileName) == "true"
        end
    end)
    return state
end

-- ================= GUI HUD =================
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("BotHUD") then playerGui:FindFirstChild("BotHUD"):Destroy() end

local guiOverlay = Instance.new("ScreenGui")
guiOverlay.Name = "BotHUD"
guiOverlay.ResetOnSpawn = false
guiOverlay.Parent = playerGui

local mainHud = Instance.new("Frame")
mainHud.Size = UDim2.fromScale(0.3,0.18)
mainHud.Position = UDim2.fromScale(0.35,0.05)
mainHud.BackgroundColor3 = Color3.fromRGB(50,50,50)
mainHud.BorderSizePixel = 0
mainHud.ClipsDescendants = true
mainHud.Parent = guiOverlay
Instance.new("UICorner", mainHud).CornerRadius = UDim.new(0,15)

-- Título "TKT Autofarm"
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.fromScale(1,0.25)
titleLabel.Position = UDim2.fromScale(0,0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255,0,0)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "TKT Autofarm"
titleLabel.Parent = mainHud


-- ================= TITLE RAINBOW EFFECT =================
task.spawn(function()
    local hue = 0
    while titleLabel and titleLabel.Parent do
        hue = (hue + 1) % 360
        titleLabel.TextColor3 = Color3.fromHSV(hue/360, 1, 1)
        task.wait(0.03)
    end
end)


-- Label jogador mais próximo
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(0.95,0.25)
label.Position = UDim2.fromScale(0.025,0.25)
label.BackgroundColor3 = Color3.fromRGB(70,70,70)
label.TextColor3 = Color3.fromRGB(255,255,255)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.BorderSizePixel = 0
label.Text = "Carregando..."
label.Parent = mainHud
Instance.new("UICorner", label).CornerRadius = UDim.new(0,10)


-- Label Meu WS
local myLabel = Instance.new("TextLabel")
myLabel.Size = UDim2.fromScale(0.45,0.25)
myLabel.Position = UDim2.fromScale(0.025,0.55)
myLabel.BackgroundColor3 = Color3.fromRGB(70,70,70)
myLabel.TextColor3 = Color3.fromRGB(255,255,255)
myLabel.TextScaled = true
myLabel.Font = Enum.Font.GothamBold
myLabel.BorderSizePixel = 0
myLabel.Text = "Meu WS: 0"
myLabel.Parent = mainHud
Instance.new("UICorner", myLabel).CornerRadius = UDim.new(0,10)


-- Botão BOT ON/OFF
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.fromScale(0.45,0.25)
toggleButton.Position = UDim2.fromScale(0.5,0.55)
toggleButton.BackgroundColor3 = Color3.fromRGB(170,40,40)
toggleButton.TextColor3 = Color3.fromRGB(255,255,255)
toggleButton.TextScaled = true
toggleButton.Font = Enum.Font.GothamBold
toggleButton.BorderSizePixel = 0
toggleButton.Text = "BOT: OFF"
toggleButton.Parent = mainHud
Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0,10)


-- Versão embaixo
local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.fromScale(1,0.15)
versionLabel.Position = UDim2.fromScale(0,0.83)
versionLabel.BackgroundTransparency = 1
versionLabel.TextColor3 = Color3.fromRGB(200,200,200)
versionLabel.TextScaled = true
versionLabel.Font = Enum.Font.Gotham
versionLabel.Text = "1.4 ALT VER(BETA)"
versionLabel.Parent = mainHud

-- ================= FUNÇÕES AUXILIARES =================
local function getWinStreak(plr)
    if not plr then return nil end
    local stats = plr:FindFirstChild("leaderstats")
    if stats then
        return stats:FindFirstChild("WinStreak") or stats:FindFirstChild("Win Streak") or
               stats:FindFirstChild("Winstreak") or stats:FindFirstChild("WS") or
               stats:FindFirstChild("Streak")
    end
    return plr:FindFirstChild("WinStreak") or plr:FindFirstChild("Win Streak") or
           plr:FindFirstChild("Winstreak") or plr:FindFirstChild("WS") or
           plr:FindFirstChild("Streak")
end

-- ================= FUNÇÕES PRINCIPAIS =================
--local guiMain = player:WaitForChild("PlayerGui")
--local modesFolder = guiMain:WaitForChild("Menu"):WaitForChild("GlobalMatchmaking")
                   --:WaitForChild("SelectMatchmaking"):WaitForChild("ModesHolder"):WaitForChild("Modes")
--local playButton = guiMain:WaitForChild("Menu"):WaitForChild("GlobalMatchmaking")
                   --:WaitForChild("SelectMatchmaking"):WaitForChild("ButtonHolder"):WaitForChild("Play")
--local modesList = {"2v2","3v3","4v4"}

--local function clickModes()
    --for _, modeName in ipairs(modesList) do
        --local button = modesFolder:FindFirstChild(modeName)
        --if button then
            --for _, c in ipairs(getconnections(button.MouseButton1Click)) do c:Fire() end
            --task.wait(0.1)
        --end
    --end
--end

--local function fireAll(button)
    --for _, sig in ipairs({button.Activated, button.MouseButton1Click, button.MouseButton1Down, button.MouseButton1Up}) do
        --if sig then for _, c in ipairs(getconnections(sig)) do c:Fire() end end
    --end
--end

-- ================= TAB =================
local function holdTab()
    if tabHeld then return end
    tabHeld = true
    game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.Tab, false, game)
end

local function releaseTab()
    if not tabHeld then return end
    tabHeld = false
    game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.Tab, false, game)
end


-- ================= FLAG DE COINS =================
local COINS_LIMIT_REACHED = false

-- Função para checar coins só uma vez
local function checkCoinsOnce()
    local player = game.Players.LocalPlayer
    local guiLobby = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
    local coinsLabel = guiLobby:WaitForChild("LeftSideInfo"):WaitForChild("Coins"):WaitForChild("Amount")
    
    local coins = tonumber(coinsLabel.Text)
    if coins and coins >= 10000 then
        COINS_LIMIT_REACHED = true
        warn("Limite de 10000 coins atingido! executeClickWrapper ficará bloqueado indefinidamente.")
    end
end

-- ================= CLICK =================

local executingClick = false

local function executeClickWrapper()
    -- Sempre checa se o limite de coins foi atingido
    if COINS_LIMIT_REACHED then
        return
    end

    if executingClick then return end
    executingClick = true
    task.wait(3)

    while true do
        if COINS_LIMIT_REACHED then
            break -- se quiser realmente infinito, pode remover
        end

    local args = {
    [1] = {
        [1] = "1v1"
    },
    [2] = false
}

game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Match"):WaitForChild("Matchmaking"):WaitForChild("Global"):WaitForChild("QueueUp"):InvokeServer(unpack(args))

          task.wait(0.8)
         end
        executingClick = false
end

-- ================= MAX DEATHS =================
local function checkMaxDeaths()
    if deathCount >= MAX_DEATHS then executeClickWrapper() end
end

-- ================= CHECAGEM DE COINS =================
task.spawn(function()
    task.wait(1) -- espera 1s para o GUI carregar
    checkCoinsOnce() -- executa só uma vez
end)

-- ================= HUMANOID TRACK =================
local function hookHumanoid(humanoid)
    if healthConn then healthConn:Disconnect() end
    alreadyDead = humanoid.Health <= 0
    healthConn = humanoid.HealthChanged:Connect(function(health)
        if health <= 0 and not alreadyDead then
            alreadyDead = true
            deathCount += 1
        elseif health > 0 then
            alreadyDead = false
        end
    end)
end

local function trackPlayer(plr)
    if trackedPlayer == plr then return end
    if healthConn then healthConn:Disconnect() end
    if charConn then charConn:Disconnect() end

    trackedPlayer = plr
    deathCount = 0

    charConn = plr.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid",5)
        if hum then hookHumanoid(hum) end
    end)

    if plr.Character then
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then hookHumanoid(hum) end
    end
end

-- ================= NEAREST PLAYER =================
local function getRoot(plr)
    return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
end

local function getNearestPlayer()
    local myRoot = getRoot(player)
    if not myRoot then return nil end
    local nearest, minDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local root = getRoot(plr)
            if root then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist < minDist then minDist, nearest = dist, plr end
            end
        end
    end
    return nearest
end

-- ================= UI UPDATE =================



task.spawn(function()



    while true do



        local nearest = getNearestPlayer()



        if nearest then



            -- Atualiza o jogador rastreado se for diferente

            if trackedPlayer ~= nearest then

                trackPlayer(nearest)

            end



            -- Pega stats

            local stats = nearest:FindFirstChild("leaderstats")

            local level = stats and stats:FindFirstChild("Level")



            -- Atualiza HUD

            label.Text = nearest.Name.." | Mortes: "..deathCount.."/"..MAX_DEATHS.." | Level: "..(level and level.Value or "Sem Level")



            -- ✅ AQUI FAZ A VERIFICAÇÃO

            if deathCount >= MAX_DEATHS then

                executeClickWrapper()

                deathCount = 0 -- reset opcional pra não ficar executando infinito

            end



        else

            label.Text = "Procurando jogador mais próximo..."

        end



        task.wait(0.4)



    end



end)


-- ================= NEAREST PLAYER DEATH COUNTER =================



local nearestDeathCount = 0

local nearestDeathConnection = nil

local monitoredPlayer = nil



local function monitorNearestPlayerDeaths()



    task.spawn(function()



        while true do

            task.wait(1)



            local nearest = getNearestPlayer()



            -- Se mudou o jogador monitorado

            if nearest ~= monitoredPlayer then



                -- desconecta antigo

                if nearestDeathConnection then

                    nearestDeathConnection:Disconnect()

                    nearestDeathConnection = nil

                end



                monitoredPlayer = nearest



                if nearest and nearest.Character then

                    local humanoid = nearest.Character:FindFirstChildOfClass("Humanoid")



                    if humanoid then

                        nearestDeathConnection = humanoid.HealthChanged:Connect(function(health)



                            if health <= 0 then

                                nearestDeathCount += 1



                                if nearestDeathCount >= MAX_DEATHS then

                                    executeClickWrapper()

                                    nearestDeathCount = 0

                                end

                            end



                        end)

                    end

                end

            end



        end



    end)



end



-- ================= TELEPORT BEHIND =================
local function teleportBehindNearest(distance)
    distance = 6.5
    local target = getNearestPlayer()
    if not target then return end
    local char, myChar = target.Character, player.Character
    if not char or not myChar then return end
    local targetRoot = char:FindFirstChild("HumanoidRootPart")
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not myRoot then return end
    local behindPosition = targetRoot.Position - (targetRoot.CFrame.LookVector * distance)
    myRoot.CFrame = CFrame.new(behindPosition, targetRoot.Position)
end

local sideDistance = 3.0
local switchTime = 0.5

local teleportConnection

local currentSide = 1
local lastSwitch = 0

local myDeathConnection
local deathLocked = false

local function watchMyFirstDeath()
    local function hookHumanoid(humanoid)
        if myDeathConnection then
            myDeathConnection:Disconnect()
        end

        myDeathConnection = humanoid.HealthChanged:Connect(function(health)
            if health <= 0 and not deathLocked then
                deathLocked = true
                myFirstDeath = true
                myDeathConnection:Disconnect()
            end
        end)
    end

    if player.Character then
        local hum = player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hookHumanoid(hum) end
    end

    player.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        hookHumanoid(hum)
    end)
end

watchMyFirstDeath()


-- ================= GET NEAREST PLAYER =================
local function getNearestPlayer()
    local myChar = player.Character
    if not myChar then return nil end

    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local nearest
    local shortest = math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist < shortest then
                    shortest = dist
                    nearest = plr
                end
            end
        end
    end

    return nearest
end

-- ================= TELEPORT SIDE =================
local function teleportSideNearest()

    local target = getNearestPlayer()
    if not target then return end

    local char = target.Character
    local myChar = player.Character
    if not char or not myChar then return end

    local targetRoot = char:FindFirstChild("HumanoidRootPart")
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not myRoot then return end

   if tick() - lastSwitch >= switchTime then
    currentSide = (math.random(0,1) == 0) and -1 or 1
    lastSwitch = tick()
end


    local offset = targetRoot.CFrame.RightVector * sideDistance * currentSide
    local pos = targetRoot.Position + offset

    myRoot.CFrame = CFrame.new(pos, targetRoot.Position)
end

-- ================= TELEPORT CONTROLLER =================
local function setTeleportBehind(enable)
    if teleportLoopConnection then
        teleportLoopConnection:Disconnect()
        teleportLoopConnection = nil
    end

    if not enable then return end

    teleportLoopConnection = RunService.Heartbeat:Connect(function()
        if not botEnabled then return end
        if levelAuthorityLock then return end

  if myFirstDeath then
    teleportSideNearest()
else
    teleportBehindNearest()
end

    end)
end

-- ================= AIMLOCK =================
local function aimLockNearestTorso(enable)
    if aimLockConnection then aimLockConnection:Disconnect() aimLockConnection = nil end
    if not enable then return end
    aimLockConnection = RunService.RenderStepped:Connect(function()
        if levelAuthorityLock then return end  -- <<< Checagem adicionada
        local target = getNearestPlayer()
        if not target or not target.Character then return end
        local torso = target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
        if torso then camera.CFrame = CFrame.new(camera.CFrame.Position, torso.Position) end
    end)
end

-- ================= BOT TOGGLE =================
botEnabled = loadBotState()
if botEnabled then
    toggleButton.Text = "BOT: ON"
    toggleButton.BackgroundColor3 = Color3.fromRGB(40,170,40)
    setTeleportBehind(true)
    aimLockNearestTorso(true)
else
    toggleButton.Text = "BOT: OFF"
    toggleButton.BackgroundColor3 = Color3.fromRGB(170,40,40)
end

toggleButton.MouseButton1Click:Connect(function()
    botEnabled = not botEnabled
    if botEnabled then
        toggleButton.Text = "BOT: ON"
        toggleButton.BackgroundColor3 = Color3.fromRGB(40,170,40)
        setTeleportBehind(true)
        aimLockNearestTorso(true)
    else
        toggleButton.Text = "BOT: OFF"
        toggleButton.BackgroundColor3 = Color3.fromRGB(170,40,40)
        setTeleportBehind(false)
        aimLockNearestTorso(false)
    end
    saveBotState(botEnabled)
end)

-- ================= CHECK NEAREST PLAYER DISCONNECT =================
task.spawn(function()
    -- espera um pouco após iniciar o script
    task.wait(4)

    while true do
        task.wait(5)

        -- Se ainda não estamos rastreando ninguém, pega o mais próximo
        if not lonePlayerUsername then
            local nearest = getNearestPlayer()
            if nearest then
                lonePlayerUsername = nearest.Name
                -- warn("Rastreando jogador:", lonePlayerUsername)
            end
        else
            -- Já estamos rastreando, verifica se ele ainda está no servidor
            local found = false

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Name == lonePlayerUsername then
                    found = true
                    break
                end
            end

            -- Se o jogador saiu do servidor
            if not found then
                -- warn("Jogador saiu do servidor:", lonePlayerUsername)
                lonePlayerUsername = nil
                executeClickWrapper()
            end
        end
    end
end)

-- ================= LEVEL MIN = STOP FARMING =================
local function enforceLevelAuthorityKillSwitch()
    if levelAuthorityLock then return end

    local nearest = getNearestPlayer()
    if not nearest then return end

    -- Pega leaderstats e level com segurança
    local leaderstats = nearest:FindFirstChild("leaderstats")
    local level = leaderstats and leaderstats:FindFirstChild("Level")
    if not level then return end

    -- Se o level do jogador for maior que MIN_LEVEL
    if level.Value >= MIN_LEVEL then
        levelAuthorityLock = true

        -- Para autoshoot
        attacking = false
        resetFlag = true
        resetAutoShoot()
        autoShootEnabled = false
        currentTarget = nil
        targetHumanoid = nil

        -- Desliga teleport e aimlock
        setTeleportBehind(false)
        aimLockNearestTorso(false)
    end
end



-- ================= SERVER PLAYER CHECK =================
local serverCheckRunning = false

local function checkServerPlayersAndQueue()
    -- debounce total
    if serverCheckRunning then return end

    local playerCount = #Players:GetPlayers()

    -- só interessa se for MAIOR que 2
    if playerCount <= 2 then return end

    serverCheckRunning = true

    task.spawn(function()
        -- segurança extra
        task.wait(1)

        -- confirma de novo
        if #Players:GetPlayers() > 2 then
            executeClickWrapper()
        end

        -- cooldown pra não repetir
        task.wait(10)
        serverCheckRunning = false
    end)
end

-- ================= VERIFICAÇÃO FINAL DE TELEPORT E AIM LOCK =================
local function checkTeleportAndAimLock()
    local playerCount = #Players:GetPlayers()

    if playerCount == 2 then
        if serverOverrideActive then
            serverOverrideActive = false
            if botEnabled then
                setTeleportBehind(true)
                aimLockNearestTorso(true)
            end
        end
    else
        if not serverOverrideActive then
            serverOverrideActive = true
            setTeleportBehind(false)
            aimLockNearestTorso(false)
        end
    end
end

-- Chamando a função dentro do loop principal
task.spawn(function()
    while true do
        -- Atualiza a verificação do nível e outras condições
        enforceLevelAuthorityKillSwitch()
        
        -- Verifica e controla o teleport e aim lock com base nas condições
        checkTeleportAndAimLock()

        -- Outras verificações do loop...
        task.wait(0.4)
    end
end)

-- ================= UPDATE HUD =================
local function updateLabel()
    -- Primeiro, pega o jogador mais próximo válido
    local nearest = getNearestPlayer()
    if nearest then
        -- Atualiza trackedPlayer só se for diferente
        if trackedPlayer ~= nearest then
            trackPlayer(nearest)
        end

        -- Pega level com segurança
        local stats = nearest:FindFirstChild("leaderstats")
        local level = stats and stats:FindFirstChild("Level")
        
        -- Atualiza o texto do HUD
        label.Text = nearest.Name.." | Mortes: "..deathCount.."/"..MAX_DEATHS.." | Level: "..(level and level.Value or "Sem Level")
    else
        label.Text = "Procurando jogador mais próximo..."
    end
end


local function updateMyWS()
    local wsObj = getWinStreak(player)
    local wsValue = wsObj and wsObj.Value or 0
    myLabel.Text = "Meu WS: "..wsValue
    return wsValue
end


-- =========================
-- 🔥 CONTADOR DE MINHAS MORTES (INDEPENDENTE)
-- =========================


local MAX_MY_DEATHS = 4
local myDeathCount = 0
local myDeathConnection

local function myplayerdeaths()

    local function connectHumanoid(humanoid)

        if myDeathConnection then
            myDeathConnection:Disconnect()
        end

        myDeathConnection = humanoid.HealthChanged:Connect(function(health)
            if health <= 0 then
                myDeathCount += 1


                if myDeathCount >= MAX_MY_DEATHS then
                    executeClickWrapper()
                    myDeathCount = 0
                end
            end
        end)

    end

    if player.Character then
        local hum = player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            connectHumanoid(hum)
        end
    end

    player.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        connectHumanoid(hum)
    end)

end

myplayerdeaths()


local function isQuickscopeMissionActive()
    local player = game.Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local lobby = playerGui:WaitForChild("Lobby", 10)
    if not lobby then return false end

    local leftSideInfo = lobby:FindFirstChild("LeftSideInfo")
    if not leftSideInfo then return false end

    -- Encontra o Frame que contém o Container
    local containerFrame = nil
    for _, obj in ipairs(leftSideInfo:GetChildren()) do
        if obj:IsA("Frame") and obj:FindFirstChild("Container") then
            containerFrame = obj
            break
        end
    end

    if not containerFrame then
        print("⚠️ Nenhum Frame com Container encontrado")
        return false
    end

    local container = containerFrame:WaitForChild("Container")
    if not container then
        print("⚠️ Container não encontrado dentro do Frame")
        return false
    end

    -- Flag para saber se achou o texto
    local found = false

    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            if obj.Text and obj.Text:upper() == "GET QUICKSCOPE KILLS" then
                --print("🔥 Quickscope Mission detectada:", obj.Text)
                found = true
                break  -- já achou, não precisa continuar
            end
        end
    end

    --if not found then
        --print("⚠️ Quickscope Mission NÃO encontrada")
    --end

    return found
end
-- ================= AUTO SHOOT =================
local function resetAutoShoot()
    attacking = false
    currentTarget = nil
    targetHumanoid = nil
    resetFlag = true
end

local function hookMyCharacter(char)
    myHumanoid = char:WaitForChild("Humanoid",5)
    if not myHumanoid then return end
    myHumanoid.Died:Connect(resetAutoShoot)
end

if player.Character then hookMyCharacter(player.Character) end
player.CharacterAdded:Connect(hookMyCharacter)

local function runShootSequence(humanoid)
    resetFlag = false
    local firstRun = true  -- flag pra controlar a primeira execução

    while humanoid.Health > 0 and myHumanoid and myHumanoid.Health > 0 and humanoid == targetHumanoid and not resetFlag do
        -- Espera 5 segundos na primeira execução, 0.5s nas repetições
        if firstRun then
            task.wait(4.2)
            firstRun = false
        else
            task.wait(0.5)
        end
        if resetFlag then return end


        -- 2️⃣ Pressiona tecla 2
        vim:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
        vim:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
        task.wait(0.3)
        if resetFlag then return end

        -- 3️⃣ Pressiona tecla 1
        vim:SendKeyEvent(true, Enum.KeyCode.One, false, game)
        vim:SendKeyEvent(false, Enum.KeyCode.One, false, game)
        task.wait(0.3)
        if resetFlag then return end


        -- 4️⃣ Click final do M1
        vim:SendMouseButtonEvent(0,0,0,true,game,0)
        task.wait(0.1)
        vim:SendMouseButtonEvent(0,0,0,false,game,0)
    end
end

local function runShootSequenceQuickscope(humanoid)
    resetFlag = false
    local firstRun = true

    while humanoid.Health > 0 
    and myHumanoid 
    and myHumanoid.Health > 0 
    and humanoid == targetHumanoid 
    and not resetFlag 
    and not levelAuthorityLock do

        if firstRun then
            task.wait(4.2)
            firstRun = false
        else
            task.wait(0.5)
        end

        if resetFlag then return end

        -- Pressiona 2
        vim:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
        vim:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
        task.wait(0.3)

        -- Pressiona 1
        vim:SendKeyEvent(true, Enum.KeyCode.One, false, game)
        vim:SendKeyEvent(false, Enum.KeyCode.One, false, game)
        task.wait(0.3)

        -- 🔥 SEGURA M2
        vim:SendMouseButtonEvent(0,0,1,true,game,0)

        -- Click M1
        vim:SendMouseButtonEvent(0,0,0,true,game,0)
        task.wait(0.1)
        vim:SendMouseButtonEvent(0,0,0,false,game,0)

        -- Solta M2
        vim:SendMouseButtonEvent(0,0,1,false,game,0)

    end
end


-- ================= AUTO SHOOT WHILE ALIVE =================
local function autoShootWhileAlive()
    task.spawn(function()
        while true do
            task.wait(0.1)

            -- 🔒 BLOQUEIO POR LEVEL
            if levelAuthorityLock then
                task.wait(0.8)
                continue
            end

            -- Verifica se seu personagem existe e está vivo
            if not myHumanoid or myHumanoid.Health <= 0 then continue end

            -- Pega o jogador mais próximo
            local target = getNearestPlayer()
            if not target or not target.Character then continue end

            local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then continue end

            -- Configura o alvo
            currentTarget = target
            targetHumanoid = humanoid
            attacking = true

            -- Executa a sequência completa, respeitando quickscope
            if isQuickscopeMissionActive() then
                runShootSequenceQuickscope(humanoid)
            else
                runShootSequence(humanoid)
            end

            -- Repete a sequência enquanto ambos estiverem vivos
            while myHumanoid and myHumanoid.Health > 0
                  and humanoid and humanoid.Health > 0
                  and not resetFlag do

                -- 🔒 Bloqueio por level durante combate
                if levelAuthorityLock then
                    task.wait(0.8)
                    break
                end

                currentTarget = target
                targetHumanoid = humanoid
                attacking = true

                -- Quickscope sempre tem prioridade
                if isQuickscopeMissionActive() then
                    runShootSequenceQuickscope(humanoid)
                else
                    runShootSequence(humanoid)
                end

                attacking = false
                task.wait(0.05)
            end

            attacking = false
        end
    end)
end

-- Ativa o auto shoot
autoShootWhileAlive()



-- ================= LOOP PRINCIPAL =================
task.spawn(function()
    while true do
        local nearest = getNearestPlayer()
        if nearest then trackPlayer(nearest) end
        updateLabel()
        updateMyWS()
        checkMaxDeaths()
        enforceLevelAuthorityKillSwitch()
        checkServerPlayersAndQueue()
        monitorNearestPlayerDeaths()


        if botEnabled then autoShootNearestPlayer() end
        task.wait(0.4)
    end
end)




-- ================= LOOP TAB + CLICK =================

task.spawn(function()
    while true do
        local myWS = updateMyWS()
        if trackedPlayer then
            local stats = trackedPlayer:FindFirstChild("leaderstats")
            local level = stats and stats:FindFirstChild("Level")
            if (level and level.Value>MIN_LEVEL) or myWS>=MAX_WIN_STREAK then
                holdTab()
                executeClickWrapper()
                task.wait(CLICK_INTERVAL)
            else
                releaseTab()
                task.wait(0.5)
            end
        else
            releaseTab()
            task.wait(0.5)
        end
    end
end)
