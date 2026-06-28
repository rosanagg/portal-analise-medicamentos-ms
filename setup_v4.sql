-- ============================================================
-- SETUP V3 - TCC MEDICAMENTOS MS
-- ============================================================
-- Estrutura completa: RAW → SILVER → GOLD
-- Inclui: análises avançadas, métricas, comparações
-- ============================================================

\set ON_ERROR_STOP on

-- Criar schemas
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- ============================================================
-- RAW: Tabelas de Landing (dados brutos)
-- ============================================================

-- EP1: Contratos MS (cabeçalho)
DROP TABLE IF EXISTS raw.ep1_contratos_ms CASCADE;
CREATE TABLE raw.ep1_contratos_ms (
  codigo_categoria text,
  codigo_modalidade_compra text,
  codigo_orgao text,
  codigo_subcategoria text,
  codigo_tipo text,
  codigo_unidade_gestora text,
  codigo_unidade_gestora_origem_contrato text,
  codigo_unidade_realizadora_compra text,
  contrato_excluido text,
  data_hora_exclusao text,
  data_hora_inclusao text,
  data_vigencia_final text,
  data_vigencia_inicial text,
  id_compra text,
  informacoes_complementares text,
  ni_fornecedor text,
  nome_categoria text,
  nome_modalidade_compra text,
  nome_orgao text,
  nome_razao_social_fornecedor text,
  nome_subcategoria text,
  nome_tipo text,
  nome_unidade_gestora text,
  nome_unidade_gestora_origem_contrato text,
  nome_unidade_realizadora_compra text,
  numero_compra text,
  numero_contrato text,
  numero_controle_pncp_contrato text,
  numero_parcelas text,
  objeto text,
  processo text,
  receita_despesa text,
  total_despesas_acessorias text,
  unidades_requisitantes text,
  valor_acumulado text,
  valor_global text,
  valor_parcela text
);

-- EP2: Itens dos contratos MS
DROP TABLE IF EXISTS raw.ep2_itens_ms CASCADE;
CREATE TABLE raw.ep2_itens_ms (
  codigo_item text,
  codigo_modalidade_compra text,
  codigo_orgao text,
  codigo_unidade_gestora text,
  codigo_unidade_gestora_origem_contrato text,
  codigo_unidade_realizadora_compra text,
  contrato_excluido text,
  contrato_item_excluido text,
  data_hora_exclusao_contrato text,
  data_hora_exclusao_item text,
  data_hora_inclusao text,
  data_vigencia_final text,
  data_vigencia_inicial text,
  descricao_iitem text,
  esfera text,
  id_compra text,
  ni_fornecedor text,
  nome_modalidade_compra text,
  nome_orgao text,
  nome_razao_social_fornecedor text,
  nome_unidade_gestora text,
  nome_unidade_gestora_origem_contrato text,
  nome_unidade_realizadora_compra text,
  numero_compra text,
  numero_contrato text,
  numero_controle_pncp_contrato text,
  numero_item text,
  poder text,
  processo text,
  quantidade_item text,
  tipo_item text,
  valor_global text,
  valor_total_item text,
  valor_unitario_item text
);

-- Preços Praticados (todos os órgãos federais)
DROP TABLE IF EXISTS raw.precos_praticados CASCADE;
CREATE TABLE raw.precos_praticados (
  capacidade_unidade_fornecimento text,
  codigo_classe text,
  codigo_item_catalogo text,
  codigo_municipio text,
  codigo_orgao text,
  codigo_uasg text,
  criterio_julgamento text,
  data_compra text,
  data_hora_atualizacao_compra text,
  data_hora_atualizacao_item text,
  data_hora_atualizacao_uasg text,
  data_resultado text,
  descricao_detalhada_item text,
  descricao_item text,
  esfera text,
  estado text,
  forma text,
  id_compra text,
  id_item_compra text,
  marca text,
  modalidade text,
  municipio text,
  ni_fornecedor text,
  nome_classe text,
  nome_fornecedor text,
  nome_orgao text,
  nome_uasg text,
  nome_unidade_fornecimento text,
  nome_unidade_medida text,
  numero_item_compra text,
  objeto_compra text,
  percentual_maior_desconto text,
  poder text,
  preco_unitario text,
  quantidade text,
  sigla_unidade_fornecimento text,
  sigla_unidade_medida text
);

