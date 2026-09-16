/*
melhorias:
* verificar se o vetor esta já ordenado
* verificar se ele é menor que 2
* n - 1 loops por interacao no segundo for?
*/

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

var sorted = []int{}

func selection(numbers []int) {
	if len(numbers) < 2 {
		fmt.Println(numbers)
		return
	}

	for len(numbers) >= 2 {
		for range len(numbers) {
			n_index := min_found(numbers)
			sorted = append(sorted, numbers[n_index])
			numbers = slices.Delete(numbers, n_index, n_index+1)
		}
	}

	fmt.Println(sorted)
}

func min_found(original_vector []int) int {
	min_n := slices.Min(original_vector[0:])
	index := slices.Index(original_vector, min_n)
	return index
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

	selection(lista_completa)
}
