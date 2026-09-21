"""As cinco figuras do relatorio, em matplotlib.

Cada funcao devolve a Figure, para o notebook exibir inline. Rodado como script,
grava os PNG em relatorio/img/:

    python3 analise/graficos.py
"""
from __future__ import annotations

import os

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.lines import Line2D
from matplotlib.ticker import (FixedFormatter, FixedLocator, FuncFormatter,
                               LogLocator, NullFormatter)

import estatistica as est
from dados import (COR, GRADE, MAQUINA_CURTA, N_REF, ORDEM_FAMILIAS,
                   ORDEM_MAQUINAS, SUAVE, TINTA, TINTA2)

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.join(os.path.dirname(AQUI), "relatorio", "img")

METRICA_ROTULO = {"energia_j": ("Energia por execução", "J"),
                  "duracao_s": ("Tempo de parede", "s"),
                  "potencia_w": ("Potência média do pacote", "W")}


def _br(v, casas=2):
    return f"{v:.{casas}f}".replace(".", ",")


def _rotulo_log(v, _=None):
    """10^k em numero por extenso, com virgula decimal: 0,01 · 0,1 · 1 · 10 · 100."""
    if v >= 1:
        return f"{v:,.0f}".replace(",", " ")
    return f"{v:g}".replace(".", ",")


def _rotulo_n(v, _=None):
    """Tamanho da entrada de forma compacta: 10 · 100 · 1k · 10k · 100k."""
    if v >= 1000:
        return f"{v/1000:g}k"
    return f"{v:g}"


def _eixo_log_limpo(ax, eixo="x", formatador=_rotulo_log):
    """Decadas rotuladas por extenso; subdivisoes sem rotulo."""
    a = ax.xaxis if eixo == "x" else ax.yaxis
    a.set_major_locator(LogLocator(base=10))
    a.set_major_formatter(FuncFormatter(formatador))
    a.set_minor_locator(LogLocator(base=10, subs=tuple(np.arange(2, 10) * 0.1)))
    a.set_minor_formatter(NullFormatter())


def _titulo(fig, titulo, subtitulo):
    fig.text(0.008, 0.985, titulo, ha="left", va="top", fontsize=15, fontweight="bold",
             color=TINTA)
    fig.text(0.008, 0.945, subtitulo, ha="left", va="top", fontsize=10, color=TINTA2)


def _legenda_linguagens(fig, y=0.985):
    fig.legend(handles=[Line2D([], [], marker="o", ls="", color=COR[l], label=l)
                        for l in ("Go", "Rust")],
               loc="upper right", bbox_to_anchor=(0.995, y), ncol=2,
               handletextpad=0.3, columnspacing=1.2)


# ------------------------------------------------------------------ figura 1 --
def ranking_linguagens(df, n=N_REF, reps=20_000):
    """Razao Go/Rust por familia: quem vence, por quanto, em cada maquina."""
    metricas = ["energia_j", "duracao_s"]
    fig, axes = plt.subplots(2, 2, figsize=(12.5, 7.6), sharex=True, sharey=True)
    ticks = [0.7, 1, 1.5, 2, 3, 4]

    for i, metrica in enumerate(metricas):
        r = est.razoes(df, metrica, n, reps)
        nome, unidade = METRICA_ROTULO[metrica]
        for j, maq in enumerate(ORDEM_MAQUINAS):
            ax = axes[i, j]
            sub = r[r["maquina"] == maq].set_index("familia").reindex(ORDEM_FAMILIAS)
            y = np.arange(len(ORDEM_FAMILIAS))[::-1]
            cores = [COR[v] for v in sub["vencedor"]]
            ax.barh(y, sub["razao"] - 1, left=1, color=cores, height=0.56, zorder=3)
            ax.axvline(1, color=SUAVE, lw=1.2, zorder=4)

            for yy, (_, linha) in zip(y, sub.iterrows()):
                razao = linha["razao"]
                x = razao if razao > 1 else 1
                ax.annotate(f"{linha['vencedor']} {_br(linha['fator'])}×",
                            (x, yy), xytext=(6, 0), textcoords="offset points",
                            va="center", ha="left", fontsize=9.5, fontweight="bold",
                            color=TINTA, zorder=5)

            ax.set_xscale("log")
            ax.set_xlim(0.62, 5.2)
            ax.xaxis.set_major_locator(FixedLocator(ticks))
            ax.xaxis.set_major_formatter(FixedFormatter([f"{_br(t, 1)}×" for t in ticks]))
            ax.xaxis.set_minor_formatter(NullFormatter())
            ax.set_yticks(y, ORDEM_FAMILIAS)
            ax.grid(axis="y", visible=False)
            ax.grid(axis="x", zorder=0)
            if i == 0:
                ax.set_title(MAQUINA_CURTA[maq], fontsize=11)
            if j == 0:
                ax.set_ylabel(f"{nome} ({unidade})", fontsize=10.5,
                              fontweight="bold", color=TINTA, labelpad=12)

    _titulo(fig, "Ranking Go × Rust por família de algoritmo",
            f"Razão entre as médias de 10 execuções em n = {n:,}".replace(",", " ")
            + ".  Barra à direita de 1× = Rust gasta menos;  à esquerda = Go gasta menos.")
    fig.legend(handles=[plt.Rectangle((0, 0), 1, 1, color=COR[l], label=f"{l} vence")
                        for l in ("Go", "Rust")],
               loc="upper right", bbox_to_anchor=(0.995, 0.995), ncol=2,
               handletextpad=0.5, columnspacing=1.4)
    fig.tight_layout(rect=(0, 0, 1, 0.915))
    return fig


