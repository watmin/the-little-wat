;; Advent of Code's validation shape, in wat: records of `key:value` fields, checked.
;;
;; Records are separated by blank lines; a record's fields are separated by spaces or newlines.
;; Seven fields are required (byr iyr eyr hgt hcl ecl pid) and one is optional (cid).
;;
;; Part one: how many records have every required field.
;; Part two: how many of those also have valid VALUES.
;;
;; **This is the puzzle F-061 is about.** Every rule here is one line of a regular expression in
;; any language that has them -- `^\d{4}$`, `^#[0-9a-f]{6}$`, `^\d{9}$`, `^(\d+)(cm|in)$` -- and
;; wat's whole regex surface is `matches?`, which answers a bool and cannot report what it
;; matched. So each rule is written out:
;;
;;   * "four digits" is a length check and a loop over `subs` (F-062: a String has no elements);
;;   * "six hex digits" is the same loop against a six-character alphabet held in a string
;;     literal, because there is no character class and no `index-of`;
;;   * "a number then cm or in" is `ends-with?`, a `subs` to cut the unit off, and the digit loop
;;     again -- where the reference says one group and one alternation.
;;
;; None of it is hard; all of it is longer than it should be, and the length is the finding. The
;; Clojure reference is 60 lines and this is 150 for the same seven rules.
;;
;; The puzzle and its input are ours (aoc/input/day19-passports.txt); Advent of Code's own texts
;; and inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day19-passports.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day19-passports.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Rec (:wat::core::HashMap :- [:wat::core::String :wat::core::String]))

(:wat::core::defn :aoc::field [r <- :aoc::Rec k <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:wat::hashmap::get r k)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} ""]))

(:wat::core::defn :aoc::has? [r <- :aoc::Rec k <- :wat::core::String] -> :wat::core::bool
  (:wat::hashmap::contains-key? r k))

;; ---- the character tests a regex would have made unnecessary
(:wat::core::defn :aoc::all-in? [s <- :wat::core::String alphabet <- :wat::core::String
                                 i <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::>= i (:wat::string::length s)) true)
    ((:wat::core::not (:wat::string::contains? alphabet
                        (:wat::string::subs s i (:wat::core::+ i 1)))) false)
    (:else (:aoc::all-in? s alphabet (:wat::core::+ i 1)))))

(:wat::core::defn :aoc::digits? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::and (:wat::core::> (:wat::string::length s) 0) (:aoc::all-in? s "0123456789" 0)))

(:wat::core::defn :aoc::digits-n? [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::and (:wat::core::= (:wat::string::length s) n) (:aoc::digits? s)))

(:wat::core::defn :aoc::year-in? [s <- :wat::core::String lo <- :wat::core::i64 hi <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::and (:aoc::digits-n? s 4)
    (:wat::core::let [n (:aoc::to-int s)]
      (:wat::core::and (:wat::core::>= n lo) (:wat::core::<= n hi)))))

(:wat::core::defn :aoc::unit-value [s <- :wat::core::String] -> :wat::core::String
  (:wat::string::subs s 0 (:wat::core::- (:wat::string::length s) 2)))

(:wat::core::defn :aoc::height-ok? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::string::ends-with? s "cm")
      (:wat::core::and (:aoc::digits? (:aoc::unit-value s))
        (:wat::core::let [n (:aoc::to-int (:aoc::unit-value s))]
          (:wat::core::and (:wat::core::>= n 150) (:wat::core::<= n 193)))))
    ((:wat::string::ends-with? s "in")
      (:wat::core::and (:aoc::digits? (:aoc::unit-value s))
        (:wat::core::let [n (:aoc::to-int (:aoc::unit-value s))]
          (:wat::core::and (:wat::core::>= n 59) (:wat::core::<= n 76)))))
    (:else false)))

