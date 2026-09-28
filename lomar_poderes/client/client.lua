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

