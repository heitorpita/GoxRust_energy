"""Agregacoes, razoes entre linguagens, tamanho de efeito e escala.

Tudo opera sobre o DataFrame devolvido por `dados.carrega()`.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from dados import N_REF, ORDEM_FAMILIAS, ORDEM_MAQUINAS, TAMANHOS

CHAVE_CELULA = ["maquina", "familia", "ling", "n"]


def resumo(df: pd.DataFrame, metricas=("energia_j", "duracao_s", "potencia_w"),
           por=CHAVE_CELULA) -> pd.DataFrame:
    """Media, desvio (populacional) e coeficiente de variacao por celula."""
    agg = {m: ["mean", lambda s: s.std(ddof=0), "size"] for m in metricas}
    out = df.groupby(por, observed=True).agg(agg)
    out.columns = [f"{m}_{'media' if k == 'mean' else 'dp' if k == '<lambda_0>' else 'n_exec'}"
                   for m, k in out.columns]
    for m in metricas:
        out[f"{m}_cv"] = 100 * out[f"{m}_dp"] / out[f"{m}_media"]
    return out.reset_index()


def _cohen_d(a: np.ndarray, b: np.ndarray) -> float:
    """d de Cohen com desvio agrupado. Positivo = `a` maior que `b`."""
    na, nb = len(a), len(b)
    sa, sb = a.std(ddof=0), b.std(ddof=0)
    sp = np.sqrt(((na - 1) * sa**2 + (nb - 1) * sb**2) / max(na + nb - 2, 1))
    return float((a.mean() - b.mean()) / sp) if sp > 0 else np.inf


def _ic_bootstrap(a: np.ndarray, b: np.ndarray, reps: int = 20_000,
                  semente: int = 42) -> tuple[float, float]:
    """IC 95% da razao media(a)/media(b), por reamostragem com reposicao."""
    rng = np.random.default_rng(semente)
    ra = rng.choice(a, size=(reps, len(a)), replace=True).mean(axis=1)
    rb = rng.choice(b, size=(reps, len(b)), replace=True).mean(axis=1)
    razoes = ra / rb
    return tuple(np.percentile(razoes, [2.5, 97.5]))


def razoes(df: pd.DataFrame, metrica: str = "energia_j", n: int = N_REF,
           reps: int = 20_000) -> pd.DataFrame:
    """Compara Go e Rust dentro de cada familia, em cada maquina.

    razao = media(Go) / media(Rust). Acima de 1 significa que Go gastou mais,
    ou seja, Rust venceu.
    """
    sub = df[df["n"] == n]
    linhas = []
    for (maq, fam), g in sub.groupby(["maquina", "familia"], observed=True):
        go = g.loc[g["ling"] == "Go", metrica].dropna().to_numpy(dtype=float)
        rust = g.loc[g["ling"] == "Rust", metrica].dropna().to_numpy(dtype=float)
        if len(go) == 0 or len(rust) == 0:
            continue
        razao = go.mean() / rust.mean()
        lo, hi = _ic_bootstrap(go, rust, reps)
        linhas.append({
            "maquina": maq, "familia": fam, "n": n, "metrica": metrica,
            "go": go.mean(), "rust": rust.mean(),
            "razao": razao, "ic_baixo": lo, "ic_alto": hi,
            "d_cohen": _cohen_d(go, rust),
            "vencedor": "Rust" if razao > 1 else "Go",
            "fator": razao if razao > 1 else 1 / razao,
            "significativo": not (lo <= 1.0 <= hi),
        })
    out = pd.DataFrame(linhas)
    out["familia"] = pd.Categorical(out["familia"], categories=ORDEM_FAMILIAS, ordered=True)
    out["maquina"] = pd.Categorical(out["maquina"], categories=ORDEM_MAQUINAS, ordered=True)
    return out.sort_values(["maquina", "familia"]).reset_index(drop=True)


def expoentes(df: pd.DataFrame, tamanhos=tuple(TAMANHOS),
              metrica: str = "duracao_s") -> pd.DataFrame:
    """Inclinacao da reta log-log da metrica contra n. 2 = quadratico, 1 = linear."""
    sub = df[df["n"].isin(list(tamanhos))]
    medias = (sub.groupby(["maquina", "familia", "ling", "n"], observed=True)[metrica]
              .mean().reset_index())
    linhas = []
    for (maq, fam, ling), g in medias.groupby(["maquina", "familia", "ling"], observed=True):
        if len(g) < 2:
            continue
        x = np.log(g["n"].to_numpy(dtype=float))
        y = np.log(g[metrica].to_numpy(dtype=float))
        linhas.append({"maquina": maq, "familia": fam, "ling": ling,
                       "expoente": float(np.polyfit(x, y, 1)[0])})
    out = pd.DataFrame(linhas)
    out["familia"] = pd.Categorical(out["familia"], categories=ORDEM_FAMILIAS, ordered=True)
    return out.pivot_table(index="familia", columns=["maquina", "ling"],
                           values="expoente", observed=True)


def ranking(df: pd.DataFrame, n: int = N_REF, metrica: str = "energia_j") -> pd.DataFrame:
    """Posicao de cada implementacao em cada maquina, e quanto ela se desloca."""
    medias = (df[df["n"] == n]
              .groupby(["maquina", "implementacao", "familia", "ling"], observed=True)[metrica]
              .mean().reset_index())
    medias["posicao"] = medias.groupby("maquina", observed=True)[metrica].rank().astype(int)
    largo = medias.pivot_table(index=["implementacao", "familia", "ling"],
                               columns="maquina", values=["posicao", metrica], observed=True)
    largo.columns = [f"{a}_{b}" for a, b in largo.columns]
    largo = largo.reset_index()
    largo["delta"] = largo["posicao_HP"] - largo["posicao_Dell"]
    return largo.sort_values("posicao_Dell").reset_index(drop=True)


def piso(df: pd.DataFrame, maquina: str = "HP", n: int = 10) -> dict:
    """Custo fixo por execucao: iniciar o processo e ler a entrada.

    Precisa do DataFrame SEM o corte de tamanho -- use `dados.carrega(minimo=0)`.
    Nao e um resultado do experimento: e a medida do instrumento que justifica
    descartar tudo abaixo de n = 10 000.
    """
    sub = df[(df["maquina"] == maquina) & (df["n"] == n)]
    return {"maquina": maquina, "n": n, "execucoes": len(sub),
            "energia_j": float(sub["energia_j"].mean()),
            "duracao_s": float(sub["duracao_s"].mean()),
            "potencia_w": float(sub["energia_j"].mean() / sub["duracao_s"].mean())}


def deriva(df: pd.DataFrame, n: int = N_REF, metrica: str = "energia_j") -> pd.DataFrame:
    """Metrica normalizada pela media da celula, por numero da execucao.

    Serve para ver se a maquina esquentou (ou o cache aqueceu) ao longo das 10
    repeticoes. Sem tendencia = a ausencia de warm-up explicito nao viciou o dado.
    """
    sub = df[df["n"] == n].copy()
    sub["norm"] = sub[metrica] / sub.groupby(
        ["maquina", "implementacao"], observed=True)[metrica].transform("mean")
    return (sub.groupby(["maquina", "execucao"], observed=True)["norm"]
            .mean().unstack("maquina"))
