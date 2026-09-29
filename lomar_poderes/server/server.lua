--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║                 SISTEMA DE PODERES SOBRENATURAIS             ║
    ║                     Desenvolvido por: LOMAR DEV              ║
    ║                     Comunidade: MRI Community                ║
    ╚══════════════════════════════════════════════════════════════╝
]]

CreateThread(function()
    print("^6====================================================================^0")
    print("^5[LOMAR DEV]^2 Sistema de Poderes Sobrenaturais v2.0 carregado!^0")
    print("^3Comunidade MRI - Desenvolvido e adaptado com dedicacao por LOMAR DEV^0")
    print("^6====================================================================^0")
end)

local function HasPoderPermission(source)
    if not Config.RequireAdminForPoderes then
        return true
    end

    -- Se Qbox estiver rodando, verifica permissão admin
    if GetResourceState('qbx_core') == 'started' then
        local hasAdmin = exports.qbx_core:HasPermission(source, 'admin') or exports.qbx_core:HasPermission(source, 'god')
        if hasAdmin then return true end
    end

    -- Verificação via ACE
    if IsPlayerAceAllowed(source, "command") or IsPlayerAceAllowed(source, "group.admin") then
        return true
    end

    return false
end

local function NotifyServer(source, msg, type)
    if GetResourceState('ox_lib') == 'started' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'LOMAR DEV - Poderes',
            description = msg,
            type = type or 'inform'
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            args = { '^6[LOMAR DEV]^0', msg }
        })
    end
end

RegisterNetEvent('lumina_poderes:server:checkAndExecute', function(spellType, extraData)
    local src = source

    if not HasPoderPermission(src) then
        NotifyServer(src, 'Você não possui permissão mística para conjurar este poder.', 'error')
        return
    end

    if spellType == 'sereia' then
        TriggerClientEvent('lumina_poderes:client:toggleSereia', src, extraData)
    elseif spellType == 'levitate' then
        TriggerClientEvent('lumina_poderes:client:levitate', src)
    elseif spellType == 'teleport' then
        TriggerClientEvent('lumina_poderes:client:magicTeleport', src)
    elseif spellType == 'flamethrower' then
        TriggerClientEvent('lumina_poderes:client:magicFlamethrower', src)
    elseif spellType == 'fumaca' then
        TriggerClientEvent('lumina_poderes:client:fazFumaca', src)
    elseif spellType == 'raio' then
        TriggerClientEvent('lumina_poderes:client:summonLightning', src)
    elseif spellType == 'terremoto' then
        TriggerClientEvent('lumina_poderes:client:earthquake', -1)
    elseif spellType == 'risada' then
        TriggerClientEvent('lumina_poderes:client:risada', src)
    end
end)

-- Sistema de Mordida de Vampiro Sincronizada
RegisterNetEvent('lumina_poderes:server:executeBite', function(targetId)
    local src = source
    targetId = tonumber(targetId)

    if not targetId or targetId <= 0 or not GetPlayerPing(targetId) or targetId == src then
        NotifyServer(src, 'Vítima inválida para morder.', 'error')
        return
    end

    TriggerClientEvent('lumina_poderes:client:playBiteVampire', src)
    TriggerClientEvent('lumina_poderes:client:playBiteVictim', targetId)
end)

-- Sincronização de partículas e sons para todos os jogadores ao redor
RegisterNetEvent("lumina_poderes:server:syncParticle", function(coords, partDict, particles, size, duration, sound)
    TriggerClientEvent("lumina_poderes:client:receiveParticle", -1, coords, partDict, particles, size, duration, sound)
end)

RegisterNetEvent("lumina_poderes:server:syncFlames", function(coords)
    local src = source
    TriggerClientEvent("lumina_poderes:client:receiveFlames", -1, src)
end)

RegisterNetEvent("lumina_poderes:server:syncSmoke", function(coords, partDict, particles, size, duration, sound)
    TriggerClientEvent("lumina_poderes:client:receiveParticle", -1, coords, partDict, particles, size, duration, sound)
end)

RegisterNetEvent("lumina_poderes:server:syncLightning", function(coords)
    TriggerClientEvent("lumina_poderes:client:receiveLightning", -1, coords)
end)

