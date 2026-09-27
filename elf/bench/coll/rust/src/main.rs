// Persistent twin: rpds 1.2.1 VectorSync (Arc). The size is argv and black_box'd.
use rpds::VectorSync;
use std::hint::black_box;
use std::time::Instant;

fn nsec(t: Instant) -> i64 {
    t.elapsed().as_nanos() as i64
}

fn rank(s: &[i64], p: i64, den: i64) -> i64 {
    let m = s.len() as i64;
    s[((p * m + (den - 1)) / den - 1) as usize]
}

fn tails(mut b: Vec<i64>) {
    b.sort_unstable();
    println!(
        "TAIL {} {} {} {}",
        rank(&b, 50, 100),
        rank(&b, 99, 100),
        rank(&b, 999, 1000),
        b[b.len() - 1]
    );
}

fn stamp(timed: bool, i: i64, batches: &mut Vec<i64>, t0: &mut Instant) {
    if timed && (i + 1) % 1000 == 0 {
        let t1 = Instant::now();
        batches.push(nsec(*t0));
        *t0 = t1;
    }
}

fn w1(n: i64, timed: bool) {
    // Persistent: a new vector every step, even though the old one is dead.
    let mut v = VectorSync::new_sync();
    let mut batches = Vec::new();
    let mut t0 = Instant::now();
    for i in 0..n {
        v = v.push_back(i);
        stamp(timed, i, &mut batches, &mut t0);
    }
    let mut s = 0i64;
    for i in 0..n {
        s += *v.get(i as usize).unwrap();
    }
    println!("ANSWER {}", black_box(s));
    if timed {
        tails(batches);
    }
}

fn w2(n: i64, timed: bool) {
    let mut v = VectorSync::<String>::new_sync();
    let mut batches = Vec::new();
    let mut t0 = Instant::now();
    for i in 0..n {
        v = v.push_back("ab".to_string());
        stamp(timed, i, &mut batches, &mut t0);
    }
    let mut s = 0i64;
    for i in 0..n {
        s += v.get(i as usize).unwrap().len() as i64;
    }
    println!("ANSWER {}", black_box(s));
    if timed {
        tails(batches);
    }
}

// One owner, keep only the latest. push_back_mut / set_mut copy a node only
// when the Arc is shared; a uniquely owned vector extends in place.
fn w1m(n: i64, timed: bool) {
    let mut v = VectorSync::new_sync();
    let mut batches = Vec::new();
    let mut t0 = Instant::now();
    for i in 0..n {
        v.push_back_mut(i);
        stamp(timed, i, &mut batches, &mut t0);
    }
    let mut s = 0i64;
    for i in 0..n {
        s += *v.get(i as usize).unwrap();
    }
    println!("ANSWER {}", black_box(s));
    if timed {
        tails(batches);
    }
}

fn w2m(n: i64, timed: bool) {
    let mut v = VectorSync::<String>::new_sync();
    let mut batches = Vec::new();
    let mut t0 = Instant::now();
    for i in 0..n {
        v.push_back_mut("ab".to_string());
        stamp(timed, i, &mut batches, &mut t0);
    }
    let mut s = 0i64;
    for i in 0..n {
        s += v.get(i as usize).unwrap().len() as i64;
    }
    println!("ANSWER {}", black_box(s));
    if timed {
        tails(batches);
    }
}

fn w3m(n: i64, timed: bool) {
    let mut r = VectorSync::new_sync();
    r.push_back_mut(0i64);
    let mut batches = Vec::new();
    let mut t0 = Instant::now();
    for i in 0..n {
        assert!(r.set_mut(0, i + 1));
        stamp(timed, i, &mut batches, &mut t0);
    }
    println!("ANSWER {}", black_box(*r.get(0).unwrap()));
    if timed {
        tails(batches);
    }
}

fn w3(n: i64, timed: bool) {
    let mut r = VectorSync::new_sync().push_back(0i64);
    let mut batches = Vec::new();
    let mut t0 = Instant::now();
    for i in 0..n {
        r = r.set(0, i + 1).unwrap();
        stamp(timed, i, &mut batches, &mut t0);
    }
    println!("ANSWER {}", black_box(*r.get(0).unwrap()));
    if timed {
        tails(batches);
    }
}

fn w4(n: i64, timed: bool) {
    let mut v = VectorSync::new_sync();
    let mut vs = VectorSync::new_sync();
    let mut batches = Vec::new();
    let mut t0 = Instant::now();
    for i in 0..n {
        v = v.push_back(i);
        vs = vs.push_back(v.clone());
        stamp(timed, i, &mut batches, &mut t0);
    }
    let mut s = 0i64;
    for i in 0..n as usize {
        s += *vs.get(i).unwrap().get(i).unwrap();
    }
    println!("ANSWER {}", black_box(s));
    if timed {
        tails(batches);
    }
}

fn w5(n: i64, timed: bool) {
    // A fresh string each concat: the persistent reading. Drop of the previous
    // string is inline, which is the twin's rule, not a retained rope.
    let mut s = String::new();
    let mut batches = Vec::new();
    let mut t0 = Instant::now();
    for i in 0..n {
        s = s + "a";
        stamp(timed, i, &mut batches, &mut t0);
    }
    println!("ANSWER {}", black_box(s.len() as i64));
    if timed {
        tails(batches);
    }
}

fn main() {
    let mut args = std::env::args();
    let _ = args.next();
    let which = args.next().expect("workload");
    let n: i64 = black_box(args.next().expect("n").parse().unwrap());
    let timed = args.next().unwrap_or_default() == "timed";
    match which.as_str() {
        "w1" => w1(n, timed),
        "w2" => w2(n, timed),
        "w3" => w3(n, timed),
        "w1m" => w1m(n, timed),
        "w2m" => w2m(n, timed),
        "w3m" => w3m(n, timed),
        "w4" => w4(n, timed),
        "w5" => w5(n, timed),
        _ => std::process::exit(2),
    }
}
