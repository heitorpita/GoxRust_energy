#!/bin/bash

# Consolida as medicoes do "perf stat -x';'" (bubble e insertion) em um unico csv.
#
# Uso: ./medicao.sh [arquivo_de_saida.csv]
#   -h, --ajuda   mostra esta ajuda

set -u

# o awk precisa de locale neutro para ler/escrever "." como separador decimal;
# a virgula do csv de saida e aplicada na formatacao final
export LC_ALL=C

# configuracao

declare -a CSV_TERMS
declare -a FOLDERS_TERMS

# arrays paralelos: termo do csv e pasta de cada algoritmo
CSV_TERMS=("bolha"      "insertion" "bolha_better" "insertion_better")
FOLDERS_TERMS=("bubble" "insert"    "bubble"       "insert")

# separador e decimal usados no csv gerado
SAIDA_SEP=";"
SAIDA_DECIMAL=","

SAIDA_PADRAO="medicoes_consolidadas.csv"


mostra_ajuda() {
    sed -n '3,6p' "$0" | sed 's/^# \{0,1\}//'
}


case "${1:-}" in
    -h|--ajuda) mostra_ajuda; exit 0 ;;
    # sem isso um "-h" viraria o nome do arquivo de saida
    -*)         echo "Opcao desconhecida: $1"; mostra_ajuda; exit 1 ;;
esac

if [ $# -gt 1 ]; then
    echo "Erro: esperado no maximo um argumento (o arquivo de saida)"
    mostra_ajuda
    exit 1
fi


SCRIPT_DIR=$(dirname "$0")

if cd "$SCRIPT_DIR"; then
    echo "Diretorio alterado para $(pwd)"
else
    echo "Erro ao alterar para o diretorio $SCRIPT_DIR"
    exit 1
fi

SAIDA=${1:-$SAIDA_PADRAO}


# extrai os eventos de um csv do perf e imprime uma linha ja formatada
# argumentos: <arquivo> <algoritmo> <tamanho> <execucao>
extrai_medicao() {
    awk -F';' \
        -v algoritmo="$2" \
        -v tamanho="$3" \
        -v execucao="$4" \
        -v sep="$SAIDA_SEP" \
        -v dec="$SAIDA_DECIMAL" '
        function num(v) {
            gsub(/^[ \t]+|[ \t]+$/, "", v)
            gsub(/,/, ".", v)
            if (v !~ /^-?[0-9]+(\.[0-9]+)?$/) return ""
            return v + 0
        }
        function fmt(v, casas,   s) {
            if (v == "") return "NA"
            s = sprintf("%." casas "f", v)
            gsub(/\./, dec, s)
            return s
        }
        /^#/ || /^[ \t]*$/ { next }
        {
            evento = $3
            # sem privilegio o perf renomeia o evento para power/energy-pkg/u
            sub(/\/[ukhGH]*$/, "/", evento)
            if (evento == "power/energy-pkg/") energia = num($1)
            else if (evento == "duration_time") duracao = num($1)
            else if (evento == "user_time")     usuario = num($1)
            else if (evento == "system_time")   sistema = num($1)
        }
        END {
            # perf reporta os tempos em nanossegundos
            duracao_s = (duracao == "") ? "" : duracao / 1e9
            usuario_s = (usuario == "") ? "" : usuario / 1e9
            sistema_s = (sistema == "") ? "" : sistema / 1e9
            potencia  = (energia == "" || duracao_s == "" || duracao_s == 0) ? "" : energia / duracao_s
            energia_p = (energia == "" || tamanho + 0 == 0) ? "" : energia / (tamanho + 0)

            printf "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n", \
                algoritmo, sep, tamanho, sep, execucao, sep, \
                fmt(energia, 6), sep, \
                fmt(duracao_s, 6), sep, \
                fmt(usuario_s, 6), sep, \
                fmt(sistema_s, 6), sep, \
                fmt(potencia, 4), sep, \
                fmt(energia_p, 9)
        }
    ' "$1"
}


TMP=$(mktemp) || exit 1
trap 'rm -f "$TMP"' EXIT

total=0

for indice in "${!CSV_TERMS[@]}"; do
    termo=${CSV_TERMS[$indice]}
    pasta=${FOLDERS_TERMS[$indice]}

    if [ ! -d "$pasta" ]; then
        echo "Aviso: pasta '$pasta' nao encontrada, pulando '$termo'"
        continue
    fi

    encontrados=0

    for arquivo in "$pasta"/"$termo"_[0-9]*_exec*.csv; do
        [ -e "$arquivo" ] || continue

        base=$(basename "$arquivo" .csv)
        resto=${base#"${termo}_"}
        tamanho=${resto%%_exec*}
        execucao=${resto##*_exec}

        # remove zeros a esquerda do numero da execucao (exec01 -> 1)
        execucao=$((10#$execucao))

        if ! [[ $tamanho =~ ^[0-9]+$ ]]; then
            echo "Aviso: nome fora do padrao, ignorando '$arquivo'"
            continue
        fi

        extrai_medicao "$arquivo" "$termo" "$tamanho" "$execucao" >> "$TMP"
        encontrados=$((encontrados + 1))
    done

    echo "$termo: $encontrados medicao(oes) em '$pasta/'"
    total=$((total + encontrados))
done

if [ "$total" -eq 0 ]; then
    echo "Erro: nenhuma medicao encontrada"
    exit 1
fi

{
    echo "algoritmo${SAIDA_SEP}tamanho${SAIDA_SEP}execucao${SAIDA_SEP}energia_joules${SAIDA_SEP}duracao_s${SAIDA_SEP}user_time_s${SAIDA_SEP}system_time_s${SAIDA_SEP}potencia_media_w${SAIDA_SEP}energia_por_elemento_j"
    sort -t"$SAIDA_SEP" -k1,1 -k2,2n -k3,3n "$TMP"
} > "$SAIDA"

echo "Total: $total medicao(oes)"
case "$SAIDA" in
    /*) echo "Arquivo gerado: $SAIDA" ;;
    *)  echo "Arquivo gerado: $(pwd)/$SAIDA" ;;
esac
