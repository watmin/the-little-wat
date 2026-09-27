# BENCH — excursus 008 baseline, collections and memory

Taken before stone 3's drops. Stone 3 is measured against this file.

Commit `4f89874` (`excursus 008 bench stone: resume note -- the strike's session closed before its measurements`), working tree dirty. The clock intrinsic, the bench programs, and `tools/bench-coll.sh` are uncommitted. Nothing in this baseline was committed.

Machine: 12th Gen Intel i7-1270P, 32 GB RAM, 64 GB swap.

## How it was measured

`tools/bench-coll.sh`, `taskset -c 0`, `perf stat -e cpu_core/instructions/,cpu_core/cycles/ -x,`, five interleaved repetitions. The size is an argument, or for wat the file `elf/bench/coll/n.txt`, read at run time. Wat's `println` quotes the line; the comparison strips the quotes before it checks the answer.

Peak RSS is `elf/bench/maxrss.c` (`ru_maxrss`, KiB). `maxrss` execs with `execv`, so the program path has to be absolute. A resumed section passed `clj` and `prlimit` as bare names and those RSS cells came back `exit 127`. They were remeasured with absolute paths. The numbers below are that remeasure where the first figure was `exit 127`.

A descendant whose resident set passed 8 GiB was killed and recorded. On the resumed section the interpreter and both C programs also had an 8 GiB address-space cap, so a full copy aborts instead of swapping the machine. Wat was not capped: its reservation is larger than 8 GiB of virtual address space.

W4 at 10^5 was measured twice, once before the run was interrupted and once on the resume. Instructions are the minimum of those ten repetitions. The cycle spread for that row is across both sittings.

Clojure's tail in the comparison is the warm run. The cold run is in the tails table.

## Instructions, cycles, RSS

Instructions are the minimum of five pinned repetitions (`cpu_core/instructions/u`), except W4 at 10^5, which has ten because the run was resumed. Cycles are the cycles of that minimum-instruction repetition. Spread is (max cycle − min cycle) / min cycle across those repetitions. No cycle comparison is made inside that spread. RSS is `ru_maxrss` in KiB. A blank instruction cell is a run that did not finish.

### W1 conj i64, then sum. Answer n*(n-1)/2.

| opponent | n | answer | instructions | cycles | cycle spread | RSS KiB |
|---|---:|---:|---:|---:|---:|---:|
| wat compiled | 10,000 | 49,995,000 | 961,160 | 675,060 | 33.4% | 956 |
| wat interpreter | 10,000 | 49,995,000 | 6,888,482,338 | 2,898,189,439 | 5.0% | 72,428 |
| Rust rpds VectorSync | 10,000 | 49,995,000 | 28,579,598 | 22,198,217 | 0.6% | 2,568 |
| C malloc/free | 10,000 | 49,995,000 | 622,930 | 664,088 | 17.6% | 1,936 |
| C never-free | 10,000 | 49,995,000 | 622,798 | 677,263 | 7.1% | 1,952 |
| Clojure | 10,000 | 49,995,000 | 6,744,342,817 | 4,916,463,423 | 1.2% | 127,452 |
| wat compiled | 100,000 | 4,999,950,000 | 6,631,345 | 1,496,954 | 5.7% | 952 |
| wat interpreter | 100,000 | 4,999,950,000 | 384,140,854,822 | 159,462,005,416 | 7.5% | 96,200 |
| Rust rpds VectorSync | 100,000 | 4,999,950,000 | 329,549,574 | 273,092,088 | 0.7% | 7,316 |
| C malloc/free | 100,000 | 4,999,950,000 | 1,523,289 | 1,018,251 | 6.2% | 2,460 |
| C never-free | 100,000 | 4,999,950,000 | 1,523,200 | 1,002,673 | 6.8% | 2,656 |
| Clojure | 100,000 | 4,999,950,000 | 7,187,160,699 | 5,076,037,849 | 1.4% | 131,508 |
| wat compiled | 1,000,000 | 499,999,500,000 | 63,331,393 | 11,536,622 | 5.9% | 9,580 |
| wat interpreter | 1,000,000 | FAIL | — | — | — | timeout |
| Rust rpds VectorSync | 1,000,000 | 499,999,500,000 | 3,646,631,083 | 3,316,397,292 | 1.4% | 53,632 |
| C malloc/free | 1,000,000 | 499,999,500,000 | 10,523,570 | 3,051,987 | 11.7% | 9,616 |
| C never-free | 1,000,000 | 499,999,500,000 | 10,523,484 | 3,336,219 | 4.0% | 9,744 |
| Clojure | 1,000,000 | 499,999,500,000 | 8,280,060,894 | 5,383,310,019 | 2.7% | 230,252 |

