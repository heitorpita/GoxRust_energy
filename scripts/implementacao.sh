#!/bin/bash

# Compila os algoritmos de ordenacao (Go e Rust) e os executa sobre as listas .in
# medindo energia com o perf, gerando um csv por (algoritmo, tamanho, execucao).
#
# Uso: scripts/implementacao.sh [opcoes] [algoritmo ...]
#   algoritmo          nome do csv (bolha_rs), fonte (go/go_algs/bubble_v1.go ou bubble_v1),
#                      pasta (go/go_bubble ou go_bubble), linguagem (go, rust) ou todos (padrao)
#   -a, --algoritmo    "bolha selection_rs" (o mesmo que passar os algoritmos no fim)
#   -L, --listar       mostra os algoritmos configurados e sai
#   -t, --tamanhos     "10 100 1000"               (padrao: todos os .in achados)
#   -r, --repeticoes   N                           (padrao: 1)
#   -T, --timeout      segundos por execucao       (padrao: 0 = sem limite)
#   -s, --sem-sudo     nao eleva privilegio (energia sai <not supported>)
#   -l, --sem-listas   nao chama o criacao_lista.sh antes de medir
#   -C, --sem-compilar nao recompila os fontes .go/.rs antes de medir
#   -c, --limpar       apaga os csv dos algoritmos/tamanhos escolhidos e recomeca do exec01
#   -y, --sim          responde "sim" a confirmacao do --limpar
#   -f, --forcar       refaz csv ja existente
#   -h, --ajuda

set -u

export LC_ALL=C

# configuracao

declare -a CSV_TERMS
declare -a FOLDERS_TERMS
declare -a SOURCE_FILES

# arrays paralelos: termo do csv, pasta de saida dos csv e fonte de cada algoritmo;
# a linguagem sai da extensao do fonte (.go ou .rs)
CSV_TERMS=(
    "bolha"                         "bolha_better"
    "insertion"
    "selection"                     "selection_better"
    "bolha_rs"                      "bolha_rs_better"
    "insertion_rs"                  "insertion_rs_better"
    "selection_rs"                  "selection_rs_better"
)
FOLDERS_TERMS=(
    "go/go_bubble"                  "go/go_bubble"
    "go/go_insert"
    "go/go_selection"               "go/go_selection"
    "rust/rust_bubble"              "rust/rust_bubble"
    "rust/rust_insert"              "rust/rust_insert"
    "rust/rust_selection"           "rust/rust_selection"
)
SOURCE_FILES=(
    "go/go_algs/bubble_v1.go"       "go/go_algs/bubble_v2.go"
    "go/go_algs/insert_v1.go"
    "go/go_algs/selection_v1.go"    "go/go_algs/selection_v2.go"
    "rust/rust_algs/bubble_sort_v1.rs"    "rust/rust_algs/bubble_sort_v2.rs"
    "rust/rust_algs/insertion_sort_v1.rs" "rust/rust_algs/insertion_sort_v2.rs"
    "rust/rust_algs/selection_sort_v1.rs" "rust/rust_algs/selection_sort_v2.rs"
)

PASTA_LISTAS="geracoes_listas"
SCRIPT_LISTAS="scripts/criacao_lista.sh"
PREFIXO_LISTA="lista"

# Go: os binarios ficam em go/go_bin/ (go/go_algs/bubble_v1.go -> go/go_bin/bubble_v1)
COMPILADOR_GO="go"
PASTA_BINARIOS_GO="go/go_bin"

# Rust: os binarios ficam em rust/rust_bin/ (rust/rust_algs/bubble_sort_v1.rs -> rust/rust_bin/bubble_sort_v1)
COMPILADOR_RUST="rustc"
FLAGS_COMPILACAO_RUST="-O -C debuginfo=0"
PASTA_BINARIOS_RUST="rust/rust_bin"

