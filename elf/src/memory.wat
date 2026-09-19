;; Does the compiler free things it should not?
;;
;; The heap is a bump pointer in r15 and the only thing that ever gives memory back is the
;; statement-level release (C-120): a sequence's non-final forms have their values discarded, so
;; r15 is marked before each one and restored after. The question this program exists to answer
;; is whether that release can reach something still live.
;;
;; The shape is deliberate:
;;
;;   * `keep` and `p` are allocated FIRST, so they sit BELOW the mark;
;;   * two heavy non-final statements then allocate megabytes and are released, so the second
;;     one REUSES exactly the addresses the first one used;
;;   * the final statement reads `keep` and `p` back.
;;
;; If the release rewound too far, the second churn would have overwritten them and the last
;; four lines would print garbage. If it rewound too little the output would still be right --
;; that failure is invisible here and shows up as resident memory instead (tools/mem.sh).
;;
;; Run both ways; they must agree.

(:wat::core::defrecord :user::P
  [x <- :wat::core::i64  y <- :wat::core::i64  label <- :wat::core::String])

(:wat::core::typealias :user::Strs (:wat::core::Vector :- [:wat::core::String]))

;; allocates n strings, each longer than the last, and answers only a length -- so every one of
;; them is garbage the moment this returns
(wat.core/defn user/churn [n :- wat.type/i64 acc :- wat.type/String] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) (wat.string/length acc)
    (user/churn (wat.core/- n 1) (wat.string/concat acc "0123456789abcdef"))))

;; the same, building a vector: 2000 conjs is about 16 MB of copying
(wat.core/defn user/grow [n :- wat.type/i64 acc :- :user::Strs] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) (wat.core/length acc)
    (user/grow (wat.core/- n 1) (wat.core/conj acc "x"))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [keep (wat.core/Vector :- [wat.type/String] "alpha" "beta" "gamma")
                 p (:user::P :label "kept" :x 11 :y 22)]

    ;; two heavy statements, both discarded -- the second reuses the first's addresses
    (wat.kernel/println (user/churn 2000 ""))
    (wat.kernel/println (user/churn 2000 ""))
    (wat.kernel/println (user/grow 2000 (wat.core/Vector :- [wat.type/String])))
    (wat.kernel/println (user/grow 2000 (wat.core/Vector :- [wat.type/String])))

    ;; and now read back what was allocated before any of that
    (wat.kernel/println (wat.core/nth keep 0))
    (wat.kernel/println (wat.core/nth keep 2))
    (wat.kernel/println (wat.core/length keep))
    (wat.kernel/println (:user::P/label p))
    (wat.kernel/println (:user::P/x p))
    (wat.kernel/println (:user::P/y p))))
