--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║                 SISTEMA DE PODERES SOBRENATURAIS             ║
    ║                     Desenvolvido por: LOMAR DEV              ║
    ║                     Comunidade: MRI Community                ║
    ╚══════════════════════════════════════════════════════════════╝
]]

local sereiaAtiva = false
local levitando = false
local visaoVampiro = false
local velocidadeVampiro = false

-- =========================================================================
-- UTILITÁRIOS E NOTIFICAÇÃO
-- =========================================================================
local function Notify(title, msg, type)
    if GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:notify({
            title = title or 'LOMAR DEV - Poderes',
            description = msg,
            type = type or 'inform'
        })
    else
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(("~b~[%s]~w~ %s"):format(title or 'LOMAR DEV', msg))
        EndTextCommandThefeedPostTicker(false, true)
    end
end

local loadedPtfxDicts = {}
local function LoadPtfx(dict)
    if loadedPtfxDicts[dict] then return end
    if not HasNamedPtfxAssetLoaded(dict) then
        RequestNamedPtfxAsset(dict)
        local timeout = 0
        while not HasNamedPtfxAssetLoaded(dict) and timeout < 200 do
            Wait(10)
            timeout = timeout + 1
        end
    end
    loadedPtfxDicts[dict] = true
end

local function PlaySpellSound(soundName, volume)
    SendNUIMessage({
        sound = soundName,
        volume = volume or 0.4
    })
end

local function PlaySpellSoundAtCoords(soundName, coords, maxDist, volume)
    TriggerServerEvent('lumina_poderes:server:syncSound', soundName, coords, maxDist or 45.0, volume or 0.7)
end

RegisterNetEvent('lumina_poderes:client:receiveSound', function(soundName, coords, maxDist, maxVolume)
    local pPed = PlayerPedId()
    local myCoords = GetEntityCoords(pPed)
    local dist = #(myCoords - coords)
    local maxDistance = maxDist or 45.0
    if dist <= maxDistance then
        local factor = 1.0 - (dist / maxDistance)
        local vol = math.max(0.05, math.min(1.0, (maxVolume or 0.6) * factor))
        PlaySpellSound(soundName, vol)
    end
end)

local function RequestAnim(animDict)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        local timeout = 0
        while not HasAnimDictLoaded(animDict) and timeout < 150 do
            Wait(10)
            timeout = timeout + 1
        end
    end
end

local function GetClosestPlayer()
    local ped = PlayerPedId()
    local myCoords = GetEntityCoords(ped)
    local closestPlayer = -1
    local closestDist = -1

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            if DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                local dist = #(myCoords - targetCoords)
                if closestDist == -1 or dist < closestDist then
                    closestDist = dist
                    closestPlayer = playerId
                end
            end
        end
    end
    return closestPlayer, closestDist
end

-- =========================================================================
-- 1. PODER DA SEREIA (Nado Veloz + Respiração Subaquática)
-- =========================================================================
local function ToggleSereia(status)
    local ped = PlayerPedId()
    local pedId = PlayerId()

    if status == nil then
        sereiaAtiva = not sereiaAtiva
    else
        sereiaAtiva = (status == "on" or status == true)
    end

    if sereiaAtiva then
        SetSwimMultiplierForPlayer(pedId, Config.Sereia.SwimSpeedMultiplier or 1.49)
        SetPedMaxTimeUnderwater(ped, Config.Sereia.MaxUnderwaterTime or 120.0)
        SetPedDiesInWater(ped, false)
        PlaySpellSound("water", 0.5)
        Notify('Sereia', 'Poder das Sereias ATIVADO! Nado veloz e respiração infinita.', 'success')

        CreateThread(function()
            while sereiaAtiva do
                Wait(500)
                local p = PlayerPedId()
                if IsPedSwimming(p) or IsPedSwimmingUnderWater(p) then
                    SetPlayerUnderwaterTimeRemaining(p, 100.0)
                    if Config.Sereia.RefillStamina then
                        ResetPlayerStamina(PlayerId())
                    end
                end
            end
        end)
    else
        SetSwimMultiplierForPlayer(pedId, 1.0)
        SetPedMaxTimeUnderwater(ped, 30.0)
        SetPedDiesInWater(ped, true)
        Notify('Sereia', 'Poder das Sereias DESATIVADO.', 'error')
    end
end

RegisterNetEvent('lumina_poderes:client:toggleSereia', function(status)
    ToggleSereia(status)
end)

RegisterCommand('respiracao', function(_, args)
    local status = args[1] and string.lower(args[1]) or nil
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'sereia', status)
end, false)

RegisterCommand('sereia', function(_, args)
    local status = args[1] and string.lower(args[1]) or nil
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'sereia', status)
end, false)

-- =========================================================================
-- 2. PODER DE LEVITAÇÃO
-- =========================================================================
local function ToggleLevitacao()
    local ped = PlayerPedId()
    local dict = "rcmcollect_paperleadinout@"
    local anim = "meditiate_idle"

    if levitando then
        levitando = false
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
        Notify('Levitação', 'Você desceu ao solo.', 'inform')
        return
    end

    levitando = true
    local coords = GetEntityCoords(ped)
    PlaySpellSound("lux", 0.4)
    Notify('Levitação', 'Levitando! Pressione [E] ou digite /levitar para cancelar.', 'success')

    RequestAnim(dict)
    local currentZ = coords.z - 0.2
    for _ = 1, 60 do
        if not levitando then break end
        currentZ = currentZ + 0.02
        SetEntityCoords(ped, coords.x, coords.y, currentZ, false, false, false, false)
        Wait(20)
    end

    if levitando then
        TaskPlayAnim(ped, dict, anim, 2.0, 2.0, -1, 37, 0.0, false, false, false)
        FreezeEntityPosition(ped, true)
    end

    CreateThread(function()
        while levitando do
            Wait(0)
            if IsControlJustReleased(0, 38) then -- Tecla E
                levitando = false
                ClearPedTasks(PlayerPedId())
                FreezeEntityPosition(PlayerPedId(), false)
                Notify('Levitação', 'Você cancelou a levitação.', 'inform')
                break
            end
        end
    end)
end

RegisterNetEvent('lumina_poderes:client:levitate', function()
    ToggleLevitacao()
end)

RegisterCommand('levitar', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'levitate')
end, false)

RegisterCommand('levitate', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'levitate')
end, false)

-- =========================================================================
-- 3. TELEPORTE MÁGICO (Mira com Raio & Trovão)
-- =========================================================================
local function GetCoordsFromCam(distance, coords)
    local rot = GetGameplayCamRot()
    local adjRot = vector3((math.pi / 180) * rot.x, (math.pi / 180) * rot.y, (math.pi / 180) * rot.z)
    local dir = vector3(-math.sin(adjRot[3]) * math.abs(math.cos(adjRot[1])), math.cos(adjRot[3]) * math.abs(math.cos(adjRot[1])), math.sin(adjRot[1]))
    return vector3(coords.x + dir.x * distance, coords.y + dir.y * distance, coords.z + dir.z * distance)
end

local function GetTargetSceneCoords(maxDist, promptMsg)
    local cam = GetGameplayCamCoord()
    local hitCoords = nil
    local aiming = true

    Notify('Mira Mágica', promptMsg or 'Mire e pressione [ENTER / Botão Esquerdo] para conjurar, ou [ESC] para cancelar.', 'inform')

    while aiming do
        Wait(0)
        local ped = PlayerPedId()
        local farCoords = GetCoordsFromCam(maxDist or 100.0, cam)
        local ray = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, farCoords.x, farCoords.y, farCoords.z, -1, ped, 4)
        local _, hit, endCoords = GetShapeTestResult(ray)

        if hit and endCoords then
            hitCoords = endCoords
            DrawMarker(28, endCoords.x, endCoords.y, endCoords.z + 0.1, 0, 0, 0, 0, 0, 0, 0.4, 0.4, 0.4, 138, 43, 226, 200, false, false, 2, false, nil, nil, false)
        end

        if IsControlJustReleased(0, 191) or IsControlJustReleased(0, 24) then -- Enter ou Click Esquerdo
            aiming = false
            return hitCoords
        elseif IsControlJustReleased(0, 177) or IsControlJustReleased(0, 73) then -- Backspace / ESC
            aiming = false
            Notify('Poderes', 'Conjuração cancelada.', 'error')
            return nil
        end
    end
end

RegisterNetEvent('lumina_poderes:client:magicTeleport', function()
    local targetCoords = GetTargetSceneCoords(Config.TeleportDistance or 100.0, 'Escolha onde teleportar com [ENTER].')
    if not targetCoords then return end

    local ped = PlayerPedId()
    local startCoords = GetEntityCoords(ped)
    local dict = "rcmbarry"
    local anim = "bar_1_attack_idle_aln"

    RequestAnim(dict)
    TaskTurnPedToFaceCoord(ped, targetCoords.x, targetCoords.y, targetCoords.z, 500)
    Wait(400)
    TaskPlayAnim(ped, dict, anim, 2.0, 2.0, 2000, 7, 0.0, false, false, false)

    Wait(800)
    TriggerServerEvent("lumina_poderes:server:syncParticle", startCoords, "core", "exp_xs_ray", 1.0, 3000, "thunder")

    Wait(400)
    SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z + 0.2, false, false, false, false)
    TriggerServerEvent("lumina_poderes:server:syncParticle", targetCoords, "core", "exp_xs_ray", 1.0, 2000, "thunder")
    Notify('Teleporte', 'Teleportado com sucesso!', 'success')
end)

RegisterCommand('tpmagico', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'teleport')
end, false)

RegisterCommand('tpcast', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'teleport')
end, false)

-- =========================================================================
-- 4. LANÇA-CHAMAS MÁGICO
-- =========================================================================
RegisterNetEvent('lumina_poderes:client:magicFlamethrower', function()
    local ped = PlayerPedId()
    local dict = "rcmbarry"
    local anim = "bar_1_attack_idle_aln"
    local cooldown = false
    local uses = 0
    local maxUses = Config.FlameUses or 4

    RequestAnim(dict)
    TaskPlayAnim(ped, dict, anim, 1.0, 1.0, -1, 50, 0.0, false, false, false)
    Wait(50)

    Notify('Chamas Mágicas', 'Pressione [E] para disparar chamas mágicas pelas mãos!', 'inform')

    while IsEntityPlayingAnim(ped, dict, anim, 1) and uses < maxUses do
        Wait(0)
        if IsControlJustReleased(0, 38) and not cooldown then
            uses = uses + 1
            cooldown = true
            local pCoords = GetEntityCoords(ped)
            TriggerServerEvent("lumina_poderes:server:syncFlames", pCoords)
            Wait(3500)
            cooldown = false
        end
    end
    ClearPedTasks(ped)
    Notify('Chamas Mágicas', 'Energia de fogo esgotada.', 'inform')
end)

RegisterCommand('magia_fogo', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'flamethrower')
end, false)

RegisterCommand('flametest', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'flamethrower')
end, false)

-- =========================================================================
-- 5. FUMAÇA MÍSTICA / DESAPARECER
-- =========================================================================
RegisterNetEvent('lumina_poderes:client:fazFumaca', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    coords = vector3(coords.x, coords.y, coords.z - 0.5)

    TriggerServerEvent("lumina_poderes:server:syncSmoke", coords, "scr_powerplay", "scr_powerplay_beast_vanish", 1.2, 3500, "thunder")
    Notify('Fumaça', 'Você conjurou uma névoa mística!', 'success')
end)

RegisterCommand('fumaca', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'fumaca')
end, false)

RegisterCommand('desaparecer', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'fumaca')
end, false)

-- =========================================================================
-- 6. PODERES DE VAMPIRO (Mordida Sincronizada, Visão & Velocidade)
-- =========================================================================

-- Comando para iniciar mordida
RegisterCommand('morder', function()
    local targetPlayer, dist = GetClosestPlayer()
    local maxDist = Config.Vampiro.DistanciaMordida or 2.5

    if targetPlayer ~= -1 and dist <= maxDist then
        local targetServerId = GetPlayerServerId(targetPlayer)
        TriggerServerEvent('lumina_poderes:server:executeBite', targetServerId)
    else
        Notify('Vampiro', 'Nenhuma vítima próxima o suficiente para morder!', 'error')
    end
end, false)

RegisterCommand('alimentar', function()
    ExecuteCommand('morder')
end, false)

-- Execução da animação no Conjurador (Vampiro)
RegisterNetEvent('lumina_poderes:client:playBiteVampire', function()
    local ped = PlayerPedId()
    local dict = "gs_rb_05@animation"
    local anim = "gs_rb_05_clip"

    RequestAnim(dict)
    FreezeEntityPosition(ped, true)
    PlaySpellSound("demon", 0.6)
    TaskPlayAnim(ped, dict, anim, 2.0, 2.0, 6000, 1, 0.0, false, false, false)
    Notify('Vampiro', 'Alimentando-se do sangue da vítima...', 'success')

    Wait(5500)
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)

    -- Cura o vampiro
    local curHealth = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.min(maxHealth, curHealth + (Config.Vampiro.CuraVampiro or 35)))
    ResetPlayerStamina(PlayerId())
    Notify('Vampiro', 'Você saciou sua sede de sangue! Saúde recuperada.', 'success')
end)

-- Execução da animação na Vítima
RegisterNetEvent('lumina_poderes:client:playBiteVictim', function()
    local ped = PlayerPedId()
    local dict = "gs_rb_04@animation"
    local anim = "gs_rb_04_clip"

    RequestAnim(dict)
    FreezeEntityPosition(ped, true)
    TaskPlayAnim(ped, dict, anim, 2.0, 2.0, 6000, 1, 0.0, false, false, false)
    Notify('Ataque', 'Um vampiro está sugando o seu sangue!', 'error')

    Wait(5500)
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)

    local curHealth = GetEntityHealth(ped)
    SetEntityHealth(ped, math.max(105, curHealth - (Config.Vampiro.DanoMordida or 25)))
end)

-- Visão Noturna de Vampiro
RegisterCommand('olhos_vampiro', function()
    visaoVampiro = not visaoVampiro
    SetNightvision(visaoVampiro)
    if visaoVampiro then
        PlaySpellSound("mental", 0.4)
        Notify('Vampiro', 'Visão Sombria ativada.', 'success')
    else
        Notify('Vampiro', 'Visão Sombria desativada.', 'inform')
    end
end, false)

RegisterCommand('visao_noturna', function()
    ExecuteCommand('olhos_vampiro')
end, false)

-- Velocidade Sobrenatural de Vampiro
RegisterCommand('velocidade_vampiro', function()
    if velocidadeVampiro then
        Notify('Vampiro', 'Você já está canalizando velocidade.', 'inform')
        return
    end

    velocidadeVampiro = true
    local pedId = PlayerId()
    SetRunSprintMultiplierForPlayer(pedId, Config.Vampiro.VelocidadeMultiplier or 1.49)
    PlaySpellSound("demon", 0.4)
    Notify('Vampiro', 'Arrancada Sobrenatural ativada!', 'success')

    CreateThread(function()
        local tempo = Config.Vampiro.DuracaoVelocidade or 12000
        local decorrido = 0
        while decorrido < tempo and velocidadeVampiro do
            Wait(300)
            decorrido = decorrido + 300
            local p = PlayerPedId()
            if IsPedSprinting(p) then
                local c = GetEntityCoords(p)
                UseParticleFxAssetNextCall("core")
                StartParticleFxNonLoopedAtCoord("exp_grd_rpg_post", c.x, c.y, c.z - 0.9, 0.0, 0.0, 0.0, 0.2, false, false, false)
            end
        end
        SetRunSprintMultiplierForPlayer(pedId, 1.0)
        velocidadeVampiro = false
        Notify('Vampiro', 'Sua energia vampírica se estabilizou.', 'inform')
    end)
end, false)

-- =========================================================================
-- 7. PODER DA TEMPESTADE (Invocar Raio Destruidor)
-- =========================================================================
RegisterNetEvent('lumina_poderes:client:summonLightning', function()
    local targetCoords = GetTargetSceneCoords(Config.RaioDistance or 80.0, 'Escolha onde o RAIO deve cair com [ENTER].')
    if not targetCoords then return end

    local ped = PlayerPedId()
    local dict = "rcmbarry"
    local anim = "bar_1_attack_idle_aln"

    RequestAnim(dict)
    TaskTurnPedToFaceCoord(ped, targetCoords.x, targetCoords.y, targetCoords.z, 500)
    Wait(200)
    TaskPlayAnim(ped, dict, anim, 2.0, 2.0, 2000, 7, 0.0, false, false, false)

    PlaySpellSound("tempestade_surja", 0.6)
    Wait(1200)

    TriggerServerEvent("lumina_poderes:server:syncLightning", targetCoords)
    Notify('Tempestade', 'Raio invocado!', 'success')
end)

RegisterCommand('raio', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'raio')
end, false)

RegisterCommand('tempestade', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'raio')
end, false)

RegisterNetEvent('lumina_poderes:client:receiveLightning', function(coords)
    local myCoords = GetEntityCoords(PlayerPedId())
    local dist = #(coords - myCoords)

    if dist <= 120.0 then
        PlaySpellSound("thunder", 0.7)
    end

    if dist <= 300.0 then
        UseParticleFxAssetNextCall("core")
        StartParticleFxLoopedAtCoord("exp_xs_ray", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 2.0, false, false, false)
        AddExplosion(coords.x, coords.y, coords.z, 29, 0.0, true, false, 0.6)
    end
end)

-- =========================================================================
-- 8. PODER DO TERREMOTO
-- =========================================================================
RegisterNetEvent('lumina_poderes:client:earthquake', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    PlaySpellSound("earthquake.mp3", 0.8)
    ShakeGameplayCam('SKY_DIVING_SHAKE', Config.Terremoto.Intensidade or 1.2)
    Notify('Terremoto', 'A terra está estremecendo sob seus pés!', 'error')

    Wait(Config.Terremoto.DuracaoMs or 8000)
    ShakeGameplayCam('SKY_DIVING_SHAKE', 0.0)
end)

RegisterCommand('terremoto', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'terremoto')
end, false)

-- =========================================================================
-- 9. ATERRORIZAR / RISADA DEMONÍACA
-- =========================================================================
RegisterNetEvent('lumina_poderes:client:risada', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    TriggerServerEvent("lumina_poderes:server:syncLaugh", coords)
    Notify('Terror', 'Você espalhou terror ao redor!', 'success')
end)

RegisterCommand('risada', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'risada')
end, false)

RegisterCommand('aterrorizar', function()
    TriggerServerEvent('lumina_poderes:server:checkAndExecute', 'risada')
end, false)

RegisterNetEvent('lumina_poderes:client:receiveLaugh', function(coords)
    local myCoords = GetEntityCoords(PlayerPedId())
    local dist = #(coords - myCoords)

    if dist <= 50.0 then
        PlaySpellSound("risada", 0.7)
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.4)
        Wait(2000)
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.0)
    end
end)

-- =========================================================================
-- 10. SINCRONIZAÇÃO GERAL EM REDE
-- =========================================================================
RegisterNetEvent("lumina_poderes:client:receiveParticle", function(coords, partDict, particles, size, duration, sound)
    local myCoords = GetEntityCoords(PlayerPedId())
    local dist = #(coords - myCoords)

    if dist <= 40.0 and sound then
        PlaySpellSound(sound, 0.4)
    end

    if dist <= 200.0 then
        RequestNamedPtfxAsset(partDict)
        local attempt = 0
        while not HasNamedPtfxAssetLoaded(partDict) and attempt < 50 do
            Wait(10)
            attempt = attempt + 1
        end

        UseParticleFxAssetNextCall(partDict)
        local ptfx = StartParticleFxLoopedAtCoord(particles, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, size or 1.0, false, false, false)
        if duration then
            SetTimeout(duration, function()
                StopParticleFxLooped(ptfx, false)
            end)
        end
    end
end)

RegisterNetEvent("lumina_poderes:client:receiveFlames", function(sourcePlayer)
    local myCoords = GetEntityCoords(PlayerPedId())
    local targetPed = GetPlayerPed(GetPlayerFromServerId(sourcePlayer))
    if not DoesEntityExist(targetPed) then return end

    local targetCoords = GetEntityCoords(targetPed)
    local dist = #(targetCoords - myCoords)

    if dist <= 40.0 then
        PlaySpellSound("flame", 0.4)
    end

    if dist <= 250.0 then
        UseParticleFxAssetNextCall("core")
        local ptfx = StartParticleFxLoopedOnEntityBone("ent_sht_flame", targetPed, 0.0, 1.0, 0.3, 180.0, 270.0, 270.0, 11816, Config.FlameThrowerSize or 2.5, false, false, false)
        SetTimeout(3500, function()
            StopParticleFxLooped(ptfx, false)
        end)
    end
end)

RegisterNetEvent("lumina_poderes:client:burn", function()
    local ped = PlayerPedId()
    StartEntityFire(ped)
    Wait(5000)
    StopEntityFire(ped)
end)

-- =========================================================================
-- 11. TRANSFORMAÇÃO EM LOBISOMEM (LOMAR DEV)
-- =========================================================================
local isLobisomem = false
local savedHumanAppearance = nil
local savedHumanModel = nil
local lobisomemNightVision = false

