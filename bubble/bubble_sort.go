package main

import (
	"bufio"
	"fmt"
	"os"
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
	for range numbers {
		for j := 0; j < len(numbers)-1; j++ {
			if numbers[j] > numbers[j+1] {
				aux := numbers[j]
				numbers[j] = numbers[j+1]
				numbers[j+1] = aux
			}
		}
	}

	fmt.Println(numbers)
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