### W2 conj a fresh string "ab" each step, then sum lengths. Answer 2*n.

| opponent | n | answer | instructions | cycles | cycle spread | RSS KiB |
|---|---:|---:|---:|---:|---:|---:|
| wat compiled | 10,000 | 20,000 | 1,440,355 | 817,818 | 18.1% | 2,464 |
| wat interpreter | 10,000 | 20,000 | 6,962,814,819 | 5,351,936,669 | 2.2% | 72,736 |
| Rust rpds VectorSync | 10,000 | 20,000 | 32,249,287 | 23,179,851 | 1.2% | 3,220 |
| C malloc/free | 10,000 | 20,000 | 4,320,805 | 1,524,886 | 6.3% | 2,072 |
| C never-free | 10,000 | 20,000 | 2,533,761 | 1,211,752 | 6.9% | 2,208 |
| Clojure | 10,000 | 20,000 | 6,732,794,851 | 4,913,880,677 | 1.4% | 124,628 |
| wat compiled | 100,000 | 200,000 | 10,966,170 | 4,823,172 | 9.4% | 6,504 |
| wat interpreter | 100,000 | 200,000 | 389,407,275,089 | 399,373,655,192 | 0.5% | 95,844 |
| Rust rpds VectorSync | 100,000 | 200,000 | 366,654,624 | 283,961,314 | 1.0% | 11,904 |
| C malloc/free | 100,000 | 200,000 | 38,978,060 | 9,864,353 | 2.9% | 5,660 |
| C never-free | 100,000 | 200,000 | 20,631,063 | 6,529,086 | 2.4% | 5,664 |
| Clojure | 100,000 | 200,000 | 7,311,582,146 | 5,055,727,336 | 2.5% | 132,496 |
| wat compiled | 1,000,000 | 2,000,000 | 103,011,277 | 43,415,512 | 4.5% | 47,652 |
| wat interpreter | 1,000,000 | FAIL | — | — | — | timeout |
| Rust rpds VectorSync | 1,000,000 | 2,000,000 | 4,013,672,425 | 3,430,032,361 | 0.4% | 100,096 |
| C malloc/free | 1,000,000 | 2,000,000 | 385,544,833 | 91,329,298 | 2.2% | 40,608 |
| C never-free | 1,000,000 | 2,000,000 | 201,597,820 | 59,268,808 | 1.1% | 40,868 |
| Clojure | 1,000,000 | 2,000,000 | 9,113,407,315 | 5,710,566,012 | 3.0% | 221,836 |

### W3 assoc one record field, keep only the latest. Answer n.

