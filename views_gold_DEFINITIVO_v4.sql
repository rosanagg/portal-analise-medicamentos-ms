-- ============================================================
-- CAMADA GOLD — SCRIPT DEFINITIVO
-- TCC MBA ENAP — Text-to-SQL: Medicamentos MS
-- ============================================================
-- Substitui todos os scripts anteriores:
--   views_text_to_sql.sql
--   views_text_to_sql_FINAL.sql
--   fix_views_comparacao.sql
--   views_gold_completo.sql
--
-- Execute com:
-- Get-Content views_gold_DEFINITIVO.sql | docker exec -i tcc-postgres psql -U postgres -d tcc_v2
--
-- Hierarquia de dependências (NÃO ALTERAR ORDEM):
--   silver.v_ep2_itens_ms_validos
--   silver.v_ep1_contratos_area_norm
--   silver.v_precos_praticados
--     └── gold.f_ms_itens_contrato         ← fato base
--           ├── gold.m_ms_item_mes_area    ← mart mensal
--           │     └── gold.m_praticados_catmat_mes
--           │           └── gold.v_ms_vs_praticados_catmat_mes
--           ├── gold.v_concentracao_fornecedores
--           └── gold.v_marcas_por_catmat
--                 └── gold.v_ms_com_marcas
-- ============================================================

\set ON_ERROR_STOP on
\echo '============================================================'
\echo 'RECRIANDO CAMADA GOLD — SCRIPT DEFINITIVO'
\echo '============================================================'
\echo ''

-- ============================================================
-- PASSO 1: DROPAR TODAS AS VIEWS AI_
-- (em CASCADE para não quebrar dependências)
-- ============================================================
\echo '🗑️  Dropando views ai_...'

DROP VIEW IF EXISTS gold.ai_visao_geral                     CASCADE;
DROP VIEW IF EXISTS gold.ai_gastos_por_ano                  CASCADE;
DROP VIEW IF EXISTS gold.ai_gastos_por_mes                  CASCADE;
DROP VIEW IF EXISTS gold.ai_sazonalidade                    CASCADE;
DROP VIEW IF EXISTS gold.ai_gastos_por_secretaria           CASCADE;
DROP VIEW IF EXISTS gold.ai_gastos_por_departamento         CASCADE;
DROP VIEW IF EXISTS gold.ai_evolucao_por_secretaria         CASCADE;
DROP VIEW IF EXISTS gold.ai_evolucao_por_departamento       CASCADE;
DROP VIEW IF EXISTS gold.ai_top_medicamentos_valor          CASCADE;
DROP VIEW IF EXISTS gold.ai_top_medicamentos_quantidade     CASCADE;
DROP VIEW IF EXISTS gold.ai_historico_medicamento           CASCADE;
DROP VIEW IF EXISTS gold.ai_medicamento_por_secretaria      CASCADE;
DROP VIEW IF EXISTS gold.ai_variacao_preco_medicamento      CASCADE;
DROP VIEW IF EXISTS gold.ai_medicamentos_fornecedor_unico   CASCADE;
DROP VIEW IF EXISTS gold.ai_top_fornecedores                CASCADE;
DROP VIEW IF EXISTS gold.ai_fornecedores_por_medicamento    CASCADE;
DROP VIEW IF EXISTS gold.ai_historico_fornecedor            CASCADE;
DROP VIEW IF EXISTS gold.ai_fornecedor_medicamento_ano      CASCADE;
DROP VIEW IF EXISTS gold.ai_concentracao_mercado            CASCADE;
DROP VIEW IF EXISTS gold.ai_alta_concentracao               CASCADE;
DROP VIEW IF EXISTS gold.ai_top_marcas                      CASCADE;
DROP VIEW IF EXISTS gold.ai_marcas_por_medicamento          CASCADE;
DROP VIEW IF EXISTS gold.ai_modalidade_por_ano              CASCADE;
DROP VIEW IF EXISTS gold.ai_modalidade_por_secretaria       CASCADE;
DROP VIEW IF EXISTS gold.ai_modalidade_preco_comparado      CASCADE;
DROP VIEW IF EXISTS gold.ai_ms_vs_brasil                    CASCADE;
DROP VIEW IF EXISTS gold.ai_ms_paga_mais_caro               CASCADE;
DROP VIEW IF EXISTS gold.ai_ms_paga_mais_barato             CASCADE;
DROP VIEW IF EXISTS gold.ai_comparacao_preco_ms_ufs         CASCADE;
DROP VIEW IF EXISTS gold.ai_judicializacao_evolucao         CASCADE;
DROP VIEW IF EXISTS gold.ai_judicializacao_top_medicamentos CASCADE;
DROP VIEW IF EXISTS gold.ai_judicializacao_vs_programatico  CASCADE;
DROP VIEW IF EXISTS gold.ai_portfolio_fornecedor             CASCADE;
DROP VIEW IF EXISTS gold.ai_evolucao_secretaria_modalidade   CASCADE;
DROP VIEW IF EXISTS gold.ai_top_fornecedores_secretaria      CASCADE;

\echo '✅ Views ai_ dropadas!'
\echo ''

-- ============================================================
-- BLOCO 1 — VISÃO GERAL
-- ============================================================
\echo '📊 Bloco 1: Visão Geral...'

CREATE VIEW gold.ai_visao_geral AS
SELECT
    COUNT(*)                                        AS total_itens_contratados,
    COUNT(DISTINCT codigo_item_catalogo)            AS total_itens_diferentes,
    COUNT(DISTINCT ni_fornecedor)                   AS total_fornecedores,
    ROUND(SUM(valor_total_item)::numeric, 2)        AS valor_total_contratado,
    ROUND(SUM(quantidade_item)::numeric, 2)         AS quantidade_total,
    ROUND(AVG(valor_unitario_item)::numeric, 2)     AS preco_medio_unitario,
    MIN(data_ref_contrato_ts::date)                 AS primeira_compra,
    MAX(data_ref_contrato_ts::date)                 AS ultima_compra