local function TransformarLobisomem()
    local ped = PlayerPedId()
    local pedId = PlayerId()

    if isLobisomem then
        Notify('Lobisomem', 'Você já está transformado em Lobisomem! Use /humano para destransformar.', 'error')
        return
    end

    -- Salva aparência humana original (compatível com illenium-appearance e modelos padrão)
    if GetResourceState('illenium-appearance') == 'started' and exports['illenium-appearance'] then
        pcall(function()
            savedHumanAppearance = exports['illenium-appearance']:getPedAppearance(ped)
        end)
    end
    savedHumanModel = GetEntityModel(ped)

    -- Efeito visual e sonoro da transformação
    local coords = GetEntityCoords(ped)
    PlaySpellSound(Config.Lobisomem.AudioTransformation or "demon", 0.8)

    -- Animação dramática de transformação
    RequestAnim("anim@mp_player_intcelebrationmale@freakout")
    TaskPlayAnim(ped, "anim@mp_player_intcelebrationmale@freakout", "freakout", 8.0, -8.0, 2500, 49, 0, false, false, false)

    -- Fumaça mística
    RequestNamedPtfxAsset(Config.Lobisomem.PtfxAsset or "core")
    local ptfxTimeout = 0
    while not HasNamedPtfxAssetLoaded(Config.Lobisomem.PtfxAsset or "core") and ptfxTimeout < 50 do
        Wait(10)
        ptfxTimeout = ptfxTimeout + 1
    end
    UseParticleFxAssetNextCall(Config.Lobisomem.PtfxAsset or "core")
    StartParticleFxNonLoopedAtCoord(Config.Lobisomem.PtfxParticle or "exp_grd_grenade_smoke", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.8, false, false, false)

    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.5)
    Wait(1200)

    -- Carrega e aplica o modelo WereWolf (Lupino_Lumina)
    local werewolfModel = Config.Lobisomem.Model or "WereWolf"
    local modelHash = GetHashKey(werewolfModel)

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 200 do
        Wait(20)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) then
        Notify('Lobisomem', 'Erro: Não foi possível carregar o modelo ' .. werewolfModel, 'error')
        ClearPedTasks(ped)
        return
    end

    SetPlayerModel(pedId, modelHash)
    SetModelAsNoLongerNeeded(modelHash)

    local newPed = PlayerPedId()
    SetPedDefaultComponentVariation(newPed)

    -- Atributos de Lobisomem
    local maxHp = Config.Lobisomem.MaxHealth or 400
    SetPedMaxHealth(newPed, maxHp)
    SetEntityHealth(newPed, maxHp)
    SetPedArmour(newPed, Config.Lobisomem.Armour or 100)
    SetRunSprintMultiplierForPlayer(pedId, Config.Lobisomem.SpeedMultiplier or 1.49)
    SetPlayerMeleeWeaponDamageModifier(pedId, Config.Lobisomem.MeleeDamageMultiplier or 2.5)

    isLobisomem = true
    Notify('Lobisomem', 'Você se transformou em Lobisomem! Poderes: /uivo, /visaolobo, /humano', 'success')

    -- Loop de manutenção dos atributos da fera
    CreateThread(function()
        while isLobisomem do
            local currentPed = PlayerPedId()
            local pId = PlayerId()

            SetRunSprintMultiplierForPlayer(pId, Config.Lobisomem.SpeedMultiplier or 1.49)
            SetPlayerMeleeWeaponDamageModifier(pId, Config.Lobisomem.MeleeDamageMultiplier or 2.5)
            ResetPlayerStamina(pId)

            -- Pulo sobre-humano da fera
            if Config.Lobisomem.PuloPoderoso and IsPedJumping(currentPed) then
                SetSuperJumpThisFrame(pId)
            end

            Wait(0)
        end
    end)
end

local isLoboSirius = false

local function TransformarLoboSirius()
    local ped = PlayerPedId()
    local pedId = PlayerId()

    if isLobisomem or isLoboSirius then
        Notify('Lobo Sirius', 'Você já está transformado! Use /humano para reverter primeiro.', 'error')
        return
    end

    if GetResourceState('illenium-appearance') == 'started' and exports['illenium-appearance'] then
        pcall(function()
            savedHumanAppearance = exports['illenium-appearance']:getPedAppearance(ped)
        end)
    end
    savedHumanModel = GetEntityModel(ped)

    local coords = GetEntityCoords(ped)
    PlaySpellSound(Config.LoboSirius.AudioTransformation or "demon", 0.8)

    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do Wait(10) end
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.5, false, false, false)

    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.4)
    Wait(1000)

    local siriusModel = Config.LoboSirius.Model or "LoboSirius"
    local modelHash = GetHashKey(siriusModel)

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 200 do
        Wait(20)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) then
        Notify('Lobo Sirius', 'Erro ao carregar modelo ' .. siriusModel, 'error')
        return
    end

    SetPlayerModel(pedId, modelHash)
    SetModelAsNoLongerNeeded(modelHash)

    local newPed = PlayerPedId()
    SetPedDefaultComponentVariation(newPed)

    local maxHp = Config.LoboSirius.MaxHealth or 300
    SetPedMaxHealth(newPed, maxHp)
    SetEntityHealth(newPed, maxHp)
    SetRunSprintMultiplierForPlayer(pedId, Config.LoboSirius.SpeedMultiplier or 1.60)

    isLoboSirius = true
    Notify('Lobo Sirius', 'Você se transformou no ágil Lobo Sirius! Comandos: /uivo, /visaolobo, /humano', 'success')

    CreateThread(function()
        while isLoboSirius do
            local pId = PlayerId()
            SetRunSprintMultiplierForPlayer(pId, Config.LoboSirius.SpeedMultiplier or 1.60)
            ResetPlayerStamina(pId)
            Wait(0)
        end
    end)
end

local function DestransformarLobisomem()
    local ped = PlayerPedId()
    local pedId = PlayerId()

    if not isLobisomem and not isLoboSirius then
        Notify('Transformação', 'Você não está em nenhuma forma de fera.', 'error')
        return
    end

    local coords = GetEntityCoords(ped)
    PlaySpellSound("demon", 0.5)

    -- Fumaça da reversão
    RequestNamedPtfxAsset("core")
    if HasNamedPtfxAssetLoaded("core") then
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.5, false, false, false)
    end

    -- Desativa visão noturna se estiver ligada
    if lobisomemNightVision then
        SetNightvision(false)
        lobisomemNightVision = false
    end

    -- Reseta modificadores
    SetRunSprintMultiplierForPlayer(pedId, 1.0)
    SetPlayerMeleeWeaponDamageModifier(pedId, 1.0)

    -- Restaura aparência humana original
    if savedHumanAppearance and GetResourceState('illenium-appearance') == 'started' and exports['illenium-appearance'] then
        pcall(function()
            exports['illenium-appearance']:setPlayerAppearance(savedHumanAppearance)
        end)
    elseif savedHumanModel then
        RequestModel(savedHumanModel)
        local t = 0
        while not HasModelLoaded(savedHumanModel) and t < 100 do
            Wait(20)
            t = t + 1
        end
        if HasModelLoaded(savedHumanModel) then
            SetPlayerModel(pedId, savedHumanModel)
            SetModelAsNoLongerNeeded(savedHumanModel)
            if GetResourceState('illenium-appearance') == 'started' then
                TriggerEvent('illenium-appearance:client:reloadSkin')
            end
        end
    else
        local defaultModel = GetHashKey("mp_m_freemode_01")
        RequestModel(defaultModel)
        while not HasModelLoaded(defaultModel) do Wait(10) end
        SetPlayerModel(pedId, defaultModel)
        SetModelAsNoLongerNeeded(defaultModel)
        if GetResourceState('illenium-appearance') == 'started' then
            TriggerEvent('illenium-appearance:client:reloadSkin')
        end
    end

    local finalPed = PlayerPedId()
    SetPedMaxHealth(finalPed, 200)
    if GetEntityHealth(finalPed) > 200 then
        SetEntityHealth(finalPed, 200)
    end

    isLobisomem = false
    isLoboSirius = false
    savedHumanAppearance = nil
    savedHumanModel = nil

    Notify('Transformação', 'Você retornou à sua forma humana.', 'inform')
end

local function UivarLobisomem()
    local ped = PlayerPedId()

    if not isLobisomem and not isLoboSirius then
        Notify('Lobisomem', 'Você precisa estar na forma de Lobo para uivar!', 'error')
        return
    end

    local coords = GetEntityCoords(ped)
    PlaySpellSound(Config.Lobisomem.AudioHowl or "demon", 0.9)

    if isLobisomem then
        RequestAnim("rcmnigel1a")
        TaskPlayAnim(ped, "rcmnigel1a", "laugh_im_amused", 8.0, -8.0, 3500, 49, 0, false, false, false)
    end

    ShakeGameplayCam('VIBRATE_SHAKE', 1.0)
    SetTimeout(2000, function()
        ShakeGameplayCam('VIBRATE_SHAKE', 0.0)
    end)

    TriggerServerEvent("lumina_poderes:server:syncHowl", coords)
    Notify('Uivo', 'Você uivou furiosamente para a lua!', 'success')
end

local function ToggleVisaoLobo()
    if not isLobisomem and not isLoboSirius then
        Notify('Instinto Feral', 'Apenas feras possuem visão noturna apurada!', 'error')
        return
    end

    lobisomemNightVision = not lobisomemNightVision
    SetNightvision(lobisomemNightVision)

    if lobisomemNightVision then
        PlaySpellSound("lux", 0.4)
        Notify('Instinto Feral', 'Visão Noturna ATIVADA.', 'success')
    else
        Notify('Instinto Feral', 'Visão Noturna DESATIVADA.', 'inform')
    end
end

-- Comandos do Lobisomem e Lobo Sirius
RegisterCommand('lobisomem', function()
    TransformarLobisomem()
end, false)

RegisterCommand('lobao', function()
    TransformarLobisomem()
end, false)

RegisterCommand('transformar', function()
    TransformarLobisomem()
end, false)

RegisterCommand('lobinho', function()
    TransformarLoboSirius()
end, false)

RegisterCommand('lobosirius', function()
    TransformarLoboSirius()
end, false)

RegisterCommand('humano', function()
    DestransformarLobisomem()
end, false)

RegisterCommand('destransformar', function()
    DestransformarLobisomem()
end, false)

RegisterCommand('uivo', function()
    UivarLobisomem()
end, false)

RegisterCommand('uivar', function()
    UivarLobisomem()
end, false)

RegisterCommand('visaolobo', function()
    ToggleVisaoLobo()
end, false)

RegisterNetEvent('lumina_poderes:client:receiveHowl', function(coords)
    local myCoords = GetEntityCoords(PlayerPedId())
    local dist = #(coords - myCoords)

    if dist <= 60.0 then
        PlaySpellSound("demon", 0.7)
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.5)
        Wait(1500)
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.0)
    end
end)

-- =========================================================================
-- 13. RESSURREIÇÃO CELESTIAL / RENASCER (LOMAR DEV)
-- =========================================================================
RegisterCommand('renascer', function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        local closestP, dist = GetClosestPlayer()
        if closestP ~= -1 and dist <= (Config.Renascer.Distancia or 5.0) then
            targetId = GetPlayerServerId(closestP)
        end
    end

    if not targetId then
        Notify('Renascer', 'Nenhum jogador próximo encontrado para ressuscitar.', 'error')
        return
    end

    TriggerServerEvent('lumina_poderes:server:executeRevive', targetId)
end, false)

RegisterCommand('reviver', function(source, args)
    ExecuteCommand('renascer ' .. (args[1] or ''))
end, false)

RegisterNetEvent('lumina_poderes:client:playReviveCaster', function()
    local ped = PlayerPedId()
    RequestAnim("rcmepsilonism8")
    TaskPlayAnim(ped, "rcmepsilonism8", "worship_base", 8.0, -8.0, 7000, 1, 0, false, false, false)
    PlaySpellSound("angel", 0.8)
    Notify('Renascer', 'Você canalizou a luz celestial para reanimar a alma.', 'success')
    Wait(7000)
    ClearPedTasks(ped)
end)

RegisterNetEvent('lumina_poderes:client:playReviveVictim', function()
    local ped = PlayerPedId()
    PlaySpellSound("angel", 0.9)

    -- Animação de anjo levitando
    RequestAnim("gx_s01@animation")
    if HasAnimDictLoaded("gx_s01@animation") then
        TaskPlayAnim(ped, "gx_s01@animation", "gx_s01_clip", 8.0, -8.0, 7000, 1, 0, false, false, false)
    end

    -- Partícula de brilho celestial
    local coords = GetEntityCoords(ped)
    RequestNamedPtfxAsset("core")
    if HasNamedPtfxAssetLoaded("core") then
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.5, false, false, false)
    end

    Wait(7000)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, Config.Renascer.VidaCurada or 200)
    ClearPedBloodDamage(ped)
    Notify('Ressurreição', 'Você foi banhado pela luz celestial e ressuscitou!', 'success')
end)

-- =========================================================================
-- 14. BEIJO DA MORTE VAMPÍRICO (LOMAR DEV)
-- =========================================================================
RegisterCommand('beijodamorte', function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        local closestP, dist = GetClosestPlayer()
        if closestP ~= -1 and dist <= (Config.BeijoDaMorte.Distancia or 3.0) then
            targetId = GetPlayerServerId(closestP)
        end
    end

    if not targetId then
        Notify('Beijo da Morte', 'Nenhuma vítima próxima ao alcance.', 'error')
        return
    end

    TriggerServerEvent('lumina_poderes:server:executeDeathKiss', targetId)
end, false)

RegisterCommand('sugaralma', function(source, args)
    ExecuteCommand('beijodamorte ' .. (args[1] or ''))
end, false)

RegisterNetEvent('lumina_poderes:client:playDeathKissCaster', function()
    local ped = PlayerPedId()
    RequestAnim("rcmbarry")
    TaskPlayAnim(ped, "rcmbarry", "bar_1_teleport_aln", 8.0, -8.0, 4000, 49, 0, false, false, false)
    PlaySpellSound("demon", 0.8)

    local curHp = GetEntityHealth(ped)
    local maxHp = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.min(maxHp, curHp + (Config.BeijoDaMorte.Cura or 100)))
    SetPedArmour(ped, 100)

    Notify('Beijo da Morte', 'Você drenou a essência vital da vítima!', 'success')
    Wait(4000)
    ClearPedTasks(ped)
end)

RegisterNetEvent('lumina_poderes:client:playDeathKissVictim', function()
    local ped = PlayerPedId()
    PlaySpellSound("demon", 0.7)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.8)

    -- Partículas de sangue
    local coords = GetEntityCoords(ped)
    RequestNamedPtfxAsset("core")
    if HasNamedPtfxAssetLoaded("core") then
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("blood_stab", coords.x, coords.y, coords.z + 0.5, 0.0, 0.0, 0.0, 2.0, false, false, false)
    end

    ApplyDamageToPed(ped, Config.BeijoDaMorte.Dano or 50, false)
    RequestAnim("missfbi5ig_0")
    TaskPlayAnim(ped, "missfbi5ig_0", "lyinginpain_loop_steve", 8.0, -8.0, 5000, 1, 0, false, false, false)

    Notify('Beijo da Morte', 'Sua alma está sendo devorada pelo vampiro!', 'error')
    Wait(5000)
    ClearPedTasks(ped)
end)

-- =========================================================================
-- 15. CANTO DA SEREIA / HIPNOSE (LOMAR DEV)
-- =========================================================================
RegisterCommand('canto_sereia', function(source, args)
    local ped = PlayerPedId()
    local targetId = tonumber(args[1])

    RequestAnim("sereia10@animation")
    if HasAnimDictLoaded("sereia10@animation") then
        TaskPlayAnim(ped, "sereia10@animation", "sereia10_clip", 8.0, -8.0, 6000, 49, 0, false, false, false)
    else
        RequestAnim("rcmepsilonism8")
        TaskPlayAnim(ped, "rcmepsilonism8", "worship_base", 8.0, -8.0, 6000, 49, 0, false, false, false)
    end

    PlaySpellSound("water", 0.8)

    if targetId then
        TriggerServerEvent('lumina_poderes:server:executeHypnosis', targetId)
    else
        local coords = GetEntityCoords(ped)
        TriggerServerEvent('lumina_poderes:server:executeHypnosisArea', coords)
    end

    Notify('Sereia', 'Você entoou o canto hipnótico das sereias!', 'success')
    Wait(6000)
    ClearPedTasks(ped)
end, false)

RegisterCommand('hipnose', function(source, args)
    ExecuteCommand('canto_sereia ' .. (args[1] or ''))
end, false)

RegisterNetEvent('lumina_poderes:client:receiveHypnosisArea', function(coords)
    local myCoords = GetEntityCoords(PlayerPedId())
    local dist = #(coords - myCoords)
    if dist > 0.5 and dist <= (Config.HipnoseSereia.Raio or 12.0) then
        TriggerEvent('lumina_poderes:client:receiveHypnosis')
    end
end)

RegisterNetEvent('lumina_poderes:client:receiveHypnosis', function()
    local ped = PlayerPedId()
    PlaySpellSound("water", 0.7)
    ShakeGameplayCam('DRUNK_SHAKE', 1.8)
    SetPedIsDrunk(ped, true)

    RequestAnim("misscarsteal4@actor")
    TaskPlayAnim(ped, "misscarsteal4@actor", "stumble", 8.0, -8.0, 10000, 1, 0, false, false, false)
    Notify('Hipnose', 'Você ouviu o canto sedutor e perdeu o controle dos seus sentidos!', 'error')

    Wait(10000)
    ClearPedTasksImmediately(ped)
    SetPedIsDrunk(ped, false)
    ShakeGameplayCam('DRUNK_SHAKE', 0.0)
end)

-- =========================================================================
-- 16. PETRIFICAÇÃO / PRISÃO DE PEDRA (LOMAR DEV)
-- =========================================================================
RegisterCommand('petrificar', function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        local closestP, dist = GetClosestPlayer()
        if closestP ~= -1 and dist <= (Config.Petrificacao.Distancia or 10.0) then
            targetId = GetPlayerServerId(closestP)
        end
    end

    if not targetId then
        Notify('Petrificação', 'Nenhum alvo próximo para petrificar.', 'error')
        return
    end

    local ped = PlayerPedId()
    RequestAnim("gx_s05@animation")
    if HasAnimDictLoaded("gx_s05@animation") then
        TaskPlayAnim(ped, "gx_s05@animation", "gx_s05_clip", 8.0, -8.0, 3000, 49, 0, false, false, false)
    else
        RequestAnim("rcmbarry")
        TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 8.0, -8.0, 3000, 49, 0, false, false, false)
    end

    PlaySpellSound("dirt", 0.8)
    TriggerServerEvent('lumina_poderes:server:executePetrify', targetId)
    Notify('Petrificação', 'Você canalizou as forças da terra contra o alvo!', 'success')
    Wait(3000)
    ClearPedTasks(ped)
end, false)

RegisterNetEvent('lumina_poderes:client:receivePetrify', function(duration)
    local ped = PlayerPedId()
    duration = duration or 10000
    PlaySpellSound("dirt", 0.9)

    -- Poeira da petrificação
    local coords = GetEntityCoords(ped)
    RequestNamedPtfxAsset("core")
    if HasNamedPtfxAssetLoaded("core") then
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("exp_grd_grenade_dirt", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.8, false, false, false)
    end

    FreezeEntityPosition(ped, true)
    RequestAnim("amb@world_human_statue@base")
    TaskPlayAnim(ped, "amb@world_human_statue@base", "base", 8.0, -8.0, duration, 1, 0, false, false, false)

    Notify('Petrificação', 'Seu corpo virou pedra sólida! Você está petrificado!', 'error')

    Wait(duration)
    PlaySpellSound("dirt", 0.6)
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    Notify('Petrificação', 'A rocha se despedaçou e você voltou a se mover.', 'inform')
end)

-- =========================================================================
-- 17. ATAQUE PSÍQUICO / RAJADA MENTAL (LOMAR DEV)
-- =========================================================================
RegisterCommand('ataquemental', function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        local closestP, dist = GetClosestPlayer()
        if closestP ~= -1 and dist <= (Config.AtaqueMental.Distancia or 15.0) then
            targetId = GetPlayerServerId(closestP)
        end
    end

    if not targetId then
        Notify('Ataque Psíquico', 'Nenhum alvo mental ao alcance.', 'error')
        return
    end

    local ped = PlayerPedId()
    RequestAnim("rcmbarry")
    TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 8.0, -8.0, 3000, 49, 0, false, false, false)
    PlaySpellSound("mental", 0.8)

    TriggerServerEvent('lumina_poderes:server:executeMentalAttack', targetId)
    Notify('Ataque Psíquico', 'Você disparou uma rajada mental devastadora!', 'success')
    Wait(3000)
    ClearPedTasks(ped)
end, false)

RegisterCommand('psiquico', function(source, args)
    ExecuteCommand('ataquemental ' .. (args[1] or ''))
end, false)

RegisterNetEvent('lumina_poderes:client:receiveMentalAttack', function(damage)
    local ped = PlayerPedId()
    PlaySpellSound("mental", 0.8)
    ShakeGameplayCam('JOLT_SHAKE', 1.5)

    -- Partículas elétricas / mentais
    local coords = GetEntityCoords(ped)
    RequestNamedPtfxAsset("core")
    if HasNamedPtfxAssetLoaded("core") then
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("ent_ray_prologue_elec_crackle", coords.x, coords.y, coords.z + 0.6, 0.0, 0.0, 0.0, 1.5, false, false, false)
    end

    ApplyDamageToPed(ped, damage or 30, false)
    RequestAnim("mp_am_hold_up")
    TaskPlayAnim(ped, "mp_am_hold_up", "cower_intro", 8.0, -8.0, 5000, 49, 0, false, false, false)
    Notify('Ataque Psíquico', 'Sua mente está sendo torturada por um ataque psíquico!', 'error')

    Wait(5000)
    ClearPedTasks(ped)
end)

-- =========================================================================
-- 18. JULGAMENTO DA LUZ DIVINA (LOMAR DEV)
-- =========================================================================
RegisterCommand('luzdivina', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    RequestAnim("sereia10@animation")
    if HasAnimDictLoaded("sereia10@animation") then
        TaskPlayAnim(ped, "sereia10@animation", "sereia10_clip", 8.0, -8.0, 4000, 49, 0, false, false, false)
    else
        RequestAnim("rcmepsilonism8")
        TaskPlayAnim(ped, "rcmepsilonism8", "worship_base", 8.0, -8.0, 4000, 49, 0, false, false, false)
    end

    PlaySpellSound("lux", 0.9)
    TriggerServerEvent('lumina_poderes:server:executeDivineLight', coords)
    Notify('Luz Divina', 'Você invocou o resplendor sagrado da Luz Divina!', 'success')
    Wait(4000)
    ClearPedTasks(ped)
end, false)

RegisterCommand('purificar', function()
    ExecuteCommand('luzdivina')
end, false)

