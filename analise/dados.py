"""Carrega as medicoes das duas maquinas em um unico DataFrame.

    import dados
    df = dados.carrega()

O ponto central deste modulo e a coluna `familia`. Os programas sao nomeados
v1/v2 em cada linguagem, mas esses nomes NAO sao semanticamente alinhados entre
Go e Rust: em `selection` as variantes estao cruzadas (ver FAMILIAS). Parear v1
com v1 compararia heapsort contra selecao quadratica.
"""
from __future__ import annotations

import os
import pandas as pd

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)

ARQUIVOS = {
    "Dell": os.path.join(RAIZ, "medicoes_garbriel.csv"),
    "HP": os.path.join(RAIZ, "medicoes_heitor2.csv"),
}

# nome usado no csv do Dell -> (algoritmo, linguagem, variante)
_MAPA_DELL = {
    "bolha":               ("bolha", "go", "v1"),
    "bolha_better":        ("bolha", "go", "v2"),
    "bolha_rs":            ("bolha", "rust", "v1"),
    "bolha_rs_better":     ("bolha", "rust", "v2"),
    "insertion":           ("insertion", "go", "v1"),
    "insertion_better":    ("insertion", "go", "v2"),
    "insertion_rs":        ("insertion", "rust", "v1"),
    "insertion_rs_better": ("insertion", "rust", "v2"),
    "selection":           ("selection", "go", "v1"),
    "selection_better":    ("selection", "go", "v2"),
    "selection_rs":        ("selection", "rust", "v1"),
    "selection_rs_better": ("selection", "rust", "v2"),
}

# (algoritmo, linguagem, variante) -> familia semantica.
# Repare em `selection`: v1 em Go e heapsort, v1 em Rust e selecao quadratica.
FAMILIAS = {
    ("bolha", "go", "v1"):      "Bubble ingênuo",
    ("bolha", "rust", "v1"):    "Bubble ingênuo",
    ("bolha", "go", "v2"):      "Bubble otimizado",
    ("bolha", "rust", "v2"):    "Bubble otimizado",
    ("insertion", "go", "v1"):  "Insertion por troca",
    ("insertion", "rust", "v1"): "Insertion por troca",
    ("insertion", "go", "v2"):  "Insertion por deslocamento",
    ("insertion", "rust", "v2"): "Insertion por deslocamento",
    ("selection", "go", "v2"):  "Selection O(n²)",
    ("selection", "rust", "v1"): "Selection O(n²)",
    ("selection", "go", "v1"):  "Heapsort",
    ("selection", "rust", "v2"): "Heapsort",
}

# ordem de leitura: do mais caro ao mais barato
ORDEM_FAMILIAS = ["Bubble ingênuo", "Bubble otimizado", "Insertion por troca",
                  "Insertion por deslocamento", "Selection O(n²)", "Heapsort"]

ORDEM_MAQUINAS = ["Dell", "HP"]
MAQUINA_LONGA = {"Dell": "Dell · i5-1135G7 (Tiger Lake, 2020)",
                 "HP": "HP · i5-5200U (Broadwell, 2015)"}
MAQUINA_CURTA = {"Dell": "Dell · i5-1135G7", "HP": "HP · i5-5200U"}

LINGUAGEM_ROTULO = {"go": "Go", "rust": "Rust"}

# O Dell so mediu de 10 000 em diante, e abaixo disso o contador RAPL nao tem
# resolucao para enxergar a diferenca (ver secao 3 do notebook). Todas as
# comparacoes usam esta faixa; as execucoes menores ficam nos CSV apenas como
# evidencia do piso do instrumento.
N_MINIMO = 10_000
TAMANHOS = [10_000, 50_000, 100_000]
TAMANHOS_COMUNS = TAMANHOS          # nome antigo, mantido por compatibilidade
N_REF = 100_000

# paleta validada para separacao em daltonismo (OKLab ΔE >= 8 entre pares)
COR = {"Go": "#2a78d6", "Rust": "#eb6834", "Dell": "#1baf7a", "HP": "#4a3aa7"}
TINTA = "#15181c"
TINTA2 = "#52514e"
SUAVE = "#898781"
GRADE = "#e1e0d9"


def _num(serie: pd.Series) -> pd.Series:
    """Converte '1,21' em 1.21 (os dois csv usam virgula decimal)."""
    return pd.to_numeric(
        serie.astype("string").str.strip().str.strip('"').str.replace(",", ".", regex=False),
        errors="coerce")


