#!/bin/bash

# Executa os algoritmos de ordenacao sobre as listas .in medindo energia com o
# perf, gerando um csv por (algoritmo, tamanho, execucao).
#
# Uso: ./implementacao.sh [opcoes]
#   -a, --algoritmo    "bolha insertion" | bubble | todos   (padrao: todos)
#   -t, --tamanhos     "10 100 1000"               (padrao: todos os .in achados)
#   -r, --repeticoes   N                           (padrao: 1)
#   -T, --timeout      segundos por execucao       (padrao: 0 = sem limite)
#   -s, --sem-sudo     nao eleva privilegio (energia sai <not supported>)
#   -l, --sem-listas   nao chama o criacao_lista.sh antes de medir
#   -c, --limpar       apaga os csv dos algoritmos/tamanhos escolhidos e recomeca do exec01
#   -y, --sim          responde "sim" a confirmacao do --limpar
#   -f, --forcar       refaz csv ja existente
#   -h, --ajuda

set -u

export LC_ALL=C

# configuracao

declare -a CSV_TERMS
declare -a FOLDERS_TERMS
declare -a SCRIPT_FILES

# arrays paralelos: termo do csv, pasta e script de cada algoritmo
CSV_TERMS=("bolha"        "insertion"    "bolha_better"     "insertion_better")
FOLDERS_TERMS=("bubble"   "insert"       "bubble"           "insert")
SCRIPT_FILES=("bubble_sort.py" "insertion.py" "bubble_better.py" "insertion_better.py")

PASTA_LISTAS="geracoes_listas"
SCRIPT_LISTAS="criacao_lista.sh"
PREFIXO_LISTA="lista"
INTERPRETADOR="python3"

EVENTOS="power/energy-pkg/,duration_time,user_time,system_time"


mostra_ajuda() {
    sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'
}


ALGORITMO="todos"
TAMANHOS=""
REPETICOES=1
TEMPO_LIMITE=0
SEM_SUDO=0
SEM_LISTAS=0
LIMPAR=0
CONFIRMADO=0
FORCAR=0

while [ $# -gt 0 ]; do
    case "$1" in
        -a|--algoritmo)   ALGORITMO=${2:-}; shift 2 ;;
        -t|--tamanhos)    TAMANHOS=${2:-}; shift 2 ;;
        -r|--repeticoes)  REPETICOES=${2:-}; shift 2 ;;
        -T|--timeout)     TEMPO_LIMITE=${2:-}; shift 2 ;;
        -s|--sem-sudo)    SEM_SUDO=1; shift ;;
        -l|--sem-listas)  SEM_LISTAS=1; shift ;;
        -c|--limpar)      LIMPAR=1; shift ;;
        -y|--sim)         CONFIRMADO=1; shift ;;
        -f|--forcar)      FORCAR=1; shift ;;
        -h|--ajuda)       mostra_ajuda; exit 0 ;;
        *) echo "Opcao desconhecida: $1"; mostra_ajuda; exit 1 ;;
    esac
done

if ! [[ $REPETICOES =~ ^[0-9]+$ ]] || [ "$REPETICOES" -lt 1 ]; then
    echo "Erro: --repeticoes deve ser um inteiro maior que zero"
    exit 1
fi

if ! [[ $TEMPO_LIMITE =~ ^[0-9]+$ ]]; then
    echo "Erro: --timeout deve ser um inteiro (segundos, 0 = sem limite)"
    exit 1
fi


SCRIPT_DIR=$(dirname "$0")

if cd "$SCRIPT_DIR"; then
    echo "Diretorio alterado para $(pwd)"
else
    echo "Erro ao alterar para o diretorio $SCRIPT_DIR"
    exit 1
fi

for programa in perf "$INTERPRETADOR"; do
    if ! command -v "$programa" > /dev/null; then
        echo "Erro: '$programa' nao encontrado no PATH"
        exit 1
    fi
done


# o contador power/energy-pkg/ so e lido com privilegio (ou perf_event_paranoid <= 0)
PREFIXO_PERF=""
ESCOPO=""
paranoid=$(cat /proc/sys/kernel/perf_event_paranoid 2> /dev/null || echo 4)

if [ "$SEM_SUDO" -eq 1 ]; then
    echo "Aviso: --sem-sudo, a energia deve sair como <not supported>"
elif [ "$(id -u)" -ne 0 ] && [ "$paranoid" -gt 0 ]; then
    if command -v sudo > /dev/null; then
        echo "perf_event_paranoid=$paranoid: usando sudo para ler power/energy-pkg/"
        sudo -v || { echo "Erro: sudo negado, a energia sairia como <not supported>"; exit 1; }
        # -n: o sudo do comando medido nunca pode pedir senha, porque o stdin
        # dele e o arquivo .in da lista (ele leria a lista como senha e falharia)
        PREFIXO_PERF="sudo -n"
    else
        echo "Aviso: sem privilegio e sem sudo, a energia deve sair como <not supported>"
    fi
fi