RegisterNetEvent('lumina_poderes:client:receiveDivineLight', function(coords)
    local myCoords = GetEntityCoords(PlayerPedId())
    local dist = #(coords - myCoords)

    if dist <= (Config.LuzDivina.Raio or 15.0) then
        PlaySpellSound("lux", 0.8)
        AnimpostfxPlay("DeadlineNeon", 3000, false)
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.8)
        Notify('Luz Divina', 'Você foi cegado pelo clarão celestial!', 'warning')
    end
end)

-- =========================================================================
-- 19. PRISÃO DE ÁGUA / AFOGAMENTO NO SECO (LOMAR DEV)
-- =========================================================================
RegisterCommand('prisao_agua', function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        local closestP, dist = GetClosestPlayer()
        if closestP ~= -1 and dist <= (Config.PrisaoAgua.Distancia or 10.0) then
            targetId = GetPlayerServerId(closestP)
        end
    end

    if not targetId then
        Notify('Prisão de Água', 'Nenhum alvo próximo para prender na água.', 'error')
        return
    end

    local ped = PlayerPedId()
    RequestAnim("gx_s04@animation")
    if HasAnimDictLoaded("gx_s04@animation") then
        TaskPlayAnim(ped, "gx_s04@animation", "gx_s04_clip", 8.0, -8.0, 4000, 49, 0, false, false, false)
    else
        RequestAnim("rcmbarry")
        TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 8.0, -8.0, 4000, 49, 0, false, false, false)
    end

    PlaySpellSound("water", 0.8)
    TriggerServerEvent('lumina_poderes:server:executeWaterPrison', targetId)
    Notify('Prisão de Água', 'Você envolveu o alvo numa esfera de água!', 'success')
    Wait(4000)
    ClearPedTasks(ped)
end, false)

RegisterCommand('afogar', function(source, args)
    ExecuteCommand('prisao_agua ' .. (args[1] or ''))
end, false)

RegisterNetEvent('lumina_poderes:client:receiveWaterPrison', function(duration)
    local ped = PlayerPedId()
    duration = duration or 8000
    PlaySpellSound("water", 0.8)

    RequestAnim("rcmnigel1b")
    TaskPlayAnim(ped, "rcmnigel1b", "swimming_idle", 8.0, -8.0, duration, 1, 0, false, false, false)
    Notify('Prisão de Água', 'Você foi preso numa bolha mágica de água e está se afogando!', 'error')

    local startTime = GetGameTimer()
    while (GetGameTimer() - startTime) < duration do
        ApplyDamageToPed(ped, 5, false)
        Wait(2000)
    end

    ClearPedTasksImmediately(ped)
    Notify('Prisão de Água', 'A bolha d\'água se dissipou.', 'inform')
end)

-- =========================================================================
-- 20. VÓRTICE DE TEMPESTADE / TORNADO (LOMAR DEV)
-- =========================================================================
RegisterCommand('tornado', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    RequestAnim("gx_s02@animation")
    if HasAnimDictLoaded("gx_s02@animation") then
        TaskPlayAnim(ped, "gx_s02@animation", "gx_s02_clip", 8.0, -8.0, 4000, 49, 0, false, false, false)
    else
        RequestAnim("rcmbarry")
        TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 8.0, -8.0, 4000, 49, 0, false, false, false)
    end

    PlaySpellSound("tornado", 0.9)
    TriggerServerEvent('lumina_poderes:server:executeTornado', coords)
    Notify('Tornado', 'Você invocou um furacão furioso!', 'success')
    Wait(4000)
    ClearPedTasks(ped)
end, false)

RegisterCommand('vendaval', function()
    ExecuteCommand('tornado')
end, false)

RegisterNetEvent('lumina_poderes:client:receiveTornado', function(coords)
    local ped = PlayerPedId()
    local myCoords = GetEntityCoords(ped)
    local dist = #(coords - myCoords)

    if dist <= 40.0 then
        PlaySpellSound("tornado", 0.8)
        ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 1.0)
    end

    -- Partícula de tornado
    RequestNamedPtfxAsset("core")
    if HasNamedPtfxAssetLoaded("core") then
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 3.5, false, false, false)
    end

    -- Empurra e derruba quem estiver no raio do tornado
    if dist > 1.0 and dist <= (Config.Tornado.Raio or 12.0) then
        SetPedToRagdoll(ped, 4000, 4000, 0, 0, 0, 0)
        Notify('Tornado', 'A força do vendaval te arremessou ao chão!', 'error')
    end
end)

-- =========================================================================
-- 21. CRUCIFICAÇÃO MÍSTICA (LOMAR DEV)
-- =========================================================================
RegisterCommand('crucificar', function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        local closestP, dist = GetClosestPlayer()
        if closestP ~= -1 and dist <= (Config.Crucificacao.Distancia or 8.0) then
            targetId = GetPlayerServerId(closestP)
        end
    end

    if not targetId then
        Notify('Crucificação', 'Nenhum alvo ao alcance para crucificar.', 'error')
        return
    end

    local ped = PlayerPedId()
    RequestAnim("gx_s07@animation")
    if HasAnimDictLoaded("gx_s07@animation") then
        TaskPlayAnim(ped, "gx_s07@animation", "gx_s07_clip", 8.0, -8.0, 4000, 49, 0, false, false, false)
    else
        RequestAnim("rcmbarry")
        TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 8.0, -8.0, 4000, 49, 0, false, false, false)
    end

    PlaySpellSound("demon", 0.8)
    TriggerServerEvent('lumina_poderes:server:executeCrucifixion', targetId)
    Notify('Crucificação', 'Você suspendeu a vítima na cruz invisível!', 'success')
    Wait(4000)
    ClearPedTasks(ped)
end, false)

RegisterNetEvent('lumina_poderes:client:receiveCrucifixion', function(duration)
    local ped = PlayerPedId()
    duration = duration or 8000
    PlaySpellSound("demon", 0.9)

    local coords = GetEntityCoords(ped)
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, coords.x, coords.y, coords.z + (Config.Crucificacao.Altura or 1.6), false, false, false, false)

    RequestAnim("anim@heists@heist_corona@single_team")
    if HasAnimDictLoaded("anim@heists@heist_corona@single_team") then
        TaskPlayAnim(ped, "anim@heists@heist_corona@single_team", "single_team_loop_boss", 8.0, -8.0, duration, 1, 0, false, false, false)
    end

    Notify('Crucificação', 'Forças arcanas te ergueram no ar numa crucificação mágica!', 'error')

    Wait(duration)
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    Notify('Crucificação', 'A cruz invisível se desfez.', 'inform')
end)

-- =========================================================================
-- 22. TELECINESE AVANÇADA (LOMAR DEV)
-- =========================================================================
local telekinesisEntity = nil
local telekinesisActive = false

local function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function GetEntityInFrontOfPlayer(maxDist)
    local ped = PlayerPedId()
    local coords = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local forward = RotationToDirection(rot)
    local target = coords + (forward * maxDist)

    local ray = StartShapeTestRay(coords.x, coords.y, coords.z, target.x, target.y, target.z, -1, ped, 0)
    local _, hit, _, _, entity = GetShapeTestResult(ray)

    if hit and DoesEntityExist(entity) and entity ~= ped then
        return entity
    end
    return nil
end

RegisterCommand('telecinese', function()
    local ped = PlayerPedId()

    if telekinesisActive and telekinesisEntity and DoesEntityExist(telekinesisEntity) then
        local camRot = GetGameplayCamRot(2)
        local forward = RotationToDirection(camRot)
        local force = Config.Telecinese.ForcaArremesso or 50.0

        RequestAnim("rcmbarry")
        TaskPlayAnim(ped, "rcmbarry", "bar_1_teleport_aln", 8.0, -8.0, 1000, 49, 0, false, false, false)
        PlaySpellSound("thunder", 0.7)

        if IsEntityAVehicle(telekinesisEntity) then
            SetVehicleForwardSpeed(telekinesisEntity, force)
            ApplyForceToEntity(telekinesisEntity, 1, forward.x * force, forward.y * force, forward.z * force + 5.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        elseif IsEntityAPed(telekinesisEntity) then
            if IsPedAPlayer(telekinesisEntity) then
                local sId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(telekinesisEntity))
                TriggerServerEvent('lumina_poderes:server:syncTelekinesisThrow', sId, forward.x * force, forward.y * force, forward.z * force + 5.0)
            else
                SetPedToRagdoll(telekinesisEntity, 4000, 4000, 0, 0, 0, 0)
                ApplyForceToEntity(telekinesisEntity, 1, forward.x * force, forward.y * force, forward.z * force + 5.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
            end
        end

        Notify('Telecinese', 'Você ARREMESSOU o alvo com a mente!', 'success')
        telekinesisActive = false
        telekinesisEntity = nil
        return
    end

    local ent = GetEntityInFrontOfPlayer(Config.Telecinese.Distancia or 25.0)
    if not ent then
        Notify('Telecinese', 'Mire em um veículo ou pessoa para erguer com a mente.', 'error')
        return
    end

    telekinesisEntity = ent
    telekinesisActive = true

    RequestAnim("rcmbarry")
    TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 8.0, -8.0, -1, 49, 0, false, false, false)
    PlaySpellSound("mental", 0.8)
    Notify('Telecinese', 'Alvo LEVITADO! Use /telecinese novamente para arremessá-lo!', 'success')

    CreateThread(function()
        local startTime = GetGameTimer()
        local maxDuration = Config.Telecinese.DuracaoSegurar or 7000

        while telekinesisActive and (GetGameTimer() - startTime) < maxDuration and DoesEntityExist(telekinesisEntity) do
            local pCoords = GetEntityCoords(PlayerPedId())
            local cRot = GetGameplayCamRot(2)
            local forward = RotationToDirection(cRot)
            local holdPos = pCoords + (forward * 8.0) + vector3(0.0, 0.0, 2.5)

            if IsEntityAVehicle(telekinesisEntity) then
                SetEntityVelocity(telekinesisEntity, 0.0, 0.0, 0.1)
                SetEntityCoords(telekinesisEntity, holdPos.x, holdPos.y, holdPos.z, false, false, false, false)
            elseif IsEntityAPed(telekinesisEntity) then
                SetEntityCoords(telekinesisEntity, holdPos.x, holdPos.y, holdPos.z, false, false, false, false)
            end

            UseParticleFxAssetNextCall("core")
            StartParticleFxNonLoopedAtCoord("ent_ray_prologue_elec_crackle", holdPos.x, holdPos.y, holdPos.z, 0.0, 0.0, 0.0, 0.6, false, false, false)
            Wait(10)
        end

        if telekinesisActive then
            telekinesisActive = false
            telekinesisEntity = nil
            ClearPedTasks(PlayerPedId())
            Notify('Telecinese', 'O controle telecinético expirou.', 'inform')
        end
    end)
end, false)

RegisterNetEvent('lumina_poderes:client:receiveTelekinesisThrow', function(forceX, forceY, forceZ)
    local ped = PlayerPedId()
    SetPedToRagdoll(ped, 4000, 4000, 0, 0, 0, 0)
    ApplyForceToEntity(ped, 1, forceX, forceY, forceZ, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.8)
    Notify('Telecinese', 'Você foi arremessado por uma força invisível!', 'error')
end)

-- =========================================================================
-- 23. ESCUDO MÍSTICO / CÚPULA PROTETORA (LOMAR DEV)
-- =========================================================================
local shieldActive = false

