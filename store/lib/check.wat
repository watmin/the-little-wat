;; store/lib/check.wat: compare what two Store backends answered.
;;
;; This suite has no external oracle. wat ships TWO services that satisfy one contract —
;; :wat::query::mem-store and :wat::query::sqlite-store — and wat/query/mem.wat says the
;; in-memory one is "dual-purpose … a genuine in-memory backend AND the oracle sqlite will be
;; differential-tested against". So the two backends check each other: the same operations are
;; driven through the same `:wat::query::Store` surface, and every line one produces must be the
;; other's.
;;
;; Where they are MEANT to differ, they are not compared. mem-store's ensure-schema is a
;; deliberate no-op ("no physical schema to establish") while sqlite-store's is where CREATE
;; TABLE happens; reporting that as a divergence would be a mistake about the contract, not a
;; finding about wat.

(:wat::core::typealias :st::Lines (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defn :st::non-empty [xs <- :st::Lines] -> :st::Lines
  (:wat::core::filterv (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool (:wat::core::not (:wat::core::= s ""))) xs))

;; every line the two backends produced, compared in order
(:wat::core::defn :st::compare [a <- :st::Lines b <- :st::Lines i <- :wat::core::i64
                                a-name <- :wat::core::String b-name <- :wat::core::String] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? a)
    nil
    (:wat::core::do
      (:wat::core::if (:wat::core::= (:wat::core::first a) (:wat::core::first b))
        nil
        (:wat::kernel::assertion-failed! :message
          (:wat::string::concat "result " (:wat::i64::to-string i) ": " a-name " answered "
                                (:wat::core::first a) ", " b-name " answered " (:wat::core::first b))))
      (:st::compare (:wat::core::rest a) (:wat::core::rest b) (:wat::core::+ i 1) a-name b-name))))

;; the two backends must agree, line for line.
(:wat::core::defn :st::check-agree [label <- :wat::core::String
                                    a-name <- :wat::core::String a <- :st::Lines
                                    b-name <- :wat::core::String b <- :st::Lines] -> :wat::core::nil
  (:wat::core::let [as (:st::non-empty a)
                    bs (:st::non-empty b)]
    (:wat::core::do
      (:wat::test::assert-eq (:wat::core::length as) (:wat::core::length bs))
      (:st::compare as bs 0 a-name b-name)
      (:wat::kernel::println
        (:wat::string::concat label ": ok (" (:wat::i64::to-string (:wat::core::length as))
                              " results, " a-name " = " b-name ")")))))
