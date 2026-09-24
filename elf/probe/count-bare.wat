;; STONE 0b's premise, as a program: a Vector or a record read OUT of a container is never a
;; read-only literal, so its count can be raised with a bare `incq [rax-8]` -- no `cmp`/`je`.
;; The reading behind it: `:c::vec-form` calls the allocator for EVERY Vector form, zero
;; elements included, and the data tail holds string literals only (`elf/compile.wat:46`).
;; The edge most likely to break it is the EMPTY vector, the classic shared static object;
;; so every shape here reads an empty one out of something, then touches it.
;; If the premise is wrong, this faults. Run both ways; they must agree.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :user::Grid (:wat::core::Vector :- [:user::Row]))
(:wat::core::defrecord :user::Box [row <- :user::Row tag <- :wat::core::String])
(:wat::core::typealias :user::Boxes (:wat::core::Vector :- [:user::Box]))

(wat.core/defn user/grow [v :- :user::Row] :- wat.type/i64
  (wat.core/length (wat.core/conj v 7)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [g  (wat.core/Vector :- [:user::Row] (wat.core/Vector :- [wat.type/i64])
                                                     (wat.core/Vector :- [wat.type/i64] 1 2))
                 bs (wat.core/Vector :- [:user::Box]
                      (:user::Box :row (wat.core/Vector :- [wat.type/i64]) :tag "t"))
                 e  (wat.core/nth g 0)
                 b  (wat.core/nth bs 0)
                 r  (:user::Box/row b)]
    (wat.kernel/println (user/grow e))                        ;; 1
    (wat.kernel/println (wat.core/length (wat.core/nth g 0))) ;; 0 -- the empty row is untouched
    (wat.kernel/println (user/grow r))                        ;; 1
    (wat.kernel/println (wat.core/length (:user::Box/row (wat.core/nth bs 0)))) ;; 0
    (wat.kernel/println (:user::Box/tag b))                   ;; "t" -- a String read: still guarded
    (wat.kernel/println (user/grow (wat.core/nth g 1)))))     ;; 3