| opponent | n | answer | instructions | cycles | cycle spread | RSS KiB |
|---|---:|---:|---:|---:|---:|---:|
| wat compiled | 10,000 | 10,000 | 501,036 | 451,620 | 8.9% | 960 |
| wat interpreter | 10,000 | 10,000 | 2,904,541,188 | 1,417,616,143 | 2.2% | 71,372 |
| Rust rpds VectorSync | 10,000 | 10,000 | 5,728,126 | 3,131,111 | 2.0% | 2,188 |
| C malloc/free | 10,000 | 10,000 | 593,045 | 662,269 | 8.8% | 1,824 |
| C never-free | 10,000 | 10,000 | 2,143,107 | 1,097,906 | 4.7% | 2,208 |
| Clojure | 10,000 | 10,000 | 6,756,037,390 | 4,905,671,370 | 1.2% | 128,376 |
| wat compiled | 100,000 | 100,000 | 2,031,103 | 689,479 | 3.5% | 952 |
| wat interpreter | 100,000 | 100,000 | 6,801,729,488 | 2,835,239,055 | 5.7% | 71,136 |
| Rust rpds VectorSync | 100,000 | 100,000 | 50,638,197 | 24,329,228 | 1.7% | 2,260 |
| C malloc/free | 100,000 | 100,000 | 1,223,083 | 735,622 | 24.1% | 1,760 |
| C never-free | 100,000 | 100,000 | 16,726,937 | 4,959,452 | 5.3% | 4,896 |
| Clojure | 100,000 | 100,000 | 7,066,448,624 | 5,047,373,512 | 1.8% | 136,448 |
| wat compiled | 1,000,000 | 1,000,000 | 17,331,169 | 3,380,932 | 1.1% | 956 |
| wat interpreter | 1,000,000 | 1,000,000 | 45,781,385,016 | 17,369,681,298 | 2.3% | 71,332 |
| Rust rpds VectorSync | 1,000,000 | 1,000,000 | 499,737,709 | 243,752,726 | 3.3% | 2,176 |
| C malloc/free | 1,000,000 | 1,000,000 | 7,523,121 | 1,635,775 | 6.3% | 1,824 |
| C never-free | 1,000,000 | 1,000,000 | 162,565,340 | 43,067,078 | 2.9% | 32,992 |
| Clojure | 1,000,000 | 1,000,000 | 7,662,656,925 | 5,207,851,076 | 2.0% | 169,068 |

### W4 keep every version, then nth(version i, i). Answer n*(n-1)/2.

| opponent | n | answer | instructions | cycles | cycle spread | RSS KiB |
|---|---:|---:|---:|---:|---:|---:|
| wat compiled | 10,000 | 49,995,000 | 10,136,673 | 5,835,691 | 7.3% | 9,304 |
| wat interpreter | 10,000 | 49,995,000 | 10,952,319,713 | 10,976,507,893 | 0.6% | 4,558,740 |
| Rust rpds VectorSync | 10,000 | 49,995,000 | 70,397,429 | 49,454,855 | 3.4% | 9,088 |
| C malloc/free | 10,000 | 49,995,000 | 4,652,469 | 162,875,917 | 0.5% | 392,608 |
| C never-free | 10,000 | 49,995,000 | 2,990,033 | 160,626,916 | 0.7% | 392,736 |
| Clojure | 10,000 | 49,995,000 | 6,809,472,238 | 4,903,439,072 | 1.1% | 122,940 |
| wat compiled | 100,000 | 4,999,950,000 | 131,848,365 | 71,433,108 | 64.7% | 104,968 |
| wat interpreter | 100,000 | FAIL | — | — | — | exit 127 |
| Rust rpds VectorSync | 100,000 | 4,999,950,000 | 840,585,776 | 633,603,967 | 21.6% | 85,440 |
| C malloc/free | 100,000 | FAIL | — | — | — | exit 127 |
| C never-free | 100,000 | FAIL | — | — | — | exit 127 |
| Clojure | 100,000 | 4,999,950,000 | 8,009,663,464 | 5,434,841,518 | 42.5% | 142,748 |
| wat compiled | 1,000,000 | 499,999,500,000 | 1,491,897,593 | 1,046,115,868 | 7.3% | 1,108,492 |
| wat interpreter | 1,000,000 | FAIL | — | — | — | exit 127 |
| Rust rpds VectorSync | 1,000,000 | 499,999,500,000 | 9,268,711,173 | 7,809,826,181 | 1.5% | 966,144 |
| C malloc/free | 1,000,000 | FAIL | — | — | — | exit 127 |
| C never-free | 1,000,000 | FAIL | — | — | — | exit 127 |
| Clojure | 1,000,000 | 499,999,500,000 | 15,648,339,990 | 8,042,794,144 | 6.5% | 409,988 |

### W5 build a string by repeated concat. Answer n.