FROM gold.f_ms_itens_contrato;

COMMENT ON VIEW gold.ai_visao_geral IS
'Visão geral do MS — KPIs principais.
Perguntas: "Resumo geral", "Total gasto pelo MS", "Quantos fornecedores?"';

-- ============================================================
-- BLOCO 2 — GASTOS TEMPORAIS
-- ============================================================
\echo '📊 Bloco 2: Gastos Temporais...'

CREATE VIEW gold.ai_gastos_por_ano AS
SELECT
    EXTRACT(YEAR FROM ano_mes_contrato)::int        AS ano,
    COUNT(DISTINCT codigo_item_catalogo)            AS itens_diferentes,
    COUNT(*)                                        AS registros,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total,
    ROUND(SUM(qtd_contratada)::numeric, 2)          AS quantidade_total,
    ROUND(AVG(vl_unit_mediana_contrato)::numeric, 2) AS preco_mediano
FROM gold.m_ms_item_mes_area
WHERE ano_mes_contrato IS NOT NULL
GROUP BY EXTRACT(YEAR FROM ano_mes_contrato)::int
ORDER BY ano;

COMMENT ON VIEW gold.ai_gastos_por_ano IS
'Gastos anuais do MS.
Perguntas: "Gastos por ano", "Quanto gastou em 2024?", "Evolução anual"';

-- ----
CREATE VIEW gold.ai_gastos_por_mes AS
SELECT
    ano_mes_contrato                                AS ano_mes,
    EXTRACT(YEAR FROM ano_mes_contrato)::int        AS ano,
    EXTRACT(MONTH FROM ano_mes_contrato)::int       AS mes,
    COUNT(DISTINCT codigo_item_catalogo)            AS itens_diferentes,
    COUNT(*)                                        AS registros,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total,
    ROUND(SUM(qtd_contratada)::numeric, 2)          AS quantidade_total,
    ROUND(AVG(vl_unit_mediana_contrato)::numeric, 2) AS preco_mediano
FROM gold.m_ms_item_mes_area
WHERE ano_mes_contrato IS NOT NULL
GROUP BY ano_mes_contrato
ORDER BY ano_mes_contrato;

COMMENT ON VIEW gold.ai_gastos_por_mes IS
'Gastos mensais do MS.
Perguntas: "Gastos por mês", "Evolução mensal 2024", "Mês que mais gastou"';

-- ----
CREATE VIEW gold.ai_sazonalidade AS
SELECT
    EXTRACT(MONTH FROM ano_mes_contrato)::int       AS mes,
    TO_CHAR(DATE '2000-01-01' + (EXTRACT(MONTH FROM ano_mes_contrato)::int - 1) * INTERVAL '1 month', 'Month') AS nome_mes,
    COUNT(DISTINCT EXTRACT(YEAR FROM ano_mes_contrato)) AS qtd_anos,
    ROUND(AVG(vl_contratado)::numeric, 2)           AS valor_medio,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total,
    ROUND(SUM(qtd_contratada)::numeric, 2)          AS quantidade_total
FROM gold.m_ms_item_mes_area
WHERE ano_mes_contrato IS NOT NULL
GROUP BY EXTRACT(MONTH FROM ano_mes_contrato)::int,
         TO_CHAR(DATE '2000-01-01' + (EXTRACT(MONTH FROM ano_mes_contrato)::int - 1) * INTERVAL '1 month', 'Month')
ORDER BY mes;

COMMENT ON VIEW gold.ai_sazonalidade IS
'Padrão de compras por mês (sazonalidade).
Perguntas: "Sazonalidade", "Qual mês compra mais?", "Padrão mensal"';

-- ============================================================
-- BLOCO 3 — SECRETARIAS E DEPARTAMENTOS
-- ============================================================
\echo '📊 Bloco 3: Secretarias e Departamentos...'

CREATE VIEW gold.ai_gastos_por_secretaria AS
SELECT
    COALESCE(secretaria, 'Não identificado')        AS secretaria,
    COUNT(DISTINCT codigo_item_catalogo)            AS itens_diferentes,
    COUNT(*)                                        AS total_itens,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total,
    ROUND(SUM(qtd_contratada)::numeric, 2)          AS quantidade_total,
    ROUND(AVG(vl_unit_mediana_contrato)::numeric, 2) AS preco_mediano
FROM gold.m_ms_item_mes_area
GROUP BY secretaria
ORDER BY valor_total DESC NULLS LAST;

COMMENT ON VIEW gold.ai_gastos_por_secretaria IS
'Gastos totais acumulados por secretaria.
Perguntas: "Qual secretaria gasta mais?", "Ranking secretarias", "Total por área"';

-- ----
CREATE VIEW gold.ai_gastos_por_departamento AS
SELECT
    COALESCE(secretaria, 'Não identificado')        AS secretaria,
    COALESCE(departamento, 'Não identificado')      AS departamento,
    COUNT(DISTINCT codigo_item_catalogo)            AS itens_diferentes,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total,
    ROUND(SUM(qtd_contratada)::numeric, 2)          AS quantidade_total,
    ROUND(AVG(vl_unit_mediana_contrato)::numeric, 2) AS preco_mediano
FROM gold.m_ms_item_mes_area
GROUP BY secretaria, departamento
ORDER BY valor_total DESC NULLS LAST;

COMMENT ON VIEW gold.ai_gastos_por_departamento IS
'Gastos totais por departamento dentro de cada secretaria.
Perguntas: "Gastos por departamento", "Breakdown DAF", "Ranking departamentos"';

-- ----
CREATE VIEW gold.ai_evolucao_por_secretaria AS
SELECT
    EXTRACT(YEAR FROM ano_mes_contrato)::int        AS ano,
    COALESCE(secretaria, 'Não identificado')        AS secretaria,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total,
    ROUND(SUM(qtd_contratada)::numeric, 2)          AS quantidade_total
