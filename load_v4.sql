-- ============================================================
-- LOAD V3 FIX - TCC MEDICAMENTOS MS
-- ============================================================
-- Versão corrigida com encoding LATIN1 para curadoria
-- ============================================================

\set ON_ERROR_STOP on

BEGIN;

\echo '🧹 Limpando tabelas...'

-- Limpar tabelas RAW
TRUNCATE TABLE raw.ep1_contratos_ms;
TRUNCATE TABLE raw.ep2_itens_ms;
TRUNCATE TABLE raw.precos_praticados;

-- Limpar tabelas SILVER
TRUNCATE TABLE silver.ep1_contratos_area_stg;
TRUNCATE TABLE silver.ep1_contratos_area CASCADE;

\echo '✅ Tabelas limpas!'
\echo ''

-- ============================================================
-- CARGA: RAW
-- ============================================================

\echo '📥 Carregando EP1 (contratos MS)...'
COPY raw.ep1_contratos_ms (
    codigo_categoria,
    codigo_modalidade_compra,
    codigo_orgao,
    codigo_subcategoria,
    codigo_tipo,
    codigo_unidade_gestora,
    codigo_unidade_gestora_origem_contrato,
    codigo_unidade_realizadora_compra,
    contrato_excluido,
    data_hora_exclusao,
    data_hora_inclusao,
    data_vigencia_final,
    data_vigencia_inicial,
    id_compra,
    informacoes_complementares,
    ni_fornecedor,
    nome_categoria,
    nome_modalidade_compra,
    nome_orgao,
    nome_razao_social_fornecedor,
    nome_subcategoria,
    nome_tipo,
    nome_unidade_gestora,
    nome_unidade_gestora_origem_contrato,
    nome_unidade_realizadora_compra,
    numero_compra,
    numero_contrato,
    numero_controle_pncp_contrato,
    numero_parcelas,
    objeto,
    processo,
    receita_despesa,
    total_despesas_acessorias,
    unidades_requisitantes,
    valor_acumulado,
    valor_global,
    valor_parcela
)
FROM '/data/ep1_contratos_ms.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8');

\echo '✅ EP1 carregado!'
\echo ''

\echo '📥 Carregando EP2 (itens dos contratos MS)...'
COPY raw.ep2_itens_ms (
    codigo_item,
    codigo_modalidade_compra,
    codigo_orgao,
    codigo_unidade_gestora,
    codigo_unidade_gestora_origem_contrato,
    codigo_unidade_realizadora_compra,
    contrato_excluido,
    contrato_item_excluido,
    data_hora_exclusao_contrato,
    data_hora_exclusao_item,
    data_hora_inclusao,
    data_vigencia_final,
    data_vigencia_inicial,
    descricao_iitem,
    esfera,
    id_compra,
    ni_fornecedor,
    nome_modalidade_compra,
    nome_orgao,
    nome_razao_social_fornecedor,
    nome_unidade_gestora,
    nome_unidade_gestora_origem_contrato,
    nome_unidade_realizadora_compra,
    numero_compra,
    numero_contrato,
    numero_controle_pncp_contrato,
    numero_item,
    poder,
    processo,
    quantidade_item,
    tipo_item,
    valor_global,
    valor_total_item,
    valor_unitario_item
)
FROM '/data/ep2_itens_ms.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8');

\echo '✅ EP2 carregado!'
\echo ''

\echo '📥 Carregando Preços Praticados...'
COPY raw.precos_praticados (
    capacidade_unidade_fornecimento,
    codigo_classe,
    codigo_item_catalogo,
    codigo_municipio,
    codigo_orgao,
    codigo_uasg,
    criterio_julgamento,
    data_compra,
    data_hora_atualizacao_compra,
    data_hora_atualizacao_item,
    data_hora_atualizacao_uasg,
    data_resultado,
    descricao_detalhada_item,
    descricao_item,
    esfera,
    estado,
    forma,
    id_compra,
    id_item_compra,
    marca,
    modalidade,
    municipio,
    ni_fornecedor,
    nome_classe,
    nome_fornecedor,
    nome_orgao,
    nome_uasg,
    nome_unidade_fornecimento,
    nome_unidade_medida,
    numero_item_compra,
    objeto_compra,
    percentual_maior_desconto,
    poder,
    preco_unitario,
    quantidade,
    sigla_unidade_fornecimento,
    sigla_unidade_medida
)
FROM '/data/precos_praticados.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8');

\echo '✅ Preços Praticados carregados!'
\echo ''

-- ============================================================
-- CARGA: SILVER (Curadoria de Áreas)
-- ============================================================

\echo '📥 Carregando Curadoria de Áreas (staging)...'
COPY silver.ep1_contratos_area_stg (
    numero_contrato,
    unidades_sigla,
    unidades_completo,
    departamento,
    secretaria
)
FROM '/data/ep1_contratos_area.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'LATIN1');
-- ⬆️ MUDANÇA: LATIN1 ao invés de UTF8

\echo '✅ Staging carregado!'
\echo ''

\echo '🔄 Processando curadoria de áreas...'

-- Atualizar carga_arquivo na staging
UPDATE silver.ep1_contratos_area_stg 
SET carga_arquivo = 'ep1_contratos_area.csv'
WHERE carga_arquivo IS NULL;