| opponent | n | answer | instructions | cycles | cycle spread | RSS KiB |
|---|---:|---:|---:|---:|---:|---:|
| wat compiled | 10,000 | 10,000 | 631,858 | 442,770 | 6.7% | 988 |
| wat interpreter | 10,000 | 10,000 | 2,711,126,880 | 1,316,082,114 | 5.6% | 71,380 |
| Rust rpds VectorSync | 10,000 | 10,000 | 860,544 | 866,297 | 7.6% | 2,260 |
| C malloc/free | 10,000 | 10,000 | 1,077,735 | 1,052,779 | 4.1% | 1,824 |
| C never-free | 10,000 | 10,000 | 3,091,706 | 15,701,712 | 1.0% | 50,720 |
| Clojure | 10,000 | 10,000 | 6,763,451,662 | 4,980,881,576 | 4.5% | 177,412 |
| wat compiled | 100,000 | 100,000 | 3,332,035 | 987,208 | 4.1% | 952 |
| wat interpreter | 100,000 | 100,000 | 4,898,427,880 | 2,549,646,709 | 2.2% | 71,132 |
| Rust rpds VectorSync | 100,000 | 100,000 | 1,940,724 | 1,213,758 | 15.1% | 2,324 |
| C malloc/free | 100,000 | 100,000 | 1,978,371 | 1,220,010 | 8.0% | 1,952 |
| C never-free | 100,000 | 100,000 | 26,198,518 | 2,022,678,835 | 0.9% | 4,886,048 |
| Clojure | 100,000 | 100,000 | 8,705,961,515 | 7,569,729,742 | 6.9% | 3,638,300 |
| wat compiled | 1,000,000 | 1,000,000 | 30,332,172 | 5,602,472 | 7.7% | 3,904 |
| wat interpreter | 1,000,000 | 1,000,000 | 26,642,143,499 | 73,770,698,329 | 3.0% | 73,360 |
| Rust rpds VectorSync | 1,000,000 | 1,000,000 | 12,742,327 | 5,295,703 | 25.4% | 3,200 |
| C malloc/free | 1,000,000 | 1,000,000 | 10,979,309 | 2,803,499 | 2.2% | 2,832 |
| C never-free | 1,000,000 | FAIL | — | — | — | exceeded |
| Clojure | 1,000,000 | 1,000,000 | 107,077,981,785 | 250,018,891,853 | 2.1% | 1,271,960 |

## Batch tails

Nanoseconds per batch of 1,000 operations. Nearest-rank p50, p99, p99.9, and the maximum. Clojure is shown cold and warm; the warm row is the one to compare. The timed wat program is native-only.

