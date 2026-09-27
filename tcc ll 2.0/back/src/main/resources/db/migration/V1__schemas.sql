-- ===========================================================================
-- V1 - Organizacao do banco em tres schemas
--
-- A separacao nao e cosmetica: ela e o mecanismo que sustenta a conformidade
-- com a LGPD (Eixo 5). Dados que identificam pessoas ficam isolados dos dados
-- de pesquisa, e a ponte entre os dois vive numa unica tabela que pode ser
-- destruida para tornar a base irreversivelmente anonima (art. 12 da LGPD).
-- ===========================================================================

CREATE SCHEMA IF NOT EXISTS identidade;
CREATE SCHEMA IF NOT EXISTS pesquisa;
CREATE SCHEMA IF NOT EXISTS operacao;

COMMENT ON SCHEMA identidade IS
    'Dados pessoais dos participantes e registros de consentimento (TCLE). '
    'Acesso restrito. Nenhuma rota publica da API le deste schema.';

COMMENT ON SCHEMA pesquisa IS
    'Dados de pesquisa pseudonimizados: sessoes, eventos de telemetria, '
    'tentativas de comando e avaliacoes. Nao contem identificadores diretos.';

COMMENT ON SCHEMA operacao IS
    'Infraestrutura da aplicacao: chaves de API, auditoria, exportacoes '
    'e historico de migracoes do Flyway.';
