;; Advent of Code's convolution shape, in wat: an image enhanced by a 512-entry lookup.
;;
;; The first line is the algorithm, 512 characters. Each step replaces every pixel -- INCLUDING
;; the infinite border around the image -- by reading its 3x3 neighbourhood as a nine-bit index
;; into the algorithm. Entry 0 is lit here, so the infinite background FLIPS on every step, which
;; is the trap the puzzle is built around: a solution that assumes the outside is dark answers a
;; number that is too small, and one that lets the grid grow without tracking the background
;; answers one that is too large.
;;
;; Part one: lit pixels after 2 steps.
;; Part two: lit pixels after 12 steps.
;;
;; The nine-bit index is built by doubling and adding -- `idx*2 + bit` -- which is F-035's
;; narrowing (C-092) in its simplest form: a SHIFT is arithmetic and needs no bit operation. The
;; puzzle never needs and, or, xor or not, so the missing half of F-035 never comes up. day04 and
;; day07 are the two that do.
;;
;; The grid grows by one ring per step, so this is also the largest thing rebuilt in the suite:
;; 54 x 54 strings at the end, built a character at a time by `concat`.
;;
;; The puzzle and its input are ours (aoc/input/day20-enhance.txt); Advent of Code's own texts
;; and inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day20-enhance.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day20-enhance.wat

(:wat::load-file! "lib/check.wat")

;; the image, and what the infinity around it currently is
(:wat::core::defrecord :aoc::Img [rows <- :aoc::Lines  bg <- :wat::core::String])

(:wat::core::defn :aoc::px [im <- :aoc::Img h <- :wat::core::i64 w <- :wat::core::i64
                            r <- :wat::core::i64 c <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::or (:wat::core::< r 0)
                    (:wat::core::or (:wat::core::< c 0)
                      (:wat::core::or (:wat::core::>= r h) (:wat::core::>= c w))))
    (:aoc::Img/bg im)
    (:wat::string::subs (:wat::core::nth (:aoc::Img/rows im) r) c (:wat::core::+ c 1))))

;; the nine-bit index: doubling is a shift, and a shift is arithmetic (C-092)
(:wat::core::defn :aoc::index-at [im <- :aoc::Img h <- :wat::core::i64 w <- :wat::core::i64
                                  r <- :wat::core::i64 c <- :wat::core::i64
                                  k <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= k 9) acc
    (:wat::core::let [dr (:wat::core::- (:wat::core::/ k 3) 1)
                      dc (:wat::core::- (:wat::core::rem k 3) 1)
                      lit (:wat::core::= (:aoc::px im h w (:wat::core::+ r dr) (:wat::core::+ c dc)) "#")]
      (:aoc::index-at im h w r c (:wat::core::+ k 1)
        (:wat::core::+ (:wat::core::* acc 2) (:wat::core::if lit 1 0))))))

(:wat::core::defn :aoc::new-row [alg <- :wat::core::String im <- :aoc::Img h <- :wat::core::i64
                                 w <- :wat::core::i64 r <- :wat::core::i64 c <- :wat::core::i64
                                 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::> c w) acc
    (:wat::core::let [i (:aoc::index-at im h w r c 0 0)]
      (:aoc::new-row alg im h w r (:wat::core::+ c 1)
        (:wat::string::concat acc (:wat::string::subs alg i (:wat::core::+ i 1)))))))

(:wat::core::defn :aoc::new-rows [alg <- :wat::core::String im <- :aoc::Img h <- :wat::core::i64
                                  w <- :wat::core::i64 r <- :wat::core::i64 acc <- :aoc::Lines] -> :aoc::Lines
  (:wat::core::if (:wat::core::> r h) acc
    (:aoc::new-rows alg im h w (:wat::core::+ r 1)
      (:wat::core::conj acc (:aoc::new-row alg im h w r -1 "")))))

(:wat::core::defn :aoc::step [alg <- :wat::core::String im <- :aoc::Img] -> :aoc::Img
  (:wat::core::let [h (:wat::core::length (:aoc::Img/rows im))
                    w (:wat::string::length (:wat::core::nth (:aoc::Img/rows im) 0))
                    ;; the infinity is all-dark or all-lit, so it maps through entry 0 or 511
                    i (:wat::core::if (:wat::core::= (:aoc::Img/bg im) ".") 0 511)]
    (:aoc::Img :rows (:aoc::new-rows alg im h w -1 (:wat::core::Vector :- [:wat::core::String]))
               :bg (:wat::string::subs alg i (:wat::core::+ i 1)))))

(:wat::core::defn :aoc::steps [alg <- :wat::core::String im <- :aoc::Img n <- :wat::core::i64] -> :aoc::Img
  (:wat::core::if (:wat::core::= n 0) im (:aoc::steps alg (:aoc::step alg im) (:wat::core::- n 1))))

(:wat::core::defn :aoc::lit-in [s <- :wat::core::String i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::string::length s)) acc
    (:aoc::lit-in s (:wat::core::+ i 1)
      (:wat::core::if (:wat::core::= (:wat::string::subs s i (:wat::core::+ i 1)) "#")
        (:wat::core::+ acc 1) acc))))

(:wat::core::defn :aoc::lit [im <- :aoc::Img i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length (:aoc::Img/rows im))) acc
    (:aoc::lit im (:wat::core::+ i 1)
      (:wat::core::+ acc (:aoc::lit-in (:wat::core::nth (:aoc::Img/rows im) i) 0 0)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [blocks (:wat::string::split
              (:wat::string::trim (:wat::io::read-file "aoc/input/day20-enhance.txt")) "\n\n")
     alg (:wat::string::trim (:wat::core::nth blocks 0))
     start (:aoc::Img :rows (:aoc::non-empty (:wat::string::split (:wat::core::nth blocks 1) "\n")) :bg ".")
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day20-enhance.expected"
                         "aoc day20 enhance"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::lit (:aoc::steps alg start 2) 0 0))
                           (int (:aoc::lit (:aoc::steps alg start 12) 0 0))))))
