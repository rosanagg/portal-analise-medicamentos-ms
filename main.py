import os
import pandas as pd
from io import StringIO
import subprocess
import requests
import re
import time
from datetime import datetime
from dotenv import load_dotenv
from pathlib import Path

# Busca o .env em múltiplos locais possíveis
for _env_path in [
    Path(__file__).resolve().parent.parent / ".env",  # raiz do projeto
    Path(__file__).resolve().parent / ".env",          # pasta backend
    Path.cwd() / ".env",                               # diretório atual
]:
    if _env_path.exists():
        load_dotenv(dotenv_path=_env_path)
        break


class DatabaseClient:
    def __init__(self, container="tcc-postgres", user="postgres", db="tcc_v4"):
        self.container = container
        self.user = user
        self.db = db

    def execute_query(self, sql: str) -> pd.DataFrame:
        sql_clean = sql.strip().rstrip(";")
        copy_sql = f"COPY ({sql_clean}) TO STDOUT WITH (FORMAT csv, HEADER true)"
        cmd = ["docker", "exec", self.container, "psql", "-U", self.user, "-d", self.db, "-c", copy_sql]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip())
        if not result.stdout.strip():
            return pd.DataFrame()
        return pd.read_csv(StringIO(result.stdout))

    def create_log_table(self):
        sql = """
        CREATE TABLE IF NOT EXISTS logs.interacoes (
            id          bigserial PRIMARY KEY,
            data_hora   timestamptz DEFAULT now(),
            ip          text,
            pergunta    text,
            sql_gerado  text,
            sucesso     boolean,
            erro        text,
            tempo_ms    integer,
            qtd_linhas  integer
        )
        """
        cmd = ["docker", "exec", self.container, "psql", "-U", self.user, "-d", self.db,
               "-c", "CREATE SCHEMA IF NOT EXISTS logs;"]
        subprocess.run(cmd, capture_output=True, text=True)
        cmd = ["docker", "exec", self.container, "psql", "-U", self.user, "-d", self.db, "-c", sql]
        subprocess.run(cmd, capture_output=True, text=True)

    def log_interaction(self, ip: str, pergunta: str, sql_gerado: str,
                        sucesso: bool, erro: str, tempo_ms: int, qtd_linhas: int):
        erro_escaped = (erro or "").replace("'", "''")[:500]
        sql_escaped  = (sql_gerado or "").replace("'", "''")[:2000]
        perg_escaped = (pergunta or "").replace("'", "''")[:500]
        sql = f"""
        INSERT INTO logs.interacoes
            (ip, pergunta, sql_gerado, sucesso, erro, tempo_ms, qtd_linhas)
        VALUES
            ('{ip}', '{perg_escaped}', '{sql_escaped}',
             {'true' if sucesso else 'false'},
             '{erro_escaped}', {tempo_ms}, {qtd_linhas})
        RETURNING id
        """
        cmd = ["docker", "exec", self.container, "psql", "-U", self.user, "-d", self.db,
               "-t", "-c", sql]
        result = subprocess.run(cmd, capture_output=True, text=True)
        try:
            first_line = result.stdout.strip().splitlines()[0].strip()
            return int(first_line)
        except:
            return None

    def get_all_ai_views(self):
        sql = """
        SELECT v.viewname,
               string_agg(c.column_name, ', ' ORDER BY c.ordinal_position) as colunas
        FROM pg_views v
        JOIN information_schema.columns c
            ON c.table_schema = 'gold' AND c.table_name = v.viewname
        WHERE v.schemaname = 'gold' AND v.viewname LIKE 'ai_%'
        GROUP BY v.viewname
        ORDER BY v.viewname
        """
        return self.execute_query(sql)


