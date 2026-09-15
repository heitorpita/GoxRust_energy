use std::io::{self, Read};

fn insertion_sort(v: &mut [i32]) {
    for i in 1..v.len() {
        let mut j = i;
        while j > 0 && v[j - 1] > v[j] {
            v.swap(j - 1, j);
            j -= 1;
        }
    }
}

fn main() {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();
    let mut it = input.split_whitespace();

    let n: usize = it.next().unwrap().parse().unwrap();
    let mut v: Vec<i32> = (0..n).map(|_| it.next().unwrap().parse().unwrap()).collect();

    insertion_sort(&mut v);

    println!("{n}");
    let strs: Vec<String> = v.iter().map(|x| x.to_string()).collect();
    println!("{}", strs.join(" "));
}