# ------------------------------------------------------------------ figura 2 --
def custo_absoluto(df, n=N_REF):
    """Quanto cada familia custa de fato, em escala log: algoritmo contra linguagem."""
    metricas = ["energia_j", "duracao_s"]
    fig, axes = plt.subplots(2, 2, figsize=(12.5, 7.6), sharey=True)

    for i, metrica in enumerate(metricas):
        medias = (df[df["n"] == n]
                  .groupby(["maquina", "familia", "ling"], observed=True)[metrica]
                  .mean().unstack("ling"))
        for j, maq in enumerate(ORDEM_MAQUINAS):
            ax = axes[i, j]
            sub = medias.loc[maq].reindex(ORDEM_FAMILIAS)
            y = np.arange(len(ORDEM_FAMILIAS))[::-1]
            ax.hlines(y, sub["Go"], sub["Rust"], color=SUAVE, lw=2, zorder=2)
            for ling in ("Go", "Rust"):
                ax.scatter(sub[ling], y, s=90, color=COR[ling], zorder=3,
                           edgecolor="#fcfcfb", linewidth=1.5)
            for yy, (_, linha) in zip(y, sub.iterrows()):
                baixo, alto = sorted([linha["Go"], linha["Rust"]])
                casas = 3 if alto < 1 else 2 if alto < 10 else 1 if alto < 100 else 0
                ax.annotate(_br(baixo, casas), (baixo, yy), xytext=(-9, 0),
                            textcoords="offset points", ha="right", va="center",
                            fontsize=8.5, color=TINTA2)
                ax.annotate(_br(alto, casas), (alto, yy), xytext=(9, 0),
                            textcoords="offset points", ha="left", va="center",
                            fontsize=8.5, color=TINTA2)

            nome, unidade = METRICA_ROTULO[metrica]
            ax.set_xscale("log")
            _eixo_log_limpo(ax, "x")
            ax.set_yticks(y, ORDEM_FAMILIAS)
            ax.grid(axis="y", visible=False)
            ax.set_xlabel(unidade, fontsize=9)
            if metrica == "energia_j":
                ax.set_xlim(0.06, 900)
            else:
                ax.set_xlim(0.006, 90)
            if i == 0:
                ax.set_title(MAQUINA_CURTA[maq], fontsize=11)
            if j == 0:
                ax.set_ylabel(f"{nome} ({unidade})", fontsize=10.5,
                              fontweight="bold", color=TINTA, labelpad=12)

    _titulo(fig, f"Custo absoluto de cada família em n = {n:,}".replace(",", " "),
            "Média de 10 execuções, escala logarítmica: cada divisão vale 10×.  "
            "A haste liga as duas implementações da mesma família — quanto mais curta, "
            "menos a linguagem importa.")
    _legenda_linguagens(fig)
    fig.tight_layout(rect=(0, 0, 1, 0.915))
    return fig


