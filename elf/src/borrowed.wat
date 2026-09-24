;; F-188 -- a pointer read OUT of a container keeps count 1, because it was stored by move. So
;; `vec_conj_own` and `str_cat_own` took a borrowed element for an owned one and extended it in
;; place while the container still held it. Bootstrap and `tools/mem.sh` were both green with
;; that in the tree; this program is here so `tools/elf-run.sh` is not.
;;
;; One shape per read site, each in both doors: passed on as an ARGUMENT (not a Symbol, so no
;; share), and bound under a name that SHADOWS a linear parameter (`own?` is keyed on spelling).
;; Every line below is what the interpreter prints. Before the count at the read, the compiled
;; program printed a longer row or a longer string on every line marked <-.
;;
;; The probes these came from are in `elf/probe/` -- one door, one site, each.

(:wat::core::typealias :user::Row  (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :user::Grid (:wat::core::Vector :- [:user::Row]))
(:wat::core::typealias :user::Strs (:wat::core::Vector :- [:wat::core::String]))
(:wat::core::defrecord :user::R [xs <- :user::Row k <- :wat::core::i64])
(:wat::core::defenum :user::B :wat::enum::Pure
  :None []
  :One  [n <- :wat::core::i64]
  :Many [xs <- :user::Row])

;; ---- the containers

(wat.core/defn user/rows [n :- wat.type/i64 acc :- :user::Grid] :- :user::Grid
  (wat.core/if (wat.core/= n 0) acc
    (user/rows (wat.core/- n 1)
      (wat.core/conj acc (wat.core/Vector :- [wat.type/i64] n 20 30)))))

(wat.core/defn user/strs [n :- wat.type/i64 acc :- :user::Strs] :- :user::Strs
  (wat.core/if (wat.core/= n 0) acc
    (user/strs (wat.core/- n 1)
      (wat.core/conj acc (wat.string/concat "ab" (wat.i64/to-string n))))))

;; a Vector made by `vec_conj_own`'s COPYING path: it carries the owned arm and has room, so a
;; later in-place `conj` on it takes path 2 rather than path 3
(wat.core/defn user/grow [v :- :user::Row junk :- :user::Row] :- :user::Row
  (wat.core/conj v 7))

(wat.core/defn user/owned [] :- :user::Row
  (user/grow (wat.core/Vector :- [wat.type/i64] 1 2 3) (wat.core/Vector :- [wat.type/i64] 5)))

(wat.core/defn user/size [b :- :user::B] :- wat.type/i64
  (:wat::core::match b
    [:user::B.None {} 0]
    [:user::B.One {:n n} 1]
    [:user::B.Many {:xs xs} (wat.core/length xs)]))

;; ---- the callees: each extends its LINEAR parameter, or a binding that shadows it

(wat.core/defn user/bump [v :- :user::Row] :- wat.type/i64
  (wat.core/length (wat.core/conj v 99)))

(wat.core/defn user/bang [s :- wat.type/String] :- wat.type/i64
  (wat.string/length (wat.string/concat s "!")))

(wat.core/defn user/nth-shadow [v :- :user::Row g :- :user::Grid] :- wat.type/i64
  (wat.core/let [v (wat.core/nth g 3)]
    (wat.core/length (wat.core/conj v 99))))

(wat.core/defn user/str-shadow [s :- wat.type/String g :- :user::Strs] :- wat.type/i64
  (wat.core/let [s (wat.core/nth g 3)]
    (wat.string/length (wat.string/concat s "!"))))

(wat.core/defn user/field-shadow [v :- :user::Row r :- :user::R] :- wat.type/i64
  (wat.core/let [v (:user::R/xs r)]
    (wat.core/length (wat.core/conj v 99))))

(wat.core/defn user/match-shadow [xs :- :user::Row b :- :user::B] :- wat.type/i64
  (:wat::core::match b
    [:user::B.None {} 0]
    [:user::B.One {:n n} n]
    [:user::B.Many {:xs xs} (wat.core/length (wat.core/conj xs 99))]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; nth, a Vector element: argument, then shadow
    (wat.core/let [g (user/rows 4 (wat.core/Vector :- [:user::Row]))
                   k (user/bump (wat.core/nth g 3))]
      (wat.kernel/println k)                                      ;; 4
      (wat.kernel/println (wat.core/length (wat.core/nth g 3))))  ;; 3   <-
    (wat.core/let [e (wat.core/Vector :- [wat.type/i64])
                   g (user/rows 4 (wat.core/Vector :- [:user::Row]))
                   k (user/nth-shadow e g)]
      (wat.kernel/println k)                                      ;; 4
      (wat.kernel/println (wat.core/length (wat.core/nth g 3))))  ;; 3   <-
    ;; nth, a String element: argument, then shadow
    (wat.core/let [g (user/strs 4 (wat.core/Vector :- [wat.type/String]))
                   k (user/bang (wat.core/nth g 3))]
      (wat.kernel/println k)                                      ;; 4
      (wat.kernel/println (wat.core/nth g 3)))                    ;; ab1 <-
    (wat.core/let [e (wat.string/concat "x" "y")
                   g (user/strs 4 (wat.core/Vector :- [wat.type/String]))
                   k (user/str-shadow e g)]
      (wat.kernel/println k)                                      ;; 4
      (wat.kernel/println (wat.core/nth g 3)))                    ;; ab1 <-
    ;; a record field: argument, then shadow
    (wat.core/let [r (:user::R :xs (user/owned) :k 0)
                   k (user/bump (:user::R/xs r))]
      (wat.kernel/println k)                                      ;; 5
      (wat.kernel/println (wat.core/length (:user::R/xs r))))     ;; 4   <-
    (wat.core/let [e (wat.core/Vector :- [wat.type/i64])
                   r (:user::R :xs (user/owned) :k 0)
                   k (user/field-shadow e r)]
      (wat.kernel/println k)                                      ;; 5
      (wat.kernel/println (wat.core/length (:user::R/xs r))))     ;; 4   <-
    ;; a match payload: only the shadow -- a bound name passed on is a Symbol, and is shared
    (wat.core/let [e (wat.core/Vector :- [wat.type/i64])
                   b (:user::B.Many {:xs (user/owned)})
                   k (user/match-shadow e b)]
      (wat.kernel/println k)                                      ;; 5
      (wat.kernel/println (user/size b)))))                       ;; 4   <-
