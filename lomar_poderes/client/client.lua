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

local function PlaySpellSound(soundName, volume)
    SendNUIMessage({
        sound = soundName,
        volume = volume or 0.4
    })
end

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

local function DestransformarLobisomem()
    local ped = PlayerPedId()
    local pedId = PlayerId()

    if not isLobisomem then
        Notify('Lobisomem', 'Você não está na forma de Lobisomem.', 'error')
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
    savedHumanAppearance = nil
    savedHumanModel = nil

    Notify('Lobisomem', 'Você retornou à sua forma humana.', 'inform')
end

local function UivarLobisomem()
    local ped = PlayerPedId()

    if not isLobisomem then
        Notify('Lobisomem', 'Você precisa estar transformado em Lobisomem para uivar!', 'error')
        return
    end

    local coords = GetEntityCoords(ped)
    PlaySpellSound(Config.Lobisomem.AudioHowl or "demon", 0.9)

    -- Animação de uivo para o céu
    RequestAnim("rcmnigel1a")
    TaskPlayAnim(ped, "rcmnigel1a", "laugh_im_amused", 8.0, -8.0, 3500, 49, 0, false, false, false)

    -- Treme a tela
    ShakeGameplayCam('VIBRATE_SHAKE', 1.0)
    SetTimeout(2000, function()
        ShakeGameplayCam('VIBRATE_SHAKE', 0.0)
    end)

    -- Sincroniza som e tremor para jogadores próximos
    TriggerServerEvent("lumina_poderes:server:syncHowl", coords)
    Notify('Uivo', 'Você uivou furiosamente para a lua!', 'success')
end

local function ToggleVisaoLobo()
    if not isLobisomem then
        Notify('Lobisomem', 'Apenas lobisomens possuem visão feral apurada!', 'error')
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

-- Comandos registrados (LOMAR DEV)
RegisterCommand('lobisomem', function()
    TransformarLobisomem()
end, false)

RegisterCommand('lobao', function()
    TransformarLobisomem()
end, false)

RegisterCommand('transformar', function()
    TransformarLobisomem()
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

