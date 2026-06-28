-- ============================================================
-- LOG DE INTERAÇÕES — Text-to-SQL: Medicamentos MS
-- ============================================================
-- Registra cada pergunta feita ao sistema para:
--   - Avaliação de acurácia (TCC)
--   - Análise de uso no teste alfa
--   - Auditoria e rastreabilidade
-- ============================================================

CREATE SCHEMA IF NOT EXISTS logs;

DROP TABLE IF EXISTS logs.interacoes;
CREATE TABLE logs.interacoes (
    id          bigserial       PRIMARY KEY,
    data_hora   timestamptz     DEFAULT now(),
    ip          text,
    pergunta    text,
    sql_gerado  text,
    sucesso     boolean,
    erro        text,
    tempo_ms    integer,
    qtd_linhas  integer
);

COMMENT ON TABLE logs.interacoes IS
'Log de todas as interações com o sistema Text-to-SQL.
Usado para avaliação de acurácia e análise de uso.';

COMMENT ON COLUMN logs.interacoes.ip          IS 'IP do usuário (identificação de sessão)';
COMMENT ON COLUMN logs.interacoes.pergunta    IS 'Pergunta em linguagem natural digitada pelo usuário';
COMMENT ON COLUMN logs.interacoes.sql_gerado  IS 'SQL gerado pelo Llama 3.1 8B';
COMMENT ON COLUMN logs.interacoes.sucesso     IS 'true = SQL executou com sucesso, false = erro';
COMMENT ON COLUMN logs.interacoes.erro        IS 'Mensagem de erro se sucesso = false';
COMMENT ON COLUMN logs.interacoes.tempo_ms    IS 'Tempo total de resposta em milissegundos';
COMMENT ON COLUMN logs.interacoes.qtd_linhas  IS 'Quantidade de linhas retornadas pela consulta';

-- View analítica para acompanhamento do teste alfa
CREATE OR REPLACE VIEW logs.v_resumo_uso AS
SELECT
    DATE(data_hora)                                     AS data,
    COUNT(*)                                            AS total_perguntas,
    COUNT(*) FILTER (WHERE sucesso = true)              AS acertos,
    COUNT(*) FILTER (WHERE sucesso = false)             AS erros,
    ROUND(
        COUNT(*) FILTER (WHERE sucesso = true)::numeric
        / NULLIF(COUNT(*), 0) * 100, 1
    )                                                   AS taxa_acerto_pct,
    ROUND(AVG(tempo_ms) FILTER (WHERE sucesso = true))  AS tempo_medio_ms,
    COUNT(DISTINCT ip)                                  AS usuarios_distintos
FROM logs.interacoes
GROUP BY DATE(data_hora)
ORDER BY data DESC;

-- View para análise de erros
CREATE OR REPLACE VIEW logs.v_erros AS
SELECT
    data_hora,
    ip,
    pergunta,
    sql_gerado,
    erro,
    tempo_ms
FROM logs.interacoes
WHERE sucesso = false
ORDER BY data_hora DESC;

-- View para perguntas mais frequentes
CREATE OR REPLACE VIEW logs.v_perguntas_frequentes AS
SELECT
    pergunta,
    COUNT(*)                                        AS total,
    COUNT(*) FILTER (WHERE sucesso = true)          AS acertos,
    ROUND(AVG(tempo_ms))                            AS tempo_medio_ms
FROM logs.interacoes
GROUP BY pergunta
ORDER BY total DESC;

\echo '✅ Schema de logs criado!'
\echo ''
\echo 'Tabela: logs.interacoes'
\echo 'Views:  logs.v_resumo_uso'
\echo '        logs.v_erros'
\echo '        logs.v_perguntas_frequentes'
\echo ''
\echo 'Para consultar durante o teste alfa:'
\echo '  SELECT * FROM logs.v_resumo_uso;'
\echo '  SELECT * FROM logs.v_erros;'
\echo '  SELECT * FROM logs.v_perguntas_frequentes LIMIT 20;'

-- ============================================================
-- TABELA DE AVALIAÇÕES DE SATISFAÇÃO (Teste Alfa)
-- ============================================================

