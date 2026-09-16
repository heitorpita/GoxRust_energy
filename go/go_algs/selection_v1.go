package main

import (
	"bufio"
	"container/heap"
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

type IntHeap []int 
func (h IntHeap) Len() int {return len(h)}
func (h IntHeap) Less(i, j int) bool {return h[i] > h[j]}
func (h IntHeap) Swap(i, j int) {h[i], h[j] = h[j], h[i]}
func (h *IntHeap) Push(x any) {
	*h = append(*h, x.(int))
}


func (h *IntHeap) Pop() any {
	old := *h
	n := len(old)
	x := old[n-1]
	*h = old[0 : n-1]
	return x
}

func selection_heap(numbers []int) {
	h := IntHeap(numbers)
	heap.Init(&h);

	for i := 0; i < len(numbers); i++ {
		heap.Pop(&h)
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

	selection_heap(lista_completa)
}
