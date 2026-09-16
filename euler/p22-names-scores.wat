;; Project Euler, names scores: sort the names, and score each by its letters and its position.
;;
;; Each name's value is the sum of its letters' alphabetical values (A=1 … Z=26); its score is
;; that value times its 1-based position in the sorted list; the answer is the total. Project
;; Euler's problem statement is not reproduced — that sentence is the problem in our own words —
;; and neither is its names.txt, which is not redistributable. The names in
;; euler/input/p22-names.txt are ours, generated deterministically, in the same shape: quoted,
;; comma-separated, unsorted on disk.
;;
;; This problem is here because it is made of the two things wat is worst at, and both show:
;;
;;   PARSING. The file is "NAME","NAME",… and there is no way to ask a regex what it matched —
;;   :wat::regex::matches? answers a bool and :wat::regex::find does not exist (F-061). So the
;;   names come out by trimming the trailing newline, splitting on "," and stripping the quotes
;;   off each piece with subs. That is the workaround F-061 predicts, written out.
;;
;;   LETTERS. A String has no characters (F-062): no chars, no index-of, no char->int, and
;;   :wat::core::reverse and (split s "") both refuse. Every letter is a one-character subs, at
;;   about 16.7 µs a call. Finding a letter's VALUE naively means scanning the alphabet with
;;   more subs calls — 26 per letter, some 700000 of them over this file. That is the trap. A
;;   PersistentMap from letter to value, built once, makes it a lookup instead (F-057's lesson:
;;   the sharing container is also the fast one), and is what the alphabet table below is.
;;
;; The answers must be the reference implementation's (oracle/euler/p22-names-scores.clj, run by
;; tools/euler-oracle.sh).
;;
;; Run from the repository root (it reads both files by path):
;;   wat euler/p22-names-scores.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :euler::Names (:wat::core::Vector :- [:wat::core::String]))
(:wat::core::typealias :euler::Values (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64]))

;; ---- the alphabet, as a map rather than a scan

(:wat::core::defn :euler::alphabet [] -> :wat::core::String "ABCDEFGHIJKLMNOPQRSTUVWXYZ")

(:wat::core::defn :euler::letter-values-from [i <- :wat::core::i64 acc <- :euler::Values] -> :euler::Values
  (:wat::core::if (:wat::core::>= i 26)
    acc
    (:euler::letter-values-from (:wat::core::+ i 1)
      (:wat::map::assoc acc (:wat::string::subs (:euler::alphabet) i (:wat::core::+ i 1)) (:wat::core::+ i 1)))))

(:wat::core::defn :euler::letter-values [] -> :euler::Values
  (:euler::letter-values-from 0 (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64])))

(:wat::core::defn :euler::letter-value [vs <- :euler::Values c <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::map::get vs c)
    [:wat::core::Option.Some {:value n} n]
    [:wat::core::Option.None {} (:wat::kernel::assertion-failed! :message (:wat::string::concat "not a letter: " c))]))

;; ---- a name's value: one subs per letter, because that is the only way to see one

(:wat::core::defn :euler::name-value-from [vs <- :euler::Values s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:euler::name-value-from vs s (:wat::core::+ i 1) n
      (:wat::core::+ acc (:euler::letter-value vs (:wat::string::subs s i (:wat::core::+ i 1)))))))

(:wat::core::defn :euler::name-value [vs <- :euler::Values s <- :wat::core::String] -> :wat::core::i64
  (:euler::name-value-from vs s 0 (:wat::string::length s) 0))

;; ---- parsing, without a regex that can report what it matched (F-061)

;; "BAITOORIA" -> BAITOORIA
(:wat::core::defn :euler::unquote [s <- :wat::core::String] -> :wat::core::String
  (:wat::core::let [n (:wat::string::length s)]
    (:wat::core::if (:wat::core::< n 2)
      s
      (:wat::string::subs s 1 (:wat::core::- n 1)))))

(:wat::core::defn :euler::names [path <- :wat::core::String] -> :euler::Names
  (:wat::core::mapv :euler::unquote
    (:wat::string::split (:wat::string::trim (:wat::io::read-file path)) ",")))

;; ---- scoring

(:wat::core::defn :euler::total-from [vs <- :euler::Values ns <- :euler::Names i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:euler::total-from vs ns (:wat::core::+ i 1) n
      (:wat::core::+ acc (:wat::core::* (:wat::core::+ i 1) (:euler::name-value vs (:wat::core::nth ns i)))))))

(:wat::core::defn :euler::min-value [vs <- :euler::Values ns <- :euler::Names i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:wat::core::let [v (:euler::name-value vs (:wat::core::nth ns i))]
      (:euler::min-value vs ns (:wat::core::+ i 1) n (:wat::core::if (:wat::core::< v acc) v acc)))))

(:wat::core::defn :euler::max-value [vs <- :euler::Values ns <- :euler::Names i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:wat::core::let [v (:euler::name-value vs (:wat::core::nth ns i))]
      (:euler::max-value vs ns (:wat::core::+ i 1) n (:wat::core::if (:wat::core::> v acc) v acc)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [vs     (:euler::letter-values)
                    raw    (:euler::names "euler/input/p22-names.txt")
                    sorted (:wat::core::sort raw)
                    n      (:wat::core::length sorted)
                    int    (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:euler::check-answers "oracle/euler/p22-names-scores.expected"
                           "euler p22 names scores"
                           (:wat::core::Vector :- [:wat::core::String]
                             ;; the count first, so a misparse says so immediately
                             (int (:wat::core::length raw))
                             ;; the sort, at both ends
                             (:wat::core::first sorted)
                             (:wat::core::nth sorted (:wat::core::- n 1))
                             ;; one known name, then the extremes
                             (int (:euler::name-value vs "COLIN"))
                             (int (:euler::min-value vs sorted 0 n 999))
                             (int (:euler::max-value vs sorted 0 n 0))
                             ;; the first two scores, then the answer
                             (int (:wat::core::* 1 (:euler::name-value vs (:wat::core::nth sorted 0))))
                             (int (:wat::core::* 2 (:euler::name-value vs (:wat::core::nth sorted 1))))
                             (int (:euler::total-from vs sorted 0 n 0))))))
