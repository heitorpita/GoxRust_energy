use std::io::{self, Read};

fn bubble_sort(v: &mut [i32]) {
    let mut limite = v.len().saturating_sub(1);
    while limite > 0 {
        let mut ultima = 0;
        for j in 0..limite {
            if v[j] > v[j + 1] {
                v.swap(j, j + 1);
                ultima = j;
            }
        }
        limite = ultima;
    }
}

fn main() {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();
    let mut it = input.split_whitespace();

    let n: usize = it.next().unwrap().parse().unwrap();
    let mut v: Vec<i32> = (0..n).map(|_| it.next().unwrap().parse().unwrap()).collect();

    bubble_sort(&mut v);

    println!("{n}");
    let strs: Vec<String> = v.iter().map(|x| x.to_string()).collect();
    println!("{}", strs.join(" "));
}