| opponent | n | p50 | p99 | p99.9 | max |
|---|---:|---:|---:|---:|---:|
| wat compiled | 10,000 | 368,615 | 1,412,064 | 1,412,064 | 1,412,064 |
| Rust rpds | 10,000 | 1,638,806 | 1,788,608 | 1,788,608 | 1,788,608 |
| C malloc/free | 10,000 | 10,978 | 13,980 | 13,980 | 13,980 |
| C never-free | 10,000 | 9,871 | 27,259 | 27,259 | 27,259 |
| Clojure cold | 10,000 | 1,370,387 | 3,552,005 | 3,552,005 | 3,552,005 |
| Clojure warm | 10,000 | 1,294,599 | 3,042,972 | 3,042,972 | 3,042,972 |
| wat compiled | 100,000 | 620,084 | 1,095,310 | 1,827,249 | 1,827,249 |
| Rust rpds | 100,000 | 1,499,433 | 2,050,943 | 2,121,809 | 2,121,809 |
| C malloc/free | 100,000 | 12,307 | 30,089 | 63,753 | 63,753 |
| C never-free | 100,000 | 9,935 | 24,246 | 121,315 | 121,315 |
| Clojure cold | 100,000 | 918,950 | 4,703,230 | 13,667,500 | 13,667,500 |
| Clojure warm | 100,000 | 210,879 | 2,093,759 | 10,425,364 | 10,425,364 |
| wat compiled | 1,000,000 | 584,193 | 944,677 | 1,172,266 | 1,548,140 |
| Rust rpds | 1,000,000 | 1,816,427 | 3,058,643 | 3,338,194 | 3,456,470 |
| C malloc/free | 1,000,000 | 7,220 | 22,449 | 301,920 | 337,654 |
| C never-free | 1,000,000 | 7,777 | 21,038 | 302,332 | 426,911 |
| Clojure cold | 1,000,000 | 56,620 | 1,503,781 | 17,622,607 | 23,819,420 |
| Clojure warm | 1,000,000 | 63,080 | 673,786 | 13,694,846 | 22,039,419 |
| wat compiled | 10,000 | 654,213 | 1,301,010 | 1,301,010 | 1,301,010 |
| Rust rpds | 10,000 | 1,605,040 | 2,256,792 | 2,256,792 | 2,256,792 |
| C malloc/free | 10,000 | 80,152 | 136,045 | 136,045 | 136,045 |
| C never-free | 10,000 | 50,829 | 57,493 | 57,493 | 57,493 |
| Clojure cold | 10,000 | 1,456,235 | 4,293,166 | 4,293,166 | 4,293,166 |
| Clojure warm | 10,000 | 1,142,141 | 1,960,069 | 1,960,069 | 1,960,069 |
| wat compiled | 100,000 | 697,669 | 942,399 | 1,686,521 | 1,686,521 |
| Rust rpds | 100,000 | 1,566,544 | 1,942,597 | 1,980,511 | 1,980,511 |
| C malloc/free | 100,000 | 74,803 | 111,568 | 113,381 | 113,381 |
| C never-free | 100,000 | 57,319 | 114,199 | 116,010 | 116,010 |
| Clojure cold | 100,000 | 705,460 | 3,513,342 | 13,913,610 | 13,913,610 |
| Clojure warm | 100,000 | 171,131 | 2,187,888 | 9,004,136 | 9,004,136 |
| wat compiled | 1,000,000 | 650,794 | 1,364,268 | 1,457,257 | 2,166,432 |
| Rust rpds | 1,000,000 | 2,044,233 | 3,170,235 | 3,278,965 | 3,312,994 |
| C malloc/free | 1,000,000 | 52,084 | 82,356 | 293,459 | 326,459 |
| C never-free | 1,000,000 | 63,938 | 166,716 | 415,423 | 474,605 |
| Clojure cold | 1,000,000 | 56,419 | 1,396,420 | 13,049,786 | 13,667,927 |
| Clojure warm | 1,000,000 | 57,431 | 405,977 | 9,374,450 | 16,783,710 |
| wat compiled | 10,000 | 4,713 | 8,844 | 8,844 | 8,844 |
| Rust rpds | 10,000 | 160,660 | 177,107 | 177,107 | 177,107 |
| C malloc/free | 10,000 | 5,469 | 5,518 | 5,518 | 5,518 |
| C never-free | 10,000 | 55,266 | 63,445 | 63,445 | 63,445 |
| Clojure cold | 10,000 | 1,191,614 | 3,203,203 | 3,203,203 | 3,203,203 |
| Clojure warm | 10,000 | 1,090,672 | 2,643,527 | 2,643,527 | 2,643,527 |
| wat compiled | 100,000 | 4,004 | 6,415 | 7,339 | 7,339 |
| Rust rpds | 100,000 | 168,775 | 205,181 | 207,022 | 207,022 |
| C malloc/free | 100,000 | 4,747 | 5,083 | 5,085 | 5,085 |
| C never-free | 100,000 | 63,051 | 130,064 | 145,695 | 145,695 |
| Clojure cold | 100,000 | 787,571 | 4,817,848 | 12,275,674 | 12,275,674 |
| Clojure warm | 100,000 | 210,971 | 2,267,945 | 8,747,851 | 8,747,851 |
| wat compiled | 1,000,000 | 5,159 | 12,958 | 37,713 | 39,358 |
| Rust rpds | 1,000,000 | 178,690 | 217,957 | 288,455 | 307,416 |
| C malloc/free | 1,000,000 | 5,785 | 5,883 | 15,518 | 25,825 |
| C never-free | 1,000,000 | 52,540 | 109,776 | 314,779 | 601,773 |
| Clojure cold | 1,000,000 | 46,923 | 1,267,299 | 8,258,653 | 12,592,384 |
| Clojure warm | 1,000,000 | 133,472 | 410,648 | 3,382,513 | 3,970,443 |
| wat compiled | 10,000 | 1,224,777 | 1,623,066 | 1,623,066 | 1,623,066 |
| Rust rpds | 10,000 | 2,809,515 | 2,946,261 | 2,946,261 | 2,946,261 |
| C malloc/free | 10,000 | 23,647,681 | 53,860,238 | 53,860,238 | 53,860,238 |
| C never-free | 10,000 | 26,774,669 | 59,407,865 | 59,407,865 | 59,407,865 |
| Clojure cold | 10,000 | 1,606,420 | 3,873,587 | 3,873,587 | 3,873,587 |
| Clojure warm | 10,000 | 1,347,010 | 15,164,745 | 15,164,745 | 15,164,745 |
| wat compiled | 100,000 | 1,560,162 | 2,675,455 | 2,757,255 | 2,757,255 |
| Rust rpds | 100,000 | 5,593,794 | 10,133,920 | 10,435,537 | 10,435,537 |
| C malloc/free | 100,000 | exceeded | | | |
| C never-free | 100,000 | exceeded | | | |
| Clojure cold | 100,000 | 1,194,474 | 39,797,203 | 44,498,363 | 44,498,363 |
| Clojure warm | 100,000 | 423,658 | 3,826,638 | 27,985,518 | 27,985,518 |
| wat compiled | 1,000,000 | 2,487,709 | 4,413,037 | 5,158,438 | 5,368,529 |
| Rust rpds | 1,000,000 | 4,804,067 | 10,674,424 | 11,616,367 | 11,673,497 |
| C malloc/free | 1,000,000 | exceeded | | | |
| C never-free | 1,000,000 | exceeded | | | |
| Clojure cold | 1,000,000 | 99,055 | 2,500,585 | 72,286,591 | 95,527,513 |
| Clojure warm | 1,000,000 | 100,400 | 648,352 | 47,884,084 | 85,660,507 |
| wat compiled | 10,000 | 10,209 | 19,037 | 19,037 | 19,037 |
| Rust rpds | 10,000 | 6,788 | 21,410 | 21,410 | 21,410 |
| C malloc/free | 10,000 | 6,271 | 9,529 | 9,529 | 9,529 |
| C never-free | 10,000 | 4,073,987 | 11,323,229 | 11,323,229 | 11,323,229 |
| Clojure cold | 10,000 | 6,144,207 | 16,604,802 | 16,604,802 | 16,604,802 |
| Clojure warm | 10,000 | 3,314,132 | 7,325,356 | 7,325,356 | 7,325,356 |
| wat compiled | 100,000 | 19,845 | 439,856 | 473,343 | 473,343 |
| Rust rpds | 100,000 | 4,824 | 16,915 | 72,708 | 72,708 |
| C malloc/free | 100,000 | 6,237 | 14,164 | 17,445 | 17,445 |
| C never-free | 100,000 | 41,707,100 | 79,385,201 | 83,556,427 | 83,556,427 |
| Clojure cold | 100,000 | 19,586,295 | 64,969,790 | 75,936,461 | 75,936,461 |
| Clojure warm | 100,000 | 14,474,201 | 42,560,565 | 43,568,577 | 43,568,577 |
| wat compiled | 1,000,000 | 75,765 | 1,100,017 | 1,176,445 | 1,220,595 |
| Rust rpds | 1,000,000 | 5,047 | 24,491 | 79,031 | 91,981 |
| C malloc/free | 1,000,000 | 5,415 | 16,754 | 61,004 | 145,966 |
| C never-free | 1,000,000 | exceeded | | | |
| Clojure cold | 1,000,000 | 156,420,393 | 383,152,482 | 407,751,033 | 440,572,253 |
| Clojure warm | 1,000,000 | 156,617,252 | 389,302,325 | 408,610,142 | 427,821,606 |