RegisterCommand('escudo', function()
    local ped = PlayerPedId()

    if shieldActive then
        Notify('Escudo Místico', 'O escudo já está ativado.', 'error')
        return
    end

    shieldActive = true
    PlaySpellSound("lux", 0.9)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedArmour(ped, 100)

    Notify('Escudo Místico', 'Cúpula mágica ativada! Imunidade e repelência ativas por 10s.', 'success')

    CreateThread(function()
        local duration = Config.EscudoMistico.DuracaoMs or 10000
        local startTime = GetGameTimer()

        while (GetGameTimer() - startTime) < duration and shieldActive do
            local coords = GetEntityCoords(ped)

            UseParticleFxAssetNextCall("core")
            StartParticleFxNonLoopedAtCoord("veh_respray_smoke", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.2, false, false, false)

            local closestP, dist = GetClosestPlayer()
            if closestP ~= -1 and dist <= (Config.EscudoMistico.RaioEmpurrao or 3.5) then
                local tPed = GetPlayerPed(closestP)
                local tCoords = GetEntityCoords(tPed)
                local pushDir = tCoords - coords
                SetPedToRagdoll(tPed, 2000, 2000, 0, 0, 0, 0)
                ApplyForceToEntity(tPed, 1, pushDir.x * 10.0, pushDir.y * 10.0, 3.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
            end

            Wait(250)
        end

        shieldActive = false
        SetEntityInvincible(ped, false)
        SetPedCanRagdoll(ped, true)
        PlaySpellSound("dirt", 0.6)
        Notify('Escudo Místico', 'A cúpula mística se desvaneceu.', 'inform')
    end)
end, false)

-- =========================================================================
-- 24. CLONES DE ILUSÃO / GUARDIÕES DE SOMBRA EM CÍRCULO (LOMAR DEV)
-- =========================================================================
local activeCloneGuardians = nil

local function DispelCloneGuardians()
    if activeCloneGuardians and #activeCloneGuardians > 0 then
        for _, clone in ipairs(activeCloneGuardians) do
            if DoesEntityExist(clone) and not IsPedDeadOrDying(clone, true) then
                local cCoords = GetEntityCoords(clone)
                UseParticleFxAssetNextCall("core")
                StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", cCoords.x, cCoords.y, cCoords.z, 0.0, 0.0, 0.0, 1.2, false, false, false)
                DeleteEntity(clone)
            end
        end
        activeCloneGuardians = nil
        PlaySoundFrontend(-1, "FocusOut", "HintCamSounds", true)
        Notify('Clones', 'Seus clones guardiões foram dispensados.', 'inform')
    end
end

RegisterCommand('clones', function()
    local ped = PlayerPedId()

    -- Se já tiver clones ativos, dissipa-os (modo toggle manual)
    if activeCloneGuardians and #activeCloneGuardians > 0 then
        DispelCloneGuardians()
        return
    end

    if IsPedDeadOrDying(ped, true) then
        Notify('Clones', 'Você não pode invocar clones agora.', 'error')
        return
    end

    local pCoords = GetEntityCoords(ped)
    local pHeading = GetEntityHeading(ped)

    PlaySoundFrontend(-1, "FocusIn", "HintCamSounds", true)
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do Wait(10) end

    RequestAnim("move_m@intimidation@cop@unarmed")
    RequestAnim("melee@unarmed@streamed_core")

    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", pCoords.x, pCoords.y, pCoords.z, 0.0, 0.0, 0.0, 2.2, false, false, false)

    local count = Config.ClonesSombra.Quantidade or 4
    local radius = Config.ClonesSombra.RaioCirculo or 2.4
    local clones = {}
    local netIds = {}
    local angleStep = 360.0 / count
    local hp = Config.ClonesSombra and Config.ClonesSombra.Vida or 200

    for i = 1, count do
        local angleOffset = (i - 1) * angleStep
        local rad = math.rad((pHeading + angleOffset) % 360.0)
        local spawnPos = pCoords + vector3(-math.sin(rad) * radius, math.cos(rad) * radius, 0.0)
        local cloneHeading = (pHeading + angleOffset + 180.0) % 360.0

        -- Cria ped sincronizado na rede (isNetwork = true, bScriptHostPed = true)
        local clone = ClonePed(ped, cloneHeading, true, true)
        if DoesEntityExist(clone) then
            SetEntityCoordsNoOffset(clone, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)
            SetEntityHeading(clone, cloneHeading)

            -- Registra entidade na rede para que todos os jogadores no servidor enxerguem
            SetEntityAsMissionEntity(clone, true, true)
            NetworkRegisterEntityAsNetworked(clone)
            local netId = NetworkGetNetworkIdFromEntity(clone)
            if netId and netId ~= 0 then
                SetNetworkIdExistsOnAllMachines(netId, true)
                SetNetworkIdCanMigrate(netId, true)
                NetworkSetNetworkIdDynamic(netId, true)
                table.insert(netIds, netId)
            end

            -- Clones são mortais como todo NPC do servidor
            SetEntityInvincible(clone, false)
            SetPedCanRagdoll(clone, true)
            SetPedCanRagdollFromPlayerImpact(clone, true)
            SetEntityMaxHealth(clone, hp)
            SetEntityHealth(clone, hp)
            SetPedArmour(clone, 50)
            SetBlockingOfNonTemporaryEvents(clone, true)
            SetPedCombatAttributes(clone, 46, true)
            SetPedFleeAttributes(clone, 0, false)
            SetEntityNoCollisionEntity(clone, ped, false)

            UseParticleFxAssetNextCall("core")
            StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", spawnPos.x, spawnPos.y, spawnPos.z, 0.0, 0.0, 0.0, 1.2, false, false, false)

            TaskPlayAnim(clone, "move_m@intimidation@cop@unarmed", "idle", 8.0, -8.0, -1, 49, 0.0, false, false, false)

            table.insert(clones, {
                entity = clone,
                angleOffset = angleOffset
            })
        end
    end

    -- Previne colisão entre os próprios clones
    for a = 1, #clones do
        for b = a + 1, #clones do
            if DoesEntityExist(clones[a].entity) and DoesEntityExist(clones[b].entity) then
                SetEntityNoCollisionEntity(clones[a].entity, clones[b].entity, false)
            end
        end
    end

    activeCloneGuardians = {}
    for _, c in ipairs(clones) do
        table.insert(activeCloneGuardians, c.entity)
    end

    -- Sincroniza a aparência dos clones para todos os jogadores do servidor
    if #netIds > 0 then
        TriggerServerEvent('lumina_poderes:server:syncClonesBatch', netIds)
    end

    Notify('Clones', 'Guardiões invocados! Eles seguirão você pelo mapa até morrerem ou se perderem.', 'success')


    -- Thread de escolta contínua: seguem até morrer ou se perder no servidor como todo NPC
    CreateThread(function()
        local maxLostDist = Config.ClonesSombra and Config.ClonesSombra.DistanciaPerdido or 75.0

        while activeCloneGuardians and #activeCloneGuardians > 0 do
            Wait(100)
            local currentMaster = PlayerPedId()
            local masterDead = IsPedDeadOrDying(currentMaster, true)
            local curPos = GetEntityCoords(currentMaster)
            local curHeading = GetEntityHeading(currentMaster)
            local isMasterMoving = GetEntitySpeed(currentMaster) > 0.5

            -- 1. Filtra clones vivos vs mortos vs perdidos
            local livingClones = {}
            for _, cData in ipairs(clones) do
                local clone = cData.entity
                if DoesEntityExist(clone) and not IsPedDeadOrDying(clone, true) then
                    local clonePos = GetEntityCoords(clone)
                    local distToMaster = #(clonePos - curPos)

                    -- Se o jogador correu/viajou para muito longe (> 75m) e o clone se perdeu
                    if distToMaster > maxLostDist and not masterDead then
                        -- O clone se perde no servidor como todo NPC
                        SetPedAsNoLongerNeeded(clone)
                        SetBlockingOfNonTemporaryEvents(clone, false)
                        SetPedCombatAttributes(clone, 46, false)
                        TaskWanderStandard(clone, 10.0, 10)
                    else
                        table.insert(livingClones, cData)
                    end
                end
                -- Se o clone morreu (IsPedDeadOrDying), ele NÃO é deletado; fica no chão como defunto
            end

            clones = livingClones
            activeCloneGuardians = {}
            for _, c in ipairs(clones) do
                table.insert(activeCloneGuardians, c.entity)
            end

            if #clones == 0 then
                break
            end

            -- 2. Varredura de ameaças próximas para proteção ativa
            local threatPed = nil
            local minThreatDist = 6.0
            for _, p in ipairs(GetGamePool('CPed')) do
                if DoesEntityExist(p) and p ~= currentMaster and not IsPedDeadOrDying(p, true) then
                    local isClone = false
                    for _, c in ipairs(clones) do
                        if p == c.entity then isClone = true break end
                    end
                    if not isClone then
                        local pDist = #(GetEntityCoords(p) - curPos)
                        if pDist < minThreatDist and (IsPedInCombat(p, currentMaster) or IsPedArmed(p, 7)) then
                            threatPed = p
                            minThreatDist = pDist
                        end
                    end
                end
            end

            -- 3. Atualiza posicionamento e escolta de cada clone vivo
            for _, cData in ipairs(clones) do
                local clone = cData.entity
                if DoesEntityExist(clone) and not IsPedDeadOrDying(clone, true) then
                    local rad = math.rad((curHeading + cData.angleOffset) % 360.0)
                    local targetSlot = curPos + vector3(-math.sin(rad) * radius, math.cos(rad) * radius, 0.0)
                    local clonePos = GetEntityCoords(clone)
                    local distToSlot = #(clonePos - targetSlot)
                    local distToMaster = #(clonePos - curPos)

                    if threatPed and DoesEntityExist(threatPed) and not IsPedDeadOrDying(threatPed, true) and distToMaster <= 8.0 then
                        if #(clonePos - GetEntityCoords(threatPed)) < 5.0 then
                            TaskCombatPed(clone, threatPed, 0, 16)
                            ApplyDamageToPed(threatPed, 10, false)
                        end
                    else
                        if isMasterMoving or distToSlot > 1.2 then
                            local moveSpeed = isMasterMoving and (GetEntitySpeed(currentMaster) > 4.0 and 3.5 or 2.2) or 1.8
                            TaskGoStraightToCoord(clone, targetSlot.x, targetSlot.y, targetSlot.z, moveSpeed, 300, 0.0, 0.0)
                        else
                            SetEntityHeading(clone, (curHeading + cData.angleOffset + 180.0) % 360.0)
                            if not IsEntityPlayingAnim(clone, "move_m@intimidation@cop@unarmed", "idle", 3) then
                                TaskPlayAnim(clone, "move_m@intimidation@cop@unarmed", "idle", 8.0, -8.0, -1, 49, 0.0, false, false, false)
                            end
                        end
                    end
                end
            end
        end

        activeCloneGuardians = nil
    end)
end, false)

-- =========================================================================
-- 24.1 MULTIDÃO DE CLONES ARMADOS / LEGIÃO DE SOMBRA (20 CLONES) (LOMAR DEV)
-- =========================================================================
local activeClonesMax = nil

local function DispelClonesMax()
    if activeClonesMax and #activeClonesMax > 0 then
        for _, clone in ipairs(activeClonesMax) do
            if DoesEntityExist(clone) and not IsPedDeadOrDying(clone, true) then
                local cCoords = GetEntityCoords(clone)
                UseParticleFxAssetNextCall("core")
                StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", cCoords.x, cCoords.y, cCoords.z, 0.0, 0.0, 0.0, 1.2, false, false, false)
                DeleteEntity(clone)
            end
        end
        activeClonesMax = nil
        PlaySoundFrontend(-1, "FocusOut", "HintCamSounds", true)
        Notify('Legião de Clones', 'Sua multidão de clones foi dispensada.', 'inform')
    end
end

RegisterCommand('clonesmax', function()
    local ped = PlayerPedId()

    -- Se já tiver clones ativos, dissipa-os (modo toggle manual)
    if activeClonesMax and #activeClonesMax > 0 then
        DispelClonesMax()
        return
    end

    if IsPedDeadOrDying(ped, true) then
        Notify('Legião de Clones', 'Você não pode invocar clones agora.', 'error')
        return
    end

    local pCoords = GetEntityCoords(ped)
    local pHeading = GetEntityHeading(ped)

    PlaySoundFrontend(-1, "FocusIn", "HintCamSounds", true)
    ShakeGameplayCam('JOLT_SHAKE', 0.6)

    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do Wait(10) end

    local weaponHash = GetHashKey(Config.ClonesMax and Config.ClonesMax.Arma or "WEAPON_COMBATPISTOL")
    RequestWeaponAsset(weaponHash, 31, 0)
    local wTimeout = 0
    while not HasWeaponAssetLoaded(weaponHash) and wTimeout < 100 do
        Wait(10)
        wTimeout = wTimeout + 1
    end

    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", pCoords.x, pCoords.y, pCoords.z, 0.0, 0.0, 0.0, 2.5, false, false, false)

    local radiusInner = Config.ClonesMax and Config.ClonesMax.RaioInterno or 2.6
    local radiusOuter = Config.ClonesMax and Config.ClonesMax.RaioExterno or 5.0
    local countInner = 8
    local countOuter = 12

    local slots = {}
    local stepInner = 360.0 / countInner
    for i = 1, countInner do
        table.insert(slots, {
            radius = radiusInner,
            angleOffset = (i - 1) * stepInner
        })
    end

    local stepOuter = 360.0 / countOuter
    for i = 1, countOuter do
        table.insert(slots, {
            radius = radiusOuter,
            angleOffset = ((i - 1) * stepOuter) + (stepOuter / 2.0)
        })
    end

    local clones = {}
    local netIds = {}
    local accuracy = Config.ClonesMax and Config.ClonesMax.Precisao or 75
    local maxHp = Config.ClonesMax and Config.ClonesMax.Vida or 200
    local armour = Config.ClonesMax and Config.ClonesMax.Colete or 50

    for _, slot in ipairs(slots) do
        local rad = math.rad((pHeading + slot.angleOffset) % 360.0)
        local spawnPos = pCoords + vector3(-math.sin(rad) * slot.radius, math.cos(rad) * slot.radius, 0.0)
        local cloneHeading = (pHeading + slot.angleOffset + 180.0) % 360.0

        -- Cria ped sincronizado na rede (isNetwork = true, bScriptHostPed = true)
        local clone = ClonePed(ped, cloneHeading, true, true)
        if DoesEntityExist(clone) then
            SetEntityCoordsNoOffset(clone, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)
            SetEntityHeading(clone, cloneHeading)

            -- Registra entidade na rede para que todos os jogadores no servidor enxerguem
            SetEntityAsMissionEntity(clone, true, true)
            NetworkRegisterEntityAsNetworked(clone)
            local netId = NetworkGetNetworkIdFromEntity(clone)
            if netId and netId ~= 0 then
                SetNetworkIdExistsOnAllMachines(netId, true)
                SetNetworkIdCanMigrate(netId, true)
                NetworkSetNetworkIdDynamic(netId, true)
                table.insert(netIds, netId)
            end

            -- Clones mortais com vida e dano real (morrem como qualquer NPC)
            SetEntityInvincible(clone, false)
            SetPedCanRagdoll(clone, true)
            SetPedCanRagdollFromPlayerImpact(clone, true)
            SetEntityMaxHealth(clone, maxHp)
            SetEntityHealth(clone, maxHp)
            SetPedArmour(clone, armour)
            SetBlockingOfNonTemporaryEvents(clone, true)
            SetPedCombatAttributes(clone, 46, true) -- ALWAYS_FIGHT
            SetPedCombatAttributes(clone, 0, true)  -- CAN_USE_COVER
            SetPedCombatAttributes(clone, 5, true)  -- CAN_FIGHT_ARMED_PEDS_WHEN_NOT_ARMED
            SetPedCombatAbility(clone, 2)           -- PROFESSIONAL
            SetPedCombatRange(clone, 2)             -- FAR
            SetPedAccuracy(clone, accuracy)
            SetPedFiringPattern(clone, GetHashKey("FIRING_PATTERN_BURST_FIRE_PISTOL"))
            SetEntityNoCollisionEntity(clone, ped, false)

            GiveWeaponToPed(clone, weaponHash, 9999, false, true)
            SetCurrentPedWeapon(clone, weaponHash, true)
            SetPedInfiniteAmmo(clone, true, weaponHash)
            SetPedInfiniteAmmoClip(clone, true)

            UseParticleFxAssetNextCall("core")
            StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", spawnPos.x, spawnPos.y, spawnPos.z, 0.0, 0.0, 0.0, 1.1, false, false, false)

            table.insert(clones, {
                entity = clone,
                radius = slot.radius,
                angleOffset = slot.angleOffset,
                isShooting = false
            })
        end
    end

    -- Remove colisões entre todos os clones para fluidez perfeita da multidão
    for a = 1, #clones do
        for b = a + 1, #clones do
            if DoesEntityExist(clones[a].entity) and DoesEntityExist(clones[b].entity) then
                SetEntityNoCollisionEntity(clones[a].entity, clones[b].entity, false)
            end
        end
    end

    activeClonesMax = {}
    for _, c in ipairs(clones) do
        table.insert(activeClonesMax, c.entity)
    end

    -- Sincroniza a aparência de todos os 20 clones para todos os jogadores do servidor
    if #netIds > 0 then
        TriggerServerEvent('lumina_poderes:server:syncClonesBatch', netIds)
    end

    Notify('Legião de Clones', 'Multidão de 20 clones armados invocada! Eles seguirão você pelo mapa até morrerem ou se perderem.', 'success')


    -- Thread de escolta contínua: seguem até morrer em combate ou se perderem no servidor como todo NPC
    CreateThread(function()
        local maxThreatDist = Config.ClonesMax and Config.ClonesMax.RaioDeteccaoAmeaca or 35.0
        local maxLostDist = Config.ClonesMax and Config.ClonesMax.DistanciaPerdido or 80.0

        while activeClonesMax and #activeClonesMax > 0 do
            Wait(100)
            local currentMaster = PlayerPedId()
            local masterDead = IsPedDeadOrDying(currentMaster, true)
            local curPos = GetEntityCoords(currentMaster)
            local curHeading = GetEntityHeading(currentMaster)
            local isMasterMoving = GetEntitySpeed(currentMaster) > 0.5

            -- 1. Filtra clones vivos vs mortos vs perdidos
            local livingClones = {}
            for _, cData in ipairs(clones) do
                local clone = cData.entity
                if DoesEntityExist(clone) and not IsPedDeadOrDying(clone, true) then
                    local clonePos = GetEntityCoords(clone)
                    local distToMaster = #(clonePos - curPos)

                    -- Se o jogador correu/viajou para longe (> 80m) e o clone se perdeu
                    if distToMaster > maxLostDist and not masterDead then
                        -- Libera o clone no servidor como qualquer NPC comum
                        SetPedAsNoLongerNeeded(clone)
                        SetBlockingOfNonTemporaryEvents(clone, false)
                        SetPedCombatAttributes(clone, 46, false)
                        TaskWanderStandard(clone, 10.0, 10)
                    else
                        table.insert(livingClones, cData)
                    end
                end
                -- Se o clone morreu (IsPedDeadOrDying), ele NÃO é deletado; fica estirado no chão como defunto
            end

            clones = livingClones
            activeClonesMax = {}
            for _, c in ipairs(clones) do
                table.insert(activeClonesMax, c.entity)
            end

            if #clones == 0 then
                break
            end

            -- 2. Varredura inteligente de ameaças reais
            local threatList = {}
            local playerAimingEntity = nil
            local _, targetedEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())
            if targetedEntity and DoesEntityExist(targetedEntity) and IsEntityAPed(targetedEntity) and not IsPedDeadOrDying(targetedEntity, true) then
                playerAimingEntity = targetedEntity
            end

            for _, p in ipairs(GetGamePool('CPed')) do
                if DoesEntityExist(p) and p ~= currentMaster and not IsPedDeadOrDying(p, true) then
                    local isOurClone = false
                    for _, c in ipairs(clones) do
                        if p == c.entity then isOurClone = true break end
                    end
                    if not isOurClone and activeCloneGuardians then
                        for _, cg in ipairs(activeCloneGuardians) do
                            if p == cg then isOurClone = true break end
                        end
                    end

                    if not isOurClone then
                        local pDist = #(GetEntityCoords(p) - curPos)
                        if pDist <= maxThreatDist then
                            local isThreat = false
                            if p == playerAimingEntity then
                                isThreat = true
                            elseif IsPedInCombat(p, currentMaster) then
                                isThreat = true
                            elseif IsPedShooting(p) then
                                isThreat = true
                            elseif IsPedArmed(p, 7) and pDist <= 22.0 then
                                isThreat = true
                            end

                            if isThreat then
                                table.insert(threatList, { ped = p, dist = pDist })
                            end
                        end
                    end
                end
            end

            if #threatList > 1 then
                table.sort(threatList, function(a, b) return a.dist < b.dist end)
            end

            -- 3. Disparos coordenados dos clones contra ameaças reais
            if #threatList > 0 then
                local primaryThreat = threatList[1].ped
                for idx, cData in ipairs(clones) do
                    local clone = cData.entity
                    if DoesEntityExist(clone) and not IsPedDeadOrDying(clone, true) then
                        local targetForThisClone = primaryThreat
                        if #threatList > 1 then
                            local targetIdx = ((idx - 1) % #threatList) + 1
                            targetForThisClone = threatList[targetIdx].ped
                        end

                        if DoesEntityExist(targetForThisClone) and not IsPedDeadOrDying(targetForThisClone, true) then
                            local cCoords = GetEntityCoords(clone)
                            local dToMaster = #(cCoords - curPos)

                            if dToMaster > 25.0 and not masterDead then
                                TaskGoStraightToCoord(clone, curPos.x, curPos.y, curPos.z, 3.5, 300, 0.0, 0.0)
                            else
                                if not cData.isShooting or math.random(1, 4) == 1 then
                                    TaskShootAtEntity(clone, targetForThisClone, 1500, GetHashKey("FIRING_PATTERN_BURST_FIRE_PISTOL"))
                                    cData.isShooting = true
                                end
                            end
                        end
                    end
                end
            else
                -- 4. Sem ameaças ativas: formação de multidão concêntrica escoltando o mestre
                for _, cData in ipairs(clones) do
                    local clone = cData.entity
                    if DoesEntityExist(clone) and not IsPedDeadOrDying(clone, true) then
                        if cData.isShooting then
                            ClearPedTasks(clone)
                            SetCurrentPedWeapon(clone, weaponHash, true)
                            cData.isShooting = false
                        end

                        local rad = math.rad((curHeading + cData.angleOffset) % 360.0)
                        local targetSlot = curPos + vector3(-math.sin(rad) * cData.radius, math.cos(rad) * cData.radius, 0.0)
                        local clonePos = GetEntityCoords(clone)
                        local distToSlot = #(clonePos - targetSlot)

                        if isMasterMoving or distToSlot > 1.2 then
                            local moveSpeed = isMasterMoving and (GetEntitySpeed(currentMaster) > 4.0 and 3.8 or 2.3) or 1.8
                            TaskGoStraightToCoord(clone, targetSlot.x, targetSlot.y, targetSlot.z, moveSpeed, 300, 0.0, 0.0)
                        else
                            SetEntityHeading(clone, (curHeading + cData.angleOffset + 180.0) % 360.0)
                            if GetSelectedPedWeapon(clone) ~= weaponHash then
                                SetCurrentPedWeapon(clone, weaponHash, true)
                            end
                        end
                    end
                end
            end
        end

        activeClonesMax = nil
    end)
end, false)

RegisterCommand('multidaoclones', function()
    ExecuteCommand('clonesmax')
end, false)

RegisterCommand('legiaodeclones', function()
    ExecuteCommand('clonesmax')
end, false)

RegisterCommand('exercitodeclones', function()
    ExecuteCommand('clonesmax')
end, false)

-- =========================================================================

-- 25. BURACO NEGRO / VÓRTICE GRAVITACIONAL APRIMORADO (LOMAR DEV)
-- =========================================================================
RegisterCommand('buraconegro', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped) + (GetEntityForwardVector(ped) * 12.0)

    RequestAnim("gx_s06@animation")
    if HasAnimDictLoaded("gx_s06@animation") then
        TaskPlayAnim(ped, "gx_s06@animation", "gx_s06_clip", 8.0, -8.0, 3000, 49, 0, false, false, false)
    else
        RequestAnim("rcmbarry")
        TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 8.0, -8.0, 3000, 49, 0, false, false, false)
    end

    PlaySpellSoundAtCoords("escuridao", coords, 55.0, 0.9)
    TriggerServerEvent('lumina_poderes:server:syncBlackHole', coords)
    Notify('Buraco Negro', 'Você invocou um vórtex de matéria escura e gravidade singular!', 'success')
    Wait(2500)
    ClearPedTasks(ped)
end, false)

RegisterNetEvent('lumina_poderes:client:receiveBlackHole', function(coords)
    local ped = PlayerPedId()
    local duration = Config.BuracoNegro.DuracaoMs or 7000
    local startTime = GetGameTimer()

    LoadPtfx("scr_ba_bb")
    LoadPtfx("scr_powerplay")
    LoadPtfx("core")

    PlaySpellSoundAtCoords("escuridao", coords, 55.0, 0.95)

    -- Partículas contínuas de fumaça escura abissal e distorção
    UseParticleFxAssetNextCall("scr_ba_bb")
    local smokeHandle = StartParticleFxLoopedAtCoord("scr_ba_bb_plane_smoke_trail", coords.x, coords.y, coords.z + 1.2, 0.0, 0.0, 0.0, 4.5, false, false, false, false)
    SetParticleFxLoopedColour(smokeHandle, 0.0, 0.0, 0.0, false)
    SetParticleFxLoopedAlpha(smokeHandle, 1.0)

    UseParticleFxAssetNextCall("scr_powerplay")
    local vortexHandle = StartParticleFxLoopedAtCoord("sp_powerplay_beast_appear_trails", coords.x, coords.y, coords.z + 1.2, 0.0, 0.0, 0.0, 3.5, false, false, false, false)
    SetParticleFxLoopedColour(vortexHandle, 0.1, 0.0, 0.3, false)
    SetParticleFxLoopedAlpha(vortexHandle, 1.0)

    -- Thread de renderização visual (Singularidade 3D + Anéis de Acreção em rotação rápida)
    CreateThread(function()
        local angle = 0.0
        while (GetGameTimer() - startTime) < duration do
            Wait(0)
            angle = (angle + 3.5) % 360.0
            local pulse = 2.4 + (math.sin(GetGameTimer() / 150.0) * 0.4)

            -- Singularidade central: esfera sólida preta como o vácuo absoluto
            DrawMarker(28, coords.x, coords.y, coords.z + 1.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, pulse, pulse, pulse, 5, 0, 15, 250, false, false, 2, nil, nil, false)

            -- Disco de acreção interior brilhante (roxo cósmico)
            DrawMarker(25, coords.x, coords.y, coords.z + 1.2, 0.0, 0.0, 0.0, 0.0, 0.0, angle, 5.0, 5.0, 0.4, 140, 0, 255, 200, false, false, 2, nil, nil, false)

            -- Disco de acreção exterior (azul celeste místico com rotação contrária)
            DrawMarker(25, coords.x, coords.y, coords.z + 1.2, 0.0, 0.0, 0.0, 0.0, 0.0, -angle * 1.5, 7.5, 7.5, 0.3, 30, 120, 255, 160, false, false, 2, nil, nil, false)

            -- Faíscas elétricas de matéria colidindo
            if math.random(1, 4) == 1 then
                UseParticleFxAssetNextCall("core")
                StartParticleFxNonLoopedAtCoord("ent_dst_elec_fire_sp", coords.x, coords.y, coords.z + 1.2, 0.0, 0.0, 0.0, 2.0, false, false, false)
            end
        end

        -- Limpa as partículas contínuas
        StopParticleFxLooped(smokeHandle, false)
        StopParticleFxLooped(vortexHandle, false)

        -- Colapso Supernova / Vácuo Final
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("exp_grd_flare", coords.x, coords.y, coords.z + 1.2, 0.0, 0.0, 0.0, 3.5, false, false, false)
        AddExplosion(coords.x, coords.y, coords.z + 1.2, 29, 0.0, true, false, 1.8)
        PlaySpellSoundAtCoords("thunder", coords, 55.0, 1.0)

        local pCoords = GetEntityCoords(ped)
        local endDist = #(coords - pCoords)
        if endDist <= 18.0 then
            ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 1.3)
            AnimpostfxPlay("CamPushInNeutral", 800, false)
            local shockDir = pCoords - coords
            local push = 18.0 / math.max(2.0, endDist)
            ApplyForceToEntity(ped, 1, shockDir.x * push, shockDir.y * push, 3.5, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
            SetPedToRagdoll(ped, 4000, 4000, 0, 0, 0, 0)
        end
    end)

    -- Thread de sucção física gravitacional
    CreateThread(function()
        while (GetGameTimer() - startTime) < duration do
            local pCoords = GetEntityCoords(ped)
            local dist = #(coords - pCoords)

            if dist <= (Config.BuracoNegro.RaioSugador or 22.0) and dist > 1.2 then
                local dir = coords - pCoords
                local pullForce = 22.0 / math.max(1.5, dist)
                ApplyForceToEntity(ped, 1, dir.x * pullForce, dir.y * pullForce, dir.z * pullForce + 0.6, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.25)
            end
            Wait(100)
        end
    end)
end)

-- =========================================================================
-- 26. FORMA FANTASMA / INTANGIBILIDADE (LOMAR DEV)
-- =========================================================================
local isGhostActive = false

RegisterCommand('fantasma', function()
    local ped = PlayerPedId()
    local pedId = PlayerId()

    if isGhostActive then
        Notify('Forma Fantasma', 'Você já está na forma espectral.', 'error')
        return
    end

    isGhostActive = true
    PlaySpellSound("mental", 0.8)
    SetEntityAlpha(ped, Config.FormaFantasma.TransparenciaAlpha or 110, false)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetRunSprintMultiplierForPlayer(pedId, Config.FormaFantasma.VelocidadeBonus or 1.45)

    Notify('Forma Fantasma', 'Você se tornou espectral! Invisível a radares e imune a balas por 10s.', 'success')

    CreateThread(function()
        local duration = Config.FormaFantasma.DuracaoMs or 10000
        local startTime = GetGameTimer()

        while (GetGameTimer() - startTime) < duration and isGhostActive do
            ResetPlayerStamina(pedId)
            local coords = GetEntityCoords(ped)
            UseParticleFxAssetNextCall("core")
            StartParticleFxNonLoopedAtCoord("veh_respray_smoke", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.5, false, false, false)
            Wait(200)
        end

        isGhostActive = false
        ResetEntityAlpha(ped)
        SetEntityInvincible(ped, false)
        SetPedCanRagdoll(ped, true)
        SetRunSprintMultiplierForPlayer(pedId, 1.0)
        PlaySpellSound("mental", 0.5)
        Notify('Forma Fantasma', 'Você materializou seu corpo novamente.', 'inform')
    end)
end, false)

-- =========================================================================
-- 27. CRIOMANCIA / CONGELAMENTO (LOMAR DEV)
-- =========================================================================
RegisterCommand('congelar', function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        local closestP, dist = GetClosestPlayer()
        if closestP ~= -1 and dist <= (Config.Criomancia.Distancia or 12.0) then
            targetId = GetPlayerServerId(closestP)
        end
    end

    if not targetId then
        Notify('Criomancia', 'Nenhum alvo ao alcance para congelar.', 'error')
        return
    end

    local ped = PlayerPedId()
    RequestAnim("gx_s04@animation")
    if HasAnimDictLoaded("gx_s04@animation") then
        TaskPlayAnim(ped, "gx_s04@animation", "gx_s04_clip", 8.0, -8.0, 3000, 49, 0, false, false, false)
    else
        RequestAnim("rcmbarry")
        TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 8.0, -8.0, 3000, 49, 0, false, false, false)
    end

    PlaySpellSound("water", 0.8)
    TriggerServerEvent('lumina_poderes:server:executeFreeze', targetId)
    Notify('Criomancia', 'Você disparou uma rajada gélida contra o alvo!', 'success')
    Wait(3000)
    ClearPedTasks(ped)
end, false)

RegisterNetEvent('lumina_poderes:client:receiveFreeze', function(duration)
    local ped = PlayerPedId()
    duration = duration or 8000
    PlaySpellSound("water", 0.9)

    SetTimecycleModifier("rply_vignette")
    FreezeEntityPosition(ped, true)

    local coords = GetEntityCoords(ped)
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.5, false, false, false)

    Notify('Criomancia', 'Você foi CONGELADO por magia de gelo!', 'error')

    Wait(duration)
    ClearTimecycleModifier()
    FreezeEntityPosition(ped, false)
    PlaySpellSound("dirt", 0.5)
    Notify('Criomancia', 'O gelo se quebrou e você voltou a se mover.', 'inform')