-- ============================================================
-- SILVER: Tabelas de Curadoria
-- ============================================================

-- Curadoria: Áreas/Departamentos/Secretarias por contrato (staging)
DROP TABLE IF EXISTS silver.ep1_contratos_area_stg CASCADE;
CREATE TABLE silver.ep1_contratos_area_stg (
  load_id bigserial PRIMARY KEY,
  numero_contrato text,
  unidades_sigla text,
  unidades_completo text,
  departamento text,
  secretaria text,
  carga_arquivo text,
  carga_ts timestamptz DEFAULT now()
);

-- Curadoria: Áreas/Departamentos/Secretarias por contrato (final)
DROP TABLE IF EXISTS silver.ep1_contratos_area CASCADE;
CREATE TABLE silver.ep1_contratos_area (
  numero_contrato text PRIMARY KEY,
  unidades_sigla text,
  unidades_completo text,
  departamento text,
  secretaria text,
  carga_id bigint,
  carga_arquivo text,
  carga_ts timestamptz DEFAULT now()
);

-- ============================================================
-- SILVER: Views de Normalização
-- ============================================================

-- EP1: Contratos MS normalizados
CREATE OR REPLACE VIEW silver.v_ep1_contratos_ms AS
SELECT
  codigo_categoria,
  codigo_modalidade_compra,
  codigo_orgao,
  codigo_subcategoria,
  codigo_tipo,
  codigo_unidade_gestora,
  codigo_unidade_gestora_origem_contrato,
  codigo_unidade_realizadora_compra,
  CASE WHEN lower(nullif(contrato_excluido,'')) IN ('true','t','1','sim','s') THEN true ELSE false END AS contrato_excluido_bool,
  NULLIF(replace(data_hora_exclusao,'T',' '),'')::timestamp AS data_hora_exclusao_ts,
  NULLIF(replace(data_hora_inclusao,'T',' '),'')::timestamp AS data_hora_inclusao_ts,
  NULLIF(replace(data_vigencia_inicial,'T',' '),'')::timestamp AS data_vigencia_inicial_ts,
  NULLIF(replace(data_vigencia_final,'T',' '),'')::timestamp AS data_vigencia_final_ts,
  NULLIF(id_compra,'') AS id_compra,
  informacoes_complementares,
  NULLIF(ni_fornecedor,'') AS ni_fornecedor,
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
  regexp_replace(regexp_replace(upper(trim(numero_contrato)), '\s+', '', 'g'), '^0+([0-9]+/)', '\1') AS numero_contrato_norm,
  numero_controle_pncp_contrato,
  NULLIF(numero_parcelas,'')::int AS numero_parcelas,
  objeto,
  processo,
  receita_despesa,
  NULLIF(total_despesas_acessorias,'')::numeric AS total_despesas_acessorias,
  unidades_requisitantes,
  NULLIF(valor_acumulado,'')::numeric AS valor_acumulado,
  NULLIF(valor_global,'')::numeric AS valor_global,
  NULLIF(valor_parcela,'')::numeric AS valor_parcela
FROM raw.ep1_contratos_ms
WHERE nome_categoria = 'Compras';  -- exclui Serviços, Cessão e Serviços de Saúde (11 registros)