(:wat::core::defn :aoc::hair-ok? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::and (:wat::core::= (:wat::string::length s) 7)
    (:wat::core::and (:wat::string::starts-with? s "#")
      (:aoc::all-in? (:wat::string::subs s 1 7) "0123456789abcdef" 0))))

(:wat::core::defn :aoc::eye-ok? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= s "amb")
    (:wat::core::or (:wat::core::= s "blu")
      (:wat::core::or (:wat::core::= s "brn")
        (:wat::core::or (:wat::core::= s "gry")
          (:wat::core::or (:wat::core::= s "grn")
            (:wat::core::or (:wat::core::= s "hzl") (:wat::core::= s "oth"))))))))

(:wat::core::defn :aoc::complete? [r <- :aoc::Rec] -> :wat::core::bool
  (:wat::core::and (:aoc::has? r "byr")
    (:wat::core::and (:aoc::has? r "iyr")
      (:wat::core::and (:aoc::has? r "eyr")
        (:wat::core::and (:aoc::has? r "hgt")
          (:wat::core::and (:aoc::has? r "hcl")
            (:wat::core::and (:aoc::has? r "ecl") (:aoc::has? r "pid"))))))))

(:wat::core::defn :aoc::valid? [r <- :aoc::Rec] -> :wat::core::bool
  (:wat::core::and (:aoc::complete? r)
    (:wat::core::and (:aoc::year-in? (:aoc::field r "byr") 1920 2002)
      (:wat::core::and (:aoc::year-in? (:aoc::field r "iyr") 2010 2020)
        (:wat::core::and (:aoc::year-in? (:aoc::field r "eyr") 2020 2030)
          (:wat::core::and (:aoc::height-ok? (:aoc::field r "hgt"))
            (:wat::core::and (:aoc::hair-ok? (:aoc::field r "hcl"))
              (:wat::core::and (:aoc::eye-ok? (:aoc::field r "ecl"))
                               (:aoc::digits-n? (:aoc::field r "pid") 9)))))))))

;; ---- parsing: a record is whitespace-separated `key:value`, across however many lines
(:wat::core::defn :aoc::add-field [r <- :aoc::Rec tok <- :wat::core::String] -> :aoc::Rec
  (:wat::core::let [parts (:wat::string::split tok ":")]
    (:wat::core::if (:wat::core::< (:wat::core::length parts) 2) r
      (:wat::hashmap::assoc r (:wat::core::nth parts 0) (:wat::core::nth parts 1)))))

(:wat::core::defn :aoc::parse-rec [toks <- :aoc::Lines i <- :wat::core::i64 acc <- :aoc::Rec] -> :aoc::Rec
  (:wat::core::if (:wat::core::>= i (:wat::core::length toks)) acc
    (:aoc::parse-rec toks (:wat::core::+ i 1) (:aoc::add-field acc (:wat::core::nth toks i)))))

(:wat::core::defn :aoc::record-of [block <- :wat::core::String] -> :aoc::Rec
  (:aoc::parse-rec
    (:aoc::non-empty (:wat::string::split
      (:wat::string::join " " (:aoc::non-empty (:wat::string::split block "\n"))) " "))
    0 (:wat::core::HashMap :- [:wat::core::String :wat::core::String])))

(:wat::core::defn :aoc::tally [bs <- :aoc::Lines i <- :wat::core::i64 strict? <- :wat::core::bool
                               acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length bs)) acc
    (:wat::core::let [r (:aoc::record-of (:wat::core::nth bs i))
                      ok (:wat::core::if strict? (:aoc::valid? r) (:aoc::complete? r))]
      (:aoc::tally bs (:wat::core::+ i 1) strict? (:wat::core::if ok (:wat::core::+ acc 1) acc)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [blocks (:wat::string::split
              (:wat::string::trim (:wat::io::read-file "aoc/input/day19-passports.txt")) "\n\n")
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day19-passports.expected"
                         "aoc day19 passports"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::tally blocks 0 false 0))
                           (int (:aoc::tally blocks 0 true 0))))))
