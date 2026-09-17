;; PAIP chapter 14 (knowledge representation and reasoning), in wat.
;;
;; A semantic network with INHERITANCE. Two things make this harder than a lookup table, and both
;; are tested:
;;
;;   OVERRIDE  a subclass can contradict a default. Birds fly; penguins do not; Opus is a penguin
;;             and Tweety is a canary, so the same question gets two answers from two birds. The
;;             search must stop at the NEAREST answer, not collect all of them -- which is why
;;             `legs` for Opus is **2** (from bird) and not 4 (from animal).
;;   CYCLES    `isa` is user-supplied, so it can contain a loop, and the query has to terminate
;;             anyway. A `seen` list is what does it.
;;
;; The wat note is a small one and it is about **F-057** again, from a third angle. `seen` is a
;; visited set -- the same insert-and-test use PAIP ch6 hit (C-083) -- and here it is genuinely
;; load-bearing: without it the query does not merely get slower, it does not return. That is worth
;; distinguishing. In ch6 the missing persistent set cost performance; here the missing primitive
;; would cost CORRECTNESS if a user reached for the wrong substitute, because a `HashSet` copies on
;; every insert (F-057) and the copy is per recursive step.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch14-knowledge.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch14-knowledge.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Names (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defstruct :paip::Isa [child <- :wat::core::String  parent <- :wat::core::String])
(:wat::core::defstruct :paip::Has [thing <- :wat::core::String  slot <- :wat::core::String  value <- :wat::core::String])

(:wat::core::defn :paip::isa-facts [] -> (:wat::core::Vector :- [:paip::Isa])
  (:wat::core::Vector :- [:paip::Isa]
    (:paip::Isa :child "penguin" :parent "bird")
    (:paip::Isa :child "bird" :parent "animal")
    (:paip::Isa :child "canary" :parent "bird")
    (:paip::Isa :child "opus" :parent "penguin")
    (:paip::Isa :child "tweety" :parent "canary")))

(:wat::core::defn :paip::has-facts [] -> (:wat::core::Vector :- [:paip::Has])
  (:wat::core::Vector :- [:paip::Has]
    (:paip::Has :thing "animal" :slot "alive" :value "yes")
    (:paip::Has :thing "animal" :slot "legs" :value "4")
    (:paip::Has :thing "bird" :slot "legs" :value "2")
    (:paip::Has :thing "bird" :slot "flies" :value "yes")
    ;; the override: a penguin contradicts the bird default
    (:paip::Has :thing "penguin" :slot "flies" :value "no")
    (:paip::Has :thing "opus" :slot "color" :value "black")))

(:wat::core::defn :paip::parents-of [x <- :wat::core::String] -> :paip::Names
  (:wat::core::mapv :paip::Isa/parent
    (:wat::core::filterv (:wat::core::fn [f <- :paip::Isa] -> :wat::core::bool
                           (:wat::core::= (:paip::Isa/child f) x)) (:paip::isa-facts))))

(:wat::core::defn :paip::own-slot [x <- :wat::core::String slot <- :wat::core::String]
  -> (:wat::core::Option :- [:wat::core::String])
  (:wat::core::let [hits (:wat::core::filterv (:wat::core::fn [f <- :paip::Has] -> :wat::core::bool
                                                (:wat::core::and (:wat::core::= (:paip::Has/thing f) x)
                                                                 (:wat::core::= (:paip::Has/slot f) slot)))
                           (:paip::has-facts))]
    (:wat::core::if (:wat::core::empty? hits) (:wat::core::Option.None {})
      (:wat::core::Option.Some {:value (:paip::Has/value (:wat::core::nth hits 0))}))))

(:wat::core::defn :paip::seen? [x <- :wat::core::String seen <- :paip::Names] -> :wat::core::bool
  (:wat::core::if (:wat::core::empty? seen) false
    (:wat::core::if (:wat::core::= x (:wat::core::first seen)) true
      (:paip::seen? x (:wat::core::rest seen)))))