-- EP2: Itens dos contratos MS normalizados
CREATE OR REPLACE VIEW silver.v_ep2_itens_ms AS
SELECT
  codigo_item AS codigo_item_catalogo,
  codigo_modalidade_compra,
  codigo_orgao,
  codigo_unidade_gestora,
  codigo_unidade_gestora_origem_contrato,
  codigo_unidade_realizadora_compra,
  CASE WHEN lower(nullif(contrato_excluido,'')) IN ('true','t','1','sim','s') THEN true ELSE false END AS contrato_excluido_bool,
  CASE WHEN lower(nullif(contrato_item_excluido,'')) IN ('true','t','1','sim','s') THEN true ELSE false END AS contrato_item_excluido_bool,
  NULLIF(replace(data_hora_exclusao_contrato,'T',' '),'')::timestamp AS data_hora_exclusao_contrato_ts,
  NULLIF(replace(data_hora_exclusao_item,'T',' '),'')::timestamp AS data_hora_exclusao_item_ts,
  NULLIF(replace(data_hora_inclusao,'T',' '),'')::timestamp AS data_hora_inclusao_ts,
  NULLIF(replace(data_vigencia_inicial,'T',' '),'')::timestamp AS data_vigencia_inicial_ts,
  NULLIF(replace(data_vigencia_final,'T',' '),'')::timestamp AS data_vigencia_final_ts,
  descricao_iitem AS descricao_item_contrato,
  esfera,
  NULLIF(id_compra,'') AS id_compra,
  NULLIF(ni_fornecedor,'') AS ni_fornecedor,
  nome_modalidade_compra,
  nome_orgao,
  nome_razao_social_fornecedor AS nome_fornecedor,
  nome_unidade_gestora,
  nome_unidade_gestora_origem_contrato,
  nome_unidade_realizadora_compra,
  numero_compra,
  numero_contrato,
  regexp_replace(regexp_replace(upper(trim(numero_contrato)), '\s+', '', 'g'), '^0+([0-9]+/)', '\1') AS numero_contrato_norm,
  numero_controle_pncp_contrato,
  NULLIF(numero_item,'')::int AS numero_item,
  poder,
  processo,
  NULLIF(quantidade_item,'')::numeric AS quantidade_item,
  tipo_item,
  NULLIF(valor_unitario_item,'')::numeric AS valor_unitario_item,
  NULLIF(valor_total_item,'')::numeric AS valor_total_item,
  NULLIF(valor_global,'')::numeric AS valor_global
FROM raw.ep2_itens_ms;

-- EP2: Somente itens VÁLIDOS (não excluídos)
CREATE OR REPLACE VIEW silver.v_ep2_itens_ms_validos AS
SELECT *
FROM silver.v_ep2_itens_ms
WHERE contrato_item_excluido_bool IS DISTINCT FROM true
  AND contrato_excluido_bool IS DISTINCT FROM true;

-- Preços Praticados normalizados
CREATE OR REPLACE VIEW silver.v_precos_praticados AS
SELECT
  NULLIF(codigo_item_catalogo,'') AS codigo_item_catalogo,
  NULLIF(id_compra,'') AS id_compra,
  NULLIF(id_item_compra,'') AS id_item_compra,
  NULLIF(numero_item_compra,'')::int AS numero_item_compra,
  NULLIF(preco_unitario,'')::numeric AS preco_unitario,
  NULLIF(quantidade,'')::numeric AS quantidade,
  NULLIF(data_compra,'')::date AS data_compra,
  date_trunc('month', NULLIF(data_compra,'')::date)::date AS ano_mes_compra,
  estado,
  municipio,
  codigo_municipio,
  codigo_orgao,
  codigo_uasg,
  nome_orgao,
  nome_uasg,
  esfera,
  poder,
  modalidade,
  criterio_julgamento,
  nome_fornecedor,
  NULLIF(ni_fornecedor,'') AS ni_fornecedor,
  marca,
  descricao_item,
  descricao_detalhada_item,
  codigo_classe,
  nome_classe,
  nome_unidade_fornecimento,
  sigla_unidade_fornecimento,
  nome_unidade_medida,
  sigla_unidade_medida,
  capacidade_unidade_fornecimento,
  objeto_compra,
  percentual_maior_desconto,
  forma,
  NULLIF(replace(data_hora_atualizacao_item,'T',' '),'')::timestamp AS data_hora_atualizacao_item_ts,
  NULLIF(replace(data_hora_atualizacao_compra,'T',' '),'')::timestamp AS data_hora_atualizacao_compra_ts,
  NULLIF(replace(data_hora_atualizacao_uasg,'T',' '),'')::timestamp AS data_hora_atualizacao_uasg_ts,
  NULLIF(data_resultado,'')::date AS data_resultado