class LlamaClient:
    """Cliente Groq — usa Llama 3.1 8B via API na nuvem (rápido, gratuito)."""
    def __init__(self):
        self.api_key = os.getenv("OPENAI_API_KEY")
        if not self.api_key:
            raise RuntimeError("GROQ_API_KEY não encontrada no .env")
        self.url = "https://api.openai.com/v1/chat/completions"
        self.model = "gpt-4o-mini"

    def generate(self, prompt: str, system: str = "") -> str:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user",   "content": prompt},
            ],
            "temperature": 0.0,
            "max_tokens": 500,
        }
        try:
            response = requests.post(self.url, headers=headers, json=payload, timeout=30)
            response.raise_for_status()
            return response.json()["choices"][0]["message"]["content"]
        except Exception as e:
            raise RuntimeError(f"Groq indisponivel: {e}")


# ──────────────────────────────────────────────────────────────────────────────
# Schema verificado contra tcc-postgres/tcc_v3 em 2026-03-07
# Colunas reais do banco — NAO alterar sem verificar no banco primeiro
# ──────────────────────────────────────────────────────────────────────────────
SCHEMA = """
Você é um especialista em SQL para análise de compras farmacêuticas do Ministério da Saúde (MS) do Brasil.
Converta a pergunta do usuário em uma consulta SQL que use EXATAMENTE uma das views abaixo (schema gold).

REGRAS ABSOLUTAS:
1. Use SOMENTE os nomes de views e colunas listados abaixo — NUNCA invente nomes
2. Retorne APENAS o SQL puro, sem explicações, sem markdown, sem comentários
3. O SQL deve começar com SELECT
4. Filtros de texto: sempre use ILIKE com %, ex: WHERE medicamento ILIKE '%insulina%'
5. Nomes de secretarias: use EXATAMENTE 'SCTIE', 'SAPS', 'SVSA', 'SAES', 'SE'
6. Nunca use colunas que não estão na lista — verifique antes de usar

GUIA DE SELEÇÃO DE VIEW:
- "valor total gasto" / "resumo" → ai_visao_geral
- "por ano" / "evolução anual" (geral, sem secretaria) → ai_gastos_por_ano (colunas: ano, valor_total, contratos, preco_mediano)
- "por mês" / "mensal" → ai_gastos_por_mes
- "sazonalidade" / "qual mês compra mais" → ai_sazonalidade
- "por secretaria" (total acumulado) → ai_gastos_por_secretaria
- "por departamento" → ai_gastos_por_departamento
- "evolução por secretaria" / "histórico secretaria por ano" → ai_evolucao_por_secretaria
- "medicamentos mais comprados" (geral) → ai_top_medicamentos_valor ou ai_top_medicamentos_quantidade
- "medicamentos da SAPS/SCTIE/SVSA" → ai_medicamento_por_secretaria com WHERE secretaria = 'SIGLA'
- "histórico de [medicamento]" / "evolução mensal" → ai_historico_medicamento com ILIKE
- "preço da [medicamento] por ano" / "variação de preço" → ai_variacao_preco_medicamento com ILIKE
- "fornecedor único" / "dependência" → ai_medicamentos_fornecedor_unico
- "top fornecedores" (geral) → ai_top_fornecedores
- "top fornecedores da SCTIE/SAPS/SVSA" → ai_top_fornecedores_secretaria com WHERE secretaria = 'SIGLA'
- "o que [fornecedor] vende" / "portfolio" → ai_portfolio_fornecedor com WHERE fornecedor ILIKE '%nome%'
- "histórico do fornecedor X" → ai_historico_fornecedor com ILIKE
- "concentração de mercado" / "poucos fornecedores" / "HHI" → ai_concentracao_mercado
- "marcas de [medicamento]" → ai_marcas_por_medicamento com ILIKE
- "modalidade por ano" / "pregão x dispensa" → ai_modalidade_por_ano
- "modalidade por secretaria" (total) → ai_modalidade_por_secretaria
- "preço por modalidade para [medicamento]" → ai_modalidade_preco_comparado com ILIKE
- "modalidade da SCTIE ao longo dos anos" → ai_evolucao_secretaria_modalidade com WHERE secretaria = 'SCTIE'
- "MS paga mais caro/barato que estados" (lista geral) → ai_ms_vs_brasil com WHERE classificacao = 'MS paga mais caro'
- "onde MS paga 20% acima" → ai_ms_paga_mais_caro (colunas: medicamento, preco_ms, preco_brasil, diferenca_reais, diferenca_percentual, valor_total_gasto)
- "onde MS economiza" → ai_ms_paga_mais_barato (colunas: medicamento, preco_ms, preco_brasil, diferenca_reais, diferenca_percentual, valor_total_gasto)
- "MS vs UFs para [medicamento] por ano" / "evolução MS vs estados" → ai_comparacao_preco_ms_ufs com ILIKE
- "judicialização por ano" → ai_judicializacao_evolucao
- "medicamentos judicializados" → ai_judicializacao_top_medicamentos
- "judicial vs programático" → ai_judicializacao_vs_programatico

VIEWS DISPONÍVEIS — colunas exatas:

gold.ai_visao_geral
  Colunas: total_itens_contratados, total_itens_diferentes, total_fornecedores, valor_total_contratado, quantidade_total, preco_medio_unitario, primeira_compra, ultima_compra

gold.ai_gastos_por_ano
  Colunas: ano, itens_diferentes, registros, contratos, valor_total, quantidade_total, preco_mediano

gold.ai_gastos_por_mes
  Colunas: ano_mes, ano, mes, itens_diferentes, registros, valor_total, quantidade_total, preco_mediano

gold.ai_sazonalidade
  Colunas: mes, nome_mes, qtd_anos, valor_medio, valor_total, quantidade_total

gold.ai_gastos_por_secretaria
  Colunas: secretaria, itens_diferentes, total_itens, valor_total, quantidade_total, preco_mediano

gold.ai_gastos_por_departamento
  Colunas: secretaria, departamento, itens_diferentes, valor_total, quantidade_total, preco_mediano

gold.ai_evolucao_por_secretaria
  Colunas: ano, secretaria, valor_total, quantidade_total

gold.ai_evolucao_por_departamento
  Colunas: ano, secretaria, departamento, itens_diferentes, valor_total, quantidade_total, preco_mediano

gold.ai_top_medicamentos_valor
  Colunas: catmat, medicamento, valor_total, quantidade_total, itens_contratados, fornecedores, preco_medio

gold.ai_top_medicamentos_quantidade
  Colunas: catmat, medicamento, quantidade_total, valor_total, itens_contratados, preco_medio

gold.ai_historico_medicamento
  Colunas: catmat, medicamento, ano_mes, ano, mes, secretaria, valor_total, quantidade_total, preco_mediano, registros

gold.ai_medicamento_por_secretaria
  Colunas: secretaria, catmat, medicamento, registros, valor_total, quantidade_total, preco_medio

gold.ai_variacao_preco_medicamento
  Colunas: catmat, medicamento, ano, registros, preco_mediano, preco_medio, preco_minimo, preco_maximo

gold.ai_medicamentos_fornecedor_unico
  Colunas: catmat, medicamento, qtd_fornecedores, fornecedor, valor_total, quantidade_total, preco_medio

gold.ai_top_fornecedores
  Colunas: ni_fornecedor, fornecedor, itens_diferentes, itens_fornecidos, valor_total, quantidade_total, preco_medio

gold.ai_top_fornecedores_secretaria
  Colunas: secretaria, ni_fornecedor, fornecedor, contratos, itens_diferentes, valor_total, quantidade_total, preco_medio

gold.ai_fornecedores_por_medicamento
  Colunas: catmat, medicamento, ni_fornecedor, fornecedor, itens_fornecidos, valor_total, quantidade_total, preco_medio, primeira_compra, ultima_compra

gold.ai_portfolio_fornecedor
  Colunas: ni_fornecedor, fornecedor, catmat, medicamento, itens_fornecidos, valor_total, quantidade_total, preco_medio, primeira_compra, ultima_compra, secretaria

gold.ai_historico_fornecedor
  Colunas: ni_fornecedor, fornecedor, ano, contratos, itens_diferentes, valor_total, quantidade_total, preco_medio

gold.ai_fornecedor_medicamento_ano
  Colunas: ni_fornecedor, fornecedor, catmat, medicamento, ano, registros, quantidade_total, valor_total, preco_medio_unitario, preco_mediano_unitario

gold.ai_concentracao_mercado
  Colunas: catmat, medicamento, qtd_fornecedores, nivel_concentracao, indice_hhi, percentual_maior_fornecedor, principais_fornecedores

gold.ai_alta_concentracao
  Colunas: catmat, qtd_fornecedores, indice_hhi, percentual_maior, principais_fornecedores

gold.ai_top_marcas
  Colunas: marca, itens_diferentes, total_compras, preco_medio

gold.ai_marcas_por_medicamento
  Colunas: catmat, marca, compras_brasil, orgaos_usam, preco_medio, preco_minimo, preco_maximo, quantidade_total

gold.ai_modalidade_por_ano
  Colunas: modalidade, ano, contratos, itens, valor_total, preco_medio_unitario

gold.ai_modalidade_por_secretaria
  Colunas: secretaria, modalidade, contratos, valor_total, preco_medio_unitario

gold.ai_modalidade_preco_comparado
  Colunas: catmat, medicamento, modalidade, registros, preco_medio, preco_mediano, valor_total

gold.ai_evolucao_secretaria_modalidade
  Colunas: secretaria, modalidade, ano, contratos, itens, valor_total, preco_medio_unitario

gold.ai_ms_vs_brasil
  Colunas: catmat, medicamento, preco_ms, preco_brasil, diferenca, percentual_diferenca, classificacao, meses_comparados
  classificacao pode ser: 'MS paga mais caro', 'MS paga mais barato', 'Preços similares'

gold.ai_ms_paga_mais_caro
  Colunas: catmat, medicamento, preco_ms, preco_brasil, diferenca_reais, diferenca_percentual, valor_total_gasto

gold.ai_ms_paga_mais_barato
  Colunas: catmat, medicamento, preco_ms, preco_brasil, diferenca_reais, diferenca_percentual, valor_total_gasto

gold.ai_comparacao_preco_ms_ufs
  Colunas: catmat, medicamento, ano, registros_ms, media_ms, mediana_ms, registros_ufs, media_ufs, mediana_ufs, diff_media, diff_mediana, pct_diff_media, pct_diff_mediana

gold.ai_judicializacao_evolucao
  Colunas: ano, itens, valor_total, quantidade_total, preco_mediano

gold.ai_judicializacao_top_medicamentos
  Colunas: catmat, medicamento, ano, registros, valor_total, quantidade_total, preco_mediano

gold.ai_judicializacao_vs_programatico
  Colunas: ano, valor_judicial, valor_programatico, valor_total, pct_judicial
"""