RegisterNetEvent("lumina_poderes:server:syncLaugh", function(coords)
    TriggerClientEvent("lumina_poderes:client:receiveLaugh", -1, coords)
end)

RegisterNetEvent("lumina_poderes:server:syncHowl", function(coords)
    TriggerClientEvent("lumina_poderes:client:receiveHowl", -1, coords)
end)

-- Comando mágico de Admin / Staff: /fire [id]
RegisterCommand("fire", function(source, args)
    if source ~= 0 and not HasPoderPermission(source) then
        NotifyServer(source, "Sem permissão.", "error")
        return
    end

    local target = tonumber(args[1]) or source
    if target and target > 0 and GetPlayerPing(target) > 0 then
        TriggerClientEvent("lumina_poderes:client:burn", target)
        if source ~= 0 then
            NotifyServer(source, "Fogo mágico ateado no ID " .. target, "success")
        end
    else
        if source ~= 0 then
            NotifyServer(source, "Jogador não encontrado.", "error")
        end
    end
end, false)

-- =========================================================================
-- NOVOS PODERES SOBRENATURAIS (LOMAR DEV) - SINCRONIZAÇÃO EM REDE
-- =========================================================================

-- 1. Ressurreição Celestial / Renascer
RegisterNetEvent('lumina_poderes:server:executeRevive', function(targetId)
    local src = source
    targetId = tonumber(targetId)

    if not targetId or targetId <= 0 or not GetPlayerPing(targetId) then
        NotifyServer(src, 'Alvo inválido para ressuscitar.', 'error')
        return
    end

    -- Animações e efeitos para ambos
    TriggerClientEvent('lumina_poderes:client:playReviveCaster', src)
    TriggerClientEvent('lumina_poderes:client:playReviveVictim', targetId)

    -- Se qbx_medical ou qb-ambulancejob existir, reviver formalmente
    if GetResourceState('qbx_medical') == 'started' then
        exports.qbx_medical:Revive(targetId)
    elseif GetResourceState('qb-ambulancejob') == 'started' then
        TriggerClientEvent('hospital:client:Revive', targetId)
    end
end)

-- 2. Beijo da Morte Vampírico
RegisterNetEvent('lumina_poderes:server:executeDeathKiss', function(targetId)
    local src = source
    targetId = tonumber(targetId)

    if not targetId or targetId <= 0 or not GetPlayerPing(targetId) or targetId == src then
        NotifyServer(src, 'Alvo inválido para o Beijo da Morte.', 'error')
        return
    end

    TriggerClientEvent('lumina_poderes:client:playDeathKissCaster', src)
    TriggerClientEvent('lumina_poderes:client:playDeathKissVictim', targetId)
end)

-- 3. Canto da Sereia / Hipnose
RegisterNetEvent('lumina_poderes:server:executeHypnosis', function(targetId)
    local src = source
    targetId = tonumber(targetId)

    if targetId and targetId > 0 and GetPlayerPing(targetId) then
        TriggerClientEvent('lumina_poderes:client:receiveHypnosis', targetId)
    end
end)

RegisterNetEvent('lumina_poderes:server:executeHypnosisArea', function(coords)
    TriggerClientEvent('lumina_poderes:client:receiveHypnosisArea', -1, coords)
end)

-- 4. Petrificação
RegisterNetEvent('lumina_poderes:server:executePetrify', function(targetId)
    local src = source
    targetId = tonumber(targetId)

    if not targetId or targetId <= 0 or not GetPlayerPing(targetId) or targetId == src then
        NotifyServer(src, 'Alvo inválido para petrificar.', 'error')
        return
    end

    TriggerClientEvent('lumina_poderes:client:receivePetrify', targetId, Config.Petrificacao.DuracaoMs or 10000)
end)

-- 5. Ataque Psíquico
RegisterNetEvent('lumina_poderes:server:executeMentalAttack', function(targetId)
    local src = source
    targetId = tonumber(targetId)

    if not targetId or targetId <= 0 or not GetPlayerPing(targetId) or targetId == src then
        NotifyServer(src, 'Alvo inválido para ataque psíquico.', 'error')
        return
    end

    TriggerClientEvent('lumina_poderes:client:receiveMentalAttack', targetId, Config.AtaqueMental.Dano or 30)
end)