FROM gold.m_ms_item_mes_area
WHERE ano_mes_contrato IS NOT NULL
GROUP BY EXTRACT(YEAR FROM ano_mes_contrato)::int, secretaria
ORDER BY ano, valor_total DESC;

COMMENT ON VIEW gold.ai_evolucao_por_secretaria IS
'Evolução ANUAL dos gastos por secretaria.
Perguntas: "Evolução SAPS por ano", "Histórico secretarias", "Crescimento por área"';

-- ----
CREATE VIEW gold.ai_evolucao_por_departamento AS
SELECT
    EXTRACT(YEAR FROM ano_mes_contrato)::int        AS ano,
    COALESCE(secretaria, 'Não identificado')        AS secretaria,
    COALESCE(departamento, 'Não identificado')      AS departamento,
    COUNT(DISTINCT codigo_item_catalogo)            AS itens_diferentes,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total,
    ROUND(SUM(qtd_contratada)::numeric, 2)          AS quantidade_total,
    ROUND(AVG(vl_unit_mediana_contrato)::numeric, 2) AS preco_mediano
FROM gold.m_ms_item_mes_area
WHERE ano_mes_contrato IS NOT NULL
GROUP BY EXTRACT(YEAR FROM ano_mes_contrato)::int, secretaria, departamento
ORDER BY ano, valor_total DESC;

COMMENT ON VIEW gold.ai_evolucao_por_departamento IS
'Evolução ANUAL dos gastos por departamento.
Perguntas: "Evolução DAF por ano", "Histórico DJUD", "Crescimento departamentos"';

-- ============================================================
-- BLOCO 4 — MEDICAMENTOS
-- ============================================================
\echo '📊 Bloco 4: Medicamentos...'

CREATE VIEW gold.ai_top_medicamentos_valor AS
SELECT
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    ROUND(SUM(valor_total_item)::numeric, 2)        AS valor_total,
    ROUND(SUM(quantidade_item)::numeric, 2)         AS quantidade_total,
    COUNT(*)                                        AS itens_contratados,
    COUNT(DISTINCT ni_fornecedor)                   AS fornecedores,
    ROUND(AVG(valor_unitario_item)::numeric, 2)     AS preco_medio
FROM gold.f_ms_itens_contrato
GROUP BY codigo_item_catalogo
ORDER BY SUM(valor_total_item) DESC
LIMIT 100;

COMMENT ON VIEW gold.ai_top_medicamentos_valor IS
'Top 100 medicamentos por valor total gasto.
Perguntas: "Medicamentos mais caros", "Top 10 por valor", "O que o MS mais gasta?"';

-- ----
CREATE VIEW gold.ai_top_medicamentos_quantidade AS
SELECT
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    ROUND(SUM(quantidade_item)::numeric, 2)         AS quantidade_total,
    ROUND(SUM(valor_total_item)::numeric, 2)        AS valor_total,
    COUNT(*)                                        AS itens_contratados,
    ROUND(AVG(valor_unitario_item)::numeric, 2)     AS preco_medio
FROM gold.f_ms_itens_contrato
GROUP BY codigo_item_catalogo
ORDER BY SUM(quantidade_item) DESC
LIMIT 100;

COMMENT ON VIEW gold.ai_top_medicamentos_quantidade IS
'Top 100 medicamentos por quantidade comprada.
Perguntas: "Medicamentos mais comprados", "Maior volume", "Top quantidade"';

-- ----
CREATE VIEW gold.ai_historico_medicamento AS
SELECT
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    ano_mes_contrato                                AS ano_mes,
    EXTRACT(YEAR FROM ano_mes_contrato)::int        AS ano,
    EXTRACT(MONTH FROM ano_mes_contrato)::int       AS mes,
    COALESCE(secretaria, 'Não identificado')        AS secretaria,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total,
    ROUND(SUM(qtd_contratada)::numeric, 2)          AS quantidade_total,
    ROUND(AVG(vl_unit_mediana_contrato)::numeric, 2) AS preco_mediano,
    COUNT(*)                                        AS registros
FROM gold.m_ms_item_mes_area
WHERE ano_mes_contrato IS NOT NULL
GROUP BY codigo_item_catalogo, ano_mes_contrato, secretaria
ORDER BY codigo_item_catalogo, ano_mes_contrato;

COMMENT ON VIEW gold.ai_historico_medicamento IS
'Histórico mensal de medicamento ESPECÍFICO por secretaria — sempre filtrar por catmat ou medicamento ILIKE.
Perguntas: "Histórico insulina", "Evolução preço dipirona", "Compras mensais adalimumabe"';

-- ----
CREATE VIEW gold.ai_medicamento_por_secretaria AS
SELECT
    COALESCE(secretaria, 'Não identificado')        AS secretaria,
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    COUNT(*)                                        AS registros,
    ROUND(SUM(valor_total_item)::numeric, 2)        AS valor_total,
    ROUND(SUM(quantidade_item)::numeric, 2)         AS quantidade_total,
    ROUND(AVG(valor_unitario_item)::numeric, 2)     AS preco_medio
FROM gold.f_ms_itens_contrato
GROUP BY secretaria, codigo_item_catalogo
ORDER BY secretaria, SUM(valor_total_item) DESC;

COMMENT ON VIEW gold.ai_medicamento_por_secretaria IS
'Quais medicamentos cada secretaria mais compra.
Perguntas: "Medicamentos da SCTIE", "O que SAPS mais compra?", "Top medicamentos por área"';

