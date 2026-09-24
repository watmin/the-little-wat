;; STONE 0b's trap door 2: `nth` over a PROMOTED Vector answers through the runtime's `tget`, and
;; stone 0b raises the count of what comes back with a bare `incq [rax-8]` -- no `cmp`. So what
;; `tget` answers must be the element itself, with its own count word at `[rax-8]`. This reads out
;; of 40-element Vectors (past `:c::arr-max`, 8, so trie-shaped) four kinds of element and hands
;; each to an in-place `conj`:
;;
;;   * a flat row (door 1: `(bump (nth g 35))`),
;;   * an EMPTY row,
;;   * a row that is itself a trie (40 elements), whose header is `vec-tree`/`heap-arm`,
;;   * a row built by a `conj` chain -- it carries `arm-own` and has room in its block, so an
;;     UNCOUNTED read of it is extended in place by `vec_conj_own` path 2.
;;
;; With no count at all (`dada88f`, before stone 0) the last two kinds DIVERGE -- native
;; `40|4|3|1|0|41|41|1|5|5` against `40|4|3|1|0|41|40|1|5|4` -- so this pins the count through
;; `tget`, not merely the absence of a fault.
;;
;; If the increment lands anywhere but the element's count, the element still reads count 1 and
;; `vec_conj_own` extends it in place: the lengths below come back one too long. Run both ways.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :user::Grid (:wat::core::Vector :- [:user::Row]))

(wat.core/defn user/bump [v :- :user::Row] :- wat.type/i64
  (wat.core/length (wat.core/conj v 99)))

;; the element allocates a String first, so `acc` is never the youngest allocation: every `conj`
;; copies (path 4) or grows inside its block (path 2), and the row ends up carrying `arm-own`
(wat.core/defn user/row [n :- wat.type/i64 acc :- :user::Row] :- :user::Row
  (wat.core/if (wat.core/= n 0) acc
    (user/row (wat.core/- n 1)
      (wat.core/conj acc (wat.core/+ n (wat.core/* 0 (wat.string/length (wat.i64/to-string n))))))))

(wat.core/defn user/fill [n :- wat.type/i64 acc :- :user::Grid] :- :user::Grid
  (wat.core/if (wat.core/= n 0) acc
    (user/fill (wat.core/- n 1)
      (wat.core/conj acc
        (wat.core/cond
          ((wat.core/= n 5) (wat.core/Vector :- [wat.type/i64]))
          ((wat.core/= n 3) (user/row 40 (wat.core/Vector :- [wat.type/i64])))
          ((wat.core/= n 2) (user/row 4 (wat.core/Vector :- [wat.type/i64])))
          (:else (wat.core/Vector :- [wat.type/i64] n 20 30)))))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [g (user/fill 40 (wat.core/Vector :- [:user::Row]))]
    (wat.kernel/println (wat.core/length g))                      ;; 40
    (wat.kernel/println (user/bump (wat.core/nth g 30)))          ;; 4   a flat row, n = 10
    (wat.kernel/println (wat.core/length (wat.core/nth g 30)))    ;; 3
    (wat.kernel/println (user/bump (wat.core/nth g 35)))          ;; 1   the empty row, n = 5
    (wat.kernel/println (wat.core/length (wat.core/nth g 35)))    ;; 0
    (wat.kernel/println (user/bump (wat.core/nth g 37)))          ;; 41  the trie row, n = 3
    (wat.kernel/println (wat.core/length (wat.core/nth g 37)))    ;; 40
    (wat.kernel/println (wat.core/nth (wat.core/nth g 37) 39))    ;; 1
    (wat.kernel/println (user/bump (wat.core/nth g 38)))          ;; 5   a conj-built row, n = 2:
    (wat.kernel/println (wat.core/length (wat.core/nth g 38)))))  ;; 4   arm-own, room in its block
