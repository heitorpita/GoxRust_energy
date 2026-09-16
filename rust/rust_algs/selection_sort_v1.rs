use std::io::{self, Read};

fn selection_sort(v: &mut [i32]) {
    let n = v.len();
    for i in 0..n {
        let mut min_idx = i;
        for j in (i + 1)..n {
            if v[j] < v[min_idx] {
                min_idx = j;
            }
        }
        if min_idx != i {
            v.swap(i, min_idx);
        }
    }
}

fn main() {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();
    let mut it = input.split_whitespace();

    let n: usize = it.next().unwrap().parse().unwrap();
    let mut v: Vec<i32> = (0..n).map(|_| it.next().unwrap().parse().unwrap()).collect();

    selection_sort(&mut v);

    println!("{n}");
    let strs: Vec<String> = v.iter().map(|x| x.to_string()).collect();
    println!("{}", strs.join(" "));
}
