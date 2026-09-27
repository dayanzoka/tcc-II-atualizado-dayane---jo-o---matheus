-- ===========================================================================
-- V7 - id_fase: a fase deixa de ser identificada só pelo número
--
-- Pedido registrado pelo time do cliente Godot em
-- docs/contrato-telemetria.md (secao "MUDANCA DE CONTRATO -- id_fase",
-- 2026-09-14): a ferramenta de autoria permite criar fases livremente, e
-- prender a coleta ao numero fixo 1..4 significava perder a telemetria de
-- qualquer fase fora dessa faixa -- o oposto do que a instrumentacao existe
-- para fazer. O cliente ja envia id_fase em todo evento e toda tentativa
-- desde essa mudanca; esta migration so abre espaco para isso no banco.
--
-- fase (SMALLINT, 1..4) fica como legado, sem remover: nao ha motivo para
-- reescrever a serie historica so por causa disso, e o proprio CHECK ja
-- aceitava NULL desde o V2, entao nenhum evento antigo precisa mudar.
-- ===========================================================================

ALTER TABLE pesquisa.evento_telemetria
    ADD COLUMN id_fase     UUID         NOT NULL,
    ADD COLUMN titulo_fase VARCHAR(60);

ALTER TABLE pesquisa.tentativa_comando
    ADD COLUMN id_fase     UUID         NOT NULL,
    ADD COLUMN titulo_fase VARCHAR(60);

CREATE INDEX ix_evento_id_fase    ON pesquisa.evento_telemetria (id_fase);
CREATE INDEX ix_tentativa_id_fase ON pesquisa.tentativa_comando (id_fase);

COMMENT ON COLUMN pesquisa.evento_telemetria.id_fase IS
    'Identidade real da fase: UUID v4 estavel gerado uma vez por fase pela ferramenta de autoria. Substitui "fase" como chave de agrupamento.';
COMMENT ON COLUMN pesquisa.evento_telemetria.titulo_fase IS
    'Rotulo legivel da fase no momento do evento, so para diagnostico -- nao usar como chave (o titulo pode ser editado depois).';
COMMENT ON COLUMN pesquisa.evento_telemetria.fase IS
    'LEGADO. Preenchido so quando a fase tem numero 1..4; null fora disso. A identidade real esta em id_fase.';

COMMENT ON COLUMN pesquisa.tentativa_comando.id_fase     IS 'Ver o comentario equivalente em evento_telemetria.';
COMMENT ON COLUMN pesquisa.tentativa_comando.titulo_fase IS 'Ver o comentario equivalente em evento_telemetria.';
COMMENT ON COLUMN pesquisa.tentativa_comando.fase        IS 'LEGADO. Ver o comentario equivalente em evento_telemetria.';