end)

-- =========================================================================
-- 28. PUXÃO SOMBRIO / CORRENTES ARCANAS (LOMAR DEV)
-- =========================================================================
RegisterCommand('puxar', function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        local closestP, dist = GetClosestPlayer()
        if closestP ~= -1 and dist <= (Config.PuxaoSombrio.Distancia or 25.0) then
            targetId = GetPlayerServerId(closestP)
        end
    end

    if not targetId then
        Notify('Puxão Sombrio', 'Nenhum alvo ao alcance para puxar.', 'error')
        return
    end

    local ped = PlayerPedId()
    local dest = GetEntityCoords(ped) + (GetEntityForwardVector(ped) * 1.8)

    RequestAnim("rcmbarry")
    TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 8.0, -8.0, 2000, 49, 0, false, false, false)
    PlaySpellSound("demon", 0.8)

    TriggerServerEvent('lumina_poderes:server:executeShadowPull', targetId, dest.x, dest.y, dest.z)
    Notify('Puxão Sombrio', 'Você arrastou a vítima até você com correntes sombrias!', 'success')
    Wait(2000)
    ClearPedTasks(ped)
end, false)

RegisterNetEvent('lumina_poderes:client:receiveShadowPull', function(destX, destY, destZ)
    local ped = PlayerPedId()
    PlaySpellSound("demon", 0.8)
    SetPedToRagdoll(ped, 3000, 3000, 0, 0, 0, 0)

    local myCoords = GetEntityCoords(ped)
    local pullDir = vector3(destX, destY, destZ) - myCoords

    ApplyForceToEntity(ped, 1, pullDir.x * 2.0, pullDir.y * 2.0, pullDir.z * 2.0 + 3.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    Notify('Puxão Sombrio', 'Correntes sombrias te puxaram pelo ar!', 'error')
end)

-- =========================================================================
-- 29. PARADA TEMPORAL (LOMAR DEV)
-- =========================================================================
RegisterCommand('parartempo', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    PlaySpellSound("earthquake", 0.9)
    AnimpostfxPlay("DeadlineNeon", 3000, false)
    TriggerServerEvent('lumina_poderes:server:syncTimeStop', coords)
    Notify('Parada Temporal', 'O TEMPO PAROU! O mundo congelou ao seu redor por 6s!', 'success')
end, false)

RegisterNetEvent('lumina_poderes:client:receiveTimeStop', function(casterSrc, coords, duration)
    local ped = PlayerPedId()
    local myCoords = GetEntityCoords(ped)
    local dist = #(coords - myCoords)

    if dist <= (Config.ParadaTemporal.Raio or 30.0) then
        if GetPlayerServerId(PlayerId()) ~= tonumber(casterSrc) then
            FreezeEntityPosition(ped, true)
            SetTimecycleModifier("rply_vignette")
            PlaySpellSound("water", 0.6)
            Notify('Parada Temporal', 'O tempo foi congelado por uma entidade arcana!', 'warning')

            Wait(duration or 6000)
            ClearTimecycleModifier()
            FreezeEntityPosition(ped, false)
            Notify('Parada Temporal', 'O fluxo do tempo retornou ao normal.', 'inform')
        end
    end
end)

-- =========================================================================
-- 30. AURA SOBRENATURAL / DESPERTAR ESPIRITUAL (LOMAR DEV)
-- =========================================================================
local isAuraActive = false
local currentAuraColor = "dourada"
local activeAuraParticles = {}

local AuraColors = {
    ["dourada"]  = { r = 255, g = 215, b = 0,   name = "Dourada (Divina)" },
    ["amarela"]  = { r = 255, g = 215, b = 0,   name = "Dourada (Divina)" },
    ["preta"]    = { r = 0,   g = 0,   b = 0,   name = "Preta (Vazio Abissal)" },
    ["sombra"]   = { r = 0,   g = 0,   b = 0,   name = "Preta (Vazio Abissal)" },
    ["azul"]     = { r = 0,   g = 160, b = 255, name = "Azul (Celestial)" },
    ["vermelha"] = { r = 255, g = 20,  b = 20,  name = "Vermelha (Fogo Carmesim)" },
    ["roxa"]     = { r = 160, g = 32,  b = 240, name = "Roxa (Etérea)" },
    ["branca"]   = { r = 255, g = 255, b = 255, name = "Branca (Luz Sagrada)" },
    ["verde"]    = { r = 0,   g = 255, b = 100, name = "Verde (Vital)" }
}

RegisterCommand('aura', function(source, args)
    local ped = PlayerPedId()
    local colorArg = args[1] and string.lower(args[1]) or nil

    if isAuraActive and (not colorArg or colorArg == currentAuraColor) then
        isAuraActive = false
        ClearTimecycleModifier()
        Notify('Aura Sobrenatural', 'Você recolheu sua aura espiritual.', 'inform')
        return
    end

    if colorArg and AuraColors[colorArg] then
        currentAuraColor = colorArg
    elseif not isAuraActive then
        currentAuraColor = "dourada"
    end

    local colorData = AuraColors[currentAuraColor] or AuraColors["dourada"]
    isAuraActive = true

    RequestAnim("rcmbarry")
    TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 8.0, -8.0, 1500, 49, 0, false, false, false)
    PlaySpellSoundAtCoords("lux", GetEntityCoords(ped), 40.0, 0.9)
    AnimpostfxPlay("DeadlineNeon", 2000, false)

    Notify('Aura Sobrenatural', ('Aura %s DESPERTADA! Velocidade e poder ampliados!'):format(colorData.name), 'success')

    -- Thread de renderização contínua das partículas no próprio jogador
    CreateThread(function()
        LoadPtfx("scr_powerplay")
        LoadPtfx("scr_ba_bb")
        LoadPtfx("core")

        local bones = { 51826, 24816, 18905, 57005, 52301, 14201, 31086 }
        local lastBroadcast = 0
        local ringAngle = 0.0

        while isAuraActive do
            local currentPed = PlayerPedId()
            local pCoords = GetEntityCoords(currentPed)
            local cfgColor = AuraColors[currentAuraColor] or AuraColors["dourada"]
            local r = cfgColor.r / 255.0
            local g = cfgColor.g / 255.0
            local b = cfgColor.b / 255.0

            -- Partículas de energia viva nos ossos principais do corpo
            for _, boneId in ipairs(bones) do
                local bIdx = GetPedBoneIndex(currentPed, boneId)
                if bIdx ~= -1 then
                    UseParticleFxAssetNextCall("scr_powerplay")
                    SetParticleFxNonLoopedColour(r, g, b)
                    SetParticleFxNonLoopedAlpha(1.0)
                    StartNetworkedParticleFxNonLoopedOnPedBone("sp_powerplay_beast_appear_trails", currentPed, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bIdx, 3.5, false, false, false)
                end
            end

            -- Se for aura de sombra / preta, adiciona fumaça densa do mri_escuridao
            if currentAuraColor == "preta" or currentAuraColor == "sombra" then
                local bIdx = GetPedBoneIndex(currentPed, 51826)
                UseParticleFxAssetNextCall("scr_ba_bb")
                SetParticleFxNonLoopedColour(0.0, 0.0, 0.0)
                SetParticleFxNonLoopedAlpha(1.0)
                StartNetworkedParticleFxNonLoopedOnPedBone("scr_ba_bb_plane_smoke_trail", currentPed, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bIdx, 5.0, false, false, false)
            end

            -- Faíscas elétricas de poder nas mãos e peito
            local chestIdx = GetPedBoneIndex(currentPed, 24816)
            if chestIdx ~= -1 then
                UseParticleFxAssetNextCall("core")
                StartNetworkedParticleFxNonLoopedOnPedBone("ent_dst_elec_fire_sp", currentPed, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, chestIdx, 1.8, false, false, false)
            end

            -- Broadcast para outros jogadores no servidor a cada 250ms
            if (GetGameTimer() - lastBroadcast) > 250 then
                lastBroadcast = GetGameTimer()
                local netId = NetworkGetNetworkIdFromEntity(currentPed)
                if netId > 0 then
                    TriggerServerEvent('lumina_poderes:server:syncAuraTick', netId, currentAuraColor)
                end
            end

            -- Buffs: super velocidade de corrida e stamina restaurada
            SetPedMoveRateOverride(currentPed, Config.Aura.VelocidadeMultiplier or 1.35)
            RestorePlayerStamina(PlayerId(), 1.0)

            Wait(180)
        end

        SetPedMoveRateOverride(PlayerPedId(), 1.0)
    end)

    -- Thread de efeitos sob os pés (anel mágico no solo que segue o jogador)
    CreateThread(function()
        local angle = 0.0
        while isAuraActive do
            Wait(0)
            angle = (angle + 3.0) % 360.0
            local currentPed = PlayerPedId()
            local pCoords = GetEntityCoords(currentPed)
            local cfgColor = AuraColors[currentAuraColor] or AuraColors["dourada"]

            DrawMarker(25, pCoords.x, pCoords.y, pCoords.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, angle, 1.8, 1.8, 0.2, cfgColor.r, cfgColor.g, cfgColor.b, 170, false, false, 2, nil, nil, false)
        end
    end)
end, false)

RegisterCommand('despertar', function(source, args)
    ExecuteCommand('aura ' .. (args[1] or 'dourada'))
end, false)

-- Recebe partículas de aura de outros jogadores
RegisterNetEvent('lumina_poderes:client:receiveAuraTick', function(pedNetId, colorName)
    if not NetworkDoesNetworkIdExist(pedNetId) then return end
    local targetPed = NetworkGetEntityFromNetworkId(pedNetId)
    if not targetPed or not DoesEntityExist(targetPed) or targetPed == PlayerPedId() then return end

    local colorData = AuraColors[colorName] or AuraColors["dourada"]
    local r = colorData.r / 255.0
    local g = colorData.g / 255.0
    local b = colorData.b / 255.0

    LoadPtfx("scr_powerplay")
    LoadPtfx("core")

    local bones = { 51826, 24816, 18905, 57005, 52301, 14201 }
    for _, boneId in ipairs(bones) do
        local bIdx = GetPedBoneIndex(targetPed, boneId)
        if bIdx ~= -1 then
            UseParticleFxAssetNextCall("scr_powerplay")
            SetParticleFxNonLoopedColour(r, g, b)
            SetParticleFxNonLoopedAlpha(1.0)
            StartNetworkedParticleFxNonLoopedOnPedBone("sp_powerplay_beast_appear_trails", targetPed, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bIdx, 3.5, false, false, false)
        end
    end

    if colorName == "preta" or colorName == "sombra" then
        LoadPtfx("scr_ba_bb")
        local bIdx = GetPedBoneIndex(targetPed, 51826)
        UseParticleFxAssetNextCall("scr_ba_bb")
        SetParticleFxNonLoopedColour(0.0, 0.0, 0.0)
        SetParticleFxNonLoopedAlpha(1.0)
        StartNetworkedParticleFxNonLoopedOnPedBone("scr_ba_bb_plane_smoke_trail", targetPed, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bIdx, 5.0, false, false, false)
    end
end)

-- =========================================================================
-- 31. CHAMAS NEGRAS / AMATERASU (LOMAR DEV)
-- =========================================================================
RegisterCommand('chamasnegras', function(source, args)
    local targetId = tonumber(args[1])
    if not targetId or targetId <= 0 then
        local closest, dist = GetClosestPlayer()
        if closest ~= -1 and dist <= (Config.ChamasNegras.Distancia or 25.0) then
            targetId = GetPlayerServerId(closest)
        else
            Notify('Chamas Negras', 'Uso: /chamasnegras [ID] ou aproxime-se de um jogador.', 'error')
            return
        end
    end

    local ped = PlayerPedId()
    RequestAnim("rcmbarry")
    TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 8.0, -8.0, 2000, 49, 0, false, false, false)
    PlaySpellSoundAtCoords("demon", GetEntityCoords(ped), 40.0, 0.9)
    AnimpostfxPlay("REDMIST", 1500, false)

    TriggerServerEvent('lumina_poderes:server:executeBlackFlames', targetId)
    Notify('Chamas Negras', 'Você lançou as Chamas Negras que consomem a alma do alvo!', 'success')
    Wait(2000)
    ClearPedTasks(ped)
end, false)

RegisterCommand('amaterasu', function(source, args)
    ExecuteCommand('chamasnegras ' .. (args[1] or ''))
end, false)

RegisterNetEvent('lumina_poderes:client:receiveBlackFlames', function(duration)
    local ped = PlayerPedId()
    duration = duration or 8000
    local startTime = GetGameTimer()

    LoadPtfx("scr_ba_bb")
    LoadPtfx("core")

    PlaySpellSoundAtCoords("flame", GetEntityCoords(ped), 40.0, 0.95)
    SetTimecycleModifier("rply_vignette")

    local particles = {}
    local bones = { 51826, 24816, 24817, 31086 }
    for _, boneId in ipairs(bones) do
        UseParticleFxAssetNextCall("scr_ba_bb")
        local handle = StartParticleFxLoopedOnEntityBone("scr_ba_bb_plane_smoke_trail", ped, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, boneId, 1.8, false, false, false)
        SetParticleFxLoopedColour(handle, 0.0, 0.0, 0.0, false)
        SetParticleFxLoopedAlpha(handle, 1.0)
        table.insert(particles, handle)
    end

    Notify('Chamas Negras', 'VOCÊ ESTÁ QUEIMANDO EM CHAMAS NEGRAS MALDITAS!', 'error')

    CreateThread(function()
        local nextTick = GetGameTimer()
        while (GetGameTimer() - startTime) < duration do
            Wait(100)
            if math.random(1, 3) == 1 then
                UseParticleFxAssetNextCall("core")
                StartParticleFxNonLoopedOnPedBone("ent_dst_elec_fire_sp", ped, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 24816, 1.5, false, false, false)
            end

            if GetGameTimer() >= nextTick then
                nextTick = GetGameTimer() + (Config.ChamasNegras.IntervaloTickMs or 1500)
                ApplyDamageToPed(ped, Config.ChamasNegras.DanoPorTick or 8, false)
                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.2)
            end
        end

        for _, handle in ipairs(particles) do
            StopParticleFxLooped(handle, false)
        end
        ClearTimecycleModifier()
        Notify('Chamas Negras', 'As chamas negras finalmente se dissiparam.', 'inform')
    end)
end)

-- =========================================================================
-- 32. LANÇA / BOLA DE ENERGIA SAGRADA (LOMAR DEV)
-- Mira com [E], animação de fogo mágico e dano massivo em todas as entidades!
-- =========================================================================
local isAimingEnergyBall = false

RegisterCommand('lanca', function()
    if isAimingEnergyBall then return end
    isAimingEnergyBall = true

    local ped = PlayerPedId()
    local dict = "rcmbarry"
    local anim = "bar_1_attack_idle_aln"

    RequestAnim(dict)
    TaskPlayAnim(ped, dict, anim, 1.0, 1.0, -1, 49, 0.0, false, false, false)

    PlaySpellSoundAtCoords("lux", GetEntityCoords(ped), 30.0, 0.7)
    Notify('Bola de Energia', 'Mire e pressione [E] ou [CLICK ESQUERDO] para disparar! [ESC] para cancelar.', 'inform')

    CreateThread(function()
        local maxDist = 120.0
        local chosenHit = nil

        while isAimingEnergyBall do
            Wait(0)
            local currentPed = PlayerPedId()
            local camCoords = GetGameplayCamCoord()
            local farCoords = GetCoordsFromCam(maxDist, camCoords)

            local ray = StartExpensiveSynchronousShapeTestLosProbe(camCoords.x, camCoords.y, camCoords.z, farCoords.x, farCoords.y, farCoords.z, -1, currentPed, 7)
            local _, hit, endCoords = GetShapeTestResult(ray)

            if hit and endCoords then
                chosenHit = endCoords
                -- Marcador 3D de mira no alvo exato (esfera e anel de impacto)
                DrawMarker(28, endCoords.x, endCoords.y, endCoords.z + 0.25, 0, 0, 0, 0, 0, 0, 0.6, 0.6, 0.6, 255, 220, 50, 220, false, false, 2, nil, nil, false)
                DrawMarker(1, endCoords.x, endCoords.y, endCoords.z - 0.3, 0, 0, 0, 0, 0, 0, 1.8, 1.8, 0.3, 255, 200, 0, 180, false, false, 2, nil, nil, false)
            else
                chosenHit = farCoords
            end

            -- Pequena bola de energia viva concentrando na mão direita do personagem
            local handPos = GetPedBoneCoords(currentPed, 60309, 0.0, 0.0, 0.0)
            DrawMarker(28, handPos.x, handPos.y, handPos.z + 0.05, 0, 0, 0, 0, 0, 0, 0.35, 0.35, 0.35, 255, 230, 80, 240, false, false, 2, nil, nil, false)

            -- Disparo com [E] (38), [ENTER] (191) ou [CLICK ESQUERDO] (24)
            if IsControlJustReleased(0, 38) or IsControlJustReleased(0, 191) or IsControlJustReleased(0, 24) then
                isAimingEnergyBall = false

                if chosenHit then
                    -- Vira o ped em direção ao alvo
                    TaskTurnPedToFaceCoord(currentPed, chosenHit.x, chosenHit.y, chosenHit.z, 300)

                    -- Animação explosiva de arremesso para frente
                    RequestAnim("weapons@projectile@grenade_str")
                    TaskPlayAnim(currentPed, "weapons@projectile@grenade_str", "throw_m_fb", 8.0, -8.0, 700, 49, 0.0, false, false, false)
                    Wait(150)

                    -- Ponto inicial elevado (sai da altura do peito/ombro para NUNCA raspar no chão!)
                    local startPos = GetPedBoneCoords(currentPed, 60309, 0.0, 0.0, 0.0) + vector3(0.0, 0.0, 0.35)

                    -- Sincroniza o disparo pelo ar com todos os jogadores
                    TriggerServerEvent('lumina_poderes:server:syncEnergyBall', startPos.x, startPos.y, startPos.z, chosenHit.x, chosenHit.y, chosenHit.z)
                    PlaySpellSoundAtCoords("lux", startPos, 45.0, 0.9)

                    Wait(500)
                    ClearPedTasks(currentPed)
                end
                break
            -- Cancelamento com [ESC] (177) ou [BACKSPACE] (73)
            elseif IsControlJustReleased(0, 177) or IsControlJustReleased(0, 73) then
                isAimingEnergyBall = false
                ClearPedTasks(currentPed)
                Notify('Bola de Energia', 'Disparo cancelado.', 'error')
                break
            end
        end
    end)
end, false)

RegisterCommand('lancadeluz', function()
    ExecuteCommand('lanca')
end, false)

RegisterCommand('boladeenergia', function()
    ExecuteCommand('lanca')
end, false)