FROM raw.precos_praticados;

-- Preços Praticados: 1 registro por compra/item (mais recente)
CREATE OR REPLACE VIEW silver.v_precos_praticados_por_compra_item AS
SELECT DISTINCT ON (id_compra, numero_item_compra)
  *
FROM silver.v_precos_praticados
WHERE id_compra IS NOT NULL
  AND numero_item_compra IS NOT NULL
ORDER BY id_compra, numero_item_compra, 
         data_hora_atualizacao_item_ts DESC NULLS LAST, 
         data_hora_atualizacao_compra_ts DESC NULLS LAST;

-- Áreas normalizadas
CREATE OR REPLACE VIEW silver.v_ep1_contratos_area_norm AS
SELECT
  a.*,
  regexp_replace(regexp_replace(upper(trim(numero_contrato)), '\s+', '', 'g'), '^0+([0-9]+/)', '\1') AS numero_contrato_norm
FROM silver.ep1_contratos_area a;

-- ============================================================
-- GOLD: Fatos e Métricas
-- ============================================================

-- FATO: Itens de contrato MS enriquecidos
CREATE OR REPLACE VIEW gold.f_ms_itens_contrato AS
SELECT
  i.id_compra,
  i.numero_compra,
  i.numero_contrato,
  i.numero_contrato_norm,
  i.numero_item,
  i.codigo_item_catalogo,
  i.descricao_item_contrato,
  i.tipo_item,
  i.quantidade_item,
  i.valor_unitario_item,
  i.valor_total_item,
  (i.quantidade_item * i.valor_unitario_item) AS valor_total_calc,
  (i.valor_total_item - (i.quantidade_item * i.valor_unitario_item)) AS delta_total_item,
  i.ni_fornecedor,
  i.nome_fornecedor,
  i.nome_orgao,
  i.nome_unidade_gestora,
  i.nome_unidade_realizadora_compra,
  
  -- Data de referência
  COALESCE(i.data_vigencia_inicial_ts, i.data_hora_inclusao_ts) AS data_ref_contrato_ts,
  date_trunc('month', COALESCE(i.data_vigencia_inicial_ts, i.data_hora_inclusao_ts))::date AS ano_mes_contrato,
  
  -- Datas adicionais
  i.data_vigencia_inicial_ts,
  i.data_vigencia_final_ts,
  i.data_hora_inclusao_ts,
  
  -- Área/Departamento/Secretaria
  a.secretaria,
  a.departamento,
  a.unidades_sigla,
  a.unidades_completo
FROM silver.v_ep2_itens_ms_validos i
LEFT JOIN silver.v_ep1_contratos_area_norm a
  ON a.numero_contrato_norm = i.numero_contrato_norm;

-- MÉTRICA: Agregado por Mês/Área/Item
CREATE OR REPLACE VIEW gold.m_ms_item_mes_area AS
SELECT
  ano_mes_contrato,
  secretaria,
  departamento,
  codigo_item_catalogo,
  max(descricao_item_contrato) AS descricao_item_contrato,
  sum(quantidade_item) AS qtd_contratada,
  sum(valor_total_item) AS vl_contratado,
  avg(valor_unitario_item) AS vl_unit_medio_contrato,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY valor_unitario_item) AS vl_unit_mediana_contrato,
  min(valor_unitario_item) AS vl_unit_min_contrato,
  max(valor_unitario_item) AS vl_unit_max_contrato,
  count(*) AS n_itens