def _le_dell() -> pd.DataFrame:
    bruto = pd.read_csv(ARQUIVOS["Dell"], dtype="string")
    chaves = bruto["algoritmo"].map(_MAPA_DELL)
    df = pd.DataFrame({
        "maquina": "Dell",
        "algoritmo": chaves.str[0],
        "linguagem": chaves.str[1],
        "variante": chaves.str[2],
        "n": pd.to_numeric(bruto["tamanho"]),
        "execucao": pd.to_numeric(bruto["execucao"]),
        "energia_j": _num(bruto["energia_joules"]),
        "duracao_s": _num(bruto["duracao_s"]),
        "potencia_w": _num(bruto["potencia_media_w"]),
        "energia_cores_j": pd.NA,
        "energia_ram_j": pd.NA,
    })
    return df


def _le_hp() -> pd.DataFrame:
    bruto = pd.read_csv(ARQUIVOS["HP"], dtype="string")
    bruto = bruto[bruto["tipo"] == "exec"]          # as linhas 'media' sao recalculadas aqui
    return pd.DataFrame({
        "maquina": "HP",
        "algoritmo": bruto["algoritmo"],
        "linguagem": bruto["linguagem"],
        "variante": bruto["variante"],
        "n": pd.to_numeric(bruto["tamanho"]),
        "execucao": pd.to_numeric(bruto["execucao"]),
        "energia_j": _num(bruto["energia_j"]),
        "duracao_s": _num(bruto["duracao_s"]),
        "potencia_w": _num(bruto["potencia_w"]),
        "energia_cores_j": _num(bruto["energia_cores_j"]),
        "energia_ram_j": _num(bruto["energia_ram_j"]),
    })


def carrega(minimo: int = N_MINIMO) -> pd.DataFrame:
    """Uma linha por execucao medida.

    Por padrao devolve so a faixa comparavel (n >= 10 000): 720 execucoes, uma
    grade balanceada de 12 programas x 3 tamanhos x 10 repeticoes em cada
    maquina. Use `carrega(minimo=0)` para incluir tambem as 360 execucoes
    pequenas do HP, que servem apenas para medir o piso do instrumento.
    """
    df = pd.concat([_le_dell(), _le_hp()], ignore_index=True)

    chaves = list(zip(df["algoritmo"], df["linguagem"], df["variante"]))
    df["familia"] = pd.Categorical([FAMILIAS[c] for c in chaves],
                                   categories=ORDEM_FAMILIAS, ordered=True)
    df["ling"] = df["linguagem"].map(LINGUAGEM_ROTULO)
    df["maquina"] = pd.Categorical(df["maquina"], categories=ORDEM_MAQUINAS, ordered=True)
    df["ling"] = pd.Categorical(df["ling"], categories=["Go", "Rust"], ordered=True)
    df["implementacao"] = df["familia"].astype(str) + " · " + df["ling"].astype(str)
    df["energia_por_elemento_uj"] = df["energia_j"] / df["n"] * 1e6
    # o Dell so registrou o dominio de pacote; cores/dram ficam ausentes, mas numericos
    df[["energia_cores_j", "energia_ram_j"]] = df[["energia_cores_j", "energia_ram_j"]].astype("Float64")

    if minimo:
        df = df[df["n"] >= minimo]

    colunas = ["maquina", "familia", "ling", "algoritmo", "linguagem", "variante",
               "n", "execucao", "energia_j", "duracao_s", "potencia_w",
               "energia_cores_j", "energia_ram_j", "energia_por_elemento_uj",
               "implementacao"]
    return df[colunas].sort_values(["maquina", "familia", "ling", "n", "execucao"]).reset_index(drop=True)


def aplica_estilo() -> None:
    """Estilo comum a todas as figuras.

    Chamado tanto pelo notebook quanto por `graficos.py` rodando sozinho, para
    que os dois caminhos produzam exatamente a mesma imagem. A base e o tema
    `whitegrid` do seaborn; os rcParams abaixo sobrescrevem o que interessa.
    """
    import matplotlib as mpl
    import seaborn as sns

    sns.set_theme(style="whitegrid")
    mpl.rcParams.update({
        "figure.dpi": 110,
        "savefig.dpi": 160,
        "figure.facecolor": "#fcfcfb",
        "axes.facecolor": "#fcfcfb",
        "savefig.facecolor": "#fcfcfb",
        "font.family": "sans-serif",
        "font.sans-serif": ["DejaVu Sans", "Liberation Sans", "sans-serif"],
        "font.size": 10,
        "axes.titlesize": 12,
        "axes.titleweight": "bold",
        "axes.titlelocation": "left",
        "axes.titlepad": 10,
        "axes.labelsize": 10,
        "axes.labelcolor": TINTA2,
        "axes.edgecolor": SUAVE,
        "axes.linewidth": 0.8,
        "axes.spines.top": False,
        "axes.spines.right": False,
        "axes.grid": True,
        "grid.color": GRADE,
        "grid.linewidth": 0.8,
        "xtick.color": TINTA2,
        "ytick.color": TINTA2,
        "xtick.labelsize": 9,
        "ytick.labelsize": 9,
        "legend.frameon": False,
        "legend.fontsize": 9,
        "text.color": TINTA,
    })