-- ----
CREATE VIEW gold.ai_variacao_preco_medicamento AS
SELECT
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    EXTRACT(YEAR FROM ano_mes_contrato)::int        AS ano,
    COUNT(*)                                        AS registros,
    ROUND(AVG(vl_unit_mediana_contrato)::numeric, 4) AS preco_mediano,
    ROUND(AVG(vl_unit_medio_contrato)::numeric, 4)  AS preco_medio,
    ROUND(MIN(vl_unit_min_contrato)::numeric, 4)    AS preco_minimo,
    ROUND(MAX(vl_unit_max_contrato)::numeric, 4)    AS preco_maximo
FROM gold.m_ms_item_mes_area
WHERE ano_mes_contrato IS NOT NULL
GROUP BY codigo_item_catalogo, EXTRACT(YEAR FROM ano_mes_contrato)::int
HAVING COUNT(*) >= 2
ORDER BY codigo_item_catalogo, ano;

COMMENT ON VIEW gold.ai_variacao_preco_medicamento IS
'Evolução do preço unitário de medicamentos por ano.
Perguntas: "Como evoluiu o preço da insulina?", "Variação de preço por ano", "Inflação medicamentos"';

-- ----
CREATE VIEW gold.ai_medicamentos_fornecedor_unico AS
SELECT
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    COUNT(DISTINCT ni_fornecedor)                   AS qtd_fornecedores,
    MAX(nome_fornecedor)                            AS fornecedor,
    ROUND(SUM(valor_total_item)::numeric, 2)        AS valor_total,
    ROUND(SUM(quantidade_item)::numeric, 2)         AS quantidade_total,
    ROUND(AVG(valor_unitario_item)::numeric, 2)     AS preco_medio
FROM gold.f_ms_itens_contrato
GROUP BY codigo_item_catalogo
HAVING COUNT(DISTINCT ni_fornecedor) = 1
ORDER BY SUM(valor_total_item) DESC;

COMMENT ON VIEW gold.ai_medicamentos_fornecedor_unico IS
'Medicamentos com apenas 1 fornecedor no MS (risco de dependência).
Perguntas: "Medicamentos com fornecedor único", "Risco de monopólio", "Dependência de fornecedor"';

-- ============================================================
-- BLOCO 5 — FORNECEDORES
-- ============================================================
\echo '📊 Bloco 5: Fornecedores...'

CREATE VIEW gold.ai_top_fornecedores AS
SELECT
    ni_fornecedor,
    MAX(nome_fornecedor)                            AS fornecedor,
    COUNT(DISTINCT codigo_item_catalogo)            AS itens_diferentes,
    COUNT(*)                                        AS itens_fornecidos,
    ROUND(SUM(valor_total_item)::numeric, 2)        AS valor_total,
    ROUND(SUM(quantidade_item)::numeric, 2)         AS quantidade_total,
    ROUND(AVG(valor_unitario_item)::numeric, 2)     AS preco_medio
FROM gold.f_ms_itens_contrato
WHERE ni_fornecedor IS NOT NULL
GROUP BY ni_fornecedor
ORDER BY SUM(valor_total_item) DESC
LIMIT 100;

COMMENT ON VIEW gold.ai_top_fornecedores IS
'Top 100 fornecedores por valor fornecido ao MS.
Perguntas: "Maiores fornecedores", "Quem mais vende pro MS?", "Top empresas"';

-- ----
CREATE VIEW gold.ai_fornecedores_por_medicamento AS
SELECT
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    ni_fornecedor,
    MAX(nome_fornecedor)                            AS fornecedor,
    COUNT(*)                                        AS itens_fornecidos,
    ROUND(SUM(valor_total_item)::numeric, 2)        AS valor_total,
    ROUND(SUM(quantidade_item)::numeric, 2)         AS quantidade_total,
    ROUND(AVG(valor_unitario_item)::numeric, 2)     AS preco_medio,
    MIN(data_ref_contrato_ts::date)                 AS primeira_compra,
    MAX(data_ref_contrato_ts::date)                 AS ultima_compra
FROM gold.f_ms_itens_contrato
WHERE ni_fornecedor IS NOT NULL
GROUP BY codigo_item_catalogo, ni_fornecedor
ORDER BY codigo_item_catalogo, SUM(valor_total_item) DESC;

COMMENT ON VIEW gold.ai_fornecedores_por_medicamento IS
'Fornecedores de cada medicamento — sempre filtrar por catmat ou medicamento ILIKE.
Perguntas: "Quem fornece insulina?", "Fornecedores dipirona", "Empresas que vendem X"';

-- ----
CREATE VIEW gold.ai_historico_fornecedor AS
SELECT
    ni_fornecedor,
    MAX(nome_fornecedor)                            AS fornecedor,
    EXTRACT(YEAR FROM ano_mes_contrato)::int        AS ano,
    COUNT(DISTINCT numero_contrato)                 AS contratos,
    COUNT(DISTINCT codigo_item_catalogo)            AS itens_diferentes,
    ROUND(SUM(valor_total_item)::numeric, 2)        AS valor_total,
    ROUND(SUM(quantidade_item)::numeric, 2)         AS quantidade_total,
    ROUND(AVG(valor_unitario_item)::numeric, 4)     AS preco_medio
FROM gold.f_ms_itens_contrato
WHERE ano_mes_contrato IS NOT NULL
  AND ni_fornecedor IS NOT NULL
GROUP BY ni_fornecedor, EXTRACT(YEAR FROM ano_mes_contrato)::int
ORDER BY ano, SUM(valor_total_item) DESC;

COMMENT ON VIEW gold.ai_historico_fornecedor IS
'Evolução anual de cada fornecedor.
Perguntas: "Histórico fornecedor X por ano", "Crescimento fornecedor", "Evolução vendas"';

-- ----
CREATE VIEW gold.ai_fornecedor_medicamento_ano AS
SELECT
    ni_fornecedor,
    MAX(nome_fornecedor)                            AS fornecedor,
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    EXTRACT(YEAR FROM ano_mes_contrato)::int        AS ano,
    COUNT(*)                                        AS registros,
    ROUND(SUM(quantidade_item)::numeric, 2)         AS quantidade_total,
    ROUND(SUM(valor_total_item)::numeric, 2)        AS valor_total,
    ROUND(AVG(valor_unitario_item)::numeric, 4)     AS preco_medio_unitario,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY valor_unitario_item)::numeric, 4
    )                                               AS preco_mediano_unitario
