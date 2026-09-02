#!/bin/bash

# Compila o gerador de entradas e cria as listas .in que ainda nao existem.
# Chamado automaticamente pelo implementacao.sh, mas pode rodar sozinho.
#
# Uso: ./criacao_lista.sh [opcoes]
#   -t, --tamanhos     "10 100 1000"   (padrao: a lista de TAMANHOS_PADRAO)
#   -f, --forcar       regera lista ja existente
#   -h, --ajuda

set -u

export LC_ALL=C

# configuracao

declare -a TAMANHOS_PADRAO

TAMANHOS_PADRAO=(10 100 1000 10000 50000 100000 1000000)

PASTA_LISTAS="geracoes_listas"
PREFIXO_LISTA="lista"
FONTE_GERADOR="geraEntrada.cpp"
BINARIO_GERADOR="gera"
COMPILADOR="g++"
FLAGS_COMPILACAO="-O2 -Wall"


mostra_ajuda() {
    sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'
}


TAMANHOS=""
FORCAR=0

while [ $# -gt 0 ]; do
    case "$1" in
        -t|--tamanhos)  TAMANHOS=${2:-}; shift 2 ;;
        -f|--forcar)    FORCAR=1; shift ;;
        -h|--ajuda)     mostra_ajuda; exit 0 ;;
        *) echo "Opcao desconhecida: $1"; mostra_ajuda; exit 1 ;;
    esac
done


SCRIPT_DIR=$(dirname "$0")

if ! cd "$SCRIPT_DIR"; then
    echo "Erro ao alterar para o diretorio $SCRIPT_DIR"
    exit 1
fi


declare -a LISTA_TAMANHOS
LISTA_TAMANHOS=()

if [ -n "$TAMANHOS" ]; then
    for tamanho in $TAMANHOS; do
        if ! [[ $tamanho =~ ^[0-9]+$ ]] || [ "$tamanho" -lt 1 ]; then
            echo "Erro: tamanho invalido '$tamanho'"
            exit 1
        fi
        LISTA_TAMANHOS+=("$tamanho")
    done
else
    LISTA_TAMANHOS=("${TAMANHOS_PADRAO[@]}")
fi

mapfile -t LISTA_TAMANHOS < <(printf '%s\n' "${LISTA_TAMANHOS[@]}" | sort -n -u)


mkdir -p "$PASTA_LISTAS"

if ! cd "$PASTA_LISTAS"; then
    echo "Erro ao entrar em '$PASTA_LISTAS'"
    exit 1
fi

if [ ! -f "$FONTE_GERADOR" ]; then
    echo "Erro: '$PASTA_LISTAS/$FONTE_GERADOR' nao encontrado"
    exit 1
fi

# recompila so quando o binario nao existe ou esta mais velho que o fonte
if [ ! -x "$BINARIO_GERADOR" ] || [ "$FONTE_GERADOR" -nt "$BINARIO_GERADOR" ]; then
    if ! command -v "$COMPILADOR" > /dev/null; then
        echo "Erro: '$COMPILADOR' nao encontrado no PATH"
        exit 1
    fi

    echo "Compilando $FONTE_GERADOR -> $BINARIO_GERADOR"

    if ! $COMPILADOR $FLAGS_COMPILACAO -o "$BINARIO_GERADOR" "$FONTE_GERADOR"; then
        echo "Erro: falha ao compilar '$FONTE_GERADOR'"
        exit 1
    fi
fi


criadas=0
existentes=0
falhas=0

for tamanho in "${LISTA_TAMANHOS[@]}"; do
    arquivo="${PREFIXO_LISTA}_${tamanho}.in"

    if [ -s "$arquivo" ] && [ "$FORCAR" -eq 0 ]; then
        existentes=$((existentes + 1))
        continue
    fi

    echo "-> gerando $arquivo ($tamanho elementos)"

    if ! ./"$BINARIO_GERADOR" "$tamanho" > "$arquivo"; then
        echo "   ERRO: o gerador falhou, removendo '$arquivo'"
        rm -f "$arquivo"
        falhas=$((falhas + 1))
        continue
    fi

    # o gerador imprime o tamanho na primeira linha; confere se bate com o pedido
    if [ "$(head -n 1 "$arquivo")" != "$tamanho" ]; then
        echo "   ERRO: '$arquivo' saiu com cabecalho inesperado, removendo"
        rm -f "$arquivo"
        falhas=$((falhas + 1))
        continue
    fi

    criadas=$((criadas + 1))
done

echo "Listas criadas: $criadas | ja existentes: $existentes | falhas: $falhas"
[ "$falhas" -gt 0 ] && exit 1
exit 0
