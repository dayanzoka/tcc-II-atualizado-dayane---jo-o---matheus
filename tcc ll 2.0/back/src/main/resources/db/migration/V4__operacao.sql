-- ===========================================================================
-- V4 - Schema de operacao (infraestrutura da aplicacao)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Chaves de API
--
-- O cliente Godot precisa se autenticar para enviar telemetria (apontamento 10
-- da banca: "requer testes de seguranca / autenticacao"). A chave em si nunca
-- e gravada; guardamos apenas o hash, do mesmo jeito que se faz com senha.
-- ---------------------------------------------------------------------------
CREATE TABLE operacao.chave_api (
    id_chave     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nome         VARCHAR(80)  NOT NULL,
    prefixo      VARCHAR(12)  NOT NULL,
    chave_hash   CHAR(64)     NOT NULL,
    escopo       VARCHAR(20)  NOT NULL,
    ativa        BOOLEAN      NOT NULL DEFAULT TRUE,
    criada_em    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expira_em    TIMESTAMPTZ,
    ultimo_uso_em TIMESTAMPTZ,

    CONSTRAINT uq_chave_api_hash    UNIQUE (chave_hash),
    CONSTRAINT uq_chave_api_prefixo UNIQUE (prefixo),
    CONSTRAINT ck_chave_api_escopo  CHECK (escopo IN ('INGESTAO', 'CONSULTA', 'ADMINISTRACAO'))
);

COMMENT ON TABLE  operacao.chave_api         IS 'Credenciais de acesso a API. A chave em claro so existe no momento da emissao.';
COMMENT ON COLUMN operacao.chave_api.prefixo IS 'Primeiros caracteres da chave, para identificar qual credencial esta em uso sem revela-la.';
COMMENT ON COLUMN operacao.chave_api.escopo  IS 'INGESTAO para o cliente Godot (so escreve); CONSULTA para o dashboard (so le).';

-- ---------------------------------------------------------------------------
-- Registro de auditoria
--
-- Sustenta o principio de responsabilizacao e prestacao de contas (art. 6, X
-- da LGPD): toda operacao sobre dado pessoal deixa rastro.
-- ---------------------------------------------------------------------------
CREATE TABLE operacao.registro_auditoria (
    id_registro   BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ocorrido_em   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    ator          VARCHAR(80)  NOT NULL,
    acao          VARCHAR(40)  NOT NULL,
    entidade      VARCHAR(60)  NOT NULL,
    id_entidade   VARCHAR(64),
    detalhe       JSONB        NOT NULL DEFAULT '{}'::jsonb,

    CONSTRAINT ck_auditoria_acao CHECK (acao IN (
        'CONSENTIMENTO_REGISTRADO', 'CONSENTIMENTO_REVOGADO',
        'PARTICIPANTE_CRIADO', 'PARTICIPANTE_ANONIMIZADO',
        'VINCULO_ROMPIDO', 'VINCULO_EXPURGADO',
        'EXPORTACAO_GERADA', 'RETENCAO_APLICADA',
        'CHAVE_API_CRIADA', 'CHAVE_API_REVOGADA'))
);

CREATE INDEX ix_auditoria_ocorrido ON operacao.registro_auditoria (ocorrido_em);
CREATE INDEX ix_auditoria_entidade ON operacao.registro_auditoria (entidade, id_entidade);

COMMENT ON TABLE  operacao.registro_auditoria         IS 'Trilha de auditoria das operacoes sobre dados pessoais.';
COMMENT ON COLUMN operacao.registro_auditoria.detalhe IS 'Contexto da operacao. PROIBIDO conter dado pessoal em texto claro.';

-- ---------------------------------------------------------------------------
-- Exportacoes
--
-- O plano B do risco "perda de dados de telemetria" pede exportacao em JSON
-- apos cada sessao. Registrar cada exportacao da rastreabilidade de onde os
-- dados da monografia sairam.
-- ---------------------------------------------------------------------------
CREATE TABLE operacao.exportacao (
    id_exportacao   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    escopo          VARCHAR(20)  NOT NULL,
    id_referencia   UUID,
    caminho_arquivo VARCHAR(400) NOT NULL,
    hash_arquivo    CHAR(64)     NOT NULL,
    total_registros INTEGER      NOT NULL,
    gerada_em       TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT ck_exportacao_escopo    CHECK (escopo IN ('SESSAO', 'SUJEITO', 'COMPLETA')),
    CONSTRAINT ck_exportacao_registros CHECK (total_registros >= 0)
);

COMMENT ON TABLE  operacao.exportacao              IS 'Historico das exportacoes JSON usadas como backup e como fonte da analise estatistica.';
COMMENT ON COLUMN operacao.exportacao.hash_arquivo IS 'SHA-256 do arquivo gerado. Permite provar na banca que o dado analisado e o dado coletado.';
