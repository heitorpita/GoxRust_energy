use std::io::{self, Read};

fn sift_down(v: &mut [i32], start: usize, end: usize) {
    let mut root = start;
    loop {
        let mut child = 2 * root + 1;
        if child > end {
            break;
        }
        if child + 1 <= end && v[child] < v[child + 1] {
            child += 1;
        }
        if v[root] < v[child] {
            v.swap(root, child);
            root = child;
        } else {
            break;
        }
    }
}

fn heap_sort(v: &mut [i32]) {
    let n = v.len();
    if n < 2 {
        return;
    }

    for start in (0..=(n / 2 - 1)).rev() {
        sift_down(v, start, n - 1);
    }

    for end in (1..n).rev() {
        v.swap(0, end);
        sift_down(v, 0, end - 1);
    }
}

fn main() {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();
    let mut it = input.split_whitespace();

    let n: usize = it.next().unwrap().parse().unwrap();
    let mut v: Vec<i32> = (0..n).map(|_| it.next().unwrap().parse().unwrap()).collect();

    heap_sort(&mut v);

    println!("{n}");
    let strs: Vec<String> = v.iter().map(|x| x.to_string()).collect();
    println!("{}", strs.join(" "));
}
