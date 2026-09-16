;; probes/telemetry/time-sk-orders.wat: does the journal's sort key really sort chronologically?
;;
;; wat/telemetry/journal.wat turns a timestamp into the store's sort key, and states the property
;; the whole read path depends on:
;;
;;   sk = #inst "<iso8601 with 9 fixed fractional digits, Z>" -- CONSTANT WIDTH, so it sorts
;;   lexicographically = chronologically (the store's `sort-by Row/sk` is the range order).
;;
;; That is load-bearing rather than decorative: wat/query/mem.wat:58-59 filters a scan range with
;; (:wat::core::>= (StoredRow/sk row) lo) and (<= ... hi) -- plain STRING comparison. If the key
;; were not constant width, a keyset scan would silently return the wrong window and paginate
;; past records, with no error anywhere.
;;
;; The usual way this breaks is an unpadded number, so the cases below are chosen to break it:
;; both i64 extremes, the epoch, either side of the epoch (a NEGATIVE instant, where an unpadded
;; or sign-prefixed rendering would invert), and a sub-second boundary.
;;
;; The reachable range is narrower than it looks -- i64 nanos spans 1677-09-21 to 2262-04-11 --
;; so a five-digit year cannot occur, which is the other classic width break.
;;
;; Expected: every line PASS, and one WIDTH line reporting a single distinct length.
;;
;; Run: wat probes/telemetry/time-sk-orders.wat

(:wat::core::typealias :ts::Ns (:wat::core::Vector :- [:wat::core::i64]))

;; ascending, and deliberately including both signs and both i64 extremes
(:wat::core::defn :ts::cases [] -> :ts::Ns
  (:wat::core::Vector :- [:wat::core::i64]
    -9223372036854775808      ;; i64 MIN -> 1677-09-21
    -1757000000000000000      ;; 1914
    -1000000000               ;; one second BEFORE the epoch
    -1                        ;; one nanosecond before the epoch
    0                         ;; the epoch
    1
    999999999                 ;; the last nanosecond of second 0
    1000000000                ;; second 1
    1500000000000000000       ;; 2017
    1757000000000000000       ;; 2025
    9223372036854775807))     ;; i64 MAX -> 2262-04-11

(:wat::core::defn :ts::sk [n <- :wat::core::i64] -> :wat::core::String
  (:wat::telemetry::time-sk n))

(:wat::core::defn :ts::say [s <- :wat::core::String] -> :wat::core::nil (:wat::kernel::println s))

;; WIDTH -- every key the same length, or the lexicographic claim is void.
(:wat::core::defn :ts::widths [] -> :wat::core::nil
  (:wat::core::let
    [ns (:ts::cases)
     w0 (:wat::string::length (:ts::sk (:wat::core::first ns)))
     bad (:wat::core::foldl
           (:wat::core::fn [a <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
             (:wat::core::if (:wat::core::= (:wat::string::length (:ts::sk n)) w0) a (:wat::core::+ a 1)))
           0 ns)]
    (:ts::say (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
      (:wat::core::if (:wat::core::= bad 0) "PASS  WIDTH constant at " "FAIL  WIDTH varies from ")
      (:wat::i64::to-string w0)
      " chars; off-width keys: "
      (:wat::i64::to-string bad))))))

;; ORDER -- for every adjacent pair a < b, the keys must compare the same way AS STRINGS.
(:wat::core::defn :ts::pair [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let [ka (:ts::sk a)
                    kb (:ts::sk b)
                    ok (:wat::core::< ka kb)]
    (:ts::say (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
      (:wat::core::if ok "PASS  " "FAIL  ")
      "ORDER " (:wat::i64::to-string a) " < " (:wat::i64::to-string b)
      "   " ka "  <  " kb)))))

(:wat::core::defn :ts::orders [] -> :wat::core::nil
  (:wat::core::let [ns (:ts::cases)
                    n  (:wat::core::length ns)]
    (:wat::core::do
      (:wat::core::mapv
        (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::nil
          (:ts::pair (:wat::core::nth ns i) (:wat::core::nth ns (:wat::core::+ i 1))))
        (:wat::core::range 0 (:wat::core::- n 1)))
      nil)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do (:ts::widths) (:ts::orders)))
