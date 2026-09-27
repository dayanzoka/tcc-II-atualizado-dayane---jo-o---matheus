-- ===========================================================================
-- V6 - Visoes analiticas
--
-- Deixar a agregacao no banco tem duas vantagens para o TCC: o dashboard nao
-- precisa reimplementar a regra de calculo, e a analise estatistica do Eixo 8
-- le exatamente os mesmos numeros que a banca ve na tela.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Desempenho por fase -- as tres metricas objetivas de aprendizado do Eixo 1:
-- taxa de acerto, tempo de resposta e uso correto dos comandos.
-- ---------------------------------------------------------------------------
CREATE VIEW pesquisa.vw_desempenho_fase AS
SELECT
    t.id_sessao,
    s.id_sujeito,
    t.fase,
    COUNT(*)                                                AS total_tentativas,
    COUNT(*) FILTER (WHERE t.resultado = 'SUCESSO')          AS total_acertos,
    COALESCE(ROUND(
        COUNT(*) FILTER (WHERE t.resultado = 'SUCESSO')::numeric
        / NULLIF(COUNT(*), 0), 4), 0)                        AS taxa_acerto,
    COUNT(*) FILTER (WHERE t.resultado = 'ERRO_LEXICO')      AS total_erros_lexicos,
    COUNT(*) FILTER (WHERE t.resultado = 'ERRO_SINTATICO')   AS total_erros_sintaticos,
    COUNT(*) FILTER (WHERE t.resultado = 'ERRO_SEMANTICO')   AS total_erros_semanticos,
    ROUND(AVG(t.tempo_resposta_ms)::numeric, 2)              AS tempo_medio_ms,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t.tempo_resposta_ms) AS tempo_mediano_ms,
    MIN(t.ocorrido_em)                                       AS primeira_tentativa_em,
    MAX(t.ocorrido_em)                                       AS ultima_tentativa_em
FROM pesquisa.tentativa_comando t
JOIN pesquisa.sessao_jogo s ON s.id_sessao = t.id_sessao
GROUP BY t.id_sessao, s.id_sujeito, t.fase;

COMMENT ON VIEW pesquisa.vw_desempenho_fase IS
    'Metricas objetivas de aprendizado por sessao e fase (Eixo 1). Separa erro lexico de sintatico, respondendo ao apontamento 5 da banca.';

-- ---------------------------------------------------------------------------
-- Resumo de sessao -- alimenta a listagem do dashboard.
-- ---------------------------------------------------------------------------
CREATE VIEW pesquisa.vw_resumo_sessao AS
SELECT
    s.id_sessao,
    s.id_sujeito,
    su.codigo       AS codigo_sujeito,
    su.grupo,
    su.coorte,
    s.versao_jogo,
    s.plataforma,
    s.status,
    s.iniciada_em,
    s.encerrada_em,
    EXTRACT(EPOCH FROM (COALESCE(s.encerrada_em, s.recebida_em) - s.iniciada_em))::bigint
                    AS duracao_segundos,
    (SELECT COUNT(*) FROM pesquisa.evento_telemetria e
       WHERE e.id_sessao = s.id_sessao)                     AS total_eventos,
    (SELECT COUNT(*) FROM pesquisa.tentativa_comando t
       WHERE t.id_sessao = s.id_sessao)                     AS total_tentativas,
    (SELECT COUNT(*) FROM pesquisa.evento_telemetria e
       WHERE e.id_sessao = s.id_sessao
         AND e.tipo_evento = 'FASE_CONCLUIDA')              AS fases_concluidas
FROM pesquisa.sessao_jogo s
JOIN pesquisa.sujeito su ON su.id_sujeito = s.id_sujeito;

COMMENT ON VIEW pesquisa.vw_resumo_sessao IS 'Uma linha por sessao, para a tela principal do dashboard de telemetria (Eixo 6).';

