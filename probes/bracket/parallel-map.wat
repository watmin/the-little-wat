;; probes/bracket/parallel-map.wat: is :wat::bracket::map really a parallel map, and is it ordered?
;;
;; :wat::bracket:: is "the brackets layer (Ruby's Parallel) built over spawn-program" -- a thread
;; or process pool with `map` and `each` as macros. It is effectively UNDOCUMENTED: the only
;; mention across the four user-facing pages is one incidental line in WAT-CHEATSHEET.md that
;; uses `:wat::bracket::runner-loop :- [I O]` as a SYNTAX SPECIMEN for binders, not as an API.
;; That is the F-088 shape: a whole parallelism layer a user cannot find.
;;
;; Two claims worth testing, and the second is the one that bites:
;;
;;   B1  same answers as a sequential mapv.
;;   B2  IN INPUT ORDER. wat-rs's own fixture is named "brackets_map_doubles_in_order", so the
;;       claim is explicit -- but its work-fn is `(* x 2)`, which takes the same time for every
;;       item, so a pool that returned COMPLETION order would pass it by luck.
;;
;; So B2 here uses an INVERTED workload: item i does work proportional to (n - i), so item 0 is
;; the slowest and the last item finishes first. Completion order would be the exact reverse of
;; input order, which no accident can hide.
;;
;; B3 times it against the sequential mapv over the same inverted workload, which is the claim
;; that makes the layer worth having at all.
;;
;; Run: wat probes/bracket/parallel-map.wat

(:wat::core::typealias :bp::V (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defn :bp::n [] -> :wat::core::i64 16)

;; CPU-bound busywork: sum 0..k, return the sum's low bits so nothing is optimized away.
(:wat::core::defn :bp::burn [k <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::rem
    (:wat::core::foldl
      (:wat::core::fn [a <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a i))
      0 (:wat::core::range 0 k))
    7))

;; ORDERING workload: item i burns (n - i) units, so the LAST item is the cheapest and finishes
;; first. If the pool returned completion order the result would be the exact reverse.
(:wat::core::defn :bp::work [x <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::do
    (:bp::burn (:wat::core::* (:wat::core::- (:bp::n) x) 20000))
    (:wat::core::* x 10)))

;; TIMING workload: every item costs the same, so ideal speedup is the runner count and the
;; measurement is not capped by one straggler the way the inverted workload is.
(:wat::core::defn :bp::even-work [x <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::do
    (:bp::burn 300000)
    (:wat::core::* x 10)))

(:wat::core::defn :bp::items [] -> :bp::V (:wat::core::range 0 (:bp::n)))

(:wat::core::defn :bp::ms-since [t0 <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::rem (:wat::core::/ (:wat::core::- (:wat::time::epoch-nanos (:wat::time::now)) t0) 1000000) 100000000))

(:wat::core::defn :bp::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [items (:bp::items)
     t0  (:wat::time::epoch-nanos (:wat::time::now))
     seq (:wat::core::mapv :bp::work items)
     t1  (:bp::ms-since t0)
     t2  (:wat::time::epoch-nanos (:wat::time::now))
     par (:wat::bracket::map (:wat::spawn::thread) items
           (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:bp::work x)))
     t3  (:bp::ms-since t2)
     ;; balanced, for the speedup number
     t4  (:wat::time::epoch-nanos (:wat::time::now))
     eseq (:wat::core::mapv :bp::even-work items)
     t5  (:bp::ms-since t4)
     t6  (:wat::time::epoch-nanos (:wat::time::now))
     epar (:wat::bracket::map (:wat::spawn::thread) items
            (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:bp::even-work x)))
     t7  (:bp::ms-since t6)]
    (:wat::core::do
      (:bp::say "runner-count           " (:wat::i64::to-string (:wat::spawn::runner-count (:wat::spawn::thread))))
      (:bp::say "sequential mapv        " (:wat::edn::write seq))
      (:bp::say "bracket::map           " (:wat::edn::write par))
      (:bp::say "B1+B2 identical & ordered"
        (:wat::core::if (:wat::core::= seq par) "PASS" "FAIL"))
      (:bp::say "inverted  seq ms       " (:wat::i64::to-string t1))
      (:bp::say "inverted  par ms       " (:wat::i64::to-string t3))
      (:bp::say "balanced  identical    " (:wat::core::if (:wat::core::= eseq epar) "PASS" "FAIL"))
      (:bp::say "balanced  seq ms       " (:wat::i64::to-string t5))
      (:bp::say "balanced  par ms       " (:wat::i64::to-string t7)))))
