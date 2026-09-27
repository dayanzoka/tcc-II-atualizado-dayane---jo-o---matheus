-- ===========================================================================
-- V2 - Schema de pesquisa (dados pseudonimizados)
--
-- Nenhuma tabela aqui guarda nome, e-mail ou qualquer identificador direto.
-- O participante e representado apenas pelo id_sujeito, um UUID sem
-- significado. A tabela que liga esse UUID a uma pessoa fica em "identidade".
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Sujeito da pesquisa
-- ---------------------------------------------------------------------------
CREATE TABLE pesquisa.sujeito (
    id_sujeito  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo      VARCHAR(20)  NOT NULL,
    coorte      VARCHAR(60),
    grupo       VARCHAR(20)  NOT NULL DEFAULT 'UNICO',
    criado_em   TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_sujeito_codigo UNIQUE (codigo),
    CONSTRAINT ck_sujeito_grupo  CHECK (grupo IN ('UNICO', 'EXPERIMENTAL', 'CONTROLE'))
);

COMMENT ON TABLE  pesquisa.sujeito              IS 'Participante representado de forma pseudonimizada.';
COMMENT ON COLUMN pesquisa.sujeito.codigo       IS 'Codigo de exibicao usado em tabelas da monografia (ex.: PB-2026-0001). Pseudonimo, nao identifica.';
COMMENT ON COLUMN pesquisa.sujeito.coorte       IS 'Turma ou grupo de recrutamento. Manter granularidade baixa para nao permitir reidentificacao.';
COMMENT ON COLUMN pesquisa.sujeito.grupo        IS 'Braco do desenho experimental (Eixo 8).';