# power/energy-pkg/ vem da PMU "power" (RAPL), que e por pacote e nao por tarefa
# (ela expoe .../devices/power/cpumask): medir so o processo devolve
# <not supported>. O contador exige o modo system-wide (-a), que por sua vez
# exige privilegio; sem ele o -a faria o perf abortar e perder ate os tempos.
if [ -n "$PREFIXO_PERF" ] || [ "$(id -u)" -eq 0 ] || [ "$paranoid" -le 0 ]; then
    ESCOPO="-a"
    echo "Medindo em modo system-wide (-a): a energia e a da maquina inteira"
    echo "durante a execucao, entao mantenha o resto do sistema ocioso."
else
    echo "Aviso: sem modo system-wide, so os tempos serao medidos"
fi


# indices dos algoritmos pedidos
declare -a INDICES
INDICES=()

if [ "$ALGORITMO" = "todos" ]; then
    for indice in "${!CSV_TERMS[@]}"; do INDICES+=("$indice"); done
else
    # aceita varios algoritmos ("bolha bolha_better") e tambem o nome da pasta
    for pedido in $ALGORITMO; do
        achou=0

        for indice in "${!CSV_TERMS[@]}"; do
            if [ "$pedido" = "${CSV_TERMS[$indice]}" ] || [ "$pedido" = "${FOLDERS_TERMS[$indice]}" ]; then
                INDICES+=("$indice")
                achou=1
            fi
        done

        if [ "$achou" -eq 0 ]; then
            echo "Erro: algoritmo '$pedido' desconhecido (use: ${CSV_TERMS[*]} ou todos)"
            exit 1
        fi
    done

    mapfile -t INDICES < <(printf '%s\n' "${INDICES[@]}" | sort -n -u)
fi


# garante as listas .in antes de medir; o criacao_lista.sh ignora as que ja existem
if [ "$SEM_LISTAS" -eq 0 ]; then
    if [ ! -x "$SCRIPT_LISTAS" ]; then
        echo "Erro: '$SCRIPT_LISTAS' nao encontrado ou sem permissao de execucao"
        exit 1
    fi

    echo "Conferindo as listas de entrada..."

    if [ -n "$TAMANHOS" ]; then
        ./"$SCRIPT_LISTAS" -t "$TAMANHOS" || exit 1
    else
        ./"$SCRIPT_LISTAS" || exit 1
    fi

    echo
fi


# tamanhos: os pedidos ou todos os .in disponiveis, sempre em ordem crescente
declare -a LISTA_TAMANHOS
LISTA_TAMANHOS=()

if [ -n "$TAMANHOS" ]; then
    for tamanho in $TAMANHOS; do
        if ! [[ $tamanho =~ ^[0-9]+$ ]]; then
            echo "Erro: tamanho invalido '$tamanho'"
            exit 1
        fi
        LISTA_TAMANHOS+=("$tamanho")
    done
else
    for entrada in "$PASTA_LISTAS"/"$PREFIXO_LISTA"_*.in; do
        [ -e "$entrada" ] || continue
        base=$(basename "$entrada" .in)
        LISTA_TAMANHOS+=("${base#"${PREFIXO_LISTA}_"}")
    done
fi

