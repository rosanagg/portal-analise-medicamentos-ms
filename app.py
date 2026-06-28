# ============================================================
# FRONTEND STREAMLIT - TEXT-TO-SQL COM LLAMA
# Ministério da Saúde / SCTIE — Identidade Visual Oficial
# ============================================================

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "backend"))
from main import TextToSQLSystem, format_number

# ============================================================
# CONFIGURAÇÃO DA PÁGINA
# ============================================================

st.set_page_config(
    page_title="Portal de Análise de Compras de Medicamentos — MS",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ============================================================
# PALETA OFICIAL MS (Manual de Identidade Visual SUS)
# Azul SUS: Pantone 287C | RGB 0,91,171 | HEX #005B9A
# ============================================================

st.markdown("""
<style>
    /* ── Importar fonte Rawline (tipografia institucional MS) ── */
    @import url('https://fonts.googleapis.com/css2?family=Noto+Sans:wght@400;500;600;700&display=swap');

    /* ── Variáveis de cor MS ── */
    :root {
        --ms-azul:        #005B9A;
        --ms-azul-escuro: #003F6B;
        --ms-azul-claro:  #E8F1F8;
        --ms-verde:       #00873F;
        --ms-cinza:       #595959;
        --ms-cinza-claro: #F4F6F8;
        --ms-branco:      #FFFFFF;
        --ms-borda:       #C8D8E8;
        --ms-alerta:      #D62828;
        --ms-sucesso:     #2E7D32;
    }

    /* ── Reset geral ── */
    html, body, [class*="css"] {
        font-family: 'Noto Sans', sans-serif !important;
    }

    .main .block-container {
        padding-top: 0 !important;
        padding-bottom: 0 !important;
        max-width: 1280px;
    }

    /* Remove espaço padrão do Streamlit no topo */
    [data-testid="stAppViewContainer"] > .main {
        padding-top: 0 !important;
    }

    [data-testid="stHeader"] {
        display: none !important;
    }

    section[data-testid="stSidebar"] + div {
        padding-top: 0 !important;
    }

    /* ── Barra superior MS ── */
    .ms-topbar {
        background: var(--ms-azul);
        color: white;
        padding: 8px 24px;
        font-size: 0.75rem;
        letter-spacing: 0.05em;
        text-transform: uppercase;
        margin-bottom: 0;
    }

    /* ── Header principal ── */
    .ms-header {
        background: linear-gradient(135deg, var(--ms-azul-escuro) 0%, var(--ms-azul) 60%, #0077CC 100%);
        color: white;
        padding: 28px 32px 24px 32px;
        display: flex;
        align-items: center;
        gap: 20px;
        margin-bottom: 24px;
        border-bottom: 4px solid var(--ms-verde);
    }

    .ms-header-logo {
        font-size: 3rem;
        line-height: 1;
    }

    .ms-header-text h1 {
        margin: 0 0 4px 0;
        font-size: 1.5rem;
        font-weight: 700;
        letter-spacing: -0.01em;
        color: white !important;
    }

    .ms-header-text p {
        margin: 0;
        font-size: 0.85rem;
        opacity: 0.85;
        color: white !important;
    }

    .ms-header-badge {
        margin-left: auto;
        background: rgba(255,255,255,0.15);
        border: 1px solid rgba(255,255,255,0.3);
        padding: 6px 14px;
        border-radius: 20px;
        font-size: 0.75rem;
        text-align: center;
        line-height: 1.4;
    }

    /* ── Caixa de busca ── */
    .ms-search-container {
        background: var(--ms-branco);
        border: 2px solid var(--ms-borda);
        border-radius: 8px;
        padding: 24px;
        margin-bottom: 20px;
        box-shadow: 0 2px 8px rgba(0,91,154,0.08);
    }

    .ms-search-label {
        font-size: 0.85rem;
        font-weight: 600;
        color: var(--ms-azul-escuro);
        text-transform: uppercase;
        letter-spacing: 0.06em;
        margin-bottom: 8px;
    }

    /* ── Botão primário MS ── */
    .stButton > button[kind="primary"] {
        background-color: var(--ms-azul) !important;
        border-color: var(--ms-azul) !important;
        font-weight: 600 !important;
        letter-spacing: 0.02em !important;
        border-radius: 4px !important;
    }

    .stButton > button[kind="primary"]:hover {
        background-color: var(--ms-azul-escuro) !important;
        border-color: var(--ms-azul-escuro) !important;
    }

    /* ── Cards de resultado ── */
    .ms-result-card {
        background: var(--ms-branco);
        border: 1px solid var(--ms-borda);
        border-radius: 8px;
        padding: 20px 24px;
        margin-bottom: 16px;
        box-shadow: 0 2px 6px rgba(0,91,154,0.06);
    }

    .ms-result-card h3 {
        color: var(--ms-azul-escuro);
        font-size: 0.9rem;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        margin: 0 0 12px 0;
        padding-bottom: 10px;
        border-bottom: 2px solid var(--ms-azul-claro);
    }

    /* ── Tag de status ── */
    .ms-tag-sucesso {
        display: inline-block;
        background: #E8F5E9;
        color: var(--ms-sucesso);
        border: 1px solid #A5D6A7;
        padding: 2px 10px;
        border-radius: 12px;
        font-size: 0.75rem;
        font-weight: 600;
    }

    .ms-tag-erro {
        display: inline-block;
        background: #FFEBEE;
        color: var(--ms-alerta);
        border: 1px solid #FFCDD2;
        padding: 2px 10px;
        border-radius: 12px;
        font-size: 0.75rem;
        font-weight: 600;
    }

    /* ── Sidebar ── */
    [data-testid="stSidebar"] {
        background: var(--ms-azul-claro) !important;
        border-right: 2px solid var(--ms-borda) !important;
    }

    [data-testid="stSidebar"] .stButton > button {
        background: white !important;
        border: 1px solid var(--ms-borda) !important;
        color: var(--ms-azul-escuro) !important;
        font-size: 0.82rem !important;
        text-align: left !important;
        border-radius: 4px !important;
        transition: all 0.15s;
    }

    [data-testid="stSidebar"] .stButton > button:hover {
        background: var(--ms-azul) !important;
        color: white !important;
        border-color: var(--ms-azul) !important;
    }

    .sidebar-section-title {
        font-size: 0.72rem;
        font-weight: 700;
        color: var(--ms-azul);
        text-transform: uppercase;
        letter-spacing: 0.08em;
        margin: 16px 0 8px 0;
        padding-bottom: 4px;
        border-bottom: 2px solid var(--ms-azul);
    }

    /* ── Footer ── */
    .ms-footer {
        background: var(--ms-azul-escuro);
        color: rgba(255,255,255,0.7);
        padding: 16px 24px;
        font-size: 0.78rem;
        text-align: center;
        margin-top: 32px;
        border-top: 3px solid var(--ms-verde);
    }

    .ms-footer strong {
        color: white;
    }

    /* ── Formulário de satisfação ── */
    .ms-form-container {
        background: var(--ms-branco);
        border: 2px solid var(--ms-azul);
        border-radius: 8px;
        padding: 24px;
        margin-top: 24px;
    }

    .ms-form-title {
        color: var(--ms-azul-escuro);
        font-size: 1rem;
        font-weight: 700;
        margin-bottom: 16px;
        display: flex;
        align-items: center;
        gap: 8px;
    }

    /* ── Métricas estilo MS ── */
    .ms-metric {
        background: var(--ms-azul-claro);
        border-left: 4px solid var(--ms-azul);
        padding: 12px 16px;
        border-radius: 0 6px 6px 0;
        margin-bottom: 8px;
    }

    .ms-metric-label {
        font-size: 0.72rem;
        color: var(--ms-cinza);
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }

    .ms-metric-value {
        font-size: 1.3rem;
        font-weight: 700;
        color: var(--ms-azul-escuro);
    }

    /* ── Esconde elementos desnecessários do Streamlit ── */
    #MainMenu, footer, header { visibility: hidden; }
    .stDeployButton { display: none; }
    [data-testid="stDecoration"] { display: none !important; }
    [data-testid="stStatusWidget"] { display: none !important; }

    /* ── Input customizado ── */
    .stTextInput > div > div > input {
        border: 2px solid var(--ms-borda) !important;
        border-radius: 4px !important;
        font-size: 1rem !important;
        padding: 10px 14px !important;
    }

    .stTextInput > div > div > input:focus {
        border-color: var(--ms-azul) !important;
        box-shadow: 0 0 0 3px rgba(0,91,154,0.15) !important;
    }

    /* ── Código SQL ── */
    .stCodeBlock {
        border-left: 4px solid var(--ms-azul) !important;
        border-radius: 0 4px 4px 0 !important;
    }
</style>
""", unsafe_allow_html=True)

# ============================================================
# FUNÇÕES DE VISUALIZAÇÃO
# ============================================================

MS_COLORS = [
    '#005B9A',  # azul MS
    '#E53935',  # vermelho
    '#00873F',  # verde MS
    '#F57C00',  # laranja
    '#7B1FA2',  # roxo
    '#0097A7',  # ciano
    '#C62828',  # vermelho escuro
    '#1565C0',  # azul escuro
    '#2E7D32',  # verde escuro
    '#AD1457',  # rosa
    '#F9A825',  # amarelo
    '#00695C',  # verde azulado
]

def create_chart(df: pd.DataFrame, chart_type: str, question: str):
    if df.empty or chart_type == "none":
        return None

    numeric_cols = df.select_dtypes(include=['number']).columns.tolist()
    text_cols    = df.select_dtypes(include=['object']).columns.tolist()
    all_cols     = df.columns.tolist()

    time_cols     = [c for c in all_cols if any(k in c.lower() for k in ['ano', 'mes', 'data', 'ano_mes'])]
    value_cols    = [c for c in numeric_cols if any(k in c.lower() for k in ['valor', 'total', 'preco', 'quantidade', 'qtd'])]
    category_cols = [c for c in text_cols if any(k in c.lower() for k in ['secretaria', 'medicamento', 'fornecedor', 'nome', 'catmat', 'modalidade', 'departamento'])]

    layout_base = dict(
        font=dict(family="Noto Sans, sans-serif", size=13, color="#003F6B"),
        paper_bgcolor="white",
        plot_bgcolor="#F4F6F8",
        height=480,
        margin=dict(l=40, r=30, t=50, b=60),
        title=dict(font=dict(size=14, color="#003F6B"), x=0.0, xanchor="left"),
    )

    if chart_type == "line_multi":
        x_col = time_cols[0] if time_cols else all_cols[0]

        # Caso 1: comparação MS vs UFs (mediana_ms + mediana_ufs)
        comparacao_cols = [c for c in df.columns if c in ['mediana_ms', 'mediana_ufs', 'media_ms', 'media_ufs']]
        # Caso 2: múltiplas colunas de valor sem coluna de categoria (ex: judicial + programatico)
        multi_value_cols = [c for c in (value_cols + numeric_cols)
                           if c != x_col and c not in (category_cols + text_cols)]

        melt_cols = comparacao_cols if comparacao_cols else (
            multi_value_cols if len(multi_value_cols) >= 2 and not category_cols else []
        )

        if melt_cols and x_col:
            id_cols = [c for c in df.columns if c not in melt_cols]
            df_melt = df.melt(id_vars=id_cols, value_vars=melt_cols,
                              var_name='série', value_name='valor')
            df_melt[x_col] = df_melt[x_col].astype(str)
            label_map = {
                'mediana_ms': 'MS (Ministério da Saúde)', 'mediana_ufs': 'UFs (Estados)',
                'media_ms': 'Média MS', 'media_ufs': 'Média UFs',
                'valor_judicial': 'Judicialização', 'valor_programatico': 'Programático',
            }
            df_melt['série'] = df_melt['série'].map(lambda x: label_map.get(x, x.replace('_', ' ').title()))
            fig = px.line(df_melt, x=x_col, y='valor', color='série', title=question,
                          markers=True, color_discrete_sequence=MS_COLORS)
            fig.update_traces(line=dict(width=2.5), marker=dict(size=7))
            fig.update_layout(**layout_base, hovermode='x unified',
                              legend=dict(bgcolor="rgba(255,255,255,0.9)", bordercolor="#C8D8E8", borderwidth=1))
            fig.update_xaxes(gridcolor="#DDE8F0", linecolor="#C8D8E8", type='category')
            fig.update_yaxes(gridcolor="#DDE8F0", linecolor="#C8D8E8")
            return fig

        color_col = category_cols[0] if category_cols else (text_cols[0] if text_cols else None)
        y_col     = value_cols[0] if value_cols else (numeric_cols[0] if numeric_cols else all_cols[2])

        if color_col:
            df_plot = df.copy()
            df_plot[x_col] = df_plot[x_col].astype(str)
            fig = px.line(
                df_plot, x=x_col, y=y_col, color=color_col,
                title=question, markers=True,
                color_discrete_sequence=MS_COLORS,
                labels={c: c.replace('_', ' ').title() for c in [x_col, y_col, color_col]}
            )
            fig.update_traces(line=dict(width=2.5))
            fig.update_layout(**layout_base, hovermode='x unified',
                              legend=dict(bgcolor="rgba(255,255,255,0.9)", bordercolor="#C8D8E8", borderwidth=1))
            fig.update_xaxes(gridcolor="#DDE8F0", linecolor="#C8D8E8", type='category')
            fig.update_yaxes(gridcolor="#DDE8F0", linecolor="#C8D8E8")
            return fig

    if chart_type == "line":
        x_col = time_cols[0] if time_cols else (text_cols[0] if text_cols else all_cols[0])
        y_col = value_cols[0] if value_cols else (numeric_cols[0] if numeric_cols else (all_cols[1] if len(all_cols) > 1 else None))
        if y_col is None or y_col == x_col:
            return None

        df_plot = df.copy()
        df_plot[x_col] = df_plot[x_col].astype(str)
        fig = px.line(
            df_plot, x=x_col, y=y_col, title=question, markers=True,
            color_discrete_sequence=[MS_COLORS[0]],
            labels={c: c.replace('_', ' ').title() for c in [x_col, y_col]}
        )
        fig.update_traces(line=dict(width=2.5), marker=dict(size=7))
        fig.update_layout(**layout_base, hovermode='x unified')
        fig.update_xaxes(gridcolor="#DDE8F0", linecolor="#C8D8E8", type='category')
        fig.update_yaxes(gridcolor="#DDE8F0", linecolor="#C8D8E8")
        return fig

    elif chart_type == "bar":
        x_col = category_cols[0] if category_cols else (text_cols[0] if text_cols else all_cols[0])
        y_col = value_cols[0] if value_cols else (numeric_cols[0] if numeric_cols else (all_cols[1] if len(all_cols) > 1 else None))
        if y_col is None or y_col == x_col:
            return None

        df_plot = df.nlargest(25, y_col) if len(df) > 25 else df

        fig = px.bar(
            df_plot, x=x_col, y=y_col, title=question,
            color=y_col, color_continuous_scale=[[0, '#E8F1F8'], [0.5, '#0077CC'], [1, '#003F6B']],
            labels={c: c.replace('_', ' ').title() for c in [x_col, y_col]}
        )
        fig.update_layout(**layout_base, showlegend=False, coloraxis_showscale=False)
        fig.update_xaxes(gridcolor="#DDE8F0", linecolor="#C8D8E8", tickangle=-35)
        fig.update_yaxes(gridcolor="#DDE8F0", linecolor="#C8D8E8")
        return fig

    elif chart_type == "pie":
        names_col  = category_cols[0] if category_cols else (text_cols[0] if text_cols else all_cols[0])
        values_col = value_cols[0] if value_cols else (numeric_cols[0] if numeric_cols else all_cols[1])

        df_plot = df.nlargest(10, values_col) if len(df) > 10 else df

        fig = px.pie(
            df_plot, names=names_col, values=values_col, title=question,
            color_discrete_sequence=MS_COLORS
        )
        fig.update_traces(textposition='inside', textinfo='percent+label',
                          marker=dict(line=dict(color='white', width=2)))
        fig.update_layout(**layout_base)
        return fig

    return None


# ============================================================
# LOG DE SATISFAÇÃO NO BANCO
# ============================================================

def salvar_avaliacao(system, pergunta, id_interacao, correspondeu, tentativas, dificuldade_pergunta, grafico_util, usaria, substituiria, comentario):
    """Salva avaliação de satisfação na tabela logs.avaliacoes"""
    coment_escaped = (comentario or "").replace("'", "''")[:1000]
    perg_escaped   = (pergunta or "").replace("'", "''")[:500]
    id_val = str(id_interacao) if id_interacao is not None else "NULL"
    sql = f"""
    INSERT INTO logs.avaliacoes (
        id_interacao, pergunta_contexto, correspondeu, tentativas,
        dificuldade_pergunta, grafico_util, usaria, substituiria, comentario
    ) VALUES (
        {id_val}, '{perg_escaped}', '{correspondeu}', {tentativas},
        {str(dificuldade_pergunta).lower()}, '{grafico_util}',
        {str(usaria).lower()}, '{substituiria}', '{coment_escaped}'
    )
    """
    cmd = ["docker", "exec", system.db.container, "psql",
           "-U", system.db.user, "-d", system.db.db, "-c", sql]
    import subprocess
    subprocess.run(cmd, capture_output=True, text=True)


def garantir_tabela_avaliacoes(system):
    sql = """
    CREATE TABLE IF NOT EXISTS logs.avaliacoes (
        id                  bigserial PRIMARY KEY,
        data_hora           timestamptz DEFAULT now(),
        pergunta_contexto   text,
        correspondeu        text,
        tentativas          integer,
        dificuldade_pergunta boolean,
        grafico_util        text,
        usaria              boolean,
        substituiria        text,
        comentario          text
    )
    """
    cmd = ["docker", "exec", system.db.container, "psql",
           "-U", system.db.user, "-d", system.db.db, "-c", sql]
    import subprocess
    subprocess.run(cmd, capture_output=True, text=True)


# ============================================================
# INICIALIZAÇÃO
# ============================================================

@st.cache_resource
def init_system():
    s = TextToSQLSystem()
    garantir_tabela_avaliacoes(s)
    return s

# ============================================================
# HEADER INSTITUCIONAL
# ============================================================

st.markdown("""
<div class="ms-topbar">
    🇧🇷 &nbsp; Governo Federal &nbsp;·&nbsp; Ministério da Saúde &nbsp;·&nbsp; SCTIE — Secretaria de Ciência, Tecnologia, Inovação e Insumos Estratégicos em Saúde
</div>
<div class="ms-header">
    <div class="ms-header-logo">🏥</div>
    <div class="ms-header-text">
        <h1>Portal de Análise de Compras de Medicamentos</h1>
        <p>Consulte dados de compras de medicamentos do Ministério da Saúde em linguagem natural &nbsp;·&nbsp; 2021–2025</p>
    </div>
    <div class="ms-header-badge">
        🤖 Llama 3.1 8B<br>
        <span style="font-size:0.7rem; opacity:0.8">Text-to-SQL · R$ 86,6B</span>
    </div>
</div>
""", unsafe_allow_html=True)

# ============================================================
# SIDEBAR
# ============================================================

with st.sidebar:
    st.markdown('<div class="sidebar-section-title">⚙️ Status do Sistema</div>', unsafe_allow_html=True)

    try:
        system = init_system()
        st.success("✅ PostgreSQL conectado")
        st.success("✅ Llama 3.1 8B ativo")
    except Exception as e:
        st.error(f"❌ Erro: {e}")
        st.stop()

    st.markdown('<div class="sidebar-section-title">💡 Exemplos de Perguntas</div>', unsafe_allow_html=True)

    exemplos = {
        "📊 Visão Geral": [
            "Resumo geral da base",
            "Evolução anual de gastos",
            "Qual mês o MS compra mais?",
        ],
        "🏥 Secretarias": [
            "Qual secretaria gasta mais?",
            "Gastos da SCTIE por ano",
            "Comparar SAPS e SCTIE",
            "Gastos por departamento da SCTIE",
        ],
        "💊 Medicamentos": [
            "Top 10 medicamentos mais caros",
            "Histórico da insulina",
            "Como evoluiu o preço da insulina?",
            "Medicamentos com fornecedor único",
        ],
        "🏭 Fornecedores": [
            "Top 10 fornecedores",
            "O que a Cristália fornece?",
            "Concentração de mercado",
        ],
        "⚖️ Comparações": [
            "MS paga mais caro que outros órgãos?",
            "Onde o MS economiza?",
            "Preço MS vs UFs para insulina",
            "Pregão é mais barato para insulina?",
        ],
        "📋 Judicialização": [
            "Gastos com judicialização por ano",
            "Medicamentos mais judicializados",
            "Judicial vs programático por ano",
        ],
    }

    for grupo, perguntas in exemplos.items():
        with st.expander(grupo, expanded=False):
            for p in perguntas:
                if st.button(p, key=p, use_container_width=True):
                    st.session_state.question = p

    st.markdown("---")
    st.markdown('<div class="sidebar-section-title">🎛️ Configurações</div>', unsafe_allow_html=True)
    show_sql      = st.checkbox("Mostrar SQL gerado", value=True)
    show_metadata = st.checkbox("Mostrar metadados", value=False)
    auto_chart    = st.checkbox("Gráfico automático", value=True)

    # Botão de avaliação
    st.markdown("---")
    st.markdown('<div class="sidebar-section-title">📝 Avalie a Ferramenta</div>', unsafe_allow_html=True)
    if st.button("📋 Abrir Formulário", use_container_width=True, key="btn_form"):
        st.session_state.show_form = True

# ============================================================
# ÁREA PRINCIPAL — BUSCA
# ============================================================

st.markdown('<div class="ms-search-container">', unsafe_allow_html=True)
st.markdown('<div class="ms-search-label">💬 Faça sua pergunta em linguagem natural</div>', unsafe_allow_html=True)

question = st.text_input(
    label="pergunta",
    label_visibility="collapsed",
    value=st.session_state.get("question", ""),
    placeholder="Ex: Quanto o Ministério da Saúde gastou com insulina em 2024?",
    key="question_input"
)

col1, col2, col3 = st.columns([1, 1, 5])
with col1:
    submit = st.button("🔍 Consultar", type="primary", use_container_width=True)
with col2:
    if st.button("🗑️ Limpar", use_container_width=True):
        st.session_state.clear()
        st.rerun()

st.markdown('</div>', unsafe_allow_html=True)

# ============================================================
# PROCESSAR PERGUNTA
# ============================================================

if submit and question:
    # Capturar IP (melhor esforço)
    try:
        import socket
        ip = socket.gethostbyname(socket.gethostname())
    except:
        ip = "localhost"

    with st.spinner("⏳ Processando com Llama 3.1 8B..."):
        result = system.process_question(question, ip=ip)

    if result["error"]:
        st.markdown(f"""
        <div class="ms-result-card">
            <h3>❌ Erro na consulta</h3>
            <span class="ms-tag-erro">Falha</span>
            <p style="margin-top:10px; color:#595959; font-size:0.9rem;">{result['error']}</p>
        </div>
        """, unsafe_allow_html=True)
    else:
        # SQL
        if show_sql:
            st.markdown('<div class="ms-result-card"><h3>📝 SQL Gerado</h3>', unsafe_allow_html=True)
            st.code(result["sql"], language="sql")
            st.markdown('</div>', unsafe_allow_html=True)

        # Metadados
        if show_metadata:
            c1, c2, c3 = st.columns(3)
            with c1:
                st.markdown(f"""<div class="ms-metric">
                    <div class="ms-metric-label">Linhas retornadas</div>
                    <div class="ms-metric-value">{result["metadata"].get("rows", 0)}</div>
                </div>""", unsafe_allow_html=True)
            with c2:
                st.markdown(f"""<div class="ms-metric">
                    <div class="ms-metric-label">Colunas</div>
                    <div class="ms-metric-value">{len(result["metadata"].get("columns", []))}</div>
                </div>""", unsafe_allow_html=True)
            with c3:
                st.markdown(f"""<div class="ms-metric">
                    <div class="ms-metric-label">Status</div>
                    <div class="ms-metric-value" style="font-size:1rem">
                        <span class="ms-tag-sucesso">✓ Sucesso</span>
                    </div>
                </div>""", unsafe_allow_html=True)

        df = result["data"]

        if df.empty:
            st.info("ℹ️ Nenhum resultado encontrado para esta consulta.")
        else:
            # Gráfico
            if auto_chart and result["chart_type"] not in ["none", "table"]:
                st.markdown('<div class="ms-result-card"><h3>📈 Visualização</h3>', unsafe_allow_html=True)
                fig = create_chart(df, result["chart_type"], question)
                if fig:
                    st.plotly_chart(fig, use_container_width=True)
                st.markdown('</div>', unsafe_allow_html=True)

            # Tabela
            st.markdown('<div class="ms-result-card"><h3>📋 Dados da Consulta</h3>', unsafe_allow_html=True)
            df_display = df.copy()
            for col in df_display.select_dtypes(include=['number']).columns:
                c = col.lower()
                # Aplica R$ só em colunas monetárias — não em quantidades e contagens
                is_money = any(k in c for k in ['valor', 'preco', 'receita'])
                is_money = is_money or (
                    any(k in c for k in ['total', 'media', 'medio', 'mediano']) and
                    not any(k in c for k in ['quantidade', 'itens', 'qtd', 'registros',
                                             'contratos', 'fornecedores', 'meses', 'anos', 'diferentes'])
                )
                if is_money:
                    df_display[col] = df_display[col].apply(format_number)
            st.dataframe(df_display, use_container_width=True, height=380)

            # Downloads
            c1, c2, c3 = st.columns(3)
            with c1:
                st.download_button(
                    "📥 Baixar CSV", df.to_csv(index=False).encode('utf-8'),
                    file_name=f"sctie_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}.csv",
                    mime="text/csv", use_container_width=True
                )
            with c2:
                st.download_button(
                    "📋 Copiar SQL", result["sql"],
                    file_name="query.sql", mime="text/plain",
                    use_container_width=True
                )
            st.markdown('</div>', unsafe_allow_html=True)

        # Guardar última pergunta e id do log para o formulário
        st.session_state.last_question = question
        st.session_state.last_id_interacao = result.get("id_interacao")

# ============================================================
# FORMULÁRIO DE SATISFAÇÃO
# ============================================================

if st.session_state.get("show_form", False):
    st.markdown("---")
    st.markdown("""
    <div class="ms-form-title">📝 Avaliação da Ferramenta — Teste Alfa</div>
    """, unsafe_allow_html=True)

    with st.form("form_avaliacao", clear_on_submit=True):
        st.markdown("Suas respostas são anônimas e ajudarão a melhorar o sistema.")
        st.markdown("")

        correspondeu = st.radio(
            "A resposta correspondeu ao que você queria saber?",
            options=["Sim", "Parcialmente", "Não"],
            horizontal=True
        )

        tentativas = st.radio(
            "Quantas tentativas precisou para obter uma resposta útil?",
            options=[1, 2, 3],
            format_func=lambda x: {1: "1", 2: "2", 3: "3 ou mais"}[x],
            horizontal=True
        )

        dificuldade_pergunta = st.radio(
            "Teve dificuldade em formular a pergunta?",
            options=["Sim", "Não"],
            horizontal=True
        )

        grafico_util = st.radio(
            "O gráfico ajudou a entender a informação?",
            options=["Sim", "Não", "Não gerou gráfico"],
            horizontal=True
        )

        usaria = st.radio(
            "Usaria essa ferramenta no seu trabalho?",
            options=["Sim", "Talvez", "Não"],
            horizontal=True
        )

        substituiria = st.radio(
            "Essa consulta substituiria uma solicitação ao setor de TI?",
            options=["Sim", "Não", "Não sei"],
            horizontal=True
        )

        comentario = st.text_area(
            "Comentários ou sugestões (opcional):",
            placeholder="O que poderia ser melhorado? Que tipo de pergunta você gostaria de fazer?",
            height=80
        )

        contexto = st.session_state.get("last_question", "")
        id_interacao = st.session_state.get("last_id_interacao")

        c1, c2 = st.columns([1, 3])
        with c1:
            enviar = st.form_submit_button("✅ Enviar Avaliação", type="primary", use_container_width=True)
        with c2:
            cancelar = st.form_submit_button("Cancelar", use_container_width=False)

        if enviar:
            salvar_avaliacao(
                system, contexto, id_interacao,
                correspondeu, tentativas,
                dificuldade_pergunta == "Sim",
                grafico_util, usaria == "Sim",
                substituiria, comentario
            )
            st.success("✅ Avaliação registrada! Obrigado pela contribuição.")
            st.session_state.show_form = False

        if cancelar:
            st.session_state.show_form = False
            st.rerun()

# ============================================================
# FOOTER INSTITUCIONAL
# ============================================================

st.markdown("""
<div class="ms-footer">
    <strong>Ministério da Saúde</strong> · SCTIE — Secretaria de Ciência, Tecnologia, Inovação e Insumos Estratégicos em Saúde<br>
    TCC MBA em Data Science e IA · ENAP 2025 &nbsp;|&nbsp;
    Dados: Compras.gov.br (2021–2025) &nbsp;|&nbsp;
    Modelo: Llama 3.1 8B via Ollama &nbsp;|&nbsp;
    Banco: PostgreSQL (tcc_v3)
</div>
""", unsafe_allow_html=True)
