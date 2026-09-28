;; R12 fixture (excursus 008 stone 3a round 5): a self-tail-recursive walker whose LAST
;; parameter is a read-only "context" pointer, passed through unchanged on every recursive
;; call and never mentioned in the base-case arm. The caller keeps using the context after the
;; walk returns, so its one reference must survive the whole recursion.
(wat.core/defrecord :user::Ctx [label :- wat.type/i64 other :- wat.type/i64])

(wat.core/defn user/walk [v :- (wat.core/Vector :- [wat.type/i64]) i :- wat.type/i64
                          acc :- wat.type/i64 ctx :- :user::Ctx] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length v))
    acc
    (user/walk v (wat.core/+ i 1) (wat.core/+ acc (wat.core/nth v i)) ctx)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let
    [c (:user::Ctx :label 7 :other 0)
     v0 (wat.core/Vector :- [wat.type/i64])
     v1 (wat.core/conj v0 1)
     v2 (wat.core/conj v1 2)
     v3 (wat.core/conj v2 3)
     s (user/walk v3 0 0 c)
     t (:user::Ctx/label c)]
    (wat.core/do
      (wat.kernel/println (wat.i64/to-string s))
      (wat.kernel/println (wat.i64/to-string t)))))
