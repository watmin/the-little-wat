;; books/little-java/lib/check.wat: compare a chapter's printed results with Java's.
;; The oracle (oracle/java/NAME.java, compiled and run by tools/java-oracle.sh) prints each
;; result as an S-expression, one per line; the chapter prints the same values its own way,
;; and every string must be Java's, in order.

(:wat::core::typealias :lj::Lines (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defn :lj::non-empty [xs <- :lj::Lines] -> :lj::Lines
  (:wat::core::filterv (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool (:wat::core::not (:wat::core::= s ""))) xs))

(:wat::core::defn :lj::compare [got <- :lj::Lines want <- :lj::Lines i <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? got)
    nil
    (:wat::core::do
      (:wat::core::if (:wat::core::= (:wat::core::first got) (:wat::core::first want))
        nil
        (:wat::kernel::assertion-failed! :message (:wat::string::concat "result " (:wat::i64::to-string i) ": wat printed "
                                                                       (:wat::core::first got) ", Java printed " (:wat::core::first want))))
      (:lj::compare (:wat::core::rest got) (:wat::core::rest want) (:wat::core::+ i 1)))))

;; Every printed result, in order, must be Java's.
(:wat::core::defn :lj::check-chapter [expected <- :wat::core::String label <- :wat::core::String got <- :lj::Lines] -> :wat::core::nil
  (:wat::core::let [want (:lj::non-empty (:wat::string::split (:wat::io::read-file expected) "\n"))]
    (:wat::core::do
      (:wat::test::assert-eq (:wat::core::length got) (:wat::core::length want))
      (:lj::compare got want 0)
      (:wat::kernel::println (:wat::string::concat label ": ok (" (:wat::i64::to-string (:wat::core::length got)) " results match Java)")))))
