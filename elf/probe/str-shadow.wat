;; The String analog of door 2 (F-188): no borrowed pointer crosses a call. `e` is passed as a
;; Symbol and shared; the borrowed String is bound INSIDE `bang` by a `let` that shadows the
;; linear parameter `s`, so the `concat` inherits the parameter's ownership by spelling.
(:wat::core::typealias :user::Strs (:wat::core::Vector :- [:wat::core::String]))

(wat.core/defn user/bang [s :- wat.type/String g :- :user::Strs] :- wat.type/i64
  (wat.core/let [s (wat.core/nth g 3)]
    (wat.string/length (wat.string/concat s "!"))))

(wat.core/defn user/fill [n :- wat.type/i64 acc :- :user::Strs] :- :user::Strs
  (wat.core/if (wat.core/= n 0) acc
    (user/fill (wat.core/- n 1)
      (wat.core/conj acc (wat.string/concat "ab" (wat.i64/to-string n))))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [e (wat.string/concat "x" "y")
                 g (user/fill 4 (wat.core/Vector :- [wat.type/String]))
                 k (user/bang e g)]
    (wat.kernel/println k)                                        ;; 4
    (wat.kernel/println (wat.core/nth g 3))                       ;; ab1
    (wat.kernel/println (wat.string/length (wat.core/nth g 3)))))  ;; 3