CREATE TABLE IF NOT EXISTS logs.avaliacoes (
    id                    bigserial       PRIMARY KEY,
    data_hora             timestamptz     DEFAULT now(),
    id_interacao          bigint          REFERENCES logs.interacoes(id),
    pergunta_contexto     text,
    correspondeu          text,           -- 'Sim' | 'Parcialmente' | 'Não'
    tentativas            integer,        -- 1 | 2 | 3 (3 = "3 ou mais")
    dificuldade_pergunta  boolean,        -- true = teve dificuldade em formular
    grafico_util          text,           -- 'Sim' | 'Não' | 'Não gerou gráfico'
    usaria                boolean,        -- true = usaria no trabalho
    substituiria          text,           -- 'Sim' | 'Não' | 'Não sei'
    comentario            text
);

COMMENT ON TABLE logs.avaliacoes IS
'Avaliações de satisfação coletadas durante o teste alfa.
Campos desenhados para cruzamento com logs.interacoes.';

COMMENT ON COLUMN logs.avaliacoes.correspondeu         IS 'A resposta correspondeu ao que o usuário queria? Sim/Parcialmente/Não';
COMMENT ON COLUMN logs.avaliacoes.tentativas           IS 'Quantas tentativas precisou para obter resposta útil';
COMMENT ON COLUMN logs.avaliacoes.dificuldade_pergunta IS 'Teve dificuldade em formular a pergunta?';
COMMENT ON COLUMN logs.avaliacoes.grafico_util         IS 'O gráfico ajudou? Sim/Não/Não gerou gráfico';
COMMENT ON COLUMN logs.avaliacoes.usaria               IS 'Usaria a ferramenta no trabalho?';
COMMENT ON COLUMN logs.avaliacoes.substituiria         IS 'Substituiria solicitação ao TI? Sim/Não/Não sei';

-- View de resumo das avaliações
CREATE OR REPLACE VIEW logs.v_resumo_avaliacoes AS
SELECT
    COUNT(*)                                                        AS total_respostas,
    -- Correspondência da resposta
    COUNT(*) FILTER (WHERE correspondeu = 'Sim')                    AS resposta_correta,
    COUNT(*) FILTER (WHERE correspondeu = 'Parcialmente')           AS resposta_parcial,
    COUNT(*) FILTER (WHERE correspondeu = 'Não')                    AS resposta_errada,
    -- Tentativas
    ROUND(AVG(tentativas), 1)                                       AS media_tentativas,
    COUNT(*) FILTER (WHERE tentativas = 1)                          AS resolveu_na_primeira,
    -- Dificuldade de formular
    COUNT(*) FILTER (WHERE dificuldade_pergunta = true)             AS teve_dificuldade_formular,
    -- Gráfico
    COUNT(*) FILTER (WHERE grafico_util = 'Sim')                    AS grafico_util,
    COUNT(*) FILTER (WHERE grafico_util = 'Não gerou gráfico')      AS sem_grafico,
    -- Adoção
    COUNT(*) FILTER (WHERE usaria = true)                           AS usariam_no_trabalho,
    COUNT(*) FILTER (WHERE substituiria = 'Sim')                    AS substituiria_ti,
    -- Percentuais
    ROUND(COUNT(*) FILTER (WHERE correspondeu = 'Sim')::numeric
        / NULLIF(COUNT(*), 0) * 100, 1)                             AS pct_correspondeu,
    ROUND(COUNT(*) FILTER (WHERE usaria = true)::numeric
        / NULLIF(COUNT(*), 0) * 100, 1)                             AS pct_usaria
FROM logs.avaliacoes;

-- View de cruzamento: avaliação + log de interação
CREATE OR REPLACE VIEW logs.v_cruzamento AS
SELECT
    a.id                        AS id_avaliacao,
    a.data_hora                 AS data_avaliacao,
    a.id_interacao,
    i.sucesso                   AS log_sucesso,
    i.tempo_ms                  AS log_tempo_ms,
    i.qtd_linhas                AS log_qtd_linhas,
    i.sql_gerado                AS log_sql,
    a.pergunta_contexto,
    a.correspondeu,
    a.tentativas,
    a.dificuldade_pergunta,
    a.grafico_util,
    a.usaria,
    a.substituiria,
    a.comentario
FROM logs.avaliacoes a
LEFT JOIN logs.interacoes i ON i.id = a.id_interacao
ORDER BY a.data_hora DESC;

COMMENT ON VIEW logs.v_cruzamento IS
'Cruzamento entre avaliação do usuário e log técnico da interação.
Permite comparar percepção do usuário (correspondeu?) com resultado real (sucesso=true).';

\echo '✅ Tabela logs.avaliacoes criada!'
\echo 'View:   logs.v_resumo_avaliacoes'
\echo '        logs.v_cruzamento'