FROM gold.f_ms_itens_contrato
WHERE ano_mes_contrato IS NOT NULL
  AND ni_fornecedor IS NOT NULL
GROUP BY ni_fornecedor, codigo_item_catalogo, EXTRACT(YEAR FROM ano_mes_contrato)::int
ORDER BY ano, codigo_item_catalogo, SUM(valor_total_item) DESC;

COMMENT ON VIEW gold.ai_fornecedor_medicamento_ano IS
'Fornecedor + medicamento + ano: quantidade, valor total, preço médio e mediano.
Perguntas: "Histórico insulina por fornecedor e ano", "Comparar fornecedores de X ao longo dos anos"';

-- ----
CREATE VIEW gold.ai_concentracao_mercado AS
SELECT
    v.codigo_item_catalogo                          AS catmat,
    MAX(f.descricao_item_contrato)                  AS medicamento,
    v.qtd_fornecedores,
    v.nivel_concentracao,
    ROUND(v.hhi::numeric, 4)                        AS indice_hhi,
    ROUND(v.maior_share::numeric * 100, 2)          AS percentual_maior_fornecedor,
    v.principais_fornecedores
FROM gold.v_concentracao_fornecedores v
LEFT JOIN gold.f_ms_itens_contrato f
    ON f.codigo_item_catalogo = v.codigo_item_catalogo
GROUP BY v.codigo_item_catalogo, v.qtd_fornecedores, v.nivel_concentracao,
         v.hhi, v.maior_share, v.principais_fornecedores
ORDER BY v.hhi DESC;

COMMENT ON VIEW gold.ai_concentracao_mercado IS
'Concentração de mercado por medicamento (Índice HHI).
Perguntas: "Concentração de mercado", "Monopólios", "Índice HHI", "Competição"';

-- ----
CREATE VIEW gold.ai_alta_concentracao AS
SELECT
    codigo_item_catalogo                            AS catmat,
    qtd_fornecedores,
    ROUND(hhi::numeric, 4)                          AS indice_hhi,
    ROUND(maior_share::numeric * 100, 2)            AS percentual_maior,
    principais_fornecedores
FROM gold.v_concentracao_fornecedores
WHERE nivel_concentracao = 'Alta concentração'
ORDER BY hhi DESC;

COMMENT ON VIEW gold.ai_alta_concentracao IS
'Medicamentos com alta concentração de mercado (poucos fornecedores).
Perguntas: "Monopólios", "Fornecedor único", "Baixa competição"';

-- ============================================================
-- BLOCO 6 — MARCAS
-- ============================================================
\echo '📊 Bloco 6: Marcas...'

CREATE VIEW gold.ai_top_marcas AS
SELECT
    marca,
    COUNT(DISTINCT codigo_item_catalogo)            AS itens_diferentes,
    SUM(qtd_compras)                                AS total_compras,
    ROUND(AVG(preco_medio_marca)::numeric, 2)       AS preco_medio
FROM gold.v_marcas_por_catmat
WHERE marca IS NOT NULL AND marca <> ''
GROUP BY marca
ORDER BY SUM(qtd_compras) DESC
LIMIT 100;

COMMENT ON VIEW gold.ai_top_marcas IS
'Top 100 marcas mais compradas no Brasil.
Perguntas: "Marcas mais usadas", "Top marcas", "Principais fabricantes"';

-- ----
CREATE VIEW gold.ai_marcas_por_medicamento AS
SELECT
    codigo_item_catalogo                            AS catmat,
    marca,
    qtd_compras                                     AS compras_brasil,
    qtd_orgaos_usam                                 AS orgaos_usam,
    ROUND(preco_medio_marca::numeric, 2)            AS preco_medio,
    ROUND(preco_min_marca::numeric, 2)              AS preco_minimo,
    ROUND(preco_max_marca::numeric, 2)              AS preco_maximo,
    ROUND(qtd_total_comprada::numeric, 2)           AS quantidade_total
FROM gold.v_marcas_por_catmat
WHERE marca IS NOT NULL
ORDER BY codigo_item_catalogo, qtd_compras DESC;

COMMENT ON VIEW gold.ai_marcas_por_medicamento IS
'Marcas disponíveis para cada medicamento — sempre filtrar por catmat ou ILIKE.
Perguntas: "Marcas de dipirona", "Quais marcas CATMAT X?", "Opções de fabricante"';

-- ============================================================
-- BLOCO 7 — MODALIDADE DE AQUISIÇÃO
-- ============================================================
\echo '📊 Bloco 7: Modalidade de Aquisição...'

CREATE VIEW gold.ai_modalidade_por_ano AS
SELECT
    c.nome_modalidade_compra                        AS modalidade,
    EXTRACT(YEAR FROM f.data_vigencia_inicial_ts)::int AS ano,
    COUNT(DISTINCT f.numero_contrato)               AS contratos,
    COUNT(*)                                        AS itens,
    ROUND(SUM(f.valor_total_item)::numeric, 2)      AS valor_total,
    ROUND(AVG(f.valor_unitario_item)::numeric, 4)   AS preco_medio_unitario
FROM gold.f_ms_itens_contrato f
JOIN raw.ep1_contratos_ms c ON f.numero_contrato = c.numero_contrato
WHERE f.data_vigencia_inicial_ts IS NOT NULL
  AND c.nome_modalidade_compra IS NOT NULL
GROUP BY c.nome_modalidade_compra, EXTRACT(YEAR FROM f.data_vigencia_inicial_ts)::int
ORDER BY ano, SUM(f.valor_total_item) DESC;

