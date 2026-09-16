;; rete/lib/check.wat: compare a rules case's results with clara's.
;; The oracle (oracle/rete/NAME.clj, run by tools/rete-oracle.sh) prints each result on its own
;; line; the wat case prints the same results its own way, and every string must be clara's, in
;; order.

(:wat::core::typealias :rete::Lines (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defn :rete::non-empty [xs <- :rete::Lines] -> :rete::Lines
  (:wat::core::filterv (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool (:wat::core::not (:wat::core::= s ""))) xs))

(:wat::core::defn :rete::compare [got <- :rete::Lines want <- :rete::Lines i <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? got)
    nil
    (:wat::core::do
      (:wat::core::if (:wat::core::= (:wat::core::first got) (:wat::core::first want))
        nil
        (:wat::kernel::assertion-failed! :message (:wat::string::concat "result " (:wat::i64::to-string i) ": wat printed "
                                                                       (:wat::core::first got) ", clara printed " (:wat::core::first want))))
      (:rete::compare (:wat::core::rest got) (:wat::core::rest want) (:wat::core::+ i 1)))))

;; Every result, in order, must be clara's.
(:wat::core::defn :rete::check-results [expected <- :wat::core::String label <- :wat::core::String got <- :rete::Lines] -> :wat::core::nil
  (:wat::core::let [want (:rete::non-empty (:wat::string::split (:wat::io::read-file expected) "\n"))]
    (:wat::core::do
      (:wat::test::assert-eq (:wat::core::length got) (:wat::core::length want))
      (:rete::compare got want 0)
      (:wat::kernel::println (:wat::string::concat label ": ok (" (:wat::i64::to-string (:wat::core::length got)) " results match clara)")))))

;; A derived fact set is compared as a sorted list of strings, since neither engine promises an
;; order for what it derived.
(:wat::core::defn :rete::sorted-join [xs <- :rete::Lines] -> :wat::core::String
  (:wat::string::join "|" (:wat::core::sort xs)))
