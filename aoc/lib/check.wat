;; aoc/lib/check.wat: compare a puzzle's answers with the reference implementation's.
;; The oracle (oracle/aoc/NAME.clj, run by tools/aoc-oracle.sh) prints each answer on its own
;; line; the wat solution prints the same answers, and every string must be Clojure's, in order.

(:wat::core::typealias :aoc::Lines (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defn :aoc::non-empty [xs <- :aoc::Lines] -> :aoc::Lines
  (:wat::core::filterv (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool (:wat::core::not (:wat::core::= s ""))) xs))

(:wat::core::defn :aoc::compare [got <- :aoc::Lines want <- :aoc::Lines i <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? got)
    nil
    (:wat::core::do
      (:wat::core::if (:wat::core::= (:wat::core::first got) (:wat::core::first want))
        nil
        (:wat::kernel::assertion-failed! :message (:wat::string::concat "answer " (:wat::i64::to-string i) ": wat printed "
                                                                       (:wat::core::first got) ", Clojure printed " (:wat::core::first want))))
      (:aoc::compare (:wat::core::rest got) (:wat::core::rest want) (:wat::core::+ i 1)))))

;; Every answer, in order, must be the reference implementation's.
(:wat::core::defn :aoc::check-answers [expected <- :wat::core::String label <- :wat::core::String got <- :aoc::Lines] -> :wat::core::nil
  (:wat::core::let [want (:aoc::non-empty (:wat::string::split (:wat::io::read-file expected) "\n"))]
    (:wat::core::do
      (:wat::test::assert-eq (:wat::core::length got) (:wat::core::length want))
      (:aoc::compare got want 0)
      (:wat::kernel::println (:wat::string::concat label ": ok (" (:wat::i64::to-string (:wat::core::length got)) " answers match Clojure)")))))

;; ---- reading a puzzle's input

(:wat::core::defn :aoc::lines [path <- :wat::core::String] -> :aoc::Lines
  (:aoc::non-empty (:wat::string::split (:wat::io::read-file path) "\n")))

(:wat::core::defn :aoc::to-int [s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::string::to-i64 s)
    [:wat::core::Option.Some {:value n} n]
    [:wat::core::Option.None {} (:wat::kernel::assertion-failed! :message (:wat::string::concat "not a number: " s))]))

(:wat::core::defn :aoc::ints [path <- :wat::core::String] -> (:wat::core::Vector :- [:wat::core::i64])
  (:wat::core::mapv :aoc::to-int (:aoc::lines path)))