COMMENT ON VIEW gold.ai_modalidade_por_ano IS
'Modalidades de aquisição por ano: Pregão, Dispensa, Inexigibilidade.
Perguntas: "Quais modalidades o MS usa?", "Evolução pregão por ano", "Dispensa vs Pregão"';

-- ----
CREATE VIEW gold.ai_modalidade_por_secretaria AS
SELECT
    COALESCE(f.secretaria, 'Não identificado')      AS secretaria,
    c.nome_modalidade_compra                        AS modalidade,
    COUNT(DISTINCT f.numero_contrato)               AS contratos,
    ROUND(SUM(f.valor_total_item)::numeric, 2)      AS valor_total,
    ROUND(AVG(f.valor_unitario_item)::numeric, 4)   AS preco_medio_unitario
FROM gold.f_ms_itens_contrato f
JOIN raw.ep1_contratos_ms c ON f.numero_contrato = c.numero_contrato
WHERE c.nome_modalidade_compra IS NOT NULL
GROUP BY f.secretaria, c.nome_modalidade_compra
ORDER BY f.secretaria, SUM(f.valor_total_item) DESC;

COMMENT ON VIEW gold.ai_modalidade_por_secretaria IS
'Modalidades de aquisição por secretaria.
Perguntas: "Qual modalidade SCTIE usa mais?", "Pregão vs dispensa por secretaria"';

-- ----
CREATE VIEW gold.ai_modalidade_preco_comparado AS
SELECT
    f.codigo_item_catalogo                          AS catmat,
    MAX(f.descricao_item_contrato)                  AS medicamento,
    c.nome_modalidade_compra                        AS modalidade,
    COUNT(*)                                        AS registros,
    ROUND(AVG(f.valor_unitario_item)::numeric, 4)   AS preco_medio,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY f.valor_unitario_item::float
        )::numeric, 4
    )                                               AS preco_mediano,
    ROUND(SUM(f.valor_total_item)::numeric, 2)      AS valor_total
FROM gold.f_ms_itens_contrato f
JOIN raw.ep1_contratos_ms c ON f.numero_contrato = c.numero_contrato
WHERE c.nome_modalidade_compra IS NOT NULL
  AND f.valor_unitario_item > 0
GROUP BY f.codigo_item_catalogo, c.nome_modalidade_compra
HAVING COUNT(*) >= 3
ORDER BY f.codigo_item_catalogo, SUM(f.valor_total_item) DESC;

COMMENT ON VIEW gold.ai_modalidade_preco_comparado IS
'Comparação de preços por modalidade de aquisição para cada medicamento.
Perguntas: "Pregão é mais barato que dispensa?", "Preço por modalidade insulina"';

-- ============================================================
-- BLOCO 8 — COMPARAÇÃO MS vs BRASIL
-- ============================================================
\echo '📊 Bloco 8: Comparação MS vs Brasil...'

CREATE VIEW gold.ai_ms_vs_brasil AS
SELECT
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    ROUND(AVG(vl_unit_mediana_contrato)::numeric, 2) AS preco_ms,
    ROUND(AVG(preco_unit_mediana)::numeric, 2)      AS preco_brasil,
    ROUND(AVG(diff_mediana_ms_vs_br)::numeric, 2)   AS diferenca,
    ROUND(AVG(COALESCE(pct_ms_vs_mediana_br, 0) * 100)::numeric, 2) AS percentual_diferenca,
    CASE
        WHEN AVG(COALESCE(pct_ms_vs_mediana_br, 0)) > 0.1  THEN 'MS paga mais caro'
        WHEN AVG(COALESCE(pct_ms_vs_mediana_br, 0)) < -0.1 THEN 'MS paga mais barato'
        ELSE 'Preços similares'
    END                                             AS classificacao,
    COUNT(*)                                        AS meses_comparados
FROM gold.v_ms_vs_praticados_catmat_mes
WHERE preco_unit_mediana IS NOT NULL
GROUP BY codigo_item_catalogo
HAVING COUNT(*) >= 3
ORDER BY AVG(diff_mediana_ms_vs_br) DESC NULLS LAST;

COMMENT ON VIEW gold.ai_ms_vs_brasil IS
'Comparação MS vs preços praticados no Brasil — classificação por medicamento.
Perguntas: "MS paga mais caro?", "Comparar com mercado", "Preço MS vs outros órgãos"';

-- ----
CREATE VIEW gold.ai_ms_paga_mais_caro AS
SELECT
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    ROUND(AVG(vl_unit_mediana_contrato)::numeric, 2) AS preco_ms,
    ROUND(AVG(preco_unit_mediana)::numeric, 2)      AS preco_brasil,
    ROUND(AVG(diff_mediana_ms_vs_br)::numeric, 2)   AS diferenca_reais,
    ROUND(AVG(COALESCE(pct_ms_vs_mediana_br, 0) * 100)::numeric, 2) AS diferenca_percentual,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total_gasto
FROM gold.v_ms_vs_praticados_catmat_mes
WHERE COALESCE(pct_ms_vs_mediana_br, 0) > 0.2
GROUP BY codigo_item_catalogo
ORDER BY SUM(vl_contratado) DESC
LIMIT 50;

COMMENT ON VIEW gold.ai_ms_paga_mais_caro IS
'Medicamentos onde MS paga 20%+ acima da mediana Brasil.
Perguntas: "Onde MS paga caro?", "Sobrepreço", "Oportunidades de economia"';

-- ----
CREATE VIEW gold.ai_ms_paga_mais_barato AS
SELECT
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    ROUND(AVG(vl_unit_mediana_contrato)::numeric, 2) AS preco_ms,
    ROUND(AVG(preco_unit_mediana)::numeric, 2)      AS preco_brasil,
    ROUND(AVG(diff_mediana_ms_vs_br)::numeric, 2)   AS diferenca_reais,
    ROUND(AVG(COALESCE(pct_ms_vs_mediana_br, 0) * 100)::numeric, 2) AS diferenca_percentual,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total_gasto