# com -a (necessario para a energia) os eventos user_time/system_time do perf somam
# todos os nucleos da maquina; o tempo de cpu do algoritmo vem do GNU time
EVENTOS="power/energy-pkg/,duration_time"
TEMPO_PROCESSO="/usr/bin/time"


mostra_ajuda() {
    sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
}


# linguagem de cada algoritmo, pela extensao do fonte
linguagem_de() {
    case "${SOURCE_FILES[$1]}" in
        *.go) echo "go" ;;
        *.rs) echo "rust" ;;
        *)    echo "desconhecida" ;;
    esac
}


# nome do binario de cada fonte
binario_de() {
    local fonte=${SOURCE_FILES[$1]}

    case "$fonte" in
        *.go) echo "$PASTA_BINARIOS_GO/$(basename "$fonte" .go)" ;;
        *.rs) echo "$PASTA_BINARIOS_RUST/$(basename "$fonte" .rs)" ;;
    esac
}


lista_algoritmos() {
    local indice

    printf '%-22s %-6s %-22s %s\n' "ALGORITMO" "LING" "PASTA DOS CSV" "FONTE"
    for indice in "${!CSV_TERMS[@]}"; do
        printf '%-22s %-6s %-22s %s\n' "${CSV_TERMS[$indice]}" "$(linguagem_de "$indice")" \
            "${FOLDERS_TERMS[$indice]}" "${SOURCE_FILES[$indice]}"
    done
}


ALGORITMO=""
TAMANHOS=""
REPETICOES=1
TEMPO_LIMITE=0
SEM_SUDO=0
SEM_LISTAS=0
SEM_COMPILAR=0
LIMPAR=0
CONFIRMADO=0
FORCAR=0
LISTAR=0

while [ $# -gt 0 ]; do
    case "$1" in
        -a|--algoritmo)   ALGORITMO="$ALGORITMO ${2:-}"; shift 2 ;;
        -L|--listar)      LISTAR=1; shift ;;
        -t|--tamanhos)    TAMANHOS=${2:-}; shift 2 ;;
        -r|--repeticoes)  REPETICOES=${2:-}; shift 2 ;;
        -T|--timeout)     TEMPO_LIMITE=${2:-}; shift 2 ;;
        -s|--sem-sudo)    SEM_SUDO=1; shift ;;
        -l|--sem-listas)  SEM_LISTAS=1; shift ;;
        -C|--sem-compilar) SEM_COMPILAR=1; shift ;;
        -c|--limpar)      LIMPAR=1; shift ;;
        -y|--sim)         CONFIRMADO=1; shift ;;
        -f|--forcar)      FORCAR=1; shift ;;
        -h|--ajuda)       mostra_ajuda; exit 0 ;;
        -*) echo "Opcao desconhecida: $1"; mostra_ajuda; exit 1 ;;
        # argumentos sem opcao sao algoritmos a medir
        *)                ALGORITMO="$ALGORITMO $1"; shift ;;
    esac
done

if [ "$LISTAR" -eq 1 ]; then
    lista_algoritmos
    exit 0
fi

# sem algoritmo pedido, mede todos
[ -n "${ALGORITMO// /}" ] || ALGORITMO="todos"

if ! [[ $REPETICOES =~ ^[0-9]+$ ]] || [ "$REPETICOES" -lt 1 ]; then
    echo "Erro: --repeticoes deve ser um inteiro maior que zero"
    exit 1
fi

if ! [[ $TEMPO_LIMITE =~ ^[0-9]+$ ]]; then
    echo "Erro: --timeout deve ser um inteiro (segundos, 0 = sem limite)"
    exit 1
fi


# os scripts ficam em scripts/, mas trabalham a partir da raiz do repositorio
SCRIPT_DIR=$(dirname "$0")/..

if cd "$SCRIPT_DIR"; then
    echo "Diretorio alterado para $(pwd)"
else
    echo "Erro ao alterar para o diretorio $SCRIPT_DIR"
    exit 1
fi


