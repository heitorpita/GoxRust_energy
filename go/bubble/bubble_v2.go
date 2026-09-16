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

func bubble(numbers []int) {

	if len(numbers) < 2 {
		fmt.Println(numbers)
		return
	}

	sorted := []int{}

	for len(numbers) >= 2 {
		found := false
		for j := 0; j < len(numbers)-1; j++ {
			// suspende, compara, retira do numbers, coloca no sorted
			// flag serve para a verificação que achou o vetor completamente ordenado
			if numbers[j] > numbers[j+1] {
				found = true
				aux := numbers[j]
				numbers[j] = numbers[j+1]
				numbers[j+1] = aux
			}
		}

		if found == false {
			for range len(numbers) {
				sorted = slices.Insert(sorted, 0, numbers[len(numbers)-1])
				numbers = numbers[:len(numbers)-1]
			}
		} else {
			sorted = slices.Insert(sorted, 0, numbers[len(numbers)-1])
			numbers = numbers[:len(numbers)-1]
		}
	}
	if len(numbers) > 0 {
		ultimo := numbers[len(numbers)-1]
		numbers = numbers[:len(numbers)-1]
		sorted = slices.Insert(sorted, 0, ultimo)
	}

	fmt.Println(sorted)
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

	bubble(lista_completa)
}