FROM gold.v_ms_vs_praticados_catmat_mes
WHERE COALESCE(pct_ms_vs_mediana_br, 0) < -0.1
GROUP BY codigo_item_catalogo
ORDER BY SUM(vl_contratado) DESC
LIMIT 50;

COMMENT ON VIEW gold.ai_ms_paga_mais_barato IS
'Medicamentos onde MS paga 10%+ abaixo da mediana Brasil.
Perguntas: "Onde MS economiza?", "Boas compras", "Preços competitivos"';

-- ----
CREATE VIEW gold.ai_comparacao_preco_ms_ufs AS
WITH ms_precos AS (
    SELECT
        codigo_item_catalogo,
        MAX(descricao_item_contrato)                AS medicamento,
        EXTRACT(YEAR FROM ano_mes_contrato)::int    AS ano,
        COUNT(*)                                    AS registros_ms,
        ROUND(AVG(vl_unit_medio_contrato)::numeric, 4)   AS media_ms,
        ROUND(AVG(vl_unit_mediana_contrato)::numeric, 4) AS mediana_ms
    FROM gold.m_ms_item_mes_area
    WHERE ano_mes_contrato IS NOT NULL
    GROUP BY codigo_item_catalogo, EXTRACT(YEAR FROM ano_mes_contrato)::int
),
ufs_precos AS (
    SELECT
        codigo_item_catalogo,
        EXTRACT(YEAR FROM ano_mes_compra)::int      AS ano,
        COUNT(*)                                    AS registros_ufs,
        ROUND(AVG(preco_unit_medio)::numeric, 4)    AS media_ufs,
        ROUND(AVG(preco_unit_mediana)::numeric, 4)  AS mediana_ufs
    FROM gold.m_praticados_catmat_mes
    GROUP BY codigo_item_catalogo, EXTRACT(YEAR FROM ano_mes_compra)::int
)
SELECT
    m.codigo_item_catalogo                          AS catmat,
    m.medicamento,
    m.ano,
    m.registros_ms,
    m.media_ms,
    m.mediana_ms,
    u.registros_ufs,
    u.media_ufs,
    u.mediana_ufs,
    ROUND((m.media_ms - u.media_ufs)::numeric, 4)  AS diff_media,
    ROUND((m.mediana_ms - u.mediana_ufs)::numeric, 4) AS diff_mediana,
    ROUND(CASE WHEN u.media_ufs > 0
               THEN (m.media_ms - u.media_ufs) / u.media_ufs * 100
          END::numeric, 2)                          AS pct_diff_media,
    ROUND(CASE WHEN u.mediana_ufs > 0
               THEN (m.mediana_ms - u.mediana_ufs) / u.mediana_ufs * 100
          END::numeric, 2)                          AS pct_diff_mediana
FROM ms_precos m
JOIN ufs_precos u
    ON u.codigo_item_catalogo = m.codigo_item_catalogo
    AND u.ano = m.ano
ORDER BY m.medicamento, m.ano;

COMMENT ON VIEW gold.ai_comparacao_preco_ms_ufs IS
'Comparação detalhada MS vs outras UFs: média e mediana por medicamento e ano.
Perguntas: "Preço MS vs UFs insulina", "Média e mediana comparada", "MS paga mais que estados?"';

-- ============================================================
-- BLOCO 9 — JUDICIALIZAÇÃO (SE/DJUD)
-- ============================================================
\echo '📊 Bloco 9: Judicialização...'

CREATE VIEW gold.ai_judicializacao_evolucao AS
SELECT
    EXTRACT(YEAR FROM ano_mes_contrato)::int        AS ano,
    COUNT(*)                                        AS itens,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total,
    ROUND(SUM(qtd_contratada)::numeric, 2)          AS quantidade_total,
    ROUND(AVG(vl_unit_mediana_contrato)::numeric, 4) AS preco_mediano
FROM gold.m_ms_item_mes_area
WHERE departamento = 'DJUD'
  AND ano_mes_contrato IS NOT NULL
GROUP BY EXTRACT(YEAR FROM ano_mes_contrato)::int
ORDER BY ano;

COMMENT ON VIEW gold.ai_judicializacao_evolucao IS
'Evolução anual dos gastos com medicamentos judicializados (SE/DJUD).
Perguntas: "Gastos com judicialização por ano", "Evolução DJUD", "Crescimento judicial"';

-- ----
CREATE VIEW gold.ai_judicializacao_top_medicamentos AS
SELECT
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    EXTRACT(YEAR FROM ano_mes_contrato)::int        AS ano,
    COUNT(*)                                        AS registros,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total,
    ROUND(SUM(qtd_contratada)::numeric, 2)          AS quantidade_total,
    ROUND(AVG(vl_unit_mediana_contrato)::numeric, 4) AS preco_mediano
FROM gold.m_ms_item_mes_area
WHERE departamento = 'DJUD'
GROUP BY codigo_item_catalogo, EXTRACT(YEAR FROM ano_mes_contrato)::int
ORDER BY SUM(vl_contratado) DESC;

COMMENT ON VIEW gold.ai_judicializacao_top_medicamentos IS
'Medicamentos mais comprados via judicialização.
Perguntas: "Quais medicamentos são mais judicializados?", "Top medicamentos DJUD"';

-- ----
CREATE VIEW gold.ai_judicializacao_vs_programatico AS
SELECT
    EXTRACT(YEAR FROM ano_mes_contrato)::int        AS ano,
    ROUND(SUM(CASE WHEN departamento = 'DJUD'
                   THEN vl_contratado END)::numeric, 2) AS valor_judicial,
    ROUND(SUM(CASE WHEN departamento != 'DJUD' OR departamento IS NULL
                   THEN vl_contratado END)::numeric, 2) AS valor_programatico,
    ROUND(SUM(vl_contratado)::numeric, 2)           AS valor_total,
    ROUND(
        SUM(CASE WHEN departamento = 'DJUD' THEN vl_contratado END) /
        NULLIF(SUM(vl_contratado), 0) * 100
    , 2)                                            AS pct_judicial
