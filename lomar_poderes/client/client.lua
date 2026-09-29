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
-- 24. CLONES DE ILUSÃO / SOMBRAS (LOMAR DEV)
-- =========================================================================
RegisterCommand('clones', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    PlaySpellSound("demon", 0.8)
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do Wait(10) end
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 2.0, false, false, false)

    local clonePeds = {}
    local angles = { 90.0, 270.0 }

    for i = 1, (Config.ClonesSombra.Quantidade or 2) do
        local clone = ClonePed(ped, false, false, false)
        if DoesEntityExist(clone) then
            SetEntityInvincible(clone, true)
            SetPedCanRagdoll(clone, false)
            SetBlockingOfNonTemporaryEvents(clone, true)

            local angle = angles[i] or (i * 120.0)
            local h = GetEntityHeading(ped) + angle
            SetEntityHeading(clone, h)

            local runTarget = coords + vector3(math.sin(math.rad(-h)) * 40.0, math.cos(math.rad(-h)) * 40.0, 0.0)
            TaskGoStraightToCoord(clone, runTarget.x, runTarget.y, runTarget.z, 3.0, -1, 0.0, 0.0)

            table.insert(clonePeds, clone)
        end
    end

    Notify('Clones', 'Você invocou sombras para despistar seus inimigos!', 'success')

    SetTimeout(Config.ClonesSombra.DuracaoMs or 10000, function()
        for _, clone in ipairs(clonePeds) do
            if DoesEntityExist(clone) then
                local cCoords = GetEntityCoords(clone)
                UseParticleFxAssetNextCall("core")
                StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", cCoords.x, cCoords.y, cCoords.z, 0.0, 0.0, 0.0, 1.2, false, false, false)
                DeleteEntity(clone)
            end
        end
    end)
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