-- Trajetória pelo ar e Detonação com DANO TOTAL em todas as entidades
RegisterNetEvent('lumina_poderes:client:receiveEnergyBall', function(startX, startY, startZ, targetX, targetY, targetZ)
    local startPos = vector3(startX, startY, startZ)
    local targetPos = vector3(targetX, targetY, targetZ)
    local totalDist = #(targetPos - startPos)
    if totalDist < 0.5 then return end

    local dir = (targetPos - startPos) / totalDist
    local speed = 55.0 -- 55 metros por segundo
    local travelTime = (totalDist / speed) * 1000.0 -- milissegundos
    local startTime = GetGameTimer()

    LoadPtfx("scr_powerplay")
    LoadPtfx("core")

    CreateThread(function()
        local currentPos = startPos
        local angle = 0.0

        while (GetGameTimer() - startTime) < travelTime do
            Wait(16)
            local elapsed = GetGameTimer() - startTime
            local progress = math.min(1.0, elapsed / travelTime)
            currentPos = startPos + (dir * (totalDist * progress))
            angle = (angle + 12.0) % 360.0

            -- Bola de Energia 3D Gigante e Radiante
            DrawMarker(28, currentPos.x, currentPos.y, currentPos.z, 0, 0, 0, 0, 0, 0, 0.95, 0.95, 0.95, 255, 235, 90, 250, false, false, 2, nil, nil, false)
            -- Anel cósmico girando ao redor da esfera
            DrawMarker(25, currentPos.x, currentPos.y, currentPos.z, 0, 0, 0, 0, 0, angle, 1.8, 1.8, 0.25, 255, 180, 40, 200, false, false, 2, nil, nil, false)

            -- Rastro de feixe contínuo de energia
            UseParticleFxAssetNextCall("scr_powerplay")
            StartParticleFxNonLoopedAtCoord("sp_powerplay_beast_appear_trails", currentPos.x, currentPos.y, currentPos.z, 0.0, 0.0, 0.0, 1.8, false, false, false)
        end

        -- =========================================================================
        -- IMPACTO EXPLOSIVO & DESTRUIÇÃO DE TODAS AS ENTIDADES
        -- =========================================================================
        local hitCoords = targetPos

        -- Áudio estrondoso de trovão e impacto místico
        PlaySpellSoundAtCoords("thunder", hitCoords, 65.0, 1.0)
        PlaySpellSoundAtCoords("lux", hitCoords, 60.0, 0.9)

        -- Explosão real que destrói cenário, quebra vidros e causa dano
        AddExplosion(hitCoords.x, hitCoords.y, hitCoords.z + 0.3, 2, 100.0, true, false, 2.5)
        AddExplosion(hitCoords.x, hitCoords.y, hitCoords.z + 0.5, 9, 80.0, true, false, 2.0)

        -- Partículas visuais de supernova sagrada
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("exp_grd_flare", hitCoords.x, hitCoords.y, hitCoords.z + 0.5, 0.0, 0.0, 0.0, 3.5, false, false, false)
        UseParticleFxAssetNextCall("scr_powerplay")
        StartParticleFxNonLoopedAtCoord("sp_powerplay_beast_appear_trails", hitCoords.x, hitCoords.y, hitCoords.z + 0.5, 0.0, 0.0, 0.0, 4.0, false, false, false)

        -- Tremor e flash de câmera para quem estiver perto
        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local myDist = #(hitCoords - myCoords)
        if myDist <= 40.0 then
            ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 1.4)
            AnimpostfxPlay("CamPushInNeutral", 700, false)
        end

        -- Onda de choque de luz se expandindo no solo
        CreateThread(function()
            local ringRadius = 0.5
            while ringRadius < 8.0 do
                Wait(0)
                ringRadius = ringRadius + 0.4
                local alpha = math.floor(240 * (1.0 - (ringRadius / 8.0)))
                DrawMarker(1, hitCoords.x, hitCoords.y, hitCoords.z - 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ringRadius * 2.0, ringRadius * 2.0, 0.4, 255, 230, 80, alpha, false, false, 2, nil, nil, false)
            end
        end)

        -- 1. DESTRUIÇÃO TOTAL DE VEÍCULOS NO RAIO (CARROS, MOTOS, CAMINHÕES)
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) then
                local vCoords = GetEntityCoords(veh)
                local vDist = #(hitCoords - vCoords)

                if vDist <= 14.0 then
                    -- Se for impacto direto (< 5.0m), o carro explode na hora!
                    if vDist <= 5.0 then
                        SetVehicleEngineHealth(veh, -4000.0)
                        ExplodeVehicle(veh, true, false)
                    else
                        -- Se for até 14 metros, destrói o motor e lataria
                        SetVehicleEngineHealth(veh, 0.0)
                        SetVehicleBodyHealth(veh, 0.0)
                        SetVehicleUndriveable(veh, true)
                    end

                    -- Força física violenta arremessando o veículo para o alto e para longe
                    local pushDir = vCoords - hitCoords
                    local len = #(pushDir)
                    local pushX = len > 0.01 and (pushDir.x / len) or 1.0
                    local pushY = len > 0.01 and (pushDir.y / len) or 0.0
                    ApplyForceToEntity(veh, 1, pushX * 45.0, pushY * 45.0, 16.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                end
            end
        end

        -- 2. DANO BRUTAL E RAGDOLL EM TODOS OS PEDS E JOGADORES NO RAIO
        for _, p in ipairs(GetGamePool('CPed')) do
            if DoesEntityExist(p) and p ~= myPed then
                local pCoords = GetEntityCoords(p)
                local pDist = #(hitCoords - pCoords)

                if pDist <= 14.0 then
                    ApplyDamageToPed(p, 180, false)
                    SetPedToRagdoll(p, 6000, 6000, 0, 0, 0, 0)

                    local pushDir = pCoords - hitCoords
                    local len = #(pushDir)
                    local pushX = len > 0.01 and (pushDir.x / len) or 1.0
                    local pushY = len > 0.01 and (pushDir.y / len) or 0.0
                    ApplyForceToEntity(p, 1, pushX * 32.0, pushY * 32.0, 14.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                end
            end
        end

        -- 3. FORÇA FÍSICA EM PROPS E OBJETOS DO CENÁRIO (CObject)
        for _, obj in ipairs(GetGamePool('CObject')) do
            if DoesEntityExist(obj) then
                local oCoords = GetEntityCoords(obj)
                local oDist = #(hitCoords - oCoords)

                if oDist <= 12.0 then
                    local pushDir = oCoords - hitCoords
                    local len = #(pushDir)
                    local pushX = len > 0.01 and (pushDir.x / len) or 1.0
                    local pushY = len > 0.01 and (pushDir.y / len) or 0.0
                    ApplyForceToEntity(obj, 1, pushX * 28.0, pushY * 28.0, 12.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                end
            end
        end
    end)
end)

-- =========================================================================
-- 33. PORTAL DIMENSIONAL (LOMAR DEV)
-- =========================================================================
local myPortalState = nil
local allActivePortals = {}
local lastTeleportTime = 0

RegisterCommand('portal', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    if not myPortalState or not myPortalState.alfa then
        myPortalState = {
            alfa = coords,
            beta = nil,
            endTime = GetGameTimer() + (Config.Portal.DuracaoMs or 120000)
        }
        TriggerServerEvent('lumina_poderes:server:setPortal', myPortalState)
        PlaySpellSoundAtCoords("lux", coords, 35.0, 0.8)
        Notify('Portal Dimensional', 'Portal Alfa (Entrada) fincado! Use /portal em outro local para abrir a Saída!', 'success')
    elseif myPortalState.alfa and not myPortalState.beta then
        myPortalState.beta = coords
        myPortalState.endTime = GetGameTimer() + (Config.Portal.DuracaoMs or 120000)
        TriggerServerEvent('lumina_poderes:server:setPortal', myPortalState)
        PlaySpellSoundAtCoords("lux", coords, 35.0, 0.8)
        Notify('Portal Dimensional', 'Fenda Aberta! Os portais Alfa e Beta estão conectados!', 'success')
    else
        myPortalState = {
            alfa = coords,
            beta = nil,
            endTime = GetGameTimer() + (Config.Portal.DuracaoMs or 120000)
        }
        TriggerServerEvent('lumina_poderes:server:setPortal', myPortalState)
        PlaySpellSoundAtCoords("lux", coords, 35.0, 0.8)
        Notify('Portal Dimensional', 'Novo Portal Alfa fincado! Use /portal no destino.', 'inform')
    end
end, false)

RegisterCommand('fecharportal', function()
    if myPortalState then
        myPortalState = nil
        TriggerServerEvent('lumina_poderes:server:closePortal')
        Notify('Portal Dimensional', 'Seus portais foram fechados e dissipados.', 'inform')
    else
        Notify('Portal Dimensional', 'Você não possui nenhum portal aberto.', 'error')
    end
end, false)

RegisterNetEvent('lumina_poderes:client:syncAllPortals', function(portalsList)
    allActivePortals = portalsList or {}
end)

CreateThread(function()
    LoadPtfx("scr_powerplay")
    local angle = 0.0

    while true do
        local hasPortals = false
        for _, pData in pairs(allActivePortals) do
            if pData and pData.alfa then
                hasPortals = true
                break
            end
        end

        if hasPortals then
            angle = (angle + 2.5) % 360.0
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)

            for srcId, pData in pairs(allActivePortals) do
                if pData.alfa then
                    local a = pData.alfa
                    DrawMarker(25, a.x, a.y, a.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, angle, 2.5, 2.5, 0.3, 0, 160, 255, 200, false, false, 2, nil, nil, false)
                    DrawMarker(1, a.x, a.y, a.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.5, 2.5, 2.5, 0, 100, 255, 60, false, false, 2, nil, nil, false)

                    if pData.beta and (GetGameTimer() - lastTeleportTime > 3500) then
                        local distA = #(pCoords - a)
                        if distA <= (Config.Portal.RaioTeleporte or 1.6) then
                            lastTeleportTime = GetGameTimer()
                            PlaySpellSoundAtCoords("escuridao", a, 30.0, 0.8)
                            AnimpostfxPlay("CamPushInNeutral", 600, false)
                            SetEntityCoords(ped, pData.beta.x, pData.beta.y, pData.beta.z + 0.2, false, false, false, false)
                            PlaySpellSoundAtCoords("lux", pData.beta, 30.0, 0.8)
                            Notify('Portal Dimensional', 'Você atravessou o Portal Alfa para Beta!', 'success')
                        end
                    end
                end

                if pData.beta then
                    local b = pData.beta
                    DrawMarker(25, b.x, b.y, b.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, -angle, 2.5, 2.5, 0.3, 200, 40, 255, 200, false, false, 2, nil, nil, false)
                    DrawMarker(1, b.x, b.y, b.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.5, 2.5, 2.5, 180, 0, 255, 60, false, false, 2, nil, nil, false)

                    if pData.alfa and (GetGameTimer() - lastTeleportTime > 3500) then
                        local distB = #(pCoords - b)
                        if distB <= (Config.Portal.RaioTeleporte or 1.6) then
                            lastTeleportTime = GetGameTimer()
                            PlaySpellSoundAtCoords("escuridao", b, 30.0, 0.8)
                            AnimpostfxPlay("CamPushInNeutral", 600, false)
                            SetEntityCoords(ped, pData.alfa.x, pData.alfa.y, pData.alfa.z + 0.2, false, false, false, false)
                            PlaySpellSoundAtCoords("lux", pData.alfa, 30.0, 0.8)
                            Notify('Portal Dimensional', 'Você atravessou o Portal Beta para Alfa!', 'success')
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- =========================================================================
-- 34. DOMO DE PROTEÇÃO ARCANA (LOMAR DEV)
-- =========================================================================
RegisterCommand('domo', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    RequestAnim("rcmbarry")
    TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 8.0, -8.0, 1500, 49, 0, false, false, false)

    PlaySpellSoundAtCoords("earthquake", coords, 45.0, 0.9)
    TriggerServerEvent('lumina_poderes:server:syncDome', coords)
    Notify('Domo de Proteção', 'Você ergueu uma barreira impenetrável de energia arcana!', 'success')
    Wait(1500)
    ClearPedTasks(ped)
end, false)

RegisterCommand('barreira', function()
    ExecuteCommand('domo')
end, false)

RegisterNetEvent('lumina_poderes:client:receiveDome', function(casterSrc, coords, duration)
    duration = duration or 12000
    local startTime = GetGameTimer()
    local domeRadius = Config.Domo.Raio or 8.5
    local isCaster = (GetPlayerServerId(PlayerId()) == tonumber(casterSrc))

    LoadPtfx("scr_powerplay")

    CreateThread(function()
        local angle = 0.0
        while (GetGameTimer() - startTime) < duration do
            Wait(0)
            angle = (angle + 1.5) % 360.0

            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, domeRadius * 2.0, domeRadius * 2.0, 4.5, 0, 180, 255, 90, false, false, 2, nil, nil, false)
            DrawMarker(25, coords.x, coords.y, coords.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, angle, domeRadius * 2.0, domeRadius * 2.0, 0.3, 100, 220, 255, 180, false, false, 2, nil, nil, false)

            if not isCaster then
                local ped = PlayerPedId()
                local pCoords = GetEntityCoords(ped)
                local dist = #(coords - pCoords)

                if dist < domeRadius then
                    local pushDir = pCoords - coords
                    local len = #(pushDir)
                    local pushX = len > 0.001 and (pushDir.x / len) or 1.0
                    local pushY = len > 0.001 and (pushDir.y / len) or 0.0
                    ApplyForceToEntity(ped, 1, pushX * (Config.Domo.ForcaRepulsao or 20.0), pushY * (Config.Domo.ForcaRepulsao or 20.0), 3.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.2)
                    Notify('Barreira Arcana', 'O domo místico te repeliu para fora!', 'error')
                end
            end
        end

        PlaySpellSoundAtCoords("lux", coords, 40.0, 0.6)
    end)
end)

-- =========================================================================
-- 35. OLHO MÍSTICO / VISÃO ESPIRITUAL (LOMAR DEV)
-- =========================================================================
local isMysticEyeActive = false