FROM gold.m_ms_item_mes_area
WHERE ano_mes_contrato IS NOT NULL
GROUP BY EXTRACT(YEAR FROM ano_mes_contrato)::int
ORDER BY ano;

COMMENT ON VIEW gold.ai_judicializacao_vs_programatico IS
'Gasto judicial vs programático por ano — percentual de judicialização.
Perguntas: "Quanto % é judicial?", "Judicialização vs compra programática", "Tendência judicial"';


-- ----
CREATE VIEW gold.ai_portfolio_fornecedor AS
SELECT
    ni_fornecedor,
    MAX(nome_fornecedor)                            AS fornecedor,
    codigo_item_catalogo                            AS catmat,
    MAX(descricao_item_contrato)                    AS medicamento,
    COUNT(*)                                        AS itens_fornecidos,
    ROUND(SUM(valor_total_item)::numeric, 2)        AS valor_total,
    ROUND(SUM(quantidade_item)::numeric, 2)         AS quantidade_total,
    ROUND(AVG(valor_unitario_item)::numeric, 4)     AS preco_medio,
    MIN(data_ref_contrato_ts::date)                 AS primeira_compra,
    MAX(data_ref_contrato_ts::date)                 AS ultima_compra,
    COALESCE(secretaria, 'Não identificado')        AS secretaria
FROM gold.f_ms_itens_contrato
WHERE ni_fornecedor IS NOT NULL
GROUP BY ni_fornecedor, codigo_item_catalogo, secretaria
ORDER BY ni_fornecedor, SUM(valor_total_item) DESC;

COMMENT ON VIEW gold.ai_portfolio_fornecedor IS
'Portfolio completo de cada fornecedor: quais medicamentos fornece, para qual secretaria, valores e datas — sempre filtrar por fornecedor ILIKE.
Perguntas: "O que a Cristália fornece?", "Quais medicamentos a empresa X vende pro MS?", "Portfolio do fornecedor Y"';

-- ============================================================
-- VERIFICAÇÃO FINAL
-- ============================================================
\echo ''
\echo '============================================================'
\echo 'INVENTÁRIO FINAL DA CAMADA GOLD'
\echo '============================================================'

SELECT
    CASE
        WHEN viewname LIKE 'ai_%' THEN '🟢 AI (Text-to-SQL)'
        WHEN viewname LIKE 'f_%'  THEN '🔵 Fato (base)'
        WHEN viewname LIKE 'm_%'  THEN '🟡 Mart (agregada)'
        WHEN viewname LIKE 'v_%'  THEN '⚪ Auxiliar'
        WHEN viewname LIKE 'd_%'  THEN '🟠 Dashboard (legado)'
        ELSE '❓ Outro'
    END                                             AS tipo,
    viewname                                        AS view
FROM pg_views
WHERE schemaname = 'gold'
ORDER BY tipo, viewname;

SELECT
    COUNT(*) FILTER (WHERE viewname LIKE 'ai_%')    AS views_ai,
    COUNT(*) FILTER (WHERE viewname NOT LIKE 'ai_%') AS views_base,
    COUNT(*)                                        AS total_views
FROM pg_views
WHERE schemaname = 'gold';

\echo ''
\echo '✅ Camada Gold recriada com sucesso!'
\echo '   33 views ai_ cobrindo 9 blocos temáticos'
\echo ''

-- ============================================================
-- ai_evolucao_secretaria_modalidade
-- Responde: "histórico da SCTIE por modalidade",
--           "como a SAPS usa pregão ao longo dos anos?"
-- ============================================================
CREATE OR REPLACE VIEW gold.ai_evolucao_secretaria_modalidade AS
SELECT
    f.secretaria,
    c.nome_modalidade_compra                            AS modalidade,
    EXTRACT(YEAR FROM f.data_ref_contrato_ts)::int      AS ano,
    COUNT(DISTINCT f.numero_contrato_norm)              AS contratos,
    COUNT(*)                                            AS itens,
    ROUND(SUM(f.valor_total_calc)::numeric, 2)          AS valor_total,
    ROUND(AVG(f.valor_unitario_item)::numeric, 4)       AS preco_medio_unitario
FROM gold.f_ms_itens_contrato f
JOIN silver.v_ep1_contratos_ms c
    ON c.numero_contrato_norm = f.numero_contrato_norm
WHERE c.nome_modalidade_compra IS NOT NULL
GROUP BY f.secretaria, c.nome_modalidade_compra, EXTRACT(YEAR FROM f.data_ref_contrato_ts)::int
ORDER BY f.secretaria, ano, valor_total DESC;

-- ============================================================
-- ai_top_fornecedores_secretaria
-- Responde: "top fornecedores da SCTIE", "quem mais vende para a SAPS?"
-- ============================================================
CREATE OR REPLACE VIEW gold.ai_top_fornecedores_secretaria AS
SELECT
    secretaria,
    ni_fornecedor,
    nome_fornecedor                                     AS fornecedor,
    COUNT(DISTINCT numero_contrato_norm)                AS contratos,
    COUNT(DISTINCT codigo_item_catalogo)                AS itens_diferentes,
    ROUND(SUM(valor_total_calc)::numeric, 2)            AS valor_total,
    ROUND(SUM(quantidade_item)::numeric, 2)             AS quantidade_total,
    ROUND(AVG(valor_unitario_item)::numeric, 4)         AS preco_medio
FROM gold.f_ms_itens_contrato
GROUP BY secretaria, ni_fornecedor, nome_fornecedor
ORDER BY secretaria, valor_total DESC;