if [ ${#LISTA_TAMANHOS[@]} -eq 0 ]; then
    echo "Erro: nenhuma lista .in encontrada em '$PASTA_LISTAS/'"
    exit 1
fi

mapfile -t LISTA_TAMANHOS < <(printf '%s\n' "${LISTA_TAMANHOS[@]}" | sort -n -u)


# remove os csv dos algoritmos/tamanhos escolhidos, para a numeracao voltar ao exec01
if [ "$LIMPAR" -eq 1 ]; then
    declare -a A_REMOVER
    A_REMOVER=()

    for indice in "${INDICES[@]}"; do
        for tamanho in "${LISTA_TAMANHOS[@]}"; do
            for arquivo in "${FOLDERS_TERMS[$indice]}"/"${CSV_TERMS[$indice]}_${tamanho}"_exec[0-9]*.csv; do
                [ -e "$arquivo" ] && A_REMOVER+=("$arquivo")
            done
        done
    done

    if [ ${#A_REMOVER[@]} -eq 0 ]; then
        echo "Limpeza: nenhum csv anterior para os algoritmos/tamanhos escolhidos"
    else
        echo "Limpeza: ${#A_REMOVER[@]} csv(s) serao APAGADOS:"
        printf '%s\n' "${A_REMOVER[@]}" | sed 's/^/  /' | head -n 10
        [ ${#A_REMOVER[@]} -gt 10 ] && echo "  ... e outros $(( ${#A_REMOVER[@]} - 10 ))"

        if [ "$CONFIRMADO" -eq 0 ]; then
            if [ ! -t 0 ]; then
                echo "Erro: --limpar precisa de confirmacao; use --sim para rodar sem terminal"
                exit 1
            fi

            printf 'Apagar esses arquivos? [s/N] '
            read -r resposta

            case "$resposta" in
                s|S|sim|SIM) ;;
                *) echo "Limpeza cancelada, nada foi apagado"; exit 1 ;;
            esac
        fi

        # os csv das rodadas com sudo pertencem ao root
        rm -f "${A_REMOVER[@]}" 2> /dev/null

        for arquivo in "${A_REMOVER[@]}"; do
            [ -e "$arquivo" ] || continue

            if ! command -v sudo > /dev/null; then
                echo "Erro: sem permissao para apagar '$arquivo'"
                exit 1
            fi

            sudo rm -f "$arquivo" || { echo "Erro: falha ao apagar '$arquivo'"; exit 1; }
        done

        echo "Limpeza: ${#A_REMOVER[@]} csv(s) removidos"
    fi

    echo
fi


# proximo numero de execucao livre para o par (termo, tamanho)
proxima_execucao() {
    local pasta=$1 termo=$2 tamanho=$3
    local arquivo base numero maior=0

    for arquivo in "$pasta"/"${termo}_${tamanho}"_exec[0-9]*.csv; do
        [ -e "$arquivo" ] || continue
        base=$(basename "$arquivo" .csv)
        numero=$((10#${base##*_exec}))
        [ "$numero" -gt "$maior" ] && maior=$numero
    done

    echo $((maior + 1))
}


# o timestamp do sudo expira (~15 min) e uma ordenacao longa passa disso; renova
# aqui, onde o stdin ainda e o terminal, antes de cada uso privilegiado
renova_sudo() {
    [ -n "$PREFIXO_PERF" ] || return 0
    sudo -v || { echo "Erro: nao foi possivel renovar o sudo"; exit 1; }
}


# anota no csv o que aconteceu com a execucao; o medicao.sh ignora linhas com '#'
marca() {
    if [ -w "$1" ]; then
        echo "$2" >> "$1"
    else
        echo "   aviso: sem permissao para anotar em '$1'"
    fi
}


geradas=0
puladas=0
falhas=0

for indice in "${INDICES[@]}"; do
    termo=${CSV_TERMS[$indice]}
    pasta=${FOLDERS_TERMS[$indice]}
    script=${SCRIPT_FILES[$indice]}

    if [ ! -f "$pasta/$script" ]; then
        echo "Aviso: '$pasta/$script' nao encontrado, pulando '$termo'"
        continue
    fi

    mkdir -p "$pasta"

    for tamanho in "${LISTA_TAMANHOS[@]}"; do
        entrada="$PASTA_LISTAS/${PREFIXO_LISTA}_${tamanho}.in"

        if [ ! -f "$entrada" ]; then
            echo "Aviso: '$entrada' nao existe, pulando tamanho $tamanho"
            puladas=$((puladas + 1))
            continue
        fi

        primeira=$(proxima_execucao "$pasta" "$termo" "$tamanho")

        for repeticao in $(seq 0 $((REPETICOES - 1))); do
            numero=$((primeira + repeticao))
            [ "$FORCAR" -eq 1 ] && numero=$((repeticao + 1))

            saida=$(printf '%s/%s_%s_exec%02d.csv' "$pasta" "$termo" "$tamanho" "$numero")

            if [ -e "$saida" ] && [ "$FORCAR" -eq 0 ]; then
                echo "  ja existe, pulando: $saida"
                puladas=$((puladas + 1))
                continue
            fi

            echo "-> $termo | n=$tamanho | exec $numero"

            comando=($PREFIXO_PERF perf stat -x';' $ESCOPO -o "$saida" -e "$EVENTOS")
            [ "$TEMPO_LIMITE" -gt 0 ] && comando+=(timeout --signal=TERM "$TEMPO_LIMITE")
            comando+=("$INTERPRETADOR" "$pasta/$script")

            renova_sudo

            inicio=$SECONDS
            "${comando[@]}" < "$entrada" > /dev/null
            estado=$?
            decorrido=$((SECONDS - inicio))

            # o perf escreve o csv como root quando roda sob sudo
            if [ -n "$PREFIXO_PERF" ] && [ -e "$saida" ]; then
                renova_sudo
                sudo -n chown "$(id -u):$(id -g)" "$saida"
            fi

            if [ ! -e "$saida" ]; then
                echo "   ERRO: perf nao gerou '$saida'"
                falhas=$((falhas + 1))
                continue
            fi

            if [ "$estado" -eq 124 ]; then
                # timeout: o perf ainda reporta os contadores do trecho executado
                marca "$saida" "# INTERROMPIDO por timeout de ${TEMPO_LIMITE}s (ordenacao incompleta)"
                echo "   interrompido em ${TEMPO_LIMITE}s (medicao parcial)"
            elif [ "$estado" -ne 0 ]; then
                marca "$saida" "# EXECUCAO FALHOU (codigo $estado)"
                echo "   ERRO: codigo $estado"
                falhas=$((falhas + 1))
                continue
            else
                echo "   ok em ${decorrido}s -> $saida"
            fi

            geradas=$((geradas + 1))
        done
    done
done

echo
echo "Csvs gerados: $geradas | pulados: $puladas | falhas: $falhas"
[ "$falhas" -gt 0 ] && exit 1
exit 0