-- Inserir na tabela final (apenas 1 registro por contrato)
INSERT INTO silver.ep1_contratos_area (
    numero_contrato,
    unidades_sigla,
    unidades_completo,
    departamento,
    secretaria,
    carga_id,
    carga_arquivo,
    carga_ts
)
SELECT DISTINCT ON (TRIM(s.numero_contrato))
    TRIM(s.numero_contrato) AS numero_contrato,
    NULLIF(TRIM(s.unidades_sigla), '') AS unidades_sigla,
    NULLIF(TRIM(s.unidades_completo), '') AS unidades_completo,
    NULLIF(TRIM(s.departamento), '') AS departamento,
    NULLIF(TRIM(s.secretaria), '') AS secretaria,
    s.load_id AS carga_id,
    s.carga_arquivo,
    s.carga_ts
FROM silver.ep1_contratos_area_stg s
WHERE s.numero_contrato IS NOT NULL 
  AND TRIM(s.numero_contrato) <> ''
ORDER BY TRIM(s.numero_contrato), s.carga_ts DESC, s.load_id DESC
ON CONFLICT (numero_contrato) DO UPDATE SET
    unidades_sigla = EXCLUDED.unidades_sigla,
    unidades_completo = EXCLUDED.unidades_completo,
    departamento = EXCLUDED.departamento,
    secretaria = EXCLUDED.secretaria,
    carga_id = EXCLUDED.carga_id,
    carga_arquivo = EXCLUDED.carga_arquivo,
    carga_ts = EXCLUDED.carga_ts;

\echo '✅ Curadoria processada!'
\echo ''

-- ============================================================
-- ANÁLISE E ÍNDICES
-- ============================================================

\echo '📊 Analisando tabelas...'

ANALYZE raw.ep1_contratos_ms;
ANALYZE raw.ep2_itens_ms;
ANALYZE raw.precos_praticados;
ANALYZE silver.ep1_contratos_area;

\echo '✅ Análise concluída!'
\echo ''

\echo '🔧 Criando índices...'

-- Índices EP2
CREATE INDEX IF NOT EXISTS ix_raw_ep2_id_compra 
    ON raw.ep2_itens_ms (id_compra);
CREATE INDEX IF NOT EXISTS ix_raw_ep2_numero_contrato 
    ON raw.ep2_itens_ms (numero_contrato);
CREATE INDEX IF NOT EXISTS ix_raw_ep2_codigo_item 
    ON raw.ep2_itens_ms (codigo_item);
CREATE INDEX IF NOT EXISTS ix_raw_ep2_ni_fornecedor 
    ON raw.ep2_itens_ms (ni_fornecedor);

-- Índices Preços Praticados
CREATE INDEX IF NOT EXISTS ix_raw_pp_id_compra 
    ON raw.precos_praticados (id_compra);
CREATE INDEX IF NOT EXISTS ix_raw_pp_codigo_item_catalogo 
    ON raw.precos_praticados (codigo_item_catalogo);
CREATE INDEX IF NOT EXISTS ix_raw_pp_data_compra 
    ON raw.precos_praticados (data_compra);
CREATE INDEX IF NOT EXISTS ix_raw_pp_marca 
    ON raw.precos_praticados (marca);
CREATE INDEX IF NOT EXISTS ix_raw_pp_nome_orgao 
    ON raw.precos_praticados (nome_orgao);

-- Índice Silver
CREATE INDEX IF NOT EXISTS ix_silver_area_numero_contrato 
    ON silver.ep1_contratos_area (numero_contrato);

\echo '✅ Índices criados!'
\echo ''

COMMIT;

-- ============================================================
-- RESUMO DA CARGA
-- ============================================================

\echo ''
\echo '============================================================'
\echo 'RESUMO DA CARGA'
\echo '============================================================'

SELECT 
    'EP1 Contratos MS' as tabela,
    COUNT(*) as total_linhas
FROM raw.ep1_contratos_ms
UNION ALL
SELECT 
    'EP2 Itens MS' as tabela,
    COUNT(*) as total_linhas
FROM raw.ep2_itens_ms
UNION ALL
SELECT 
    'Preços Praticados' as tabela,
    COUNT(*) as total_linhas
FROM raw.precos_praticados
UNION ALL
SELECT 
    'Curadoria Áreas' as tabela,
    COUNT(*) as total_linhas
FROM silver.ep1_contratos_area;

\echo ''
\echo '============================================================'
\echo 'ESTATÍSTICAS PRINCIPAIS'
\echo '============================================================'

-- Itens válidos (não excluídos)
SELECT 
    'Itens válidos (não excluídos)' as metrica,
    COUNT(*) as valor
FROM silver.v_ep2_itens_ms_validos;

-- Itens únicos
SELECT 
    'Códigos CATMAT únicos' as metrica,
    COUNT(DISTINCT codigo_item) as valor
FROM raw.ep2_itens_ms;

-- Fornecedores únicos
SELECT 
    'Fornecedores únicos (MS)' as metrica,
    COUNT(DISTINCT ni_fornecedor) as valor
FROM raw.ep2_itens_ms
WHERE ni_fornecedor IS NOT NULL AND ni_fornecedor <> '';

-- Contratos únicos
SELECT 
    'Contratos únicos' as metrica,
    COUNT(DISTINCT numero_contrato) as valor
FROM raw.ep2_itens_ms;

\echo ''
\echo '✅ CARGA FINALIZADA COM SUCESSO!'
\echo ''
\echo 'Próximos passos:'
\echo '  - Consultar views GOLD para análises'
\echo '  - Exemplos:'
\echo '    SELECT * FROM gold.d_visao_geral_ms;'
\echo '    SELECT * FROM gold.v_ms_top_itens_valor LIMIT 10;'
\echo '    SELECT * FROM gold.d_ms_paga_mais_caro LIMIT 10;'
\echo ''