-- ---------------------------------------------------------------------------
-- Vetor de features por sessao (Eixo 4)
--
-- Responde ao item "definir quais features da telemetria a IA do Godot vai
-- usar para classificar a evolucao do jogador". Deixar o vetor definido em uma
-- visao versionada garante que o que a IA consome e o que a monografia
-- descreve sejam a mesma coisa.
-- ---------------------------------------------------------------------------
CREATE VIEW pesquisa.vw_features_ia AS
WITH tentativas AS (
    SELECT
        id_sessao,
        COUNT(*)                                              AS tentativas_total,
        COUNT(*) FILTER (WHERE resultado = 'SUCESSO')          AS acertos_total,
        AVG(tempo_resposta_ms)                                 AS tempo_medio_ms,
        STDDEV_POP(tempo_resposta_ms)                          AS desvio_tempo_ms,
        COUNT(*) FILTER (WHERE resultado = 'ERRO_LEXICO')      AS erros_lexicos,
        COUNT(*) FILTER (WHERE resultado = 'ERRO_SINTATICO')   AS erros_sintaticos,
        COUNT(DISTINCT desafio)                                AS desafios_distintos
    FROM pesquisa.tentativa_comando
    GROUP BY id_sessao
),
eventos AS (
    SELECT
        id_sessao,
        COUNT(*) FILTER (WHERE tipo_evento = 'DICA_SOLICITADA')   AS dicas_solicitadas,
        COUNT(*) FILTER (WHERE tipo_evento = 'JOGADOR_CAPTURADO') AS vezes_capturado,
        COUNT(*) FILTER (WHERE tipo_evento = 'FASE_CONCLUIDA')    AS fases_concluidas,
        COUNT(*) FILTER (WHERE tipo_evento = 'FASE_ABANDONADA')   AS fases_abandonadas
    FROM pesquisa.evento_telemetria
    GROUP BY id_sessao
)
SELECT
    s.id_sessao,
    s.id_sujeito,
    EXTRACT(EPOCH FROM (COALESCE(s.encerrada_em, s.recebida_em) - s.iniciada_em))::bigint
                                                              AS duracao_segundos,
    COALESCE(t.tentativas_total, 0)                           AS tentativas_total,
    COALESCE(ROUND(t.acertos_total::numeric
        / NULLIF(t.tentativas_total, 0), 4), 0)               AS taxa_acerto_global,
    COALESCE(ROUND(t.tempo_medio_ms::numeric, 2), 0)          AS tempo_medio_resposta_ms,
    COALESCE(ROUND(t.desvio_tempo_ms::numeric, 2), 0)         AS desvio_tempo_resposta_ms,
    COALESCE(ROUND(t.erros_lexicos::numeric
        / NULLIF(t.tentativas_total, 0), 4), 0)               AS proporcao_erro_lexico,
    COALESCE(ROUND(t.erros_sintaticos::numeric
        / NULLIF(t.tentativas_total, 0), 4), 0)               AS proporcao_erro_sintatico,
    COALESCE(ROUND(t.tentativas_total::numeric
        / NULLIF(t.desafios_distintos, 0), 2), 0)             AS media_tentativas_por_desafio,
    COALESCE(e.dicas_solicitadas, 0)                          AS dicas_solicitadas,
    COALESCE(e.vezes_capturado, 0)                            AS vezes_capturado,
    COALESCE(e.fases_concluidas, 0)                           AS fases_concluidas,
    COALESCE(e.fases_abandonadas, 0)                          AS fases_abandonadas
FROM pesquisa.sessao_jogo s
LEFT JOIN tentativas t ON t.id_sessao = s.id_sessao
LEFT JOIN eventos    e ON e.id_sessao = s.id_sessao;

COMMENT ON VIEW pesquisa.vw_features_ia IS
    'Vetor de features por sessao consumido pela IA do Godot para classificar a evolucao do jogador (Eixo 4, apontamentos 6 e 8 da banca).';

-- ---------------------------------------------------------------------------
-- Ganho de aprendizado por sujeito (Eixo 8)
--
-- Uma linha por sujeito com o par pre/pos ja pareado, que e o formato de
-- entrada do teste-t pareado e do Wilcoxon.
-- ---------------------------------------------------------------------------
CREATE VIEW pesquisa.vw_ganho_aprendizado AS
SELECT
    su.id_sujeito,
    su.codigo,
    su.grupo,
    su.coorte,
    pre.total_acertos                                         AS acertos_pre,
    pre.total_itens                                           AS itens_pre,
    pos.total_acertos                                         AS acertos_pos,
    pos.total_itens                                           AS itens_pos,
    ROUND(pre.total_acertos::numeric / NULLIF(pre.total_itens, 0), 4) AS escore_pre,
    ROUND(pos.total_acertos::numeric / NULLIF(pos.total_itens, 0), 4) AS escore_pos,
    ROUND((pos.total_acertos::numeric / NULLIF(pos.total_itens, 0))
        - (pre.total_acertos::numeric / NULLIF(pre.total_itens, 0)), 4) AS ganho_absoluto,
    ROUND(
        ((pos.total_acertos::numeric / NULLIF(pos.total_itens, 0))
       - (pre.total_acertos::numeric / NULLIF(pre.total_itens, 0)))
        / NULLIF(1 - (pre.total_acertos::numeric / NULLIF(pre.total_itens, 0)), 0), 4)
                                                              AS ganho_normalizado
FROM pesquisa.sujeito su
LEFT JOIN pesquisa.avaliacao pre ON pre.id_sujeito = su.id_sujeito AND pre.momento = 'PRE'
LEFT JOIN pesquisa.avaliacao pos ON pos.id_sujeito = su.id_sujeito AND pos.momento = 'POS';

COMMENT ON VIEW pesquisa.vw_ganho_aprendizado IS
    'Par pre/pos por sujeito, entrada direta do teste-t pareado ou Wilcoxon (Eixo 8). ganho_normalizado usa a formula de ganho normalizado de Hake.';
