;; The String analog of door 1 (F-188): a String read out of a Vector by `nth` is passed to a
;; function whose parameter is linear, and that function `concat`s onto it. `str_cat_own` tests
;; the same word `vec_conj_own` does -- count 1 -- so a borrowed element that was stored by move
;; is written in place, and the caller's Vector sees the append.
(:wat::core::typealias :user::Strs (:wat::core::Vector :- [:wat::core::String]))

(wat.core/defn user/bang [s :- wat.type/String] :- wat.type/i64
  (wat.string/length (wat.string/concat s "!")))

(wat.core/defn user/fill [n :- wat.type/i64 acc :- :user::Strs] :- :user::Strs
  (wat.core/if (wat.core/= n 0) acc
    (user/fill (wat.core/- n 1)
      (wat.core/conj acc (wat.string/concat "ab" (wat.i64/to-string n))))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [g (user/fill 4 (wat.core/Vector :- [wat.type/String]))
                 k (user/bang (wat.core/nth g 3))]
    (wat.kernel/println k)                                        ;; 4 -- "ab1!"
    (wat.kernel/println (wat.core/nth g 3))                       ;; ab1, not ab1!
    (wat.kernel/println (wat.string/length (wat.core/nth g 3)))))  ;; 3