## Runs that did not finish

These are not disagreeing answers. The program was killed or aborted before it printed.

| workload | n | opponent | what happened |
|---|---:|---|---|
| W1 | 1,000,000 | wat interpreter | no answer in 900 s |
| W2 | 1,000,000 | wat interpreter | no answer in 900 s |
| W4 | 100,000 | wat interpreter | resident set passed 8 GiB; the resume aborted under the 8 GiB address cap (exit 134) |
| W4 | 100,000 | C malloc/free and C never-free | resident set passed 8 GiB. Both keep every version until the end, so the peaks match |
| W4 | 1,000,000 | wat interpreter | aborted under the 8 GiB address cap |
| W4 | 1,000,000 | C malloc/free and C never-free | resident set passed 8 GiB |
| W5 | 1,000,000 | C never-free | resident set passed 8 GiB. At 10^5 the same program peaked at 4,886,048 KiB |

Wat's own W4 at 1,000,000 finished. Peak RSS 1,108,492 KiB. That is under the 8 GiB line.

## R1 — one owner on W1–W3

The Rust column in the tables above is `push_back` / `set`: a new vector every step. That is the persistent API. The one-owner API is `push_back_mut` / `set_mut` (`w1m`, `w2m`, `w3m`). Both were remeasured in one sitting, five pinned repetitions, `taskset -c 0`, the same counters. Answers agreed with the wat results on every cell. W4 and W5 were not rerun.