# ------------------------------------------------------------------ figura 3 --
def escala(df, metrica="energia_j"):
    """Energia contra n, log-log, com o expoente ajustado em cada painel."""
    medias = (df.groupby(["maquina", "familia", "ling", "n"], observed=True)[metrica]
              .mean().reset_index())
    exp = est.expoentes(df, metrica=metrica)
    fig, axes = plt.subplots(2, 3, figsize=(12.5, 7.2), sharex=True, sharey=True)

    for ax, fam in zip(axes.ravel(), ORDEM_FAMILIAS):
        sub = medias[medias["familia"] == fam]
        for maq, estilo in (("HP", "-"), ("Dell", "--")):
            for ling in ("Go", "Rust"):
                s_ = sub[(sub["maquina"] == maq) & (sub["ling"] == ling)].sort_values("n")
                if s_.empty:
                    continue
                ax.plot(s_["n"], s_[metrica], estilo, color=COR[ling], lw=2,
                        marker="o", ms=6, mec="#fcfcfb", mew=1.2, zorder=3)

        # referencia de inclinacao 2, ancorada no menor valor do painel
        x = np.array([1e4, 1e5])
        base = sub[metrica].min() * 0.55
        ax.plot(x, base * (x / x[0]) ** 2, color=SUAVE, lw=1.2, zorder=1)
        ax.annotate("n²", (x[1], base * 100), xytext=(-2, 2), textcoords="offset points",
                    ha="right", va="bottom", fontsize=9, color=SUAVE, zorder=2)

        # expoentes ajustados, no canto livre (acima e a esquerda da curva)
        linhas = ["expoente    Dell   HP"]
        for ling in ("Go", "Rust"):
            linhas.append(f"{ling:<8}  {_br(exp.loc[fam, ('Dell', ling)])}  "
                          f"{_br(exp.loc[fam, ('HP', ling)])}")
        ax.annotate("\n".join(linhas), (0.03, 0.97), xycoords="axes fraction",
                    va="top", ha="left", fontsize=8.5, color=TINTA2,
                    family="monospace",
                    bbox=dict(boxstyle="round,pad=0.35", fc="#fcfcfb",
                              ec=GRADE, lw=0.8), zorder=4)

        ax.set_xscale("log")
        ax.set_yscale("log")
        _eixo_log_limpo(ax, "x", _rotulo_n)
        _eixo_log_limpo(ax, "y")
        ax.xaxis.set_minor_locator(FixedLocator([]))
        ax.set_xticks([1e4, 5e4, 1e5])
        ax.set_xlim(8e3, 1.5e5)
        ax.set_ylim(1.2e-2, 1.2e3)
        ax.set_title(fam, fontsize=11)

    for ax in axes[-1]:
        ax.set_xlabel("n (elementos)")
    for ax in axes[:, 0]:
        ax.set_ylabel(f"{METRICA_ROTULO[metrica][0].lower()} ({METRICA_ROTULO[metrica][1]})")

    _titulo(fig, "Como a energia escala com o tamanho da entrada",
            "Eixos logarítmicos, nos três tamanhos comuns às duas máquinas.  A reta cinza "
            "tem inclinação 2 (custo quadrático puro);  a caixa traz o expoente ajustado.")
    fig.legend(handles=[Line2D([], [], color=COR[l], ls=e, lw=2, marker="o", ms=5,
                               label=f"{l} · {m}")
                        for m, e in (("HP", "-"), ("Dell", "--")) for l in ("Go", "Rust")],
               loc="upper right", bbox_to_anchor=(0.995, 0.995), ncol=4,
               handlelength=3.2, handletextpad=0.5, columnspacing=1.4)
    fig.tight_layout(rect=(0, 0, 1, 0.90))
    return fig