FROM gold.f_ms_itens_contrato
GROUP BY 1,2,3,4;

-- MÉTRICA: Agregado por Fornecedor
CREATE OR REPLACE VIEW gold.m_ms_fornecedor AS
SELECT
  secretaria,
  departamento,
  ni_fornecedor,
  max(nome_fornecedor) AS nome_fornecedor,
  sum(valor_total_item) AS vl_contratado,
  sum(quantidade_item) AS qtd_contratada,
  count(*) AS n_itens,
  count(DISTINCT numero_contrato) AS n_contratos
FROM gold.f_ms_itens_contrato
GROUP BY 1,2,3;

-- MÉTRICA: Preços Praticados agregados por CATMAT/Mês
CREATE OR REPLACE VIEW gold.m_praticados_catmat_mes AS
SELECT
  ano_mes_compra,
  codigo_item_catalogo,
  count(*) AS n_registros,
  avg(preco_unitario) AS preco_unit_medio,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY preco_unitario) AS preco_unit_mediana,
  percentile_cont(0.25) WITHIN GROUP (ORDER BY preco_unitario) AS preco_unit_p25,
  percentile_cont(0.75) WITHIN GROUP (ORDER BY preco_unitario) AS preco_unit_p75,
  min(preco_unitario) AS preco_unit_min,
  max(preco_unitario) AS preco_unit_max,
  sum(quantidade) AS qtd_total,
  CASE WHEN sum(quantidade) = 0 THEN NULL
       ELSE sum(preco_unitario * quantidade) / sum(quantidade)
  END AS preco_unit_medio_ponderado
FROM silver.v_precos_praticados
WHERE preco_unitario IS NOT NULL
GROUP BY 1,2;

-- ============================================================
-- GOLD: Análises Comparativas
-- ============================================================

-- ANÁLISE: MS vs Brasil (preços praticados)
CREATE OR REPLACE VIEW gold.v_ms_vs_praticados_catmat_mes AS
SELECT
  m.ano_mes_contrato,
  m.secretaria,
  m.departamento,
  m.codigo_item_catalogo,
  m.descricao_item_contrato,
  m.qtd_contratada,
  m.vl_contratado,
  m.vl_unit_medio_contrato,
  m.vl_unit_mediana_contrato,
  p.preco_unit_medio,
  p.preco_unit_mediana,
  p.preco_unit_p25,
  p.preco_unit_p75,
  p.preco_unit_medio_ponderado,
  (m.vl_unit_mediana_contrato - p.preco_unit_mediana) AS diff_mediana_ms_vs_br,
  CASE WHEN p.preco_unit_mediana IS NULL OR p.preco_unit_mediana = 0 THEN NULL
       ELSE (m.vl_unit_mediana_contrato / p.preco_unit_mediana - 1)
  END AS pct_ms_vs_mediana_br
FROM gold.m_ms_item_mes_area m
LEFT JOIN gold.m_praticados_catmat_mes p
  ON p.ano_mes_compra = m.ano_mes_contrato
 AND p.codigo_item_catalogo = m.codigo_item_catalogo;

-- ============================================================
-- GOLD: Rankings e Tops
-- ============================================================

-- TOP 50: Itens por valor
CREATE OR REPLACE VIEW gold.v_ms_top_itens_valor AS
SELECT
  codigo_item_catalogo,
  max(descricao_item_contrato) AS descricao_item_contrato,
  sum(valor_total_item) AS vl_contratado,
  sum(quantidade_item) AS qtd_contratada,
  count(DISTINCT numero_contrato) AS n_contratos,
  count(DISTINCT ni_fornecedor) AS n_fornecedores
FROM gold.f_ms_itens_contrato
GROUP BY 1
ORDER BY vl_contratado DESC
LIMIT 50;