-- ---------------------------------------------------------------------------
-- Catalogo de tipos de evento
--
-- Documentar o catalogo no proprio banco evita que a monografia e o codigo
-- divirjam, e da a rastreabilidade que a banca pediu.
-- ---------------------------------------------------------------------------
CREATE TABLE pesquisa.tipo_evento (
    codigo       VARCHAR(40)  PRIMARY KEY,
    descricao    VARCHAR(200) NOT NULL,
    eixo_origem  VARCHAR(20)  NOT NULL,
    ativo        BOOLEAN      NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE  pesquisa.tipo_evento             IS 'Catalogo dos eventos que o cliente Godot pode emitir.';
COMMENT ON COLUMN pesquisa.tipo_evento.eixo_origem IS 'Eixo do planejamento que justifica a coleta deste evento.';

-- ---------------------------------------------------------------------------
-- Sessao de jogo
-- ---------------------------------------------------------------------------
CREATE TABLE pesquisa.sessao_jogo (
    id_sessao       UUID         PRIMARY KEY,
    id_sujeito      UUID         NOT NULL,
    versao_jogo     VARCHAR(30)  NOT NULL,
    plataforma      VARCHAR(30)  NOT NULL,
    iniciada_em     TIMESTAMPTZ  NOT NULL,
    encerrada_em    TIMESTAMPTZ,
    status          VARCHAR(20)  NOT NULL DEFAULT 'ABERTA',
    recebida_em     TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT fk_sessao_sujeito FOREIGN KEY (id_sujeito)
        REFERENCES pesquisa.sujeito (id_sujeito) ON DELETE CASCADE,
    CONSTRAINT ck_sessao_status  CHECK (status IN ('ABERTA', 'ENCERRADA', 'ABANDONADA')),
    CONSTRAINT ck_sessao_periodo CHECK (encerrada_em IS NULL OR encerrada_em >= iniciada_em)
);

CREATE INDEX ix_sessao_sujeito ON pesquisa.sessao_jogo (id_sujeito);
CREATE INDEX ix_sessao_inicio   ON pesquisa.sessao_jogo (iniciada_em);

COMMENT ON TABLE  pesquisa.sessao_jogo              IS 'Uma partida do inicio ao fim, unidade de agrupamento da telemetria.';
COMMENT ON COLUMN pesquisa.sessao_jogo.id_sessao    IS 'UUID gerado pelo cliente Godot, o que torna a abertura de sessao idempotente.';
COMMENT ON COLUMN pesquisa.sessao_jogo.iniciada_em  IS 'Relogio do cliente.';
COMMENT ON COLUMN pesquisa.sessao_jogo.recebida_em  IS 'Relogio do servidor. A diferenca entre os dois mede a defasagem e o atraso de sincronizacao offline.';

-- ---------------------------------------------------------------------------
-- Evento de telemetria (tabela de maior volume)
--
-- id_evento vem do cliente. E isso que permite reenviar um lote inteiro apos
-- falha de rede sem duplicar nada -- requisito derivado do risco "integracao
-- cliente-servidor mais lenta que o previsto" e do modo MOCK como fallback.
-- ---------------------------------------------------------------------------
CREATE TABLE pesquisa.evento_telemetria (
    id_evento    UUID         PRIMARY KEY,
    id_sessao    UUID         NOT NULL,
    sequencia    BIGINT       NOT NULL,
    tipo_evento  VARCHAR(40)  NOT NULL,
    fase         SMALLINT,
    ocorrido_em  TIMESTAMPTZ  NOT NULL,
    recebido_em  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    payload      JSONB        NOT NULL DEFAULT '{}'::jsonb,

    CONSTRAINT fk_evento_sessao FOREIGN KEY (id_sessao)
        REFERENCES pesquisa.sessao_jogo (id_sessao) ON DELETE CASCADE,
    CONSTRAINT fk_evento_tipo FOREIGN KEY (tipo_evento)
        REFERENCES pesquisa.tipo_evento (codigo),
    CONSTRAINT uq_evento_sequencia UNIQUE (id_sessao, sequencia),
    CONSTRAINT ck_evento_fase      CHECK (fase IS NULL OR fase BETWEEN 1 AND 4),
    CONSTRAINT ck_evento_sequencia CHECK (sequencia >= 0)
);

CREATE INDEX ix_evento_sessao_ocorrido ON pesquisa.evento_telemetria (id_sessao, ocorrido_em);
CREATE INDEX ix_evento_tipo            ON pesquisa.evento_telemetria (tipo_evento);
CREATE INDEX ix_evento_recebido        ON pesquisa.evento_telemetria (recebido_em);
CREATE INDEX ix_evento_payload         ON pesquisa.evento_telemetria USING GIN (payload);

COMMENT ON COLUMN pesquisa.evento_telemetria.id_evento IS 'UUID gerado no cliente. Chave de idempotencia do reenvio.';
COMMENT ON COLUMN pesquisa.evento_telemetria.sequencia IS 'Contador monotonico por sessao. Permite detectar lacunas causadas por perda de pacote.';
COMMENT ON COLUMN pesquisa.evento_telemetria.payload   IS 'Atributos especificos do tipo de evento. PROIBIDO conter dado pessoal (ver docs/lgpd).';

-- ---------------------------------------------------------------------------
-- Tentativa de comando no terminal
--
-- Tabela dedicada, e nao apenas um tipo de evento generico, porque e daqui que
-- saem as tres metricas objetivas de aprendizado do Eixo 1: taxa de acerto,
-- tempo de resposta e uso correto dos comandos. Consultar isso dentro de JSONB
-- seria caro e fragil na hora da analise estatistica.
-- ---------------------------------------------------------------------------
CREATE TABLE pesquisa.tentativa_comando (
    id_tentativa        UUID         PRIMARY KEY,
    id_sessao           UUID         NOT NULL,
    fase                SMALLINT     NOT NULL,
    desafio             VARCHAR(60)  NOT NULL,
    entrada_normalizada VARCHAR(240) NOT NULL,
    tokens              JSONB        NOT NULL DEFAULT '[]'::jsonb,
    resultado           VARCHAR(20)  NOT NULL,
    codigo_erro         VARCHAR(40),
    tempo_resposta_ms   INTEGER      NOT NULL,
    numero_tentativa    SMALLINT     NOT NULL,
    ocorrido_em         TIMESTAMPTZ  NOT NULL,
    recebido_em         TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT fk_tentativa_sessao FOREIGN KEY (id_sessao)
        REFERENCES pesquisa.sessao_jogo (id_sessao) ON DELETE CASCADE,
    CONSTRAINT ck_tentativa_fase      CHECK (fase BETWEEN 1 AND 4),
    CONSTRAINT ck_tentativa_resultado CHECK (resultado IN (
        'SUCESSO', 'ERRO_LEXICO', 'ERRO_SINTATICO', 'ERRO_SEMANTICO', 'TIMEOUT', 'ABANDONO')),
    CONSTRAINT ck_tentativa_tempo     CHECK (tempo_resposta_ms >= 0),
    CONSTRAINT ck_tentativa_numero    CHECK (numero_tentativa > 0)
);

CREATE INDEX ix_tentativa_sessao_fase ON pesquisa.tentativa_comando (id_sessao, fase);
CREATE INDEX ix_tentativa_resultado   ON pesquisa.tentativa_comando (resultado);

COMMENT ON TABLE  pesquisa.tentativa_comando                     IS 'Cada comando digitado no terminal e o veredito do analisador lexico-sintatico (Eixo 3).';
COMMENT ON COLUMN pesquisa.tentativa_comando.entrada_normalizada IS 'Texto digitado, ja sanitizado e truncado. E TEXTO LIVRE: risco de dado pessoal incidental (ver docs/lgpd).';
COMMENT ON COLUMN pesquisa.tentativa_comando.tokens              IS 'Tokens produzidos pelo analisador lexico (VERBO, IDENTIFICADOR, NUMERO).';
COMMENT ON COLUMN pesquisa.tentativa_comando.resultado           IS 'Distingue erro lexico de sintatico -- a diferenca que a banca cobrou no apontamento 5.';

-- ---------------------------------------------------------------------------
-- Avaliacao de aprendizado (pre-teste e pos-teste, Eixo 8)
-- ---------------------------------------------------------------------------
CREATE TABLE pesquisa.avaliacao (
    id_avaliacao       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    id_sujeito         UUID         NOT NULL,
    momento            VARCHAR(10)  NOT NULL,
    versao_instrumento VARCHAR(20)  NOT NULL,
    aplicada_em        TIMESTAMPTZ  NOT NULL,
    total_itens        SMALLINT     NOT NULL,
    total_acertos      SMALLINT     NOT NULL,
    registrada_em      TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT fk_avaliacao_sujeito FOREIGN KEY (id_sujeito)
        REFERENCES pesquisa.sujeito (id_sujeito) ON DELETE CASCADE,
    CONSTRAINT uq_avaliacao_momento  UNIQUE (id_sujeito, momento),
    CONSTRAINT ck_avaliacao_momento  CHECK (momento IN ('PRE', 'POS')),
    CONSTRAINT ck_avaliacao_itens    CHECK (total_itens > 0),
    CONSTRAINT ck_avaliacao_acertos  CHECK (total_acertos >= 0 AND total_acertos <= total_itens)
);

COMMENT ON TABLE  pesquisa.avaliacao         IS 'Instrumento de conhecimento em ciberseguranca aplicado antes e depois das sessoes.';
COMMENT ON COLUMN pesquisa.avaliacao.momento IS 'PRE ou POS. O par por sujeito e o que alimenta o teste-t pareado / Wilcoxon.';

CREATE TABLE pesquisa.resposta_avaliacao (
    id_resposta       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    id_avaliacao      UUID        NOT NULL,
    numero_item       SMALLINT    NOT NULL,
    alternativa       VARCHAR(10) NOT NULL,
    correta           BOOLEAN     NOT NULL,
    tempo_resposta_ms INTEGER,

    CONSTRAINT fk_resposta_avaliacao FOREIGN KEY (id_avaliacao)
        REFERENCES pesquisa.avaliacao (id_avaliacao) ON DELETE CASCADE,
    CONSTRAINT uq_resposta_item  UNIQUE (id_avaliacao, numero_item),
    CONSTRAINT ck_resposta_item  CHECK (numero_item > 0),
    CONSTRAINT ck_resposta_tempo CHECK (tempo_resposta_ms IS NULL OR tempo_resposta_ms >= 0)
);

COMMENT ON TABLE pesquisa.resposta_avaliacao IS 'Resposta item a item, para analise de dificuldade por questao.';