-- 6. Julgamento da Luz Divina
RegisterNetEvent('lumina_poderes:server:executeDivineLight', function(coords)
    TriggerClientEvent('lumina_poderes:client:receiveDivineLight', -1, coords)
end)

-- 7. Prisão de Água
RegisterNetEvent('lumina_poderes:server:executeWaterPrison', function(targetId)
    local src = source
    targetId = tonumber(targetId)

    if not targetId or targetId <= 0 or not GetPlayerPing(targetId) or targetId == src then
        NotifyServer(src, 'Alvo inválido para a prisão de água.', 'error')
        return
    end

    TriggerClientEvent('lumina_poderes:client:receiveWaterPrison', targetId, Config.PrisaoAgua.DuracaoMs or 8000)
end)

-- 8. Tornado / Vórtice
RegisterNetEvent('lumina_poderes:server:executeTornado', function(coords)
    TriggerClientEvent('lumina_poderes:client:receiveTornado', -1, coords)
end)

-- 9. Crucificação Mística
RegisterNetEvent('lumina_poderes:server:executeCrucifixion', function(targetId)
    local src = source
    targetId = tonumber(targetId)

    if not targetId or targetId <= 0 or not GetPlayerPing(targetId) or targetId == src then
        NotifyServer(src, 'Alvo inválido para crucificação.', 'error')
        return
    end

    TriggerClientEvent('lumina_poderes:client:receiveCrucifixion', targetId, Config.Crucificacao.DuracaoMs or 8000)
end)

-- =========================================================================
-- PODERES ORIGINAIS & CRIATIVOS (LOMAR DEV) - SINCRONIZAÇÃO EM REDE
-- =========================================================================

-- 1. Telecinese (Lançamento / Arremesso)
RegisterNetEvent('lumina_poderes:server:syncTelekinesisThrow', function(targetId, forceX, forceY, forceZ)
    local target = tonumber(targetId)
    if target and target > 0 and GetPlayerPing(target) > 0 then
        TriggerClientEvent('lumina_poderes:client:receiveTelekinesisThrow', target, forceX, forceY, forceZ)
    end
end)

-- 2. Escudo Místico
RegisterNetEvent('lumina_poderes:server:syncShield', function(coords)
    TriggerClientEvent('lumina_poderes:client:receiveShieldEffect', -1, coords)
end)

-- 3. Buraco Negro / Vórtice Gravitacional
RegisterNetEvent('lumina_poderes:server:syncBlackHole', function(coords)
    TriggerClientEvent('lumina_poderes:client:receiveBlackHole', -1, coords)
end)

-- 4. Criomancia (Congelamento)
RegisterNetEvent('lumina_poderes:server:executeFreeze', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId <= 0 or not GetPlayerPing(targetId) or targetId == src then
        NotifyServer(src, 'Alvo inválido para congelar.', 'error')
        return
    end
    TriggerClientEvent('lumina_poderes:client:receiveFreeze', targetId, Config.Criomancia.DuracaoMs or 8000)
end)

-- 5. Puxão Sombrio
RegisterNetEvent('lumina_poderes:server:executeShadowPull', function(targetId, destX, destY, destZ)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId <= 0 or not GetPlayerPing(targetId) or targetId == src then
        NotifyServer(src, 'Alvo inválido para o puxão sombrio.', 'error')
        return
    end
    TriggerClientEvent('lumina_poderes:client:receiveShadowPull', targetId, destX, destY, destZ)
end)

-- 6. Parada Temporal
RegisterNetEvent('lumina_poderes:server:syncTimeStop', function(coords)
    local src = source
    TriggerClientEvent('lumina_poderes:client:receiveTimeStop', -1, src, coords, Config.ParadaTemporal.DuracaoMs or 6000)
end)

-- =========================================================================
-- NOVOS PODERES DE ALTO IMPACTO VISUAL & AUDÍVEL (LOMAR DEV)
-- =========================================================================

