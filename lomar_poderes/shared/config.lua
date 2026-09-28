--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║                 SISTEMA DE PODERES SOBRENATURAIS             ║
    ║                     Desenvolvido por: LOMAR DEV              ║
    ║                     Comunidade: MRI Community                ║
    ╚══════════════════════════════════════════════════════════════╝
]]

Config = {}

-- Configurações de Permissão
-- Se true, comandos de poderes exigem permissão de Admin (Qbox/ACE)
-- Se false, qualquer jogador pode testar os comandos
Config.RequireAdminForPoderes = false

-- Distância máxima da mira do Teleporte Mágico e Raio
Config.TeleportDistance = 100
Config.RaioDistance = 80

-- Lança-Chamas Mágico
Config.FlameThrowerSize = 2.5
Config.FlameUses = 4

-- Poder de Sereia
Config.Sereia = {
    SwimSpeedMultiplier = 1.49,
    MaxUnderwaterTime = 120.0,
    RefillStamina = true
}

-- Poder de Vampiro
Config.Vampiro = {
    DanoMordida = 25,       -- Vida removida da vítima
    CuraVampiro = 35,       -- Vida restaurada ao vampiro
    DistanciaMordida = 2.5, -- Distância máxima para morder
    VelocidadeMultiplier = 1.49,
    DuracaoVelocidade = 12000 -- 12 segundos de arrancada
}

-- Terremoto
Config.Terremoto = {
    DuracaoMs = 8000,
    Intensidade = 1.2
}

-- Poder de Lobisomem / Lupino (LOMAR DEV)
Config.Lobisomem = {
    Model = 'WereWolf',                  -- Modelo do ped na meta/stream (Lupino_Lumina)
    MaxHealth = 400,                     -- Vida sobre-humana de fera
    Armour = 100,                        -- Armadura de couro de lobo
    SpeedMultiplier = 1.49,              -- Arrancada veloz de fera
    MeleeDamageMultiplier = 2.5,         -- Dano brutal das garras
    PuloPoderoso = true,                 -- Super salto de fera
    AudioTransformation = 'demon',       -- Efeito sonoro místico
    AudioHowl = 'demon',                 -- Som do uivo da fera
    PtfxAsset = 'core',                  -- Partícula de fumaça mística
    PtfxParticle = 'exp_grd_grenade_smoke'
}
