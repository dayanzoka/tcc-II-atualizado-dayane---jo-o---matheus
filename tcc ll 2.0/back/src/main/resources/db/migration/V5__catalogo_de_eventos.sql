-- ===========================================================================
-- V5 - Catalogo de eventos de telemetria
--
-- Este catalogo e a resposta concreta a pergunta "o que exatamente voces
-- coletam?". Cada linha justifica sua propria existencia apontando o eixo do
-- planejamento que precisa daquele dado. Evento que nao serve a nenhum eixo
-- nao entra: coleta sem finalidade viola o principio da necessidade
-- (art. 6, III da LGPD).
-- ===========================================================================

INSERT INTO pesquisa.tipo_evento (codigo, descricao, eixo_origem) VALUES
    -- Ciclo de vida da sessao
    ('SESSAO_INICIADA',      'Jogador abriu uma nova sessao de jogo',                          'Eixo 6'),
    ('SESSAO_ENCERRADA',     'Jogador encerrou a sessao pelo menu',                            'Eixo 6'),
    ('SESSAO_ABANDONADA',    'Sessao encerrada sem despedida, detectada por inatividade',      'Eixo 6'),

    -- Progressao entre as quatro fases (Eixo 2: Cesar, Vigenere, SHA-256, AES)
    ('FASE_INICIADA',        'Jogador entrou em uma das quatro fases',                         'Eixo 2'),
    ('FASE_CONCLUIDA',       'Jogador resolveu o desafio criptografico da fase',               'Eixo 2'),
    ('FASE_ABANDONADA',      'Jogador saiu da fase sem concluir',                              'Eixo 2'),
    ('DICA_SOLICITADA',      'Jogador pediu dica -- indicador indireto de dificuldade',        'Eixo 8'),
    ('CIFRA_DEMONSTRADA',    'Jogador usou o exemplo visual de texto claro versus cifrado',    'Eixo 2'),

    -- Terminal e analisador lexico-sintatico (Eixo 3)
    ('COMANDO_SUBMETIDO',    'Jogador submeteu um comando no terminal',                        'Eixo 3'),
    ('ERRO_LEXICO',          'Analisador lexico rejeitou o token',                             'Eixo 3'),
    ('ERRO_SINTATICO',       'Parser recursivo descendente rejeitou a estrutura do comando',   'Eixo 3'),

    -- Inteligencia artificial (Eixo 4)
    ('CACHORRO_DETECTOU',    'Cachorro farejador localizou o jogador via A*',                  'Eixo 4'),
    ('CACHORRO_PERDEU',      'Cachorro farejador perdeu o rastro do jogador',                  'Eixo 4'),
    ('JOGADOR_CAPTURADO',    'Jogador foi alcancado pelo cachorro farejador',                  'Eixo 4'),

    -- Desempenho do cliente (Eixo 7)
    ('AMOSTRA_DESEMPENHO',   'Amostra periodica de FPS e uso de memoria do cliente Godot',     'Eixo 7');

COMMENT ON COLUMN pesquisa.tipo_evento.codigo IS
    'Codigo estavel. Nao renomear apos o inicio da coleta -- quebraria a serie historica.';
