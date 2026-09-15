;; A Little Java, A Few Patterns, chapter 6 (Boring Protocols).
;; Every visitor implements one interface, PieVisitorI, and keeps its extra arguments in fields;
;; a pie has one accept for all of them. In wat the interface is a surface, PieVisitorI, each
;; visitor is a struct holding its fields (RemV {o}, SubstV {n o}, LtdSubstV {c n o}) that
;; extend-types the surface, and accept calls the surface's features on whatever visitor it is
;; given, as Java's accept calls ask.forTop.
;;
;; Java's pies hold any Object. accept is written here at pies of i64: a function generic over
;; the surface, (PieVisitorI :- [T]), refuses a struct that extends it at a concrete T (F-029;
;; probes/java/visitor-surface-generic.wat), so each element type would need its own accept.
;; Results are printed as the Java oracle's are (oracle/java/ch06-boring-protocols.java, run by
;; tools/java-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-java/ch06-boring-protocols.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defenum :lj::PieD :- [T] :wat::enum::Pure
  :Bot []
  :Top [t <- T  r <- (:lj::PieD :- [T])])

(:wat::core::defn :lj::bot :- [T] [] -> (:lj::PieD :- [T]) (:lj::PieD.Bot {}))
(:wat::core::defn :lj::top :- [T] [t <- T r <- (:lj::PieD :- [T])] -> (:lj::PieD :- [T]) (:lj::PieD.Top {:t t :r r}))

;; the protocol
(:wat::core::defsurface :lj::PieVisitorI :- [T] :nature :wat::core::Struct
  :features [(for-bot [self <- (:lj::PieVisitorI :- [T])] -> (:lj::PieD :- [T]))
             (for-top [self <- (:lj::PieVisitorI :- [T]) t <- T r <- (:lj::PieD :- [T])] -> (:lj::PieD :- [T]))])

(:wat::core::defn :lj::accept [p <- (:lj::PieD :- [:wat::core::i64]) ask <- (:lj::PieVisitorI :- [:wat::core::i64])] -> (:lj::PieD :- [:wat::core::i64])
  (:wat::core::match p
    [:lj::PieD.Bot {} (:lj::PieVisitorI/for-bot ask)]
    [:lj::PieD.Top {:t t :r r} (:lj::PieVisitorI/for-top ask t r)]))

;; the visitors: each a struct of its arguments, implementing the protocol

(:wat::core::defstruct :lj::RemV [o <- :wat::core::i64])
(:wat::core::extend-type :lj::RemV (:lj::PieVisitorI :- [:wat::core::i64])
  (for-bot [self] -> (:lj::PieD :- [:wat::core::i64]) (:lj::bot))
  (for-top [self t r] -> (:lj::PieD :- [:wat::core::i64])
    (:wat::core::if (:wat::core::= (:lj::RemV/o self) t)
      (:lj::accept r self)
      (:lj::top t (:lj::accept r self)))))

(:wat::core::defstruct :lj::SubstV [n <- :wat::core::i64  o <- :wat::core::i64])
(:wat::core::extend-type :lj::SubstV (:lj::PieVisitorI :- [:wat::core::i64])
  (for-bot [self] -> (:lj::PieD :- [:wat::core::i64]) (:lj::bot))
  (for-top [self t r] -> (:lj::PieD :- [:wat::core::i64])
    (:wat::core::if (:wat::core::= (:lj::SubstV/o self) t)
      (:lj::top (:lj::SubstV/n self) (:lj::accept r self))
      (:lj::top t (:lj::accept r self)))))

;; substitute only the first c
(:wat::core::defstruct :lj::LtdSubstV [c <- :wat::core::i64  n <- :wat::core::i64  o <- :wat::core::i64])
(:wat::core::extend-type :lj::LtdSubstV (:lj::PieVisitorI :- [:wat::core::i64])
  (for-bot [self] -> (:lj::PieD :- [:wat::core::i64]) (:lj::bot))
  (for-top [self t r] -> (:lj::PieD :- [:wat::core::i64])
    (:wat::core::cond
      ((:wat::core::= (:lj::LtdSubstV/c self) 0) (:lj::top t r))
      ((:wat::core::= (:lj::LtdSubstV/o self) t)
        (:lj::top (:lj::LtdSubstV/n self)
                  (:lj::accept r (:lj::LtdSubstV :c (:wat::core::- (:lj::LtdSubstV/c self) 1) :n (:lj::LtdSubstV/n self) :o (:lj::LtdSubstV/o self)))))
      (:else (:lj::top t (:lj::accept r self))))))

(:wat::core::defn :lj::show-pie [p <- (:lj::PieD :- [:wat::core::i64])] -> :wat::core::String
  (:wat::core::match p
    [:lj::PieD.Bot {} "(Bot)"]
    [:lj::PieD.Top {:t t :r r} (:wat::string::concat "(Top " (:wat::i64::to-string t) " " (:lj::show-pie r) ")")]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [pie (:lj::top 3 (:lj::top 2 (:lj::top 3 (:lj::top 7 (:lj::top 3 (:lj::bot))))))
                    show :lj::show-pie]
    (:lj::check-chapter "oracle/java/ch06-boring-protocols.expected"
                        "little-java ch06 boring-protocols"
                        (:wat::core::Vector :- [:wat::core::String]
                          (show (:lj::accept pie (:lj::RemV :o 3)))
                          (show (:lj::accept pie (:lj::RemV :o 8)))
                          (show (:lj::accept pie (:lj::SubstV :n 5 :o 3)))
                          (show (:lj::accept pie (:lj::LtdSubstV :c 2 :n 5 :o 3)))
                          (show (:lj::accept pie (:lj::LtdSubstV :c 0 :n 5 :o 3)))
                          (show (:lj::accept pie (:lj::LtdSubstV :c 9 :n 5 :o 3)))
                          ;; visitors compose through accept
                          (show (:lj::accept (:lj::accept pie (:lj::LtdSubstV :c 1 :n 5 :o 3)) (:lj::RemV :o 3)))
                          (show (:lj::accept (:lj::bot) (:lj::SubstV :n 1 :o 2)))))))
