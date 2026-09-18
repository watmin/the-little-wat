;; oracle/aoc/day16-assembly.clj: the reference implementation of our sixteenth puzzle, in Advent
;; of Code's shape — a four-register machine, read from text.
;;
;; Four instructions. `cpy x y` copies a register or a literal into a register; `inc r` and
;; `dec r` change one by one; `jnz x y` jumps y instructions when x is not zero, and falls
;; through otherwise. Registers a, b, c and d start at zero.
;;
;; Part one: the value left in register a.
;; Part two: the same, with register c starting at 1 instead.
;;
;; The puzzle and its input are ours (aoc/input/day16-assembly.txt); Advent of Code's own texts
;; and inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def program
  (->> (slurp "aoc/input/day16-assembly.txt") str/split-lines (remove str/blank?)
       (mapv #(str/split % #"\s+"))))

(defn reg? [s] (contains? #{"a" "b" "c" "d"} s))

(defn run [c0]
  (loop [ip 0 regs {"a" 0 "b" 0 "c" c0 "d" 0}]
    (if (or (< ip 0) (>= ip (count program)))
      (regs "a")
      (let [[op x y] (program ip)
            v (fn [s] (if (reg? s) (regs s) (Long/parseLong s)))]
        (case op
          "cpy" (recur (inc ip) (assoc regs y (v x)))
          "inc" (recur (inc ip) (update regs x inc))
          "dec" (recur (inc ip) (update regs x dec))
          "jnz" (recur (if (zero? (v x)) (inc ip) (+ ip (v y))) regs))))))

(println "=>" (run 0))
(println "=>" (run 1))
