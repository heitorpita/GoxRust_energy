# analise/

Tudo que transforma os dois CSV consolidados nos números e figuras do
[relatório](../relatorio/g00_ordenar_em_joules.md).

**Comece pelo notebook: [`analise.ipynb`](analise.ipynb).** Ele é o memorial de
cálculo — cada afirmação do relatório sai de uma célula de lá, e o notebook já está
versionado com as saídas executadas.

## Rodar

```bash
uv venv && uv pip install -r ../requirements.txt   # ou pip, num venv qualquer
jupyter lab analise.ipynb                          # e Run All
```

Os módulos também rodam sem Jupyter:

```bash
python3 analise/graficos.py    # regrava relatorio/img/*.png
```

## Os arquivos

| Arquivo | O que faz |
|:--|:--|
| `analise.ipynb` | **o notebook**: inventário dos dados, a correção do pareamento, qualidade da medição (piso, resolução, deriva), as comparações, as figuras, o efeito prático e as ameaças à validade. |
| `dados.py` | lê os dois formatos de CSV em um único DataFrame. Resolve a vírgula decimal, traduz os nomes do CSV do Dell (`bolha_rs_better`) para `(algoritmo, linguagem, variante)` e — o mais importante — deriva a coluna `familia`. Também guarda a paleta e o estilo das figuras. `carrega()` já devolve só a faixa comparável (n ≥ 10 000); use `carrega(minimo=0)` para incluir as execuções pequenas do HP. |
| `estatistica.py` | agregações por célula, razão Go÷Rust com IC 95% por *bootstrap*, *d* de Cohen, expoente de escala log–log, ranking por máquina, piso de medição e teste de deriva. |
| `graficos.py` | as cinco figuras do relatório, em matplotlib. Cada função devolve a `Figure`; rodado como script, grava os PNG em `relatorio/img/`. |

## A coluna `familia`, e por que ela existe

Os nomes `v1`/`v2` **não** são semanticamente alinhados entre as duas linguagens.
Em `selection`, as variantes estão cruzadas:

| | Go | Rust |
|:--|:--|:--|
| `v1` | heapsort (`container/heap`), Θ(n log n) | seleção clássica, Θ(n²) |
| `v2` | seleção com `slices.Delete`, Θ(n²) | heapsort (*sift-down*), Θ(n log n) |

Parear `v1` com `v1` mediria heapsort contra seleção quadrática e devolveria 72,6×
"a favor de Go" em n = 100 000 — um número real, reprodutível e sem sentido algum
como afirmação sobre linguagens. O dicionário `FAMILIAS`, em `dados.py`, reagrupa
por algoritmo de fato implementado, e é essa coluna que todos os gráficos e tabelas
usam.

## Dados de entrada

| Arquivo | Máquina | Execuções no CSV | Comparáveis (n ≥ 10 000) |
|:--|:--|--:|--:|
| `../medicoes_garbriel.csv` | Dell Inspiron 15 3511 · i5-1135G7 | 360 | 360 |
| `../medicoes_heitor2.csv` | HP · i5-5200U | 720 | 360 |

**O recorte em n ≥ 10 000.** Duas razões: o Dell só foi medido a partir daí, e abaixo
disso o RAPL reporta em passos de 0,01 J — em n ≤ 1 000 os valores assumem só quatro
níveis distintos e o coeficiente de variação chega a 43%. Incluir n = 1 000 no ajuste
log–log derruba os expoentes das famílias quadráticas de ~2,0 para ~1,8: estaria
medindo o piso, não o algoritmo. Com o corte, a grade fica balanceada (12 programas ×
3 tamanhos × 10 repetições em cada máquina) e `carrega()` devolve 720 execuções.

`medicoes_heitor2.csv` **substitui** o `medicoes_heitor.csv` original: é uma
re-execução completa da bateria no HP, agora incluindo `insert_v2.go`, que faltava.
O arquivo antigo fica no repositório como histórico e não é lido por nada aqui.

## Cores

Paleta validada para separação em daltonismo, em tema claro e escuro:
Go `#2a78d6` · Rust `#eb6834` · Dell `#1baf7a` · HP `#4a3aa7`.

A cor segue sempre a mesma entidade: azul é Go em toda figura onde linguagens
aparecem, verde é o Dell em toda figura onde máquinas aparecem.