local function DrawText3DMystic(coords, text, color)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(color.r, color.g, color.b, color.a or 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

RegisterCommand('olhomistico', function()
    isMysticEyeActive = not isMysticEyeActive
    local ped = PlayerPedId()

    if isMysticEyeActive then
        PlaySpellSound("lux", 0.8)
        SetTimecycleModifier("REDMIST")
        SetTimecycleModifierStrength(0.4)
        AnimpostfxPlay("SwitchSceneMichael", 1000, false)
        Notify('Olho Místico', 'Visão Espiritual ATIVADA! Sentindo a essência vital de todos ao redor.', 'success')

        CreateThread(function()
            local startTime = GetGameTimer()
            local maxDuration = Config.OlhoMistico.DuracaoMs or 25000

            while isMysticEyeActive and (GetGameTimer() - startTime < maxDuration) do
                Wait(0)
                local pCoords = GetEntityCoords(ped)

                for _, playerId in ipairs(GetActivePlayers()) do
                    if playerId ~= PlayerId() then
                        local tPed = GetPlayerPed(playerId)
                        if DoesEntityExist(tPed) then
                            local tCoords = GetEntityCoords(tPed)
                            local dist = #(pCoords - tCoords)

                            if dist <= (Config.OlhoMistico.Raio or 45.0) then
                                local hp = math.max(0, GetEntityHealth(tPed) - 100)
                                local maxHp = math.max(1, GetEntityMaxHealth(tPed) - 100)
                                local sId = GetPlayerServerId(playerId)
                                local label = ("~b~[ID: %d]~w~ Alma: ~g~%d/%d HP"):format(sId, hp, maxHp)

                                DrawText3DMystic(vector3(tCoords.x, tCoords.y, tCoords.z + 1.1), label, { r = 255, g = 255, b = 255, a = 240 })
                                DrawLine(pCoords.x, pCoords.y, pCoords.z, tCoords.x, tCoords.y, tCoords.z, 0, 180, 255, 120)
                            end
                        end
                    end
                end
            end

            if isMysticEyeActive then
                isMysticEyeActive = false
                ClearTimecycleModifier()
                Notify('Olho Místico', 'A visão espiritual se fechou.', 'inform')
            end
        end)
    else
        ClearTimecycleModifier()
        Notify('Olho Místico', 'Visão Espiritual DESATIVADA.', 'inform')
    end
end, false)

-- =========================================================================
-- COMBOS CINEMATOGRÁFICOS DE COMBATE (LOMAR DEV)
-- =========================================================================

local isCinematicComboActive = false
local isAimingCombo = false
local currentCinematicCam = nil

-- Reset imediato, síncrono e 100% seguro (sem yield / sem Wait, pode ser chamado em qualquer lugar)
local function ResetComboState()
    SetTimeScale(1.0)
    RenderScriptCams(false, false, 0, true, true)
    DestroyAllCams(true)
    currentCinematicCam = nil
    ClearFocus()
    local ped = PlayerPedId()
    SetPedCanRagdoll(ped, true)
    SetEntityInvincible(ped, false)
    isCinematicComboActive = false
    isAimingCombo = false
end

-- Finalização suave de câmeras e desativação automática após o combo
local function FinishCinematicCamSmooth()
    SetTimeScale(1.0)
    if currentCinematicCam and DoesCamExist(currentCinematicCam) then
        RenderScriptCams(false, true, 600, true, true)
        Wait(600)
        DestroyCam(currentCinematicCam, false)
        currentCinematicCam = nil
    else
        RenderScriptCams(false, false, 0, true, true)
    end
    ResetComboState()
end

-- Busca o ped mais próximo do ponto mirado no solo/objeto usando GetGamePool('CPed')
local function GetClosestPedToCoords(coords, radius, ignorePed)
    local bestPed = nil
    local bestDist = radius or 4.5
    for _, p in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(p) and p ~= ignorePed and not IsPedDeadOrDying(p, true) then
            local pPos = GetEntityCoords(p)
            local d = #(pPos - coords)
            if d < bestDist then
                bestDist = d
                bestPed = p
            end
        end
    end
    return bestPed
end

-- =========================================================================
-- OPÇÃO A: BLINK STRIKE (COMBO TELEPORTE 3-HIT CINEMATOGRÁFICO)
-- =========================================================================

local function ExecuteBlinkStrike(targetPed)
    CreateThread(function()
        local attacker = PlayerPedId()
        if not DoesEntityExist(targetPed) or IsPedDeadOrDying(targetPed, true) then
            Notify('Combate', 'Alvo inválido!', 'error')
            ResetComboState()
            return
        end

        isCinematicComboActive = true
        SetPedCanRagdoll(attacker, false)
        SetEntityInvincible(attacker, true)

        -- Pré-carrega animações essenciais
        RequestAnim("melee@unarmed@streamed_core")
        RequestAnim("melee@large_wpn@streamed_core")
        LoadPtfx("core")
        LoadPtfx("scr_powerplay")

        local isVictimPlayer = IsPedAPlayer(targetPed)
        local victimServerId = nil
        if isVictimPlayer then
            local pIndex = NetworkGetPlayerIndexFromPed(targetPed)
            if pIndex ~= -1 then
                victimServerId = GetPlayerServerId(pIndex)
            end
        end

        local tCoords = GetEntityCoords(targetPed)
        local tHeading = GetEntityHeading(targetPed)
        local rad = math.rad(tHeading)
        local tForward = vector3(-math.sin(rad), math.cos(rad), 0.0)
        local tRight = vector3(math.cos(rad), math.sin(rad), 0.0)

        -- -------------------------------------------------------------
        -- HIT 1: PELAS COSTAS (Flash-step atrás + gancho na nuca)
        -- -------------------------------------------------------------
        local aCoords = GetEntityCoords(attacker)
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("ent_dst_elec_fire_sp", aCoords.x, aCoords.y, aCoords.z + 0.5, 0.0, 0.0, 0.0, 1.2, false, false, false)
        PlaySoundFrontend(-1, "FocusIn", "HintCamSounds", true)

        -- Posiciona atacante 0.85m atrás da vítima
        local hit1Pos = tCoords - (tForward * 0.85)
        SetEntityCoordsNoOffset(attacker, hit1Pos.x, hit1Pos.y, hit1Pos.z, false, false, false)
        SetEntityHeading(attacker, tHeading)

        -- Câmera cinematográfica over-the-shoulder
        local camPos1 = hit1Pos - (tForward * 1.6) + (tRight * 0.65) + vector3(0.0, 0.0, 0.85)
        currentCinematicCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camPos1.x, camPos1.y, camPos1.z, 0.0, 0.0, 0.0, 62.0, true, 2)
        PointCamAtCoord(currentCinematicCam, tCoords.x, tCoords.y, tCoords.z + 0.65)
        SetCamActive(currentCinematicCam, true)
        RenderScriptCams(true, true, 120, true, true)

        -- Executa golpe forte na nuca (acelerado a 2.4x)
        ClearPedTasksImmediately(attacker)
        TaskPlayAnim(attacker, "melee@unarmed@streamed_core", "heavy_punch_b", 8.0, -8.0, 600, 0, 0.0, false, false, false)
        SetEntityAnimSpeed(attacker, "melee@unarmed@streamed_core", "heavy_punch_b", 2.4)

        -- Frame de impacto imediato
        Wait(140)
        PlaySoundFrontend(-1, "BASE_JUMP_PASSED", "HUD_AWARDS", true)
        ShakeCam(currentCinematicCam, "HAND_SHAKE", 0.6)

        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("ent_dst_elec_fire_sp", tCoords.x, tCoords.y, tCoords.z + 0.65, 0.0, 0.0, 0.0, 1.2, false, false, false)

        local dmg1 = Config.BlinkStrike.DanoHit1 or 25
        if isVictimPlayer and victimServerId then
            TriggerServerEvent('lumina_poderes:server:syncComboHit', victimServerId, 'blinkstrike', 'hit1', dmg1)
        else
            ClearPedTasksImmediately(targetPed)
            TaskPlayAnim(targetPed, "melee@unarmed@streamed_core", "hit_heavy_r", 8.0, -8.0, 500, 0, 0.0, false, false, false)
            ApplyDamageToPed(targetPed, dmg1, false)
            local curHp = GetEntityHealth(targetPed)
            SetEntityHealth(targetPed, math.max(0, curHp - dmg1))
        end

        -- -------------------------------------------------------------
        -- HIT 2: DO ALTO (Teleporte Aéreo + Downward Axe Hammer Slam)
        -- -------------------------------------------------------------
        Wait(380)
        UseParticleFxAssetNextCall("scr_powerplay")
        StartParticleFxNonLoopedAtCoord("sp_powerplay_beast_appear_trails", hit1Pos.x, hit1Pos.y, hit1Pos.z + 0.5, 0.0, 0.0, 0.0, 1.0, false, false, false)

        -- Reaparece a 3.2m de altura sobre a vítima
        local hit2Pos = tCoords + vector3(0.0, 0.0, 3.2)
        SetEntityCoordsNoOffset(attacker, hit2Pos.x, hit2Pos.y, hit2Pos.z, false, false, false)
        SetEntityHeading(attacker, tHeading)

        -- Câmera em ângulo baixo olhando para cima
        local camPos2 = tCoords + (tForward * 2.2) - (tRight * 0.8) - vector3(0.0, 0.0, 0.2)
        SetCamParams(currentCinematicCam, camPos2.x, camPos2.y, camPos2.z, 0.0, 0.0, 0.0, 56.0, 180, 0, 0, 2)
        PointCamAtCoord(currentCinematicCam, tCoords.x, tCoords.y, tCoords.z + 1.8)

        -- Martelo descendente vertical pesado (2.5x)
        ClearPedTasksImmediately(attacker)
        TaskPlayAnim(attacker, "melee@large_wpn@streamed_core", "ground_attack_on_spot", 8.0, -8.0, 800, 0, 0.0, false, false, false)
        SetEntityAnimSpeed(attacker, "melee@large_wpn@streamed_core", "ground_attack_on_spot", 2.5)

        -- Descida vertiginosa ao chão
        Wait(190)
        SetEntityCoordsNoOffset(attacker, tCoords.x - (tForward.x * 0.3), tCoords.y - (tForward.y * 0.3), tCoords.z, false, false, false)

        -- Impacto pesado no solo
        PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds", true)
        ShakeCam(currentCinematicCam, "LARGE_EXPLOSION_SHAKE", 0.9)
        TriggerServerEvent('lumina_poderes:server:syncComboEffects', tCoords, 'slam_crater')

        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("exp_grd_sticky", tCoords.x, tCoords.y, tCoords.z, 0.0, 0.0, 0.0, 1.4, false, false, false)

        local dmg2 = Config.BlinkStrike.DanoHit2 or 35
        if isVictimPlayer and victimServerId then
            TriggerServerEvent('lumina_poderes:server:syncComboHit', victimServerId, 'blinkstrike', 'hit2', dmg2)
        else
            SetPedToRagdoll(targetPed, 1400, 1400, 0, false, false, false)
            ApplyDamageToPed(targetPed, dmg2, false)
            local curHp = GetEntityHealth(targetPed)
            SetEntityHealth(targetPed, math.max(0, curHp - dmg2))
        end

        -- -------------------------------------------------------------
        -- HIT 3: FINISHER FRONTAL (Slow-Mo + Soco de Impacto Devastador)
        -- -------------------------------------------------------------
        Wait(420)
        local curVictimPos = GetEntityCoords(targetPed)
        local oppHeading = (tHeading + 180.0) % 360.0
        local hit3Pos = curVictimPos + (tForward * 1.25)
        SetEntityCoordsNoOffset(attacker, hit3Pos.x, hit3Pos.y, curVictimPos.z, false, false, false)
        SetEntityHeading(attacker, oppHeading)

        -- Câmera cinematográfica lateral em close-up
        local camPos3 = curVictimPos + (tRight * 2.2) + vector3(0.0, 0.0, 0.4)
        SetCamParams(currentCinematicCam, camPos3.x, camPos3.y, camPos3.z, 0.0, 0.0, 0.0, 44.0, 180, 0, 0, 2)
        PointCamAtCoord(currentCinematicCam, curVictimPos.x, curVictimPos.y, curVictimPos.z + 0.3)

        -- Efeito Slow-Motion estilo Matrix
        if Config.BlinkStrike.SlowMotion then
            SetTimeScale(0.18)
            StartScreenEffect("DrugsDrivingIn", 350, false)
        end

        -- Preparação rápida do soco reto
        ClearPedTasksImmediately(attacker)
        TaskPlayAnim(attacker, "melee@unarmed@streamed_core", "heavy_punch_a", 8.0, -8.0, 1000, 0, 0.0, false, false, false)
        SetEntityAnimSpeed(attacker, "melee@unarmed@streamed_core", "heavy_punch_a", 2.4)

        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedOnPedBone("ent_dst_elec_fire_sp", attacker, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 60309, 1.2, false, false, false)

        Wait(170)

        -- SNAP: Retorno seco à velocidade normal com explosão de força
        SetTimeScale(1.0)
        PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds", true)
        StartScreenEffect("CamPushInNeutral", 200, false)
        ShakeCam(currentCinematicCam, "LARGE_EXPLOSION_SHAKE", 1.5)

        -- Onda de choque saindo do peito do adversário
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("exp_grd_sticky", curVictimPos.x, curVictimPos.y, curVictimPos.z + 0.5, 0.0, 0.0, 0.0, 2.0, false, false, false)
        TriggerServerEvent('lumina_poderes:server:syncComboEffects', curVictimPos, 'punch_shockwave')

        local launchDir = -tForward
        local force = Config.BlinkStrike.ForcaArremesso or 32.0
        local dmg3 = Config.BlinkStrike.DanoHit3 or 65

        if isVictimPlayer and victimServerId then
            TriggerServerEvent('lumina_poderes:server:syncComboHit', victimServerId, 'blinkstrike', 'hit3', dmg3, {
                x = launchDir.x * force,
                y = launchDir.y * force,
                z = 8.0
            })
        else
            ApplyDamageToPed(targetPed, dmg3, false)
            local curHp = GetEntityHealth(targetPed)
            SetEntityHealth(targetPed, math.max(0, curHp - dmg3))
            SetPedToRagdoll(targetPed, 5000, 5000, 0, false, false, false)
            ApplyForceToEntity(targetPed, 1, launchDir.x * 45.0, launchDir.y * 45.0, 12.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end

        PointCamAtEntity(currentCinematicCam, targetPed, 0.0, 0.0, 0.0, true)
        Wait(450)

        FinishCinematicCamSmooth()
    end)
end

-- =========================================================================
-- OPÇÃO B: AGARRÃO DEVASTADOR (CHOKE SLAM CINEMATOGRÁFICO)
-- =========================================================================

local function ExecuteChokeSlam(targetPed)
    CreateThread(function()
        local attacker = PlayerPedId()
        if not DoesEntityExist(targetPed) or IsPedDeadOrDying(targetPed, true) then
            Notify('Combate', 'Alvo inválido!', 'error')
            ResetComboState()
            return
        end

        isCinematicComboActive = true
        SetPedCanRagdoll(attacker, false)
        SetEntityInvincible(attacker, true)

        RequestAnim("rcmextreme2")
        RequestAnim("melee@large_wpn@streamed_core")
        LoadPtfx("core")
        LoadPtfx("scr_powerplay")

        local isVictimPlayer = IsPedAPlayer(targetPed)
        local victimServerId = nil
        if isVictimPlayer then
            local pIndex = NetworkGetPlayerIndexFromPed(targetPed)
            if pIndex ~= -1 then
                victimServerId = GetPlayerServerId(pIndex)
            end
        end

        local tCoords = GetEntityCoords(targetPed)
        local tHeading = GetEntityHeading(targetPed)
        local rad = math.rad(tHeading)
        local tForward = vector3(-math.sin(rad), math.cos(rad), 0.0)
        local tRight = vector3(math.cos(rad), math.sin(rad), 0.0)

        -- Câmera lateral dramática
        local camPos = tCoords + (tRight * 2.6) + (tForward * 1.4) + vector3(0.0, 0.0, 0.75)
        currentCinematicCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, 55.0, true, 2)
        PointCamAtCoord(currentCinematicCam, tCoords.x, tCoords.y, tCoords.z + 0.6)
        SetCamActive(currentCinematicCam, true)
        RenderScriptCams(true, true, 180, true, true)

        -- Dash sonoro até o adversário
        local grabPos = tCoords + (tForward * 0.75)
        UseParticleFxAssetNextCall("scr_powerplay")
        StartParticleFxNonLoopedAtCoord("sp_powerplay_beast_appear_trails", grabPos.x, grabPos.y, grabPos.z + 0.5, 0.0, 0.0, 0.0, 1.0, false, false, false)
        PlaySoundFrontend(-1, "FocusIn", "HintCamSounds", true)
        SetEntityCoordsNoOffset(attacker, grabPos.x, grabPos.y, grabPos.z, false, false, false)
        SetEntityHeading(attacker, (tHeading + 180.0) % 360.0)

        -- Agarra o pescoço da vítima no ar
        ClearPedTasksImmediately(attacker)
        TaskPlayAnim(attacker, "rcmextreme2", "loop_punching", 8.0, -8.0, 1400, 49, 0.0, false, false, false)
        SetEntityAnimSpeed(attacker, "rcmextreme2", "loop_punching", 0.5)

        if isVictimPlayer and victimServerId then
            TriggerServerEvent('lumina_poderes:server:syncComboHit', victimServerId, 'chokeslam', 'chokegrab', 0)
        else
            AttachEntityToEntity(targetPed, attacker, GetPedBoneIndex(attacker, 60309), 0.0, 0.45, 0.4, 0.0, 0.0, 180.0, false, false, false, false, 2, true)
        end

        PlaySoundFrontend(-1, "BASE_JUMP_PASSED", "HUD_AWARDS", true)

        -- Eleva a vítima mais alto com aura de energia queimando na garganta
        Wait(400)
        if not isVictimPlayer then
            AttachEntityToEntity(targetPed, attacker, GetPedBoneIndex(attacker, 60309), 0.0, 0.45, 0.65, 0.0, 0.0, 180.0, false, false, false, false, 2, true)
        end

        PointCamAtCoord(currentCinematicCam, tCoords.x, tCoords.y, tCoords.z + 1.3)

        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedOnPedBone("ent_dst_elec_fire_sp", attacker, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 60309, 1.4, false, false, false)

        Wait(800)

        -- Salto e ESMAGAMENTO violento contra o chão
        if not isVictimPlayer then
            DetachEntity(targetPed, true, true)
        end

        ClearPedTasksImmediately(attacker)
        TaskPlayAnim(attacker, "melee@large_wpn@streamed_core", "ground_attack_on_spot", 8.0, -8.0, 1000, 0, 0.0, false, false, false)
        SetEntityAnimSpeed(attacker, "melee@large_wpn@streamed_core", "ground_attack_on_spot", 2.6)

        Wait(220)

        -- Impacto cataclísmico
        PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds", true)
        ShakeCam(currentCinematicCam, "LARGE_EXPLOSION_SHAKE", 1.4)
        TriggerServerEvent('lumina_poderes:server:syncComboEffects', tCoords, 'slam_crater')

        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("exp_grd_sticky", tCoords.x, tCoords.y, tCoords.z, 0.0, 0.0, 0.0, 1.8, false, false, false)
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("ent_dst_elec_fire_sp", tCoords.x, tCoords.y, tCoords.z + 0.3, 0.0, 0.0, 0.0, 1.5, false, false, false)

        local dmg = Config.ChokeSlam.Dano or 85
        if isVictimPlayer and victimServerId then
            TriggerServerEvent('lumina_poderes:server:syncComboHit', victimServerId, 'chokeslam', 'chokeslam', dmg)
        else
            ApplyDamageToPed(targetPed, dmg, false)
            local curHp = GetEntityHealth(targetPed)
            SetEntityHealth(targetPed, math.max(0, curHp - dmg))
            SetPedToRagdoll(targetPed, 4500, 4500, 0, false, false, false)
            ApplyForceToEntity(targetPed, 1, -tForward.x * 22.0, -tForward.y * 22.0, 3.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end

        Wait(400)

        FinishCinematicCamSmooth()
    end)
end

-- =========================================================================
-- OPÇÃO C: CHUVA DE GOLPES RÁPIDOS (BARRAGE / ORA ORA)
-- =========================================================================

local function ExecuteBarrage(targetPed)
    CreateThread(function()
        local attacker = PlayerPedId()
        if not DoesEntityExist(targetPed) or IsPedDeadOrDying(targetPed, true) then
            Notify('Combate', 'Alvo inválido!', 'error')
            ResetComboState()
            return
        end

        isCinematicComboActive = true
        SetPedCanRagdoll(attacker, false)
        SetEntityInvincible(attacker, true)

        RequestAnim("rcmextreme2")
        RequestAnim("melee@unarmed@streamed_core")
        LoadPtfx("core")

        local isVictimPlayer = IsPedAPlayer(targetPed)
        local victimServerId = nil
        if isVictimPlayer then
            local pIndex = NetworkGetPlayerIndexFromPed(targetPed)
            if pIndex ~= -1 then
                victimServerId = GetPlayerServerId(pIndex)
            end
        end

        local tCoords = GetEntityCoords(targetPed)
        local tHeading = GetEntityHeading(targetPed)
        local rad = math.rad(tHeading)
        local tForward = vector3(-math.sin(rad), math.cos(rad), 0.0)
        local tRight = vector3(math.cos(rad), math.sin(rad), 0.0)

        -- Posiciona atacante 1.1m na frente do alvo
        local standPos = tCoords + (tForward * 1.1)
        SetEntityCoordsNoOffset(attacker, standPos.x, standPos.y, standPos.z, false, false, false)
        SetEntityHeading(attacker, (tHeading + 180.0) % 360.0)

        -- Câmera frontal / lateral dinâmica estilo jogo de luta
        local camPos = tCoords + (tRight * 1.8) + (tForward * 1.5) + vector3(0.0, 0.0, 0.5)
        currentCinematicCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, 52.0, true, 2)
        PointCamAtCoord(currentCinematicCam, tCoords.x, tCoords.y, tCoords.z + 0.55)
        SetCamActive(currentCinematicCam, true)
        RenderScriptCams(true, true, 180, true, true)

        -- Inicia sequência frenética de socos (2.6x de velocidade)
        ClearPedTasksImmediately(attacker)
        TaskPlayAnim(attacker, "rcmextreme2", "loop_punching", 8.0, -8.0, 2500, 49, 0.0, false, false, false)
        SetEntityAnimSpeed(attacker, "rcmextreme2", "loop_punching", 2.6)

        local totalPunches = Config.Barrage.QtdSocos or 18
        local dmgPerPunch = Config.Barrage.DanoPorSoco or 4

        for i = 1, totalPunches do
            local bone = (i % 2 == 0) and 60309 or 18905
            UseParticleFxAssetNextCall("core")
            StartParticleFxNonLoopedOnPedBone("ent_dst_elec_fire_sp", attacker, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bone, 0.8, false, false, false)

            PlaySoundFrontend(-1, "BASE_JUMP_PASSED", "HUD_AWARDS", true)
            ShakeCam(currentCinematicCam, "HAND_SHAKE", 0.35)

            if isVictimPlayer and victimServerId then
                TriggerServerEvent('lumina_poderes:server:syncComboHit', victimServerId, 'barrage', 'hit', dmgPerPunch)
            else
                TaskPlayAnim(targetPed, "melee@unarmed@streamed_core", "hit_heavy_l", 8.0, -8.0, 120, 0, 0.0, false, false, false)
                ApplyDamageToPed(targetPed, dmgPerPunch, false)
                local curHp = GetEntityHealth(targetPed)
                SetEntityHealth(targetPed, math.max(0, curHp - dmgPerPunch))
            end

            Wait(110)
        end

        -- Pausa dramática para o golpe final
        Wait(90)

        if Config.Barrage.SlowMotionFinisher then
            SetTimeScale(0.25)
        end

        -- Golpe de palmas duplas / onda de choque frontal
        ClearPedTasksImmediately(attacker)
        TaskPlayAnim(attacker, "melee@unarmed@streamed_core", "heavy_punch_a", 8.0, -8.0, 800, 0, 0.0, false, false, false)
        SetEntityAnimSpeed(attacker, "melee@unarmed@streamed_core", "heavy_punch_a", 2.6)

        Wait(160)

        SetTimeScale(1.0)
        PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds", true)
        ShakeCam(currentCinematicCam, "LARGE_EXPLOSION_SHAKE", 1.3)

        -- Onda de choque no peito
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedAtCoord("exp_grd_sticky", tCoords.x, tCoords.y, tCoords.z + 0.6, 0.0, 0.0, 0.0, 1.8, false, false, false)
        TriggerServerEvent('lumina_poderes:server:syncComboEffects', tCoords, 'punch_shockwave')

        local launchDir = -tForward
        local finDmg = Config.Barrage.DanoFinisher or 55
        local finForce = Config.Barrage.ForcaArremesso or 25.0

        if isVictimPlayer and victimServerId then
            TriggerServerEvent('lumina_poderes:server:syncComboHit', victimServerId, 'barrage', 'finish', finDmg, {
                x = launchDir.x * finForce,
                y = launchDir.y * finForce,
                z = 6.0
            })
        else
            ApplyDamageToPed(targetPed, finDmg, false)
            local curHp = GetEntityHealth(targetPed)
            SetEntityHealth(targetPed, math.max(0, curHp - finDmg))
            SetPedToRagdoll(targetPed, 4500, 4500, 0, false, false, false)
            ApplyForceToEntity(targetPed, 1, launchDir.x * 32.0, launchDir.y * 32.0, 8.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end

        Wait(400)

        FinishCinematicCamSmooth()
    end)
end

-- =========================================================================
-- OPÇÃO D: COMBO EM ÁREA / MASSACRE MULTI-ALVO (LOMAR DEV)
-- =========================================================================

local function ExecuteComboArea(victimList, centerCoords)
    CreateThread(function()
        local attacker = PlayerPedId()
        if not victimList or #victimList == 0 then
            Notify('Combo em Área', 'Nenhum alvo na área!', 'error')
            ResetComboState()
            return
        end

        isCinematicComboActive = true
        SetPedCanRagdoll(attacker, false)
        SetEntityInvincible(attacker, true)

        -- Pré-carrega animações e efeitos
        RequestAnim("melee@unarmed@streamed_core")
        RequestAnim("melee@large_wpn@streamed_core")
        RequestAnim("rcmextreme2")
        LoadPtfx("core")
        LoadPtfx("scr_powerplay")

        local totalVictims = #victimList
        local elevatedThreshold = Config.ComboArea.CameraElevadaIndex or 5
        local isCameraElevated = false

        -- Inicializa a câmera cinematográfica focando a área
        local initCamPos = centerCoords + vector3(0.0, -9.0, 4.5)
        currentCinematicCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", initCamPos.x, initCamPos.y, initCamPos.z, 0.0, 0.0, 0.0, 60.0, true, 2)
        PointCamAtCoord(currentCinematicCam, centerCoords.x, centerCoords.y, centerCoords.z + 0.8)
        SetCamActive(currentCinematicCam, true)
        RenderScriptCams(true, true, 180, true, true)

        local dmg = Config.ComboArea.DanoPorAlvo or 70

        for idx, targetPed in ipairs(victimList) do
            if DoesEntityExist(targetPed) and not IsPedDeadOrDying(targetPed, true) then
                local tCoords = GetEntityCoords(targetPed)
                local tHeading = GetEntityHeading(targetPed)
                local rad = math.rad(tHeading)
                local tForward = vector3(-math.sin(rad), math.cos(rad), 0.0)
                local tRight = vector3(math.cos(rad), math.sin(rad), 0.0)

                local isVictimPlayer = IsPedAPlayer(targetPed)
                local victimServerId = nil
                if isVictimPlayer then
                    local pIndex = NetworkGetPlayerIndexFromPed(targetPed)
                    if pIndex ~= -1 then
                        victimServerId = GetPlayerServerId(pIndex)
                    end
                end

                -- Gestão da câmera: close-up dinâmico até a 4ª vítima, depois visão aérea elevada
                if idx < elevatedThreshold then
                    -- Câmera de corte rápido próxima
                    local closeCam = tCoords + (tRight * 2.2) - (tForward * 1.5) + vector3(0.0, 0.0, 0.7)
                    SetCamParams(currentCinematicCam, closeCam.x, closeCam.y, closeCam.z, 0.0, 0.0, 0.0, 55.0, 120, 0, 0, 2)
                    PointCamAtCoord(currentCinematicCam, tCoords.x, tCoords.y, tCoords.z + 0.5)
                else
                    -- A partir da 5ª vítima: eleva a câmera para o céu (visão panorâmica de massacre)
                    if not isCameraElevated then
                        isCameraElevated = true
                        local highCamPos = centerCoords + vector3(0.0, -14.0, 14.0)
                        SetCamParams(currentCinematicCam, highCamPos.x, highCamPos.y, highCamPos.z, -45.0, 0.0, 0.0, 65.0, 400, 0, 0, 2)
                        PointCamAtCoord(currentCinematicCam, centerCoords.x, centerCoords.y, centerCoords.z + 0.5)
                    end
                end

                -- Rastro elétrico e som de teleporte
                UseParticleFxAssetNextCall("scr_powerplay")
                StartParticleFxNonLoopedAtCoord("sp_powerplay_beast_appear_trails", tCoords.x, tCoords.y, tCoords.z + 0.4, 0.0, 0.0, 0.0, 1.0, false, false, false)
                PlaySoundFrontend(-1, "FocusIn", "HintCamSounds", true)

                local isFinalVictim = (idx == totalVictims)

                if isFinalVictim then
                    -- ---------------------------------------------------------
                    -- GOLPE FINAL CLIMÁTICO (Slow-Mo + Super Impacto no Solo)
                    -- ---------------------------------------------------------
                    local hitFinalPos = tCoords + vector3(0.0, 0.0, 3.2)
                    SetEntityCoordsNoOffset(attacker, hitFinalPos.x, hitFinalPos.y, hitFinalPos.z, false, false, false)
                    SetEntityHeading(attacker, tHeading)

                    ClearPedTasksImmediately(attacker)
                    TaskPlayAnim(attacker, "melee@large_wpn@streamed_core", "ground_attack_on_spot", 8.0, -8.0, 800, 0, 0.0, false, false, false)
                    SetEntityAnimSpeed(attacker, "melee@large_wpn@streamed_core", "ground_attack_on_spot", 2.6)

                    Wait(140)
                    SetEntityCoordsNoOffset(attacker, tCoords.x - (tForward.x * 0.3), tCoords.y - (tForward.y * 0.3), tCoords.z, false, false, false)

                    -- Slow motion de impacto
                    SetTimeScale(0.2)
                    Wait(80)
                    SetTimeScale(1.0)

                    PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds", true)
                    ShakeCam(currentCinematicCam, "LARGE_EXPLOSION_SHAKE", 1.5)
                    StartScreenEffect("CamPushInNeutral", 200, false)

                    UseParticleFxAssetNextCall("core")
                    StartParticleFxNonLoopedAtCoord("exp_grd_sticky", tCoords.x, tCoords.y, tCoords.z, 0.0, 0.0, 0.0, 2.0, false, false, false)
                    TriggerServerEvent('lumina_poderes:server:syncComboEffects', tCoords, 'slam_crater')

                    if isVictimPlayer and victimServerId then
                        TriggerServerEvent('lumina_poderes:server:syncComboHit', victimServerId, 'comboarea', 'hit', dmg + 30, {
                            x = -tForward.x * 40.0,
                            y = -tForward.y * 40.0,
                            z = 10.0
                        })
                    else
                        ApplyDamageToPed(targetPed, dmg + 30, false)
                        local curHp = GetEntityHealth(targetPed)
                        SetEntityHealth(targetPed, math.max(0, curHp - (dmg + 30)))
                        SetPedToRagdoll(targetPed, 5000, 5000, 0, false, false, false)
                        ApplyForceToEntity(targetPed, 1, -tForward.x * 40.0, -tForward.y * 40.0, 10.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                    end

                    Wait(350)
                else
                    -- ---------------------------------------------------------
                    -- GOLPES ALTERNADOS (Blink Punch, Axe Hammer, Micro-Barrage, Choke Throw)
                    -- ---------------------------------------------------------
                    local pattern = (idx % 4)

                    if pattern == 1 then
                        -- Blitz Hook pelas Costas
                        local strikePos = tCoords - (tForward * 0.85)
                        SetEntityCoordsNoOffset(attacker, strikePos.x, strikePos.y, strikePos.z, false, false, false)
                        SetEntityHeading(attacker, tHeading)

                        ClearPedTasksImmediately(attacker)
                        TaskPlayAnim(attacker, "melee@unarmed@streamed_core", "heavy_punch_b", 8.0, -8.0, 400, 0, 0.0, false, false, false)
                        SetEntityAnimSpeed(attacker, "melee@unarmed@streamed_core", "heavy_punch_b", 2.8)

                        Wait(90)
                        PlaySoundFrontend(-1, "BASE_JUMP_PASSED", "HUD_AWARDS", true)
                        ShakeCam(currentCinematicCam, "HAND_SHAKE", 0.4)

                        UseParticleFxAssetNextCall("core")
                        StartParticleFxNonLoopedAtCoord("ent_dst_elec_fire_sp", tCoords.x, tCoords.y, tCoords.z + 0.6, 0.0, 0.0, 0.0, 1.0, false, false, false)

                        if isVictimPlayer and victimServerId then
                            TriggerServerEvent('lumina_poderes:server:syncComboHit', victimServerId, 'comboarea', 'hit', dmg, {
                                x = -tForward.x * 28.0,
                                y = -tForward.y * 28.0,
                                z = 6.0
                            })
                        else
                            ApplyDamageToPed(targetPed, dmg, false)
                            local curHp = GetEntityHealth(targetPed)
                            SetEntityHealth(targetPed, math.max(0, curHp - dmg))
                            SetPedToRagdoll(targetPed, 4000, 4000, 0, false, false, false)
                            ApplyForceToEntity(targetPed, 1, -tForward.x * 28.0, -tForward.y * 28.0, 6.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                        end
                        Wait(140)

                    elseif pattern == 2 then
                        -- Martelo do Alto
                        local strikePos = tCoords + vector3(0.0, 0.0, 2.6)
                        SetEntityCoordsNoOffset(attacker, strikePos.x, strikePos.y, strikePos.z, false, false, false)
                        SetEntityHeading(attacker, tHeading)

                        ClearPedTasksImmediately(attacker)
                        TaskPlayAnim(attacker, "melee@large_wpn@streamed_core", "ground_attack_on_spot", 8.0, -8.0, 500, 0, 0.0, false, false, false)
                        SetEntityAnimSpeed(attacker, "melee@large_wpn@streamed_core", "ground_attack_on_spot", 2.8)

                        Wait(110)
                        SetEntityCoordsNoOffset(attacker, tCoords.x - (tForward.x * 0.3), tCoords.y - (tForward.y * 0.3), tCoords.z, false, false, false)

                        PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds", true)
                        ShakeCam(currentCinematicCam, "LARGE_EXPLOSION_SHAKE", 0.6)

                        UseParticleFxAssetNextCall("core")
                        StartParticleFxNonLoopedAtCoord("exp_grd_sticky", tCoords.x, tCoords.y, tCoords.z, 0.0, 0.0, 0.0, 1.2, false, false, false)

                        if isVictimPlayer and victimServerId then
                            TriggerServerEvent('lumina_poderes:server:syncComboHit', victimServerId, 'comboarea', 'hit', dmg, {
                                x = tForward.x * 12.0,
                                y = tForward.y * 12.0,
                                z = -6.0
                            })
                        else
                            ApplyDamageToPed(targetPed, dmg, false)
                            local curHp = GetEntityHealth(targetPed)
                            SetEntityHealth(targetPed, math.max(0, curHp - dmg))
                            SetPedToRagdoll(targetPed, 4000, 4000, 0, false, false, false)
                            ApplyForceToEntity(targetPed, 1, tForward.x * 12.0, tForward.y * 12.0, -6.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                        end
                        Wait(150)

                    elseif pattern == 3 then
                        -- Micro Barrage Frontal de 4 Socos Rápidos + Impulso
                        local strikePos = tCoords + (tForward * 1.05)
                        SetEntityCoordsNoOffset(attacker, strikePos.x, strikePos.y, strikePos.z, false, false, false)
                        SetEntityHeading(attacker, (tHeading + 180.0) % 360.0)

                        ClearPedTasksImmediately(attacker)
                        TaskPlayAnim(attacker, "rcmextreme2", "loop_punching", 8.0, -8.0, 600, 49, 0.0, false, false, false)
                        SetEntityAnimSpeed(attacker, "rcmextreme2", "loop_punching", 3.0)

                        PlaySoundFrontend(-1, "BASE_JUMP_PASSED", "HUD_AWARDS", true)
                        Wait(100)

                        -- Soco de finalização
                        ClearPedTasksImmediately(attacker)
                        TaskPlayAnim(attacker, "melee@unarmed@streamed_core", "heavy_punch_a", 8.0, -8.0, 400, 0, 0.0, false, false, false)
                        SetEntityAnimSpeed(attacker, "melee@unarmed@streamed_core", "heavy_punch_a", 2.6)

                        PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds", true)
                        ShakeCam(currentCinematicCam, "HAND_SHAKE", 0.5)

                        UseParticleFxAssetNextCall("core")
                        StartParticleFxNonLoopedAtCoord("exp_grd_sticky", tCoords.x, tCoords.y, tCoords.z + 0.5, 0.0, 0.0, 0.0, 1.2, false, false, false)

                        if isVictimPlayer and victimServerId then
                            TriggerServerEvent('lumina_poderes:server:syncComboHit', victimServerId, 'comboarea', 'hit', dmg, {
                                x = -tForward.x * 32.0,
                                y = -tForward.y * 32.0,
                                z = 7.0
                            })
                        else
                            ApplyDamageToPed(targetPed, dmg, false)
                            local curHp = GetEntityHealth(targetPed)
                            SetEntityHealth(targetPed, math.max(0, curHp - dmg))
                            SetPedToRagdoll(targetPed, 4500, 4500, 0, false, false, false)
                            ApplyForceToEntity(targetPed, 1, -tForward.x * 32.0, -tForward.y * 32.0, 7.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                        end
                        Wait(160)

                    else
                        -- Arremesso de Pescoço Violento
                        local strikePos = tCoords + (tForward * 0.75)
                        SetEntityCoordsNoOffset(attacker, strikePos.x, strikePos.y, strikePos.z, false, false, false)
                        SetEntityHeading(attacker, (tHeading + 180.0) % 360.0)

                        ClearPedTasksImmediately(attacker)
                        TaskPlayAnim(attacker, "melee@large_wpn@streamed_core", "ground_attack_on_spot", 8.0, -8.0, 500, 0, 0.0, false, false, false)
                        SetEntityAnimSpeed(attacker, "melee@large_wpn@streamed_core", "ground_attack_on_spot", 2.8)

                        PlaySoundFrontend(-1, "BASE_JUMP_PASSED", "HUD_AWARDS", true)
                        ShakeCam(currentCinematicCam, "HAND_SHAKE", 0.4)

                        UseParticleFxAssetNextCall("core")
                        StartParticleFxNonLoopedAtCoord("ent_dst_elec_fire_sp", tCoords.x, tCoords.y, tCoords.z + 0.4, 0.0, 0.0, 0.0, 1.2, false, false, false)

                        if isVictimPlayer and victimServerId then
                            TriggerServerEvent('lumina_poderes:server:syncComboHit', victimServerId, 'comboarea', 'hit', dmg, {
                                x = -tForward.x * 26.0,
                                y = -tForward.y * 26.0,
                                z = 5.0
                            })
                        else
                            ApplyDamageToPed(targetPed, dmg, false)
                            local curHp = GetEntityHealth(targetPed)
                            SetEntityHealth(targetPed, math.max(0, curHp - dmg))
                            SetPedToRagdoll(targetPed, 4000, 4000, 0, false, false, false)
                            ApplyForceToEntity(targetPed, 1, -tForward.x * 26.0, -tForward.y * 26.0, 5.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                        end
                        Wait(140)
                    end
                end
            end
        end

        -- Pausa no ar observando todos os corpos no chão
        Wait(400)

        FinishCinematicCamSmooth()
    end)
end

-- =========================================================================
-- SISTEMA DE MIRA INDIVIDUAL (RAYCAST TOTAL + MARCADOR 3D)
-- =========================================================================

local function StartComboAiming(comboType)
    ResetComboState()

    local ped = PlayerPedId()
    if IsPedDeadOrDying(ped, true) or IsPedInAnyVehicle(ped, true) then
        Notify('Combate', 'Você não pode usar isso agora.', 'error')
        return
    end

    isAimingCombo = true

    local comboNames = {
        blinkstrike = 'Blink Strike',
        chokeslam = 'Agarrão Devastador',
        barrage = 'Chuva de Golpes'
    }
    local name = comboNames[comboType] or 'Combo'

    RequestAnim("rcmbarry")
    TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 1.0, 1.0, -1, 49, 0.0, false, false, false)

    Notify(name, 'Mire no adversário e pressione [E], [ENTER] ou [CLICK] para desferir! [ESC] cancela.', 'inform')

    CreateThread(function()
        local maxDist = 45.0
        local startTime = GetGameTimer()

        while isAimingCombo do
            Wait(0)
            local currentPed = PlayerPedId()

            DisableControlAction(0, 200, true) -- ESC (Pause Menu)
            DisableControlAction(0, 199, true) -- Pause
            DisableControlAction(0, 322, true) -- ESC / Cancel
            DisableControlAction(0, 177, true) -- Backspace
            DisableControlAction(0, 202, true) -- Frontend Cancel

            local camCoords = GetGameplayCamCoord()
            local farCoords = GetCoordsFromCam(maxDist, camCoords)

            local ray = StartExpensiveSynchronousShapeTestLosProbe(camCoords.x, camCoords.y, camCoords.z, farCoords.x, farCoords.y, farCoords.z, -1, currentPed, 7)
            local _, hit, endCoords, _, hitEntity = GetShapeTestResult(ray)

            local chosenHit = (hit and endCoords) and endCoords or farCoords
            local detectedPed = nil

            if hit and endCoords then
                if hitEntity and DoesEntityExist(hitEntity) and IsEntityAPed(hitEntity) and hitEntity ~= currentPed and not IsPedDeadOrDying(hitEntity, true) then
                    detectedPed = hitEntity
                else
                    detectedPed = GetClosestPedToCoords(endCoords, 4.5, currentPed)
                end

                if detectedPed and DoesEntityExist(detectedPed) then
                    local tPos = GetEntityCoords(detectedPed)
                    DrawMarker(28, tPos.x, tPos.y, tPos.z + 0.95, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.5, 255, 30, 30, 230, false, false, 2, nil, nil, false)
                    DrawMarker(1, tPos.x, tPos.y, tPos.z - 0.95, 0, 0, 0, 0, 0, 0, 1.7, 1.7, 0.35, 255, 50, 50, 200, false, false, 2, nil, nil, false)
                else
                    DrawMarker(28, endCoords.x, endCoords.y, endCoords.z + 0.25, 0, 0, 0, 0, 0, 0, 0.55, 0.55, 0.55, 255, 210, 50, 220, false, false, 2, nil, nil, false)
                    DrawMarker(1, endCoords.x, endCoords.y, endCoords.z - 0.3, 0, 0, 0, 0, 0, 0, 1.8, 1.8, 0.3, 255, 190, 0, 170, false, false, 2, nil, nil, false)
                end
            end

            local canTrigger = (GetGameTimer() - startTime) > 250

            if canTrigger and (IsControlJustReleased(0, 38) or IsControlJustReleased(0, 191) or IsControlJustReleased(0, 24) or IsDisabledControlJustReleased(0, 24)) then
                isAimingCombo = false
                ClearPedTasks(currentPed)

                if detectedPed and DoesEntityExist(detectedPed) and not IsPedDeadOrDying(detectedPed, true) then
                    if comboType == 'blinkstrike' then
                        ExecuteBlinkStrike(detectedPed)
                    elseif comboType == 'chokeslam' then
                        ExecuteChokeSlam(detectedPed)
                    elseif comboType == 'barrage' then
                        ExecuteBarrage(detectedPed)
                    end
                else
                    Notify('Combate', 'Nenhum adversário no local mirado! Aponte a mira para um NPC ou jogador.', 'error')
                    ResetComboState()
                end
                break

            elseif IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 322) or IsDisabledControlJustReleased(0, 177)
                or IsDisabledControlJustReleased(0, 199) or IsDisabledControlJustReleased(0, 202)
                or IsControlJustReleased(0, 177) or IsControlJustReleased(0, 200) or IsControlJustReleased(0, 322) or IsControlJustReleased(0, 73) then
                isAimingCombo = false
                ClearPedTasks(currentPed)
                ResetComboState()
                Notify('Combate', 'Mira cancelada.', 'error')
                break
            end
        end
    end)
end

-- =========================================================================
-- SISTEMA DE MIRA EM ÁREA (MASSACRE MULTI-ALVO ATÉ 20 ENTIDADES)
-- =========================================================================

local function StartComboAreaAiming()
    ResetComboState()

    local ped = PlayerPedId()
    if IsPedDeadOrDying(ped, true) or IsPedInAnyVehicle(ped, true) then
        Notify('Combo em Área', 'Você não pode usar isso agora.', 'error')
        return
    end

    isAimingCombo = true

    RequestAnim("rcmbarry")
    TaskPlayAnim(ped, "rcmbarry", "bar_1_attack_idle_aln", 1.0, 1.0, -1, 49, 0.0, false, false, false)

    Notify('Massacre em Área', 'Mire na área dos inimigos e pressione [E], [ENTER] ou [CLICK] para massacrar! [ESC] cancela.', 'inform')

    CreateThread(function()
        local maxDist = Config.ComboArea.DistanciaMira or 45.0
        local areaRadius = Config.ComboArea.RaioArea or 18.0
        local maxVictims = Config.ComboArea.LimiteEntidades or 20
        local startTime = GetGameTimer()

        while isAimingCombo do
            Wait(0)
            local currentPed = PlayerPedId()

            DisableControlAction(0, 200, true) -- ESC (Pause Menu)
            DisableControlAction(0, 199, true) -- Pause
            DisableControlAction(0, 322, true) -- ESC / Cancel
            DisableControlAction(0, 177, true) -- Backspace
            DisableControlAction(0, 202, true) -- Frontend Cancel

            local camCoords = GetGameplayCamCoord()
            local farCoords = GetCoordsFromCam(maxDist, camCoords)

            local ray = StartExpensiveSynchronousShapeTestLosProbe(camCoords.x, camCoords.y, camCoords.z, farCoords.x, farCoords.y, farCoords.z, -1, currentPed, 7)
            local _, hit, endCoords = GetShapeTestResult(ray)

            local chosenCenter = (hit and endCoords) and endCoords or farCoords
            local victimList = {}

            if hit and endCoords then
                -- Renderiza o grande perímetro de área no solo
                DrawMarker(1, endCoords.x, endCoords.y, endCoords.z - 0.35, 0, 0, 0, 0, 0, 0, areaRadius * 2.0, areaRadius * 2.0, 0.45, 255, 30, 30, 160, false, false, 2, nil, nil, false)
                DrawMarker(28, endCoords.x, endCoords.y, endCoords.z + 0.35, 0, 0, 0, 0, 0, 0, 0.8, 0.8, 0.8, 255, 50, 50, 220, false, false, 2, nil, nil, false)

                -- Mapeia todas as entidades dentro da área demarcada
                for _, p in ipairs(GetGamePool('CPed')) do
                    if DoesEntityExist(p) and p ~= currentPed and not IsPedDeadOrDying(p, true) then
                        local pPos = GetEntityCoords(p)
                        local dist = #(pPos - endCoords)
                        if dist <= areaRadius then
                            table.insert(victimList, p)
                            -- Marca cada vítima travada com uma esfera vermelha sobre a cabeça
                            DrawMarker(28, pPos.x, pPos.y, pPos.z + 0.95, 0, 0, 0, 0, 0, 0, 0.4, 0.4, 0.4, 255, 0, 0, 220, false, false, 2, nil, nil, false)
                            if #victimList >= maxVictims then
                                break
                            end
                        end
                    end
                end
            end

            local canTrigger = (GetGameTimer() - startTime) > 250

            -- Disparo do Massacre em Área
            if canTrigger and (IsControlJustReleased(0, 38) or IsControlJustReleased(0, 191) or IsControlJustReleased(0, 24) or IsDisabledControlJustReleased(0, 24)) then
                isAimingCombo = false
                ClearPedTasks(currentPed)

                if #victimList > 0 then
                    ExecuteComboArea(victimList, chosenCenter)
                else
                    Notify('Combo em Área', 'Nenhum alvo detectado dentro do raio de massacre demarcado!', 'error')
                    ResetComboState()
                end
                break

            -- Cancelamento
            elseif IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 322) or IsDisabledControlJustReleased(0, 177)
                or IsDisabledControlJustReleased(0, 199) or IsDisabledControlJustReleased(0, 202)
                or IsControlJustReleased(0, 177) or IsControlJustReleased(0, 200) or IsControlJustReleased(0, 322) or IsControlJustReleased(0, 73) then
                isAimingCombo = false
                ClearPedTasks(currentPed)
                ResetComboState()
                Notify('Combo em Área', 'Mira cancelada.', 'error')
                break
            end
        end
    end)
end

-- =========================================================================
-- REGISTRO DOS COMANDOS
-- =========================================================================

-- Opção A: Blink Strike
RegisterCommand('blinkstrike', function()
    StartComboAiming('blinkstrike')
end, false)

RegisterCommand('comboteleporte', function()
    StartComboAiming('blinkstrike')
end, false)

-- Opção B: Agarrão Devastador / Choke Slam
RegisterCommand('chokeslam', function()
    StartComboAiming('chokeslam')
end, false)

RegisterCommand('agarrardevastador', function()
    StartComboAiming('chokeslam')
end, false)

-- Opção C: Chuva de Golpes Rápidos / Barrage
RegisterCommand('barrage', function()
    StartComboAiming('barrage')
end, false)

RegisterCommand('chuvadegolpes', function()
    StartComboAiming('barrage')
end, false)

-- Opção D: Combo em Área / Massacre Múltiplo (até 20 alvos)
RegisterCommand('comboarea', function()
    StartComboAreaAiming()
end, false)

RegisterCommand('massacre', function()
    StartComboAreaAiming()
end, false)

RegisterCommand('combomultiplo', function()
    StartComboAreaAiming()
end, false)

-- =========================================================================
-- SINCRONIZAÇÃO EM REDE: VÍTIMA E ESPECTADORES
-- =========================================================================

RegisterNetEvent('lumina_poderes:client:onComboHitVictim', function(comboType, stage, damage, forceData, attackerSrc)
    local ped = PlayerPedId()

    if damage and damage > 0 then
        ApplyDamageToPed(ped, damage, false)
    end

    if comboType == 'blinkstrike' then
        if stage == 'hit1' then
            RequestAnim("melee@unarmed@streamed_core")
            TaskPlayAnim(ped, "melee@unarmed@streamed_core", "hit_heavy_r", 8.0, -8.0, 500, 0, 0.0, false, false, false)
            ShakeGameplayCam('JOLT_SHAKE', 1.0)
        elseif stage == 'hit2' then
            SetPedToRagdoll(ped, 1200, 1200, 0, false, false, false)
            ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 1.2)
        elseif stage == 'hit3' then
            ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 2.0)
            local fx = forceData and forceData.x or 0.0
            local fy = forceData and forceData.y or 0.0
            local fz = forceData and forceData.z or 7.0
            SetPedToRagdoll(ped, 5000, 5000, 0, false, false, false)
            ApplyForceToEntity(ped, 1, fx, fy, fz, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end
    elseif comboType == 'chokeslam' then
        if stage == 'chokegrab' then
            ShakeGameplayCam('JOLT_SHAKE', 0.8)
        elseif stage == 'chokeslam' then
            ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 1.5)
            SetPedToRagdoll(ped, 4500, 4500, 0, false, false, false)
            ApplyForceToEntity(ped, 1, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end
    elseif comboType == 'barrage' then
        if stage == 'hit' then
            RequestAnim("melee@unarmed@streamed_core")
            TaskPlayAnim(ped, "melee@unarmed@streamed_core", "hit_heavy_l", 8.0, -8.0, 120, 0, 0.0, false, false, false)
            ShakeGameplayCam('HAND_SHAKE', 0.35)
        elseif stage == 'finish' then
            ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 1.8)
            local fx = forceData and forceData.x or 0.0
            local fy = forceData and forceData.y or 0.0
            local fz = forceData and forceData.z or 6.0
            SetPedToRagdoll(ped, 4500, 4500, 0, false, false, false)
            ApplyForceToEntity(ped, 1, fx, fy, fz, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end
    elseif comboType == 'comboarea' then
        ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 1.6)
        local fx = forceData and forceData.x or 0.0
        local fy = forceData and forceData.y or 0.0
        local fz = forceData and forceData.z or 8.0
        SetPedToRagdoll(ped, 4500, 4500, 0, false, false, false)
        ApplyForceToEntity(ped, 1, fx, fy, fz, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    end
end)

RegisterNetEvent('lumina_poderes:client:playComboEffects', function(coords, effectType)
    if not coords then return end
    local pCoords = GetEntityCoords(PlayerPedId())
    if #(pCoords - coords) > 60.0 then return end

    if effectType == 'slam_crater' then
        RequestNamedPtfxAsset("core")
        if HasNamedPtfxAssetLoaded("core") then
            UseParticleFxAssetNextCall("core")
            StartParticleFxNonLoopedAtCoord("exp_grd_sticky", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.4, false, false, false)
        end
    elseif effectType == 'punch_shockwave' then
        RequestNamedPtfxAsset("core")
        if HasNamedPtfxAssetLoaded("core") then
            UseParticleFxAssetNextCall("core")
            StartParticleFxNonLoopedAtCoord("exp_grd_sticky", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.8, false, false, false)
        end
    end
end)

-- =========================================================================
-- SINCRONIZAÇÃO DE CLONES PARA OUTROS JOGADORES NO SERVIDOR (LOMAR DEV)
-- =========================================================================
RegisterNetEvent('lumina_poderes:client:onSyncClonesBatch', function(netIds, ownerServerId)
    local ownerPlayer = GetPlayerFromServerId(ownerServerId)
    if ownerPlayer == -1 or ownerPlayer == PlayerId() then return end

    CreateThread(function()
        local ownerPed = GetPlayerPed(ownerPlayer)
        local myPed = PlayerPedId()

        for _, netId in ipairs(netIds) do
            local timeout = 0
            local clonePed = NetworkGetEntityFromNetworkId(netId)
            while not DoesEntityExist(clonePed) and timeout < 40 do
                Wait(50)
                clonePed = NetworkGetEntityFromNetworkId(netId)
                timeout = timeout + 1
            end

            if DoesEntityExist(clonePed) then
                if DoesEntityExist(ownerPed) then
                    ClonePedToTarget(ownerPed, clonePed)
                    SetEntityNoCollisionEntity(clonePed, ownerPed, false)
                end
                SetEntityNoCollisionEntity(clonePed, myPed, false)
            end
        end
    end)
end)