-- Sincronização de Áudio Espacial / 3D para Todos os Jogadores Próximos
RegisterNetEvent('lumina_poderes:server:syncSound', function(soundName, coords, maxDist, volume)
    TriggerClientEvent('lumina_poderes:client:receiveSound', -1, soundName, coords, maxDist or 45.0, volume or 0.7)
end)

-- Aura Espiritual Contínua
RegisterNetEvent('lumina_poderes:server:syncAura', function(pedNetId, colorName, active)
    TriggerClientEvent('lumina_poderes:client:receiveAura', -1, pedNetId, colorName, active)
end)

RegisterNetEvent('lumina_poderes:server:syncAuraTick', function(pedNetId, colorName)
    TriggerClientEvent('lumina_poderes:client:receiveAuraTick', -1, pedNetId, colorName)
end)

-- Chamas Negras / Amaterasu
RegisterNetEvent('lumina_poderes:server:executeBlackFlames', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId <= 0 or not GetPlayerPing(targetId) or targetId == src then
        NotifyServer(src, 'Alvo inválido para as Chamas Negras.', 'error')
        return
    end
    TriggerClientEvent('lumina_poderes:client:receiveBlackFlames', targetId, Config.ChamasNegras.DuracaoMs or 8000)
end)

-- Lança Celestial / Bola de Energia Sagrada
RegisterNetEvent('lumina_poderes:server:syncLightSpear', function(startX, startY, startZ, dirX, dirY, dirZ)
    TriggerClientEvent('lumina_poderes:client:receiveLightSpear', -1, startX, startY, startZ, dirX, dirY, dirZ)
end)

RegisterNetEvent('lumina_poderes:server:syncEnergyBall', function(startX, startY, startZ, targetX, targetY, targetZ)
    TriggerClientEvent('lumina_poderes:client:receiveEnergyBall', -1, startX, startY, startZ, targetX, targetY, targetZ)
end)

-- Domo de Proteção Arcana
RegisterNetEvent('lumina_poderes:server:syncDome', function(coords)
    local src = source
    TriggerClientEvent('lumina_poderes:client:receiveDome', -1, src, coords, Config.Domo.DuracaoMs or 12000)
end)

-- Portal Dimensional (Sincronização dos dois pontos de fenda)
local activePortals = {}

RegisterNetEvent('lumina_poderes:server:setPortal', function(portalData)
    local src = source
    activePortals[src] = portalData
    TriggerClientEvent('lumina_poderes:client:syncAllPortals', -1, activePortals)
end)

RegisterNetEvent('lumina_poderes:server:closePortal', function()
    local src = source
    if activePortals[src] then
        activePortals[src] = nil
        TriggerClientEvent('lumina_poderes:client:syncAllPortals', -1, activePortals)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if activePortals[src] then
        activePortals[src] = nil
        TriggerClientEvent('lumina_poderes:client:syncAllPortals', -1, activePortals)
    end
end)

-- =========================================================================
-- COMBOS CINEMATOGRÁFICOS DE COMBATE (LOMAR DEV)
-- =========================================================================

-- Sincronização de dano e reações do alvo quando for outro jogador
RegisterNetEvent('lumina_poderes:server:syncComboHit', function(targetServerId, comboType, stage, damage, forceData)
    local src = source
    targetServerId = tonumber(targetServerId)
    if targetServerId and targetServerId > 0 and GetPlayerPing(targetServerId) > 0 and targetServerId ~= src then
        TriggerClientEvent('lumina_poderes:client:onComboHitVictim', targetServerId, comboType, stage, damage, forceData, src)
    end
end)

-- Sincronização de efeitos visuais e sonoros dos combos para todos os jogadores ao redor
RegisterNetEvent('lumina_poderes:server:syncComboEffects', function(coords, effectType)
    if coords then
        TriggerClientEvent('lumina_poderes:client:playComboEffects', -1, coords, effectType)
    end
end)

-- Sincronização em rede de clones para que todos os jogadores no servidor vejam a multidão
RegisterNetEvent('lumina_poderes:server:syncClonesBatch', function(netIds)
    local src = source
    if netIds and #netIds > 0 then
        TriggerClientEvent('lumina_poderes:client:onSyncClonesBatch', -1, netIds, src)
    end
end)


