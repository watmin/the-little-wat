;; **Does the ownership analysis actually FIRE?** `str_cat_own` exists (F-127/C-151): when the
;; compiler has proved the left operand of a `concat` is a last use, it writes into that buffer
;; instead of copying it. F-140 found records have no such path at all -- this asks whether the
;; path Strings DO have is reached from the shape that needs it most, an accumulator in a loop.
;;
;; If it fires, this is linear. If it does not, building an n-character String is O(n^2).
(wat.core/defn user/build [acc :- wat.type/String i :- wat.type/i64 n :- wat.type/i64] :- wat.type/String
  (wat.core/if (wat.core/= i n) acc
    (user/build (wat.string/concat acc "x") (wat.core/+ i 1) n)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.string/byte-length (user/build "" 0 5000000))))
