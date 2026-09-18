;; oracle/aoc/day19-passports.clj: the reference implementation of our nineteenth puzzle, in
;; Advent of Code's shape — records of `key:value` fields, validated.
;;
;; Records are separated by blank lines; a record's fields are separated by spaces or newlines.
;; Seven fields are required (byr iyr eyr hgt hcl ecl pid) and one is optional (cid).
;;
;; Part one: how many records have every required field.
;; Part two: how many of those also have valid VALUES —
;;   byr 1920-2002, iyr 2010-2020, eyr 2020-2030, each four digits;
;;   hgt a number followed by cm (150-193) or in (59-76);
;;   hcl a # and six hex digits; ecl one of seven words; pid exactly nine digits.
;;
;; The puzzle and its input are ours (aoc/input/day19-passports.txt); Advent of Code's own texts
;; and inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def required #{"byr" "iyr" "eyr" "hgt" "hcl" "ecl" "pid"})
(def eye-colours #{"amb" "blu" "brn" "gry" "grn" "hzl" "oth"})

(def records
  (for [block (str/split (str/trim (slurp "aoc/input/day19-passports.txt")) #"\n\n")]
    (into {} (for [tok (str/split (str/trim block) #"\s+")
                   :let [[k v] (str/split tok #":" 2)]]
               [k (or v "")]))))

(defn complete? [r] (every? r required))

(defn digits? [s n] (and (= n (count s)) (every? #(Character/isDigit ^char %) s)))

(defn year-in? [s lo hi]
  (and (digits? s 4) (<= lo (Long/parseLong s) hi)))

(defn height-ok? [s]
  (cond
    (str/ends-with? s "cm") (let [n (subs s 0 (- (count s) 2))]
                              (and (digits? n (count n)) (seq n) (<= 150 (Long/parseLong n) 193)))
    (str/ends-with? s "in") (let [n (subs s 0 (- (count s) 2))]
                              (and (digits? n (count n)) (seq n) (<= 59 (Long/parseLong n) 76)))
    :else false))

(defn hair-ok? [s]
  (and (= 7 (count s)) (= \# (first s))
       (every? #(contains? (set "0123456789abcdef") %) (rest s))))

(defn valid? [r]
  (and (complete? r)
       (year-in? (r "byr") 1920 2002)
       (year-in? (r "iyr") 2010 2020)
       (year-in? (r "eyr") 2020 2030)
       (height-ok? (r "hgt"))
       (hair-ok? (r "hcl"))
       (contains? eye-colours (r "ecl"))
       (digits? (r "pid") 9)))

(println "=>" (count (filter complete? records)))
(println "=>" (count (filter valid? records)))
