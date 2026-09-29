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

-- Lobo Ágil / Sirius (LOMAR DEV)
Config.LoboSirius = {
    Model = 'LoboSirius',                -- Modelo animal de 4 patas (Lobo_Sirius_Lumina)
    MaxHealth = 300,
    SpeedMultiplier = 1.60,              -- Agilidade extrema
    AudioTransformation = 'demon'
}

-- Novos Poderes Sobrenaturais (LOMAR DEV)
Config.Renascer = {
    Distancia = 5.0,
    VidaCurada = 200,
    TempoLevitacao = 8000
}

Config.BeijoDaMorte = {
    Distancia = 3.0,
    Dano = 50,
    Cura = 100
}

Config.HipnoseSereia = {
    Raio = 12.0,
    DuracaoMs = 12000
}

Config.Petrificacao = {
    Distancia = 10.0,
    DuracaoMs = 10000
}

Config.AtaqueMental = {
    Distancia = 15.0,
    Dano = 30,
    DuracaoMs = 6000
}

Config.LuzDivina = {
    Raio = 15.0,
    DuracaoMs = 5000
}

Config.PrisaoAgua = {
    Distancia = 10.0,
    DuracaoMs = 8000,
    Dano = 25
}

Config.Tornado = {
    Raio = 12.0,
    DuracaoMs = 8000,
    ForcaEmpurrao = 4.0
}

Config.Crucificacao = {
    Distancia = 8.0,
    DuracaoMs = 8000,
    Altura = 1.6
}

-- Poderes Criativos & Originais (LOMAR DEV)
Config.Telecinese = {
    Distancia = 25.0,
    DuracaoSegurar = 7000,
    ForcaArremesso = 50.0
}

Config.EscudoMistico = {
    DuracaoMs = 10000,
    RaioEmpurrao = 3.5
}

Config.ClonesSombra = {
    Quantidade = 2,
    DuracaoMs = 10000
}

Config.BuracoNegro = {
    DistanciaMira = 40.0,
    RaioSugador = 22.0,
    DuracaoMs = 7000,
    ForcaExplosao = 2.0
}

Config.FormaFantasma = {
    DuracaoMs = 10000,
    TransparenciaAlpha = 110,
    VelocidadeBonus = 1.45
}

Config.Criomancia = {
    Distancia = 12.0,
    DuracaoMs = 8000
}

Config.PuxaoSombrio = {
    Distancia = 25.0,
    VelocidadeArrasto = 25.0
}

Config.ParadaTemporal = {
    Raio = 30.0,
    DuracaoMs = 6000
}

-- Novos Poderes Arrojados & Visuais (LOMAR DEV)
Config.Aura = {
    VelocidadeMultiplier = 1.35,
    DuracaoMs = 60000,
    PtfxDict = 'scr_powerplay',
    PtfxName = 'sp_powerplay_beast_appear_trails',
    SmokeDict = 'scr_ba_bb',
    SmokeName = 'scr_ba_bb_plane_smoke_trail',
    Bones = { 51826, 52301, 23553, 24816, 24817, 60309 }
}

Config.ChamasNegras = {
    Distancia = 25.0,
    DuracaoMs = 8000,
    DanoPorTick = 8,
    IntervaloTickMs = 1500
}

Config.LancaLuz = {
    DistanciaMax = 70.0,
    Velocidade = 45.0,
    RaioImpacto = 6.0,
    Dano = 55
}

Config.Portal = {
    DuracaoMs = 120000, -- 2 minutos ativo
    RaioTeleporte = 1.6
}

Config.Domo = {
    Raio = 8.5,
    DuracaoMs = 12000,
    ForcaRepulsao = 20.0
}

Config.OlhoMistico = {
    Raio = 45.0,
    DuracaoMs = 25000
}