-- TOP 50: Itens por quantidade
CREATE OR REPLACE VIEW gold.v_ms_top_itens_quantidade AS
SELECT
  codigo_item_catalogo,
  max(descricao_item_contrato) AS descricao_item_contrato,
  sum(quantidade_item) AS qtd_contratada,
  sum(valor_total_item) AS vl_contratado,
  count(DISTINCT numero_contrato) AS n_contratos,
  count(DISTINCT ni_fornecedor) AS n_fornecedores
FROM gold.f_ms_itens_contrato
GROUP BY 1
ORDER BY qtd_contratada DESC
LIMIT 50;

-- TOP 100: Fornecedores
CREATE OR REPLACE VIEW gold.v_ms_top_fornecedores AS
SELECT
  ni_fornecedor,
  max(nome_fornecedor) AS nome_fornecedor,
  sum(valor_total_item) AS vl_contratado,
  sum(quantidade_item) AS qtd_contratada,
  count(DISTINCT codigo_item_catalogo) AS n_itens_diferentes,
  count(DISTINCT numero_contrato) AS n_contratos,
  count(*) AS n_linhas
FROM gold.f_ms_itens_contrato
GROUP BY 1
ORDER BY vl_contratado DESC
LIMIT 100;

-- ============================================================
-- GOLD: Análises Avançadas (NOVAS!)
-- ============================================================

-- MARCAS: Análise de marcas por CATMAT
CREATE OR REPLACE VIEW gold.v_marcas_por_catmat AS
SELECT 
    codigo_item_catalogo,
    marca,
    COUNT(*) as qtd_compras,
    AVG(preco_unitario) as preco_medio_marca,
    STDDEV(preco_unitario) as desvio_padrao_marca,
    MIN(preco_unitario) as preco_min_marca,
    MAX(preco_unitario) as preco_max_marca,
    COUNT(DISTINCT nome_orgao) as qtd_orgaos_usam,
    SUM(quantidade) as qtd_total_comprada
FROM silver.v_precos_praticados
WHERE marca IS NOT NULL AND marca <> ''
  AND codigo_item_catalogo IS NOT NULL
GROUP BY codigo_item_catalogo, marca
ORDER BY codigo_item_catalogo, qtd_compras DESC;

-- MS COM MARCAS: Enriquece itens MS com info de marcas
CREATE OR REPLACE VIEW gold.v_ms_com_marcas AS
SELECT 
    ms.*,
    m.marca,
    m.preco_medio_marca,
    m.qtd_orgaos_usam as qtd_orgaos_usam_marca,
    m.qtd_compras as qtd_compras_marca_brasil,
    (ms.valor_unitario_item - m.preco_medio_marca) as diff_vs_media_marca,
    CASE WHEN m.preco_medio_marca = 0 OR m.preco_medio_marca IS NULL THEN NULL
         ELSE (ms.valor_unitario_item / m.preco_medio_marca - 1) * 100
    END as pct_diff_vs_media_marca
FROM gold.f_ms_itens_contrato ms
LEFT JOIN gold.v_marcas_por_catmat m
    ON ms.codigo_item_catalogo = m.codigo_item_catalogo;

-- VARIAÇÃO DE PREÇOS MS: Analisa variabilidade de preços
CREATE OR REPLACE VIEW gold.v_variacao_precos_ms AS
SELECT 
    codigo_item_catalogo,
    max(descricao_item_contrato) as descricao_item_contrato,
    COUNT(*) as qtd_contratos,
    AVG(valor_unitario_item) as preco_medio,
    STDDEV(valor_unitario_item) as desvio_padrao,
    MIN(valor_unitario_item) as preco_min,
    MAX(valor_unitario_item) as preco_max,
    MAX(valor_unitario_item) - MIN(valor_unitario_item) as amplitude,
    CASE WHEN AVG(valor_unitario_item) = 0 THEN NULL
         ELSE STDDEV(valor_unitario_item) / AVG(valor_unitario_item)
    END as coef_variacao,
    CASE 
        WHEN STDDEV(valor_unitario_item) / NULLIF(AVG(valor_unitario_item), 0) > 0.5 
        THEN 'Alta variação'
        WHEN STDDEV(valor_unitario_item) / NULLIF(AVG(valor_unitario_item), 0) > 0.2 
        THEN 'Moderada variação'
        ELSE 'Baixa variação'
    END as nivel_variacao
