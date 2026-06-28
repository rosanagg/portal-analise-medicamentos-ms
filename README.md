# Portal de Análise de Compras de Medicamentos do Ministério da Saúde

Sistema de consulta em linguagem natural sobre compras públicas de medicamentos do Ministério da Saúde (MS), desenvolvido como Trabalho de Conclusão de Curso do MBA em Ciência de Dados e Inteligência Artificial Aplicadas — ENAP (2026).

O sistema utiliza a abordagem Text-to-SQL com o modelo GPT-4o-mini (OpenAI) para converter perguntas em linguagem natural em consultas SQL sobre uma base de dados PostgreSQL estruturada em Arquitetura Medalhão (Bronze/Silver/Gold).

## Estrutura do repositório

```
├── main.py                        # Motor Text-to-SQL (geração e execução de SQL)
├── app.py                         # Interface web (Streamlit)
├── setup_v4.sql                   # Criação do schema e tabelas (Bronze/Silver/Gold)
├── load_v4.sql                    # Carga dos dados nas tabelas RAW e Silver
├── views_gold_DEFINITIVO_v4.sql   # Views analíticas da camada Gold
├── setup_log.sql                  # Schema de logs de interações e avaliações
├── .env.example                   # Modelo de variáveis de ambiente
└── README.md
```

## Pré-requisitos

- Python 3.10+
- Docker (com container PostgreSQL em execução)
- Conta na OpenAI com chave de API ativa

## Instalação

```bash
pip install streamlit pandas python-dotenv requests
```

## Configuração

1. Copie o arquivo de exemplo de variáveis de ambiente:

```bash
cp .env.example .env
```

2. Edite o `.env` e insira sua chave de API da OpenAI:

```
OPENAI_API_KEY=sk-proj-...
```

3. Certifique-se de que o container PostgreSQL está rodando com o nome `tcc-postgres` e o banco `tcc_v4`:

```bash
docker ps | grep tcc-postgres
```

## Carga dos dados

Execute os scripts SQL na seguinte ordem:

```bash
psql -U postgres -d tcc_v4 -f setup_v4.sql
psql -U postgres -d tcc_v4 -f setup_log.sql
psql -U postgres -d tcc_v4 -f load_v4.sql
psql -U postgres -d tcc_v4 -f views_gold_DEFINITIVO_v4.sql
```

Os arquivos de dados (CSV) devem ser depositados em `/data/` dentro do container, ou o caminho ajustado no `load_v4.sql`. Os dados estão disponíveis no repositório Zenodo: https://doi.org/10.5281/zenodo.20997853

## Execução

```bash
streamlit run app.py
```

## Dados

Os dados utilizados neste projeto são de domínio público, extraídos da API do portal Compras.gov.br (classe CATMAT 6505 — medicamentos, UASG 250005 — Ministério da Saúde, período 2019–2024).

Repositório de dados: https://doi.org/10.5281/zenodo.20997853

## Declaração de uso de IA Generativa

Ferramentas de IA generativa foram utilizadas nas seguintes etapas:
- Refatoração e revisão de código-fonte (scripts Python e SQL)
- Revisão textual do manuscrito acadêmico

A responsabilidade pelo conteúdo final, interpretações e conclusões é integralmente da autora.

## Autora

Rosana — Diretora de Programa, DGITS/SCTIE/Ministério da Saúde  
MBA em Ciência de Dados e Inteligência Artificial Aplicadas — ENAP, 2026

