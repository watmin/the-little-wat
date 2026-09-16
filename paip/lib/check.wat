;; paip/lib/check.wat: compare a chapter's printed results with guile's.
;; The oracle (oracle/paip/NAME.scm, run by tools/paip-oracle.sh) prints each result on its own
;; line; the chapter prints the same values its own way, and every string must be guile's, in
;; order.

(:wat::core::typealias :paip::Lines (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defn :paip::non-empty [xs <- :paip::Lines] -> :paip::Lines
  (:wat::core::filterv (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool (:wat::core::not (:wat::core::= s ""))) xs))

(:wat::core::defn :paip::compare [got <- :paip::Lines want <- :paip::Lines i <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? got)
    nil
    (:wat::core::do
      (:wat::core::if (:wat::core::= (:wat::core::first got) (:wat::core::first want))
        nil
        (:wat::kernel::assertion-failed! :message (:wat::string::concat "result " (:wat::i64::to-string i) ": wat printed "
                                                                       (:wat::core::first got) ", guile printed " (:wat::core::first want))))
      (:paip::compare (:wat::core::rest got) (:wat::core::rest want) (:wat::core::+ i 1)))))

;; Every printed result, in order, must be guile's.
(:wat::core::defn :paip::check-chapter [expected <- :wat::core::String label <- :wat::core::String got <- :paip::Lines] -> :wat::core::nil
  (:wat::core::let [want (:paip::non-empty (:wat::string::split (:wat::io::read-file expected) "\n"))]
    (:wat::core::do
      (:wat::test::assert-eq (:wat::core::length got) (:wat::core::length want))
      (:paip::compare got want 0)
      (:wat::kernel::println (:wat::string::concat label ": ok (" (:wat::i64::to-string (:wat::core::length got)) " results match guile)")))))
