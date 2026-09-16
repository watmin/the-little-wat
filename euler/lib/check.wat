;; euler/lib/check.wat: compare a problem's answers with the reference implementation's.
;; The oracle (oracle/euler/NAME.clj, run by tools/euler-oracle.sh) prints each answer on its own
;; line; the wat solution prints the same answers, and every string must be Clojure's, in order.

(:wat::core::typealias :euler::Lines (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defn :euler::non-empty [xs <- :euler::Lines] -> :euler::Lines
  (:wat::core::filterv (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool (:wat::core::not (:wat::core::= s ""))) xs))

(:wat::core::defn :euler::compare [got <- :euler::Lines want <- :euler::Lines i <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? got)
    nil
    (:wat::core::do
      (:wat::core::if (:wat::core::= (:wat::core::first got) (:wat::core::first want))
        nil
        (:wat::kernel::assertion-failed! :message (:wat::string::concat "answer " (:wat::i64::to-string i) ": wat printed "
                                                                       (:wat::core::first got) ", Clojure printed " (:wat::core::first want))))
      (:euler::compare (:wat::core::rest got) (:wat::core::rest want) (:wat::core::+ i 1)))))

;; Every answer, in order, must be the reference implementation's.
(:wat::core::defn :euler::check-answers [expected <- :wat::core::String label <- :wat::core::String got <- :euler::Lines] -> :wat::core::nil
  (:wat::core::let [want (:euler::non-empty (:wat::string::split (:wat::io::read-file expected) "\n"))]
    (:wat::core::do
      (:wat::test::assert-eq (:wat::core::length got) (:wat::core::length want))
      (:euler::compare got want 0)
      (:wat::kernel::println (:wat::string::concat label ": ok (" (:wat::i64::to-string (:wat::core::length got)) " answers match Clojure)")))))
