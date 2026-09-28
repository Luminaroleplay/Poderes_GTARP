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
