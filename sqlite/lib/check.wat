;; sqlite/lib/check.wat: compare a case's results with the sqlite3 CLI's.
;; The oracle (oracle/sqlite/NAME.sql, run by tools/sqlite-oracle.sh) prints each result on its
;; own line; the wat case prints the same results its own way, and every string must be
;; sqlite3's, in order.

(:wat::core::typealias :sq::Lines (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defn :sq::non-empty [xs <- :sq::Lines] -> :sq::Lines
  (:wat::core::filterv (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool (:wat::core::not (:wat::core::= s ""))) xs))

(:wat::core::defn :sq::compare [got <- :sq::Lines want <- :sq::Lines i <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? got)
    nil
    (:wat::core::do
      (:wat::core::if (:wat::core::= (:wat::core::first got) (:wat::core::first want))
        nil
        (:wat::kernel::assertion-failed! :message (:wat::string::concat "result " (:wat::i64::to-string i) ": wat printed "
                                                                       (:wat::core::first got) ", sqlite3 printed " (:wat::core::first want))))
      (:sq::compare (:wat::core::rest got) (:wat::core::rest want) (:wat::core::+ i 1)))))

;; Every result, in order, must be the sqlite3 CLI's.
(:wat::core::defn :sq::check-results [expected <- :wat::core::String label <- :wat::core::String got <- :sq::Lines] -> :wat::core::nil
  (:wat::core::let [want (:sq::non-empty (:wat::string::split (:wat::io::read-file expected) "\n"))]
    (:wat::core::do
      (:wat::test::assert-eq (:wat::core::length got) (:wat::core::length want))
      (:sq::compare got want 0)
      (:wat::kernel::println (:wat::string::concat label ": ok (" (:wat::i64::to-string (:wat::core::length got)) " results match sqlite3)")))))