# rodando como "sudo scripts/...": os arquivos criados voltam para quem chamou o sudo
DONO=""
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_UID:-}" ]; then
    DONO="$SUDO_UID:${SUDO_GID:-$SUDO_UID}"
fi

devolve_dono() {
    [ -n "$DONO" ] || return 0
    chown "$DONO" "$@" 2> /dev/null
}

if [ -n "$DONO" ]; then
    echo "Aviso: rodando com sudo; prefira rodar sem sudo (o script pede a senha so para o perf)."
    echo "       Os arquivos criados serao devolvidos a $DONO."
fi


# indices dos algoritmos pedidos
declare -a INDICES
INDICES=()

for pedido in $ALGORITMO; do
    achou=0

    # aceita o fonte com ./ na frente e a pasta com / no fim
    pedido=${pedido#./}
    pedido=${pedido%/}

    for indice in "${!CSV_TERMS[@]}"; do
        fonte=${SOURCE_FILES[$indice]}
        pasta=${FOLDERS_TERMS[$indice]}
        base_fonte=$(basename "$fonte")

        case "$pedido" in
            todos|"${CSV_TERMS[$indice]}"|"$(linguagem_de "$indice")"|"$fonte"|"$base_fonte"|"${base_fonte%.*}"|"$(dirname "$fonte")"|"$pasta"|"$(basename "$pasta")")
                INDICES+=("$indice")
                achou=1
                ;;
        esac
    done

    if [ "$achou" -eq 0 ]; then
        echo "Erro: algoritmo '$pedido' desconhecido; os configurados sao:"
        lista_algoritmos
        exit 1
    fi
done

mapfile -t INDICES < <(printf '%s\n' "${INDICES[@]}" | sort -n -u)

echo "Algoritmos: $(for indice in "${INDICES[@]}"; do printf '%s ' "${CSV_TERMS[$indice]}"; done)"


if ! command -v perf > /dev/null; then
    echo "Erro: 'perf' nao encontrado no PATH"
    exit 1
fi

if [ ! -x "$TEMPO_PROCESSO" ]; then
    echo "Erro: '$TEMPO_PROCESSO' (GNU time) nao encontrado; instale o pacote 'time'"
    exit 1
fi


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


geradas=0
puladas=0
falhas=0

# algoritmos cujo fonte nao compilou; sao pulados na medicao para nao usar um binario antigo
declare -A NAO_COMPILOU
NAO_COMPILOU=()


# compila os fontes dos algoritmos pedidos; so recompila o que nao tem binario ou
# esta mais novo que ele. A compilacao fica fora do perf para nao entrar na medicao.
# Um fonte que nao compila so tira o proprio algoritmo da medicao
if [ "$SEM_COMPILAR" -eq 0 ]; then
    echo
    echo "Compilando os fontes..."

    compilados=0
    atualizados=0

    for indice in "${INDICES[@]}"; do
        termo=${CSV_TERMS[$indice]}
        fonte=${SOURCE_FILES[$indice]}
        binario=$(binario_de "$indice")

        if [ ! -f "$fonte" ]; then
            continue
        fi

        if [ -x "$binario" ] && [ ! "$fonte" -nt "$binario" ]; then
            atualizados=$((atualizados + 1))
            continue
        fi

        case "$(linguagem_de "$indice")" in
            go)   comando_compilacao=("$COMPILADOR_GO" build -o "$binario" "$fonte") ;;
            rust) comando_compilacao=("$COMPILADOR_RUST" $FLAGS_COMPILACAO_RUST -o "$binario" "$fonte") ;;
            *)    echo "   ERRO: linguagem desconhecida para '$fonte', pulando '$termo'"
                  NAO_COMPILOU[$indice]=1
                  falhas=$((falhas + 1))
                  continue ;;
        esac

        if ! command -v "${comando_compilacao[0]}" > /dev/null; then
            echo "   ERRO: '${comando_compilacao[0]}' nao encontrado no PATH, pulando '$termo'"
            echo "         (use --sem-compilar se ja tem os binarios)"
            NAO_COMPILOU[$indice]=1
            falhas=$((falhas + 1))
            continue
        fi

        mkdir -p "$(dirname "$binario")"
        devolve_dono "$(dirname "$binario")"

        echo "-> ${comando_compilacao[*]}"

        if ! "${comando_compilacao[@]}"; then
            echo "   ERRO: falha ao compilar '$fonte', pulando '$termo'"
            NAO_COMPILOU[$indice]=1
            falhas=$((falhas + 1))
            continue
        fi

        devolve_dono "$binario"
        compilados=$((compilados + 1))
    done

    echo "Binarios compilados: $compilados | ja atualizados: $atualizados | falhas: ${#NAO_COMPILOU[@]}"
    echo
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


