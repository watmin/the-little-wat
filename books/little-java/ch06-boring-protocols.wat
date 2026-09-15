;; A Little Java, A Few Patterns, chapter 6 (Boring Protocols).
;; Every visitor now implements one interface, PieVisitorI, and keeps its extra arguments in
;; fields; a pie has one accept for all of them. In wat the protocol is one generic struct type,
;; PieVisitor, and each visitor is a function building an instance whose functions close over
;; its arguments. Java's r.accept(this) is accept with the same visitor, built again: values
;; have no identity, so a visitor built from the same arguments is the same visitor.
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

;; the protocol: what every pie visitor provides
(:wat::core::defstruct :lj::PieVisitor :- [T]
  [for-bot <- [:-> (:lj::PieD :- [T])]
   for-top <- [T (:lj::PieD :- [T]) :-> (:lj::PieD :- [T])]])

(:wat::core::defn :lj::accept :- [T] [p <- (:lj::PieD :- [T]) ask <- (:lj::PieVisitor :- [T])] -> (:lj::PieD :- [T])
  (:wat::core::match p
    [:lj::PieD.Bot {} ((:lj::PieVisitor/for-bot ask))]
    [:lj::PieD.Top {:t t :r r} ((:lj::PieVisitor/for-top ask) t r)]))

(:wat::core::defn :lj::rem-v :- [T] [o <- T] -> (:lj::PieVisitor :- [T])
  (:lj::PieVisitor :for-bot (:wat::core::fn [] -> (:lj::PieD :- [T]) (:lj::bot))
                   :for-top (:wat::core::fn [t <- T r <- (:lj::PieD :- [T])] -> (:lj::PieD :- [T])
                              (:wat::core::if (:wat::core::= o t)
                                (:lj::accept r (:lj::rem-v o))
                                (:lj::top t (:lj::accept r (:lj::rem-v o)))))))

(:wat::core::defn :lj::subst-v :- [T] [n <- T o <- T] -> (:lj::PieVisitor :- [T])
  (:lj::PieVisitor :for-bot (:wat::core::fn [] -> (:lj::PieD :- [T]) (:lj::bot))
                   :for-top (:wat::core::fn [t <- T r <- (:lj::PieD :- [T])] -> (:lj::PieD :- [T])
                              (:wat::core::if (:wat::core::= o t)
                                (:lj::top n (:lj::accept r (:lj::subst-v n o)))
                                (:lj::top t (:lj::accept r (:lj::subst-v n o)))))))

;; substitute only the first c
(:wat::core::defn :lj::ltd-subst-v :- [T] [c <- :wat::core::i64 n <- T o <- T] -> (:lj::PieVisitor :- [T])
  (:lj::PieVisitor :for-bot (:wat::core::fn [] -> (:lj::PieD :- [T]) (:lj::bot))
                   :for-top (:wat::core::fn [t <- T r <- (:lj::PieD :- [T])] -> (:lj::PieD :- [T])
                              (:wat::core::cond
                                ((:wat::core::= c 0) (:lj::top t r))
                                ((:wat::core::= o t) (:lj::top n (:lj::accept r (:lj::ltd-subst-v (:wat::core::- c 1) n o))))
                                (:else (:lj::top t (:lj::accept r (:lj::ltd-subst-v c n o))))))))

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
                          (show (:lj::accept pie (:lj::rem-v 3)))
                          (show (:lj::accept pie (:lj::rem-v 8)))
                          (show (:lj::accept pie (:lj::subst-v 5 3)))
                          (show (:lj::accept pie (:lj::ltd-subst-v 2 5 3)))
                          (show (:lj::accept pie (:lj::ltd-subst-v 0 5 3)))
                          (show (:lj::accept pie (:lj::ltd-subst-v 9 5 3)))
                          ;; visitors compose through accept
                          (show (:lj::accept (:lj::accept pie (:lj::ltd-subst-v 1 5 3)) (:lj::rem-v 3)))
                          (show (:lj::accept (:lj::bot) (:lj::subst-v 1 2)))))))