;; ask the thing itself, then its parents depth first, and STOP at the first answer
(:wat::core::defn :paip::get-slot [x <- :wat::core::String slot <- :wat::core::String seen <- :paip::Names]
  -> (:wat::core::Option :- [:wat::core::String])
  (:wat::core::if (:paip::seen? x seen) (:wat::core::Option.None {})
    (:wat::core::match (:paip::own-slot x slot)
      [:wat::core::Option.Some {:value v} (:wat::core::Option.Some {:value v})]
      [:wat::core::Option.None {}
        (:paip::ask-parents (:paip::parents-of x) 0 slot (:wat::core::conj seen x))])))

(:wat::core::defn :paip::ask-parents
  [ps <- :paip::Names i <- :wat::core::i64 slot <- :wat::core::String seen <- :paip::Names]
  -> (:wat::core::Option :- [:wat::core::String])
  (:wat::core::if (:wat::core::>= i (:wat::core::length ps)) (:wat::core::Option.None {})
    (:wat::core::match (:paip::get-slot (:wat::core::nth ps i) slot seen)
      [:wat::core::Option.Some {:value v} (:wat::core::Option.Some {:value v})]
      [:wat::core::Option.None {} (:paip::ask-parents ps (:wat::core::+ i 1) slot seen)])))

(:wat::core::defn :paip::q [x <- :wat::core::String slot <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:paip::get-slot x slot (:wat::core::Vector :- [:wat::core::String]))
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} "#f"]))

;; ---- ancestors, in the order the query would visit them
(:wat::core::defn :paip::ancestors [x <- :wat::core::String seen <- :paip::Names] -> :paip::Names
  (:wat::core::if (:paip::seen? x seen) (:wat::core::Vector :- [:wat::core::String])
    (:paip::anc-loop (:paip::parents-of x) 0 (:wat::core::conj seen x)
      (:wat::core::Vector :- [:wat::core::String]))))

(:wat::core::defn :paip::anc-loop [ps <- :paip::Names i <- :wat::core::i64 seen <- :paip::Names acc <- :paip::Names] -> :paip::Names
  (:wat::core::if (:wat::core::>= i (:wat::core::length ps)) acc
    (:wat::core::let [p (:wat::core::nth ps i)]
      (:paip::anc-loop ps (:wat::core::+ i 1) seen
        (:wat::core::concat (:wat::core::conj acc p) (:paip::ancestors p seen))))))

(:wat::core::defn :paip::show-names [ns <- :paip::Names] -> :wat::core::String
  (:wat::string::concat "(" (:wat::string::join " " ns) ")"))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:paip::check-chapter "oracle/paip/ch14-knowledge.expected"
                          "paip ch14 knowledge"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:paip::q "opus" "color")
                            (:paip::q "opus" "alive")
                            (:paip::q "tweety" "alive")
                            (:paip::q "bird" "legs")
                            (:paip::q "animal" "legs")
                            ;; the OVERRIDE: two birds, two answers
                            (:paip::q "bird" "flies")
                            (:paip::q "penguin" "flies")
                            (:paip::q "opus" "flies")
                            (:paip::q "tweety" "flies")
                            (:paip::b (:wat::core::= (:paip::q "opus" "flies") (:paip::q "tweety" "flies")))
                            ;; legs comes from bird, not animal, because bird is NEARER
                            (:paip::q "opus" "legs")
                            (:paip::b (:wat::core::= (:paip::q "opus" "legs") (:paip::q "animal" "legs")))
                            (:paip::q "opus" "salary")
                            (:paip::show-names (:paip::ancestors "opus" (:wat::core::Vector :- [:wat::core::String])))
                            (int (:wat::core::length (:paip::ancestors "opus" (:wat::core::Vector :- [:wat::core::String]))))))))
