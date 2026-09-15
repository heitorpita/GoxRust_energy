#include <iostream>
#include <vector>
#include <cstdlib>
#include <ctime>
#include <string>

using namespace std;

int sorteia (int n) {
  return rand() % n;
}


void troca (std::vector<int>& v, int i, int j) {
  int tmp = v[i];
  v[i] = v[j];
  v[j] = tmp;
}


void init_vector (std::vector<int>& v, int n) {
  for (int i = 0; i < n; i++) {
    v.push_back(i + 1);
  }
}


void shuffle_vector (std::vector<int>& v, int n, int times) {
  int i1, i2;
  while (times > 0) {
    i1 = sorteia(n);
    i2 = sorteia(n);
    troca(v, i1, i2);
    times--;
  }
}


void print_vector (std::vector<int>& v) {
  std::cout << v.size() << std::endl;
  for (auto x : v) {
    std::cout << x << " ";
  }
  std::cout << endl;

}


int main (int argc, char **argv) {
  if (argc < 2) {
    std::cout << "Uso: indique o número de elementos do vetor.\nExemplo: ./gera 10" << std::endl;
    return 0;
  }
  int n = std::stoi(argv[1]);
  std::vector<int> v;

  srand(time(0));
  
  init_vector(v, n);
  shuffle_vector(v, n, 2 * n);
  print_vector(v);
  
  return 0;
}