EXAMPLES = """
EXEMPLOS — responda SOMENTE com o SQL, nada mais:

Pergunta: "resumo geral"
SQL: SELECT * FROM gold.ai_visao_geral

Pergunta: "qual o valor total gasto pelo MS em medicamentos"
SQL: SELECT valor_total_contratado FROM gold.ai_visao_geral

Pergunta: "evolucao anual de gastos"
SQL: SELECT ano, valor_total FROM gold.ai_gastos_por_ano ORDER BY ano

Pergunta: "quantos contratos foram firmados por ano"
SQL: SELECT ano, registros AS contratos FROM gold.ai_gastos_por_ano ORDER BY ano

Pergunta: "como evoluiu o gasto com medicamentos por ano entre 2021 e 2025"
SQL: SELECT ano, valor_total FROM gold.ai_gastos_por_ano WHERE ano BETWEEN 2021 AND 2025 ORDER BY ano

Pergunta: "quanto o MS gastou em 2024"
SQL: SELECT ano, valor_total FROM gold.ai_gastos_por_ano WHERE ano = 2024

Pergunta: "gastos mensais em 2023"
SQL: SELECT ano_mes, valor_total FROM gold.ai_gastos_por_mes WHERE ano = 2023 ORDER BY ano_mes

Pergunta: "qual mes o MS compra mais"
SQL: SELECT nome_mes, valor_medio FROM gold.ai_sazonalidade ORDER BY valor_medio DESC

Pergunta: "qual secretaria gasta mais"
SQL: SELECT secretaria, valor_total FROM gold.ai_gastos_por_secretaria ORDER BY valor_total DESC

Pergunta: "gastos por departamento da SCTIE"
SQL: SELECT departamento, valor_total FROM gold.ai_gastos_por_departamento WHERE secretaria = 'SCTIE' ORDER BY valor_total DESC

Pergunta: "historico de compras por secretaria por ano"
SQL: SELECT ano, secretaria, valor_total FROM gold.ai_evolucao_por_secretaria ORDER BY ano, secretaria

Pergunta: "gastos da SAPS por ano"
SQL: SELECT ano, secretaria, valor_total FROM gold.ai_evolucao_por_secretaria WHERE secretaria = 'SAPS' ORDER BY ano

Pergunta: "comparar SAPS e SCTIE ao longo dos anos"
SQL: SELECT ano, secretaria, valor_total FROM gold.ai_evolucao_por_secretaria WHERE secretaria IN ('SAPS', 'SCTIE') ORDER BY ano, secretaria

Pergunta: "top 10 medicamentos mais comprados por valor"
SQL: SELECT medicamento, valor_total FROM gold.ai_top_medicamentos_valor ORDER BY valor_total DESC LIMIT 10

Pergunta: "top 10 medicamentos por quantidade"
SQL: SELECT medicamento, quantidade_total FROM gold.ai_top_medicamentos_quantidade ORDER BY quantidade_total DESC LIMIT 10

Pergunta: "quais os 10 medicamentos mais comprados pela SAPS"
SQL: SELECT medicamento, valor_total, quantidade_total FROM gold.ai_medicamento_por_secretaria WHERE secretaria = 'SAPS' ORDER BY valor_total DESC LIMIT 10

Pergunta: "top 10 medicamentos mais comprados pela SCTIE"
SQL: SELECT medicamento, valor_total, quantidade_total FROM gold.ai_medicamento_por_secretaria WHERE secretaria = 'SCTIE' ORDER BY valor_total DESC LIMIT 10

Pergunta: "top 10 medicamentos mais comprados pela SVSA"
SQL: SELECT medicamento, valor_total, quantidade_total FROM gold.ai_medicamento_por_secretaria WHERE secretaria = 'SVSA' ORDER BY valor_total DESC LIMIT 10

Pergunta: "historico da dipirona"
SQL: SELECT ano_mes, medicamento, valor_total FROM gold.ai_historico_medicamento WHERE medicamento ILIKE '%dipirona%' ORDER BY ano_mes

Pergunta: "como evoluiu o preco da insulina por ano"
SQL: SELECT ano, medicamento, preco_mediano, preco_medio FROM gold.ai_variacao_preco_medicamento WHERE medicamento ILIKE '%insulina%' ORDER BY ano

Pergunta: "medicamentos com fornecedor unico"
SQL: SELECT medicamento, fornecedor, valor_total FROM gold.ai_medicamentos_fornecedor_unico ORDER BY valor_total DESC LIMIT 20

Pergunta: "top 10 fornecedores"
SQL: SELECT fornecedor, valor_total FROM gold.ai_top_fornecedores ORDER BY valor_total DESC LIMIT 10

Pergunta: "top 10 fornecedores da SCTIE"
SQL: SELECT fornecedor, valor_total, itens_diferentes FROM gold.ai_top_fornecedores_secretaria WHERE secretaria = 'SCTIE' ORDER BY valor_total DESC LIMIT 10

Pergunta: "quais fornecedores mais vendem para a SAPS"
SQL: SELECT fornecedor, valor_total, itens_diferentes FROM gold.ai_top_fornecedores_secretaria WHERE secretaria = 'SAPS' ORDER BY valor_total DESC LIMIT 10

Pergunta: "top fornecedores da SVSA"
SQL: SELECT fornecedor, valor_total FROM gold.ai_top_fornecedores_secretaria WHERE secretaria = 'SVSA' ORDER BY valor_total DESC LIMIT 10

Pergunta: "fornecedores de insulina"
SQL: SELECT fornecedor, valor_total, preco_medio FROM gold.ai_fornecedores_por_medicamento WHERE medicamento ILIKE '%insulina%' ORDER BY valor_total DESC

Pergunta: "o que a cristalia fornece"
SQL: SELECT medicamento, valor_total, quantidade_total, secretaria FROM gold.ai_portfolio_fornecedor WHERE fornecedor ILIKE '%cristalia%' ORDER BY valor_total DESC

Pergunta: "historico do fornecedor Y por ano"
SQL: SELECT ano, fornecedor, valor_total, itens_diferentes FROM gold.ai_historico_fornecedor WHERE fornecedor ILIKE '%Y%' ORDER BY ano

Pergunta: "quais medicamentos tem maior concentracao de mercado"
SQL: SELECT medicamento, qtd_fornecedores, nivel_concentracao, indice_hhi, percentual_maior_fornecedor FROM gold.ai_concentracao_mercado ORDER BY indice_hhi DESC LIMIT 20

Pergunta: "quais medicamentos tiveram maior variacao de preco entre contratos"
SQL: SELECT medicamento, ano, preco_minimo, preco_maximo, preco_mediano, ROUND((preco_maximo - preco_minimo)::numeric, 4) AS variacao FROM gold.ai_variacao_preco_medicamento ORDER BY (preco_maximo - preco_minimo) DESC LIMIT 20

Pergunta: "medicamentos com alta concentracao de fornecedores"
SQL: SELECT medicamento, qtd_fornecedores, nivel_concentracao, indice_hhi, percentual_maior_fornecedor FROM gold.ai_concentracao_mercado ORDER BY indice_hhi DESC LIMIT 20

Pergunta: "qual a distribuicao de compras por modalidade"
SQL: SELECT modalidade, SUM(valor_total) AS valor_total, SUM(contratos) AS contratos FROM gold.ai_modalidade_por_ano GROUP BY modalidade ORDER BY valor_total DESC

Pergunta: "quais modalidades o MS usa por ano"
SQL: SELECT modalidade, ano, valor_total FROM gold.ai_modalidade_por_ano ORDER BY ano, valor_total DESC

Pergunta: "participacao percentual de cada modalidade por secretaria"
SQL: SELECT secretaria, modalidade, valor_total, contratos FROM gold.ai_modalidade_por_secretaria ORDER BY secretaria, valor_total DESC

Pergunta: "como se distribuem as modalidades de compra da SCTIE ao longo dos anos"
SQL: SELECT ano, modalidade, valor_total, contratos FROM gold.ai_evolucao_secretaria_modalidade WHERE secretaria = 'SCTIE' ORDER BY ano, valor_total DESC

Pergunta: "historico de compras da SCTIE por modalidade"
SQL: SELECT ano, modalidade, valor_total FROM gold.ai_evolucao_secretaria_modalidade WHERE secretaria = 'SCTIE' ORDER BY ano, valor_total DESC

Pergunta: "como a SAPS usa pregao ao longo dos anos"
SQL: SELECT ano, modalidade, valor_total FROM gold.ai_evolucao_secretaria_modalidade WHERE secretaria = 'SAPS' ORDER BY ano, valor_total DESC

Pergunta: "o Ministerio da Saude paga mais caro que os estados para quais medicamentos"
SQL: SELECT medicamento, preco_ms, preco_brasil, diferenca, percentual_diferenca FROM gold.ai_ms_vs_brasil WHERE classificacao = 'MS paga mais caro' ORDER BY percentual_diferenca DESC LIMIT 20

Pergunta: "onde o MS paga mais caro que o Brasil"
SQL: SELECT medicamento, preco_ms, preco_brasil, diferenca_reais, diferenca_percentual, valor_total_gasto FROM gold.ai_ms_paga_mais_caro ORDER BY diferenca_percentual DESC LIMIT 20

Pergunta: "o Ministerio da Saude paga mais caro que os estados para quais medicamentos"
SQL: SELECT medicamento, preco_ms, preco_brasil, diferenca_reais, diferenca_percentual, valor_total_gasto FROM gold.ai_ms_paga_mais_caro ORDER BY diferenca_percentual DESC LIMIT 20

Pergunta: "onde o MS economiza em relacao ao Brasil"
SQL: SELECT medicamento, preco_ms, preco_brasil, diferenca_reais, diferenca_percentual, valor_total_gasto FROM gold.ai_ms_paga_mais_barato ORDER BY diferenca_percentual ASC LIMIT 20

Pergunta: "comparar preco MS vs Brasil"
SQL: SELECT medicamento, preco_ms, preco_brasil, percentual_diferenca, classificacao FROM gold.ai_ms_vs_brasil ORDER BY percentual_diferenca DESC LIMIT 20

Pergunta: "compare a evolucao anual do preco mediano da insulina comprada pelo MS versus o preco praticado pelas demais UFs entre 2021 e 2025"
SQL: SELECT ano, medicamento, mediana_ms, mediana_ufs, pct_diff_mediana FROM gold.ai_comparacao_preco_ms_ufs WHERE medicamento ILIKE '%insulina%' ORDER BY ano

Pergunta: "preco MS vs UFs para insulina por ano"
SQL: SELECT ano, medicamento, mediana_ms, mediana_ufs, pct_diff_mediana FROM gold.ai_comparacao_preco_ms_ufs WHERE medicamento ILIKE '%insulina%' ORDER BY ano

Pergunta: "como evoluiu a judicializacao por ano"
SQL: SELECT ano, valor_total FROM gold.ai_judicializacao_evolucao ORDER BY ano

Pergunta: "medicamentos mais judicializados"
SQL: SELECT medicamento, ano, valor_total FROM gold.ai_judicializacao_top_medicamentos ORDER BY valor_total DESC LIMIT 20

Pergunta: "como evoluiu a judicializacao em comparacao com as compras programaticas"
SQL: SELECT ano, valor_judicial, valor_programatico, pct_judicial FROM gold.ai_judicializacao_vs_programatico ORDER BY ano
"""