# ------------------------------------------------------------------ figura 4 --
def mudanca_de_ranking(df, n=N_REF):
    """Slope chart: a posicao de cada implementacao em cada maquina."""
    r = est.ranking(df, n)
    mudaram = int((r["delta"] != 0).sum())
    fig, ax = plt.subplots(figsize=(12.5, 6.4))

    xa, xb = 0.0, 1.0
    for _, linha in r.iterrows():
        cor = COR[linha["ling"]]
        ya, yb = linha["posicao_Dell"], linha["posicao_HP"]
        t = np.linspace(0, 1, 100)
        suave = ya + (yb - ya) * (3 * t**2 - 2 * t**3)          # smoothstep
        ax.plot(xa + t * (xb - xa), suave, color=cor, lw=2, alpha=0.85, zorder=2)
        ax.scatter([xa, xb], [ya, yb], s=70, color=cor, zorder=3,
                   edgecolor="#fcfcfb", linewidth=1.5)
        ax.annotate(f"{linha['implementacao']}  {int(ya)}º", (xa, ya), xytext=(-12, 0),
                    textcoords="offset points", ha="right", va="center", fontsize=9.5)
        ax.annotate(f"{int(yb)}º  {linha['implementacao']}", (xb, yb), xytext=(12, 0),
                    textcoords="offset points", ha="left", va="center", fontsize=9.5)

    ax.set_xlim(-0.75, 1.75)
    ax.set_ylim(len(r) + 0.6, 0.4)
    ax.set_xticks([xa, xb], [MAQUINA_CURTA["Dell"], MAQUINA_CURTA["HP"]], fontsize=11)
    ax.tick_params(axis="x", length=0, pad=10)
    for rotulo in ax.get_xticklabels():
        rotulo.set_fontweight("bold")
        rotulo.set_color(TINTA)
    ax.set_yticks([])
    ax.grid(False)
    for lado in ("left", "bottom"):
        ax.spines[lado].set_visible(False)
    ax.vlines([xa, xb], 0.6, len(r) + 0.4, color=GRADE, lw=1.2, zorder=1)

    _titulo(fig, "O ranking de energia muda quando a máquina muda",
            f"Posição no consumo total para ordenar {n:,}".replace(",", " ")
            + f" inteiros (1.º = menos energia).  {mudaram} das {len(r)} posições se alteram.")
    _legenda_linguagens(fig)
    fig.tight_layout(rect=(0, 0, 1, 0.90))
    return fig


# ------------------------------------------------------------------ figura 5 --
def energia_contra_tempo(df, tamanhos=(10_000, 50_000, 100_000)):
    """Cada maquina ocupa uma faixa de potencia quase constante: E = P x t."""
    medias = (df[df["n"].isin(list(tamanhos))]
              .groupby(["maquina", "familia", "ling", "n"], observed=True)
              [["energia_j", "duracao_s"]].mean().reset_index())
    fig, ax = plt.subplots(figsize=(9.5, 7.0))

    t = np.array([2e-3, 5e1])
    for potencia in (6, 12.5):
        ax.plot(t, potencia * t, color=SUAVE, lw=1.2, zorder=1)
        ax.annotate(f"{_br(potencia, 1).rstrip('0').rstrip(',')} W",
                    (8e-3, potencia * 8e-3), xytext=(-6, 6), textcoords="offset points",
                    ha="right", fontsize=9.5, fontweight="bold", color=TINTA2,
                    bbox=dict(boxstyle="round,pad=0.2", fc="#fcfcfb", ec="none"), zorder=4)

    for maq in ORDEM_MAQUINAS:
        s = medias[medias["maquina"] == maq]
        ax.scatter(s["duracao_s"], s["energia_j"], s=70, color=COR[maq], alpha=0.9,
                   edgecolor="#fcfcfb", linewidth=1.2, zorder=3, label=MAQUINA_CURTA[maq])

    ax.set_xscale("log")
    ax.set_yscale("log")
    _eixo_log_limpo(ax, "x")
    _eixo_log_limpo(ax, "y")
    ax.set_xlim(2.5e-3, 40)
    ax.set_ylim(2.5e-2, 400)
    ax.set_xlabel("tempo de parede por execução (s)")
    ax.set_ylabel("energia por execução (J)")
    ax.legend(loc="upper left")

    _titulo(fig, "Energia é, essencialmente, tempo × potência da máquina",
            "Cada ponto é uma célula (família × linguagem × tamanho), n ∈ {10 mil, 50 mil, 100 mil}.\n"
            "As retas cinzas são potências constantes.")
    fig.tight_layout(rect=(0, 0, 1, 0.90))
    return fig


TODAS = {
    "fig1_ranking_linguagens": ranking_linguagens,
    "fig2_custo_absoluto": custo_absoluto,
    "fig3_escala": escala,
    "fig4_mudanca_de_ranking": mudanca_de_ranking,
    "fig5_energia_contra_tempo": energia_contra_tempo,
}


def grava_todas(df=None):
    """Grava relatorio/img/*.png para todas as figuras."""
    import dados as _d
    if df is None:
        _d.aplica_estilo()
        df = _d.carrega()
    os.makedirs(SAIDA, exist_ok=True)
    for nome, f in TODAS.items():
        fig = f(df)
        caminho = os.path.join(SAIDA, f"{nome}.png")
        fig.savefig(caminho, bbox_inches="tight")
        plt.close(fig)
        print(f"relatorio/img/{nome}.png")


if __name__ == "__main__":
    grava_todas()