FROM gold.f_ms_itens_contrato
WHERE valor_unitario_item > 0
GROUP BY codigo_item_catalogo
HAVING COUNT(*) >= 5  -- só itens com pelo menos 5 compras
ORDER BY coef_variacao DESC NULLS LAST;

-- CONCENTRAÇÃO DE FORNECEDORES: Índice Herfindahl-Hirschman
CREATE OR REPLACE VIEW gold.v_concentracao_fornecedores AS
WITH market_share AS (
    SELECT 
        codigo_item_catalogo,
        ni_fornecedor,
        SUM(valor_total_item) as valor_fornecedor,
        SUM(SUM(valor_total_item)) OVER (PARTITION BY codigo_item_catalogo) as valor_total_item,
        SUM(valor_total_item) / 
            NULLIF(SUM(SUM(valor_total_item)) OVER (PARTITION BY codigo_item_catalogo), 0) as share
    FROM gold.f_ms_itens_contrato
    WHERE valor_total_item > 0
    GROUP BY codigo_item_catalogo, ni_fornecedor
)
SELECT 
    codigo_item_catalogo,
    COUNT(DISTINCT ni_fornecedor) as qtd_fornecedores,
    SUM(POWER(share, 2)) as hhi,  -- Herfindahl-Hirschman Index
    CASE 
        WHEN SUM(POWER(share, 2)) > 0.25 THEN 'Alta concentração'
        WHEN SUM(POWER(share, 2)) > 0.15 THEN 'Moderada concentração'
        ELSE 'Baixa concentração'
    END as nivel_concentracao,
    MAX(share) as maior_share,
    STRING_AGG(ni_fornecedor, ', ' ORDER BY share DESC) FILTER (WHERE share > 0.1) as principais_fornecedores
FROM market_share
GROUP BY codigo_item_catalogo
HAVING COUNT(DISTINCT ni_fornecedor) > 1
ORDER BY hhi DESC;

-- SAZONALIDADE: Compras por mês
CREATE OR REPLACE VIEW gold.v_sazonalidade_compras AS
SELECT 
    EXTRACT(MONTH FROM ano_mes_contrato) as mes,
    secretaria,
    SUM(vl_contratado) as valor_total,
    COUNT(*) as qtd_itens,
    COUNT(DISTINCT codigo_item_catalogo) as itens_unicos
FROM gold.m_ms_item_mes_area
WHERE ano_mes_contrato IS NOT NULL
GROUP BY mes, secretaria
ORDER BY secretaria, mes;

-- EVOLUÇÃO TEMPORAL: Séries temporais
CREATE OR REPLACE VIEW gold.v_evolucao_temporal_ms AS
SELECT 
    ano_mes_contrato,
    SUM(vl_contratado) as valor_total_mes,
    SUM(qtd_contratada) as qtd_total_mes,
    COUNT(DISTINCT codigo_item_catalogo) as itens_unicos_mes,
    AVG(vl_unit_mediana_contrato) as preco_mediano_mes
FROM gold.m_ms_item_mes_area
WHERE ano_mes_contrato IS NOT NULL
GROUP BY ano_mes_contrato
ORDER BY ano_mes_contrato;

-- ============================================================
-- GOLD: Dashboards KPIs
-- ============================================================