Instructions are the minimum of the five. Cycles are that repetition's cycles. Spread is (max − min) / min of the five cycle counts.

| workload | n | persistent ins | one-owner ins | one-owner cycles | spread | persistent RSS | one-owner RSS |
|---|---:|---:|---:|---:|---:|---:|---:|
| W1 | 10,000 | 28,557,102 | 9,071,945 | 2,765,501 | 4.0% | 2,696 | 2,708 |
| W1 | 100,000 | 329,347,707 | 91,489,855 | 22,662,591 | 1.9% | 7,292 | 6,400 |
| W1 | 1,000,000 | 3,644,630,825 | 932,683,073 | 222,603,195 | 2.7% | 53,644 | 44,820 |
| W2 | 10,000 | 32,198,086 | 12,457,304 | 3,634,076 | 3.6% | 3,196 | 3,072 |
| W2 | 100,000 | 366,152,908 | 125,193,226 | 31,314,632 | 2.2% | 11,792 | 10,856 |
| W2 | 1,000,000 | 4,008,670,715 | 1,269,105,325 | 309,730,023 | 3.1% | 99,860 | 90,772 |
| W3 | 10,000 | 5,726,356 | 2,875,763 | 1,350,393 | 3.4% | 2,196 | 2,200 |
| W3 | 100,000 | 50,635,941 | 22,135,733 | 6,179,871 | 49.1% | 2,196 | 2,068 |
| W3 | 1,000,000 | 499,736,489 | 214,736,106 | 53,690,490 | 0.9% | 2,200 | 1,976 |

W3 at 10^5 has a 49.1% cycle spread. Its instruction counts across the five repetitions stay inside 22,135,733–22,136,432. No cycle claim on that row.

Clojure one-owner (`transient`, `conj!` / `assoc!`, `persistent!` at the end), same sitting:

| workload | n | instructions | cycles | spread | RSS KiB | p50 ns |
|---|---:|---:|---:|---:|---:|---:|
| W1 | 10,000 | 6,827,383,921 | 4,857,354,123 | 2.0% | 130,436 | 1,302,960 |
| W1 | 100,000 | 7,223,768,550 | 4,969,034,757 | 2.2% | 135,944 | 725,942 |
| W1 | 1,000,000 | 8,332,111,209 | 5,335,786,880 | 1.8% | 160,980 | 43,278 |
| W2 | 10,000 | 6,944,073,165 | 4,884,828,748 | 1.2% | 131,132 | 1,260,278 |
| W2 | 100,000 | 7,303,799,829 | 4,975,751,624 | 2.7% | 133,096 | 735,630 |
| W2 | 1,000,000 | 8,879,926,116 | 5,463,926,992 | 1.5% | 150,660 | 51,722 |
| W3 | 10,000 | 6,786,644,017 | 4,775,439,801 | 2.4% | 128,668 | 1,359,300 |
| W3 | 100,000 | 7,125,493,916 | 4,999,626,563 | 2.7% | 134,960 | 713,623 |
| W3 | 1,000,000 | 7,476,373,120 | 5,055,306,592 | 2.8% | 132,784 | 28,799 |

C `malloc`/`free` on W1–W3 was already a mutable buffer. The never-free column is the bump. The wat interpreter runs the same uniquely owned source as the compiled program. Those three were not given a second API.