for indice in "${INDICES[@]}"; do
    termo=${CSV_TERMS[$indice]}
    pasta=${FOLDERS_TERMS[$indice]}
    fonte=${SOURCE_FILES[$indice]}
    binario=$(binario_de "$indice")

    if [ ! -f "$fonte" ]; then
        echo "Aviso: '$fonte' nao encontrado, pulando '$termo'"
        continue
    fi

    if [ -n "${NAO_COMPILOU[$indice]:-}" ]; then
        echo "Aviso: '$fonte' nao compilou, pulando '$termo'"
        continue
    fi

    if [ ! -x "$binario" ]; then
        echo "Aviso: binario '$binario' nao existe, pulando '$termo'"
        continue
    fi

    mkdir -p "$pasta"
    devolve_dono "$pasta"

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

            # o GNU time fica por fora do timeout para somar o tempo de cpu do algoritmo
            # mesmo quando ele e interrompido
            tempo="${saida%.csv}.tempo"
            rm -f "$tempo" 2> /dev/null

            comando=($PREFIXO_PERF perf stat -x';' $ESCOPO -o "$saida" -e "$EVENTOS")
            comando+=("$TEMPO_PROCESSO" -f '%U;%S' -o "$tempo")
            [ "$TEMPO_LIMITE" -gt 0 ] && comando+=(timeout --signal=TERM "$TEMPO_LIMITE")
            comando+=("./$binario")

            renova_sudo

            inicio=$SECONDS
            "${comando[@]}" < "$entrada" > /dev/null
            estado=$?
            decorrido=$((SECONDS - inicio))

            # o perf e o GNU time escrevem como root quando rodam sob sudo
            if [ -n "$PREFIXO_PERF" ] && [ -e "$saida" ]; then
                renova_sudo
                sudo -n chown "$(id -u):$(id -g)" "$saida"
                [ -e "$tempo" ] && sudo -n chown "$(id -u):$(id -g)" "$tempo"
            fi
            [ -e "$saida" ] && devolve_dono "$saida"

            if [ ! -e "$saida" ]; then
                echo "   ERRO: perf nao gerou '$saida'"
                rm -f "$tempo" 2> /dev/null
                falhas=$((falhas + 1))
                continue
            fi

            # anexa ao csv do perf o tempo de cpu do algoritmo; a ultima linha do GNU time
            # e "user;system" em segundos (antes dela pode vir o aviso de codigo de saida)
            linha_tempo=$(tail -n 1 "$tempo" 2> /dev/null)

            if [[ $linha_tempo =~ ^([0-9]+\.[0-9]+)\;([0-9]+\.[0-9]+)$ ]]; then
                marca "$saida" "# tempo de cpu do processo medido (GNU time, resolucao de 10 ms)"
                marca "$saida" "${BASH_REMATCH[1]};s;processo_user_time;;;;"
                marca "$saida" "${BASH_REMATCH[2]};s;processo_system_time;;;;"
            else
                echo "   aviso: tempo de cpu do processo nao registrado ('$tempo')"
            fi

            rm -f "$tempo" 2> /dev/null

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