-- DASHBOARD: Visão Geral MS
CREATE OR REPLACE VIEW gold.d_visao_geral_ms AS
SELECT 
    COUNT(DISTINCT numero_contrato) as total_contratos,
    COUNT(DISTINCT codigo_item_catalogo) as total_itens_unicos,
    COUNT(DISTINCT ni_fornecedor) as total_fornecedores,
    SUM(valor_total_item) as valor_total_contratado,
    SUM(quantidade_item) as quantidade_total,
    AVG(valor_unitario_item) as ticket_medio,
    MIN(data_ref_contrato_ts) as primeira_compra,
    MAX(data_ref_contrato_ts) as ultima_compra
FROM gold.f_ms_itens_contrato;

-- DASHBOARD: Onde MS paga mais caro
CREATE OR REPLACE VIEW gold.d_ms_paga_mais_caro AS
SELECT *
FROM gold.v_ms_vs_praticados_catmat_mes
WHERE pct_ms_vs_mediana_br > 0.2  -- 20%+ acima da mediana
  AND vl_contratado > 1000         -- apenas itens relevantes
ORDER BY vl_contratado DESC
LIMIT 50;

-- DASHBOARD: Onde MS paga mais barato
CREATE OR REPLACE VIEW gold.d_ms_paga_mais_barato AS
SELECT *
FROM gold.v_ms_vs_praticados_catmat_mes
WHERE pct_ms_vs_mediana_br < -0.1  -- 10%+ abaixo da mediana
  AND vl_contratado > 1000
ORDER BY vl_contratado DESC
LIMIT 50;

-- ============================================================
-- COMENTÁRIOS
-- ============================================================

COMMENT ON SCHEMA raw IS 'Dados brutos (landing zone)';
COMMENT ON SCHEMA silver IS 'Dados limpos e normalizados';
COMMENT ON SCHEMA gold IS 'Métricas, análises e dashboards';

COMMENT ON VIEW gold.f_ms_itens_contrato IS 'Fato principal: itens de contratos MS enriquecidos';
COMMENT ON VIEW gold.m_ms_item_mes_area IS 'Métrica: agregado por mês/área/item';
COMMENT ON VIEW gold.v_ms_vs_praticados_catmat_mes IS 'Análise: MS vs preços praticados Brasil';
COMMENT ON VIEW gold.v_concentracao_fornecedores IS 'Análise: concentração de mercado (HHI)';
COMMENT ON VIEW gold.v_variacao_precos_ms IS 'Análise: variabilidade de preços MS';
COMMENT ON VIEW gold.v_marcas_por_catmat IS 'Análise: marcas por CATMAT no Brasil';

-- ============================================================
-- FIM
-- ============================================================

\echo '✅ Setup V3 concluído com sucesso!'
\echo ''
\echo 'Schemas criados: raw, silver, gold'
\echo 'Tabelas: 4 (raw)'
\echo 'Views: 25+ (silver + gold)'
\echo ''
\echo 'Próximo passo: Executar load_v3.sql para carregar os dados'

-- ============================================================
-- ÍNDICES DE PERFORMANCE
-- Acelera consultas das views Gold nas colunas mais filtradas
-- ============================================================

-- Tabela raw (usada pelas views silver)
CREATE INDEX IF NOT EXISTS idx_ep1_categoria    ON raw.ep1_contratos_ms (nome_categoria);
CREATE INDEX IF NOT EXISTS idx_ep1_orgao        ON raw.ep1_contratos_ms (codigo_orgao);
CREATE INDEX IF NOT EXISTS idx_ep2_contrato     ON raw.ep2_itens_ms (numero_contrato);
CREATE INDEX IF NOT EXISTS idx_ep2_catmat       ON raw.ep2_itens_ms (codigo_item);
CREATE INDEX IF NOT EXISTS idx_preco_catmat     ON raw.precos_praticados (codigo_item_catalogo);
CREATE INDEX IF NOT EXISTS idx_preco_data       ON raw.precos_praticados (data_compra);

-- Tabela materializada de fatos (base das views Gold)
-- f_ms_itens_contrato é uma VIEW, não tabela — índices vão nas tabelas base acima

\echo '✅ Índices criados!'
