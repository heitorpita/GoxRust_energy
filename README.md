# GoxRust_energy

Medição de **energia e tempo** de algoritmos de ordenação implementados em **Go** e
**Rust**, com `perf` sobre os contadores RAPL, em **duas máquinas** de gerações
diferentes.

Projeto 1 da disciplina de Engenharia de Software Sustentável — Gabriel Moura e Heitor.

| | |
|:--|:--|
| 📄 **Relatório** | [`relatorio/g00_ordenar_em_joules.md`](relatorio/g00_ordenar_em_joules.md) |
| 📓 **Análise** | [`analise/analise.ipynb`](analise/analise.ipynb) — pandas · matplotlib · seaborn |
| 📊 **Dados** | `medicoes_garbriel.csv` (Dell) · `medicoes_heitor2.csv` (HP) |
| 📏 **Recorte** | comparações usam listas de **10 000 elementos em diante** |

---

## O que foi medido

Doze programas de linha de comando — seis em Go, seis em Rust — que leem uma lista
de inteiros do `stdin`, ordenam em memória e imprimem o resultado. Nenhum usa a
ordenação da biblioteca padrão.

**720 execuções comparáveis** (10 repetições por célula), somando 16,6 kJ e 32 min
sob medição, em uma grade balanceada:

| Máquina | CPU | Tamanhos comparados | Execuções |
|:--|:--|:--|--:|
| Dell Inspiron 15 3511 | i5-1135G7 (Tiger Lake, 2020) | 10k · 50k · 100k | 360 |
| HP | i5-5200U (Broadwell, 2015) | 10k · 50k · 100k | 360 |

O HP também mediu listas de 10 a 1 000 elementos (mais 360 execuções). Elas ficam
fora das comparações — abaixo de 10 mil o contador RAPL não tem resolução para
enxergar a diferença — e aparecem só na §3.4 do relatório, como a evidência que
justifica o corte.

## Os resultados, em três linhas

- **Rust venceu 5 das 6 famílias em cada máquina — mas não as mesmas cinco.** Duas
  famílias invertem o sinal do resultado quando a máquina muda, e 7 das 12 posições
  do ranking de energia se alteram.
- **O algoritmo tem ~800× mais alavancagem que a linguagem.** 880× entre a melhor e
  a pior configuração, contra no máximo 3,28× entre Go e Rust.
- **Mais rápido não é mais verde.** O Dell é mais rápido nas 12 implementações e
  ainda assim gasta mais joules em 10 delas.

O relatório detalha cada um, com intervalos de confiança e as ameaças à validade.

## ⚠️ O pareamento `v1`/`v2` não é confiável

Os programas são nomeados `v1`/`v2` em cada linguagem, mas esses nomes **não estão
alinhados** entre Go e Rust. Em `selection` as variantes estão cruzadas:

| | Go | Rust |
|:--|:--|:--|
| `v1` | heapsort (`container/heap`), Θ(n log n) | seleção clássica, Θ(n²) |
| `v2` | seleção com `slices.Delete`, Θ(n²) | heapsort (*sift-down*), Θ(n log n) |

Parear `v1` com `v1` compararia heapsort contra seleção quadrática e devolveria
72,6× "a favor de Go" — um número reprodutível e sem sentido algum como afirmação
sobre linguagens. A análise reagrupa por **família semântica** (o que o código de
fato faz), em `analise/dados.py`.

---

## Estrutura

```
.
├── relatorio/
│   ├── g00_ordenar_em_joules.md   o relatório (formato do site do curso)
│   └── img/                       as figuras que ele referencia
├── analise/
│   ├── analise.ipynb              o notebook: memorial de cálculo
│   ├── dados.py                   carrega os CSV, define as famílias semânticas
│   ├── estatistica.py             razões, bootstrap, d de Cohen, expoentes
│   └── graficos.py                as cinco figuras do relatório
├── scripts/
│   ├── criacao_lista.sh           gera as listas de entrada
│   ├── implementacao.sh           compila e roda a bateria sob perf
│   └── medicao.sh                 consolida os CSV por execução
├── go/go_algs/                    as seis implementações em Go
├── rust/rust_algs/                as seis implementações em Rust
├── geracoes_listas/               gerador de entradas e as listas .in
├── medicoes_garbriel.csv          medições do Dell
├── medicoes_heitor2.csv           medições do HP
├── medicoes_heitor.csv            bateria anterior do HP (histórico, não usada)
└── specs.txt / specs_hp.txt       descrição das máquinas
```

## Rodar a análise

```bash
uv venv && uv pip install pandas matplotlib seaborn jupyter    # ou pip install -r requirements.txt
jupyter lab analise/analise.ipynb                              # e Run All
```

`graficos.py` também roda sozinho e regrava `relatorio/img/*.png`:

```bash
python3 analise/graficos.py
```

## Refazer a bateria de medições

```bash
scripts/implementacao.sh -r 10 -t "10000 50000 100000"
scripts/medicao.sh saida.csv
```

Precisa de `perf` com acesso a `power/energy-pkg/` — ou seja,
`perf_event_paranoid ≤ 0` ou privilégio de *root*. O contador RAPL tem escopo de
pacote, então a medição é `system-wide` (`-a`): **os joules são os da máquina
inteira durante a janela de execução**, não a energia marginal do algoritmo.

---

## Publicando o relatório

`relatorio/g00_ordenar_em_joules.md` já traz o *front matter* do template do curso.
Todas as imagens — inclusive a do campo `image:` — estão referenciadas como
`img/figN.png`, relativas ao próprio `.md`.

Ao copiar para o site, leve a pasta `img/` junto. Se o site guardar as figuras em
outro lugar (o template do curso usa `img/<grupo>/`), ajuste o prefixo nos seis
pontos: o campo `image:` do *front matter* e as cinco chamadas `![...](img/...)`.
