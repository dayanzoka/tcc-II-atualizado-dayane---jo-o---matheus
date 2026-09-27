-- ===========================================================================
-- V3 - Schema de identidade (dados pessoais)
--
-- Este e o unico schema que sabe quem sao as pessoas. Regras de ouro:
--
--   1. O e-mail nunca e gravado em texto claro. Guardamos HMAC-SHA-256 com um
--      pepper que vive fora do banco (variavel de ambiente PB_PRIVACY_PEPPER).
--      Como o pepper e global e nao por linha, a busca por e-mail continua
--      possivel: recebe-se o e-mail, calcula-se o HMAC e compara-se. Um salt
--      por linha impediria essa busca, e sem ela o participante nao consegue
--      exercer os direitos do art. 18 da LGPD.
--
--   2. A ligacao entre pessoa e dado de pesquisa mora somente em
--      vinculo_sujeito. Apagar a linha de vinculo torna a telemetria
--      daquele participante anonima de forma irreversivel, atendendo ao
--      pedido de eliminacao sem destruir o resultado ja publicado.
-- ===========================================================================

CREATE TABLE identidade.participante (
    id_participante UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nome_completo   VARCHAR(180) NOT NULL,
    email_hmac      CHAR(64)     NOT NULL,
    criado_em       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    atualizado_em   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    anonimizado_em  TIMESTAMPTZ,

    CONSTRAINT uq_participante_email UNIQUE (email_hmac)
);

COMMENT ON TABLE  identidade.participante                IS 'Pessoa fisica que aceitou participar da validacao pedagogica.';
COMMENT ON COLUMN identidade.participante.nome_completo  IS 'DADO PESSOAL. Necessario apenas para a assinatura do TCLE.';
COMMENT ON COLUMN identidade.participante.email_hmac     IS 'DADO PESSOAL PSEUDONIMIZADO. HMAC-SHA-256 do e-mail em minusculas, com pepper externo ao banco.';
COMMENT ON COLUMN identidade.participante.anonimizado_em IS 'Marca a execucao de um pedido de eliminacao. Quando preenchido, nome_completo ja foi sobrescrito.';

-- ---------------------------------------------------------------------------
-- Registro de consentimento (TCLE)
-- ---------------------------------------------------------------------------
CREATE TABLE identidade.consentimento (
    id_consentimento UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    id_participante  UUID        NOT NULL,
    versao_termo     VARCHAR(20) NOT NULL,
    finalidade       VARCHAR(60) NOT NULL,
    aceito_em        TIMESTAMPTZ NOT NULL DEFAULT now(),
    revogado_em      TIMESTAMPTZ,
    origem_ip_hmac   CHAR(64),

    CONSTRAINT fk_consentimento_participante FOREIGN KEY (id_participante)
        REFERENCES identidade.participante (id_participante) ON DELETE CASCADE,
    CONSTRAINT ck_consentimento_finalidade CHECK (finalidade IN (
        'PESQUISA_ACADEMICA', 'COLETA_TELEMETRIA', 'DIVULGACAO_RESULTADOS')),
    CONSTRAINT ck_consentimento_revogacao CHECK (revogado_em IS NULL OR revogado_em >= aceito_em)
);

CREATE INDEX ix_consentimento_participante ON identidade.consentimento (id_participante);

COMMENT ON TABLE  identidade.consentimento                IS 'Prova de consentimento livre e esclarecido, por finalidade e por versao do termo (art. 8 da LGPD).';
COMMENT ON COLUMN identidade.consentimento.versao_termo   IS 'Versao do TCLE aceita. Mudou o termo, precisa de novo consentimento.';
COMMENT ON COLUMN identidade.consentimento.finalidade     IS 'Consentimento e especifico por finalidade -- nao existe consentimento generico.';
COMMENT ON COLUMN identidade.consentimento.origem_ip_hmac IS 'DADO PESSOAL PSEUDONIMIZADO. HMAC do IP, guardado so como evidencia do aceite.';

-- ---------------------------------------------------------------------------
-- Vinculo participante <-> sujeito (a ponte)
--
-- Uma unica linha por participante. E o unico caminho de reidentificacao que
-- existe no sistema. Rompe-se o vinculo e a base de pesquisa vira anonima.
-- ---------------------------------------------------------------------------
CREATE TABLE identidade.vinculo_sujeito (
    id_participante UUID        PRIMARY KEY,
    id_sujeito      UUID        NOT NULL,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now(),
    rompido_em      TIMESTAMPTZ,

    CONSTRAINT fk_vinculo_participante FOREIGN KEY (id_participante)
        REFERENCES identidade.participante (id_participante) ON DELETE CASCADE,
    CONSTRAINT fk_vinculo_sujeito FOREIGN KEY (id_sujeito)
        REFERENCES pesquisa.sujeito (id_sujeito) ON DELETE CASCADE,
    CONSTRAINT uq_vinculo_sujeito UNIQUE (id_sujeito)
);

COMMENT ON TABLE  identidade.vinculo_sujeito            IS 'CHAVE DE REIDENTIFICACAO. Apagar esta linha anonimiza a telemetria do participante de forma irreversivel.';
COMMENT ON COLUMN identidade.vinculo_sujeito.rompido_em IS
    'Eliminacao em duas fases. Fase 1: o pedido e aceito, rompido_em e preenchido '
    'e o vinculo deixa de ser usado. Fase 2: apos a carencia, a rotina de expurgo '
    'apaga a linha e a anonimizacao se torna irreversivel. Manter as duas fases '
    'evita que um pedido feito por engano destrua o dado no mesmo instante.';
