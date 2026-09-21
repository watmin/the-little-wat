;; The SAME builder as elf/bench/strbuild.wat with one difference: the accumulator is read TWICE
;; per iteration rather than once. The extra read happens BEFORE the concat, so nothing can
;; observe a change made afterwards -- extending in place is still safe.
;;
;; But `:c::linear?` is a membership test in a list built from an OCCURRENCE COUNT of at most one
;; (`:c::linear-of` / `:c::occ-sum`), so two mentions disqualify the name and `str_cat_own` is
;; not reached. If this goes quadratic where strbuild.wat is linear, the analysis is counting
;; mentions where it means "no read after the write" -- and the same limit would bind any
;; ownership path given to records (F-140).
(wat.core/defn user/build [acc :- wat.type/String i :- wat.type/i64 n :- wat.type/i64] :- wat.type/String
  (wat.core/if (wat.core/= i n) acc
    (wat.core/if (wat.core/>= (wat.string/byte-length acc) 0)
      (user/build (wat.string/concat acc "x") (wat.core/+ i 1) n)
      acc)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.string/byte-length (user/build "" 0 200000))))
