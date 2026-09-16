package main

import (
	"bufio"
	"fmt"
	"os"
	"slices"
	"strconv"
	"strings"
)

var leitor = bufio.NewReader(os.Stdin)

func input() string {
	linha, err := leitor.ReadString('\n')
	if err != nil && linha == "" {
		panic(err)
	}
	return strings.TrimSuffix(linha, "\n")
}

func insertion(numbers []int) {
	for i := range len(numbers) {
		n_index, n_min := min_found(numbers, i)
		aux := numbers[i]
		numbers[i] = n_min
		numbers[n_index] = aux
	}

	fmt.Println(numbers)
}

func min_found(original_vector []int, position int) (int, int) {
	n_min := slices.Min(original_vector[position:])
	index := slices.Index(original_vector[position:], n_min) + position

	return index, n_min
}

func main() {
	n := input()
	_ = n
	lista_completa_texto := input()

	lista_completa_campos := strings.Fields(lista_completa_texto)

	lista_completa := make([]int, len(lista_completa_campos))
	for v, i := range lista_completa_campos {
		valor, err := strconv.Atoi(i)
		if err != nil {
			panic(err)
		}
		lista_completa[v] = valor
	}

	insertion(lista_completa)
}