class TextToSQLSystem:
    def __init__(self):
        self.db = DatabaseClient()
        self.llama = LlamaClient()
        self.db.create_log_table()
        print("🔍 Carregando schema do banco...")
        self.views_df = self.db.get_all_ai_views()
        print(f"✅ {len(self.views_df)} views carregadas!")

    def _extract_sql_from_response(self, response: str) -> str:
        """Extração robusta: pega SELECT até ; ou fim, normaliza espaços"""
        if not response:
            raise ValueError("Modelo retornou resposta vazia")
        # Remove markdown
        text = re.sub(r'```sql', '', response, flags=re.IGNORECASE)
        text = re.sub(r'```', '', text).strip()
        # Normaliza aspas tipográficas que o GPT às vezes usa
        text = text.replace('‘', "'").replace('’', "'").replace('“', '"').replace('”', '"')
        # Busca SELECT em qualquer ponto da resposta
        match = re.search(r'(SELECT\b.+?)(?:;\s*$|;\s*\n|$)', text, re.IGNORECASE | re.DOTALL)
        if not match:
            raise ValueError(f"Nao foi possivel extrair SQL da resposta: {text[:200]}")
        sql = match.group(1).strip()
        sql = re.sub(r'\s+', ' ', sql).strip().rstrip(';')
        return sql

    def _generate_sql(self, question: str) -> str:
        system_prompt = f"""{SCHEMA}

{EXAMPLES}"""

        raw = self.llama.generate(
            prompt=f"Pergunta: {question}\nSQL:",
            system=system_prompt,
        )

        sql = self._extract_sql_from_response(raw)

        if not sql.upper().startswith("SELECT"):
            raise ValueError(f"Llama nao gerou SELECT valido. Resposta bruta: {raw[:300]}")

        if "gold." not in sql.lower():
            raise ValueError(f"SQL nao usa schema gold. SQL: {sql}")

        return sql + ";"

    # ──────────────────────────────────────────────────────────────────────
    # Detecção de gráfico baseada nas COLUNAS REAIS do resultado
    # ──────────────────────────────────────────────────────────────────────
    def _detect_chart_type(self, df: pd.DataFrame, question: str) -> str:
        if df.empty:
            return "none"

        q = question.lower()
        cols = [c.lower() for c in df.columns]

        has_ano     = "ano" in cols
        has_ano_mes = "ano_mes" in cols
        has_time    = has_ano or has_ano_mes

        has_category = any(c in cols for c in ["secretaria", "fornecedor", "departamento", "modalidade"])
        has_medicamento = "medicamento" in cols
        has_preco = any("preco" in c for c in cols)

        if has_time and has_category and len(df) > 1:
            return "line_multi"

        # medicamento + ano = linha (evolução temporal de um medicamento)
        if has_time and has_medicamento and len(df) > 1:
            return "line"

        # ano + preço sem categoria = linha
        if has_time and has_preco and len(df) > 1:
            return "line"

        if has_time and len(df) > 1:
            return "line"

        if any(w in q for w in ["top", "maior", "menor", "ranking", "mais", "menos", "caro", "barato"]):
            return "bar"

        if any(w in q for w in ["comparar", "versus", "vs", "entre"]):
            return "bar"

        if any(w in q for w in ["distribuicao", "percentual", "participacao"]):
            return "pie" if len(df) <= 8 else "bar"

        return "bar" if len(df) > 3 else "table"

    def process_question(self, question: str, ip: str = "desconhecido"):
        inicio = time.time()
        sql = None
        try:
            sql = self._generate_sql(question)
            df = self.db.execute_query(sql)
            chart_type = self._detect_chart_type(df, question)
            tempo_ms = int((time.time() - inicio) * 1000)
            id_log = self.db.log_interaction(
                ip=ip, pergunta=question, sql_gerado=sql,
                sucesso=True, erro="", tempo_ms=tempo_ms, qtd_linhas=len(df)
            )
            return {
                "question": question,
                "sql": sql,
                "data": df,
                "metadata": {
                    "success": True,
                    "rows": len(df),
                    "columns": list(df.columns) if not df.empty else [],
                },
                "chart_type": chart_type,
                "error": None,
                "id_interacao": id_log,
            }
        except Exception as e:
            tempo_ms = int((time.time() - inicio) * 1000)
            id_log = self.db.log_interaction(
                ip=ip, pergunta=question, sql_gerado=sql or "",
                sucesso=False, erro=str(e), tempo_ms=tempo_ms, qtd_linhas=0
            )
            return {
                "question": question,
                "error": f"Erro: {str(e)}",
                "data": pd.DataFrame(),
                "sql": None,
                "metadata": {"success": False},
                "chart_type": None,
                "id_interacao": id_log,
            }

    def close(self):
        pass


def format_number(value):
    if pd.isna(value):
        return "-"
    if isinstance(value, (int, float)):
        if value >= 1e9:
            return f"R$ {value/1e9:.2f}B"
        elif value >= 1e6:
            return f"R$ {value/1e6:.2f}M"
        elif value >= 1e3:
            return f"R$ {value/1e3:.2f}K"
        return f"R$ {value:.2f}"
    return str(value)
