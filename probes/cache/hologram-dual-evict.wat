;; probes/cache/hologram-dual-evict.wat: does re-putting a key into a HolographicLru delete it?
;;
;; :wat::cache::HolographicLru is a SIMILARITY-keyed cache -- get takes a probe and returns the
;; value stored under the nearest key that clears a filter, built on the VSA algebra C-039
;; checked. It holds two things: a Hologram (which holds the values) and a
;; (Lru :- [HolonAST nil]) used only to bound and age the key set.
;;
;; put's stated algorithm, from wat/cache.wat:
;;
;;   1. Insert (key, val) into the Hologram.
;;   2. Push key -> nil onto the LRU.
;;   3. "If step 2 displaced an entry (OVER CAPACITY), remove ITS key from the Hologram too --
;;      the dual-eviction invariant."
;;
;; But Stone 1's own contract says Lru::put displaces in TWO cases, not one:
;;
;;   "Returns the DISPLACED entry -- the least-recently-used one when the insert pushed past
;;    capacity, OR `k`'s PREVIOUS BINDING WHEN `k` WAS ALREADY PRESENT"
;;
;; and probes/cache/lru-laws.wat L4 confirms the second case empirically. The Option carries no
;; discriminant, so step 3 cannot tell an eviction from an update -- and on an update the key it
;; removes from the Hologram is the one just inserted.
;;
;; H2 below is that case. H1 is its positive control (a first put must survive, or H2 proves
;; nothing) and H3 checks the invariant the mechanism actually exists for.
;;
;; Run: wat probes/cache/hologram-dual-evict.wat

(:wat::core::defn :hd::say [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label s)))

(:wat::core::defn :hd::sayi [label <- :wat::core::String n <- :wat::core::i64] -> :wat::core::nil
  (:hd::say label (:wat::i64::to-string n)))

(:wat::core::defn :hd::hit? [o <- (:wat::core::Option :- [:wat::holon::HolonAST])] -> :wat::core::String
  (:wat::core::match o
    [:wat::core::Option.Some {:value v} "hit"]
    [:wat::core::Option.None {} "MISS"]))

;; H1 -- the positive control: one put, one entry, and it is findable.
(:wat::core::defn :hd::h1 [] -> :wat::core::nil
  (:wat::core::let [h (:wat::cache::HolographicLru::new (:wat::holon::filter-accept-any) 8)
                    k (:wat::holon::leaf "alpha")
                    v (:wat::holon::leaf "one")
                    _ (:wat::cache::HolographicLru::put h k v)]
    (:wat::core::do
      (:hd::sayi "H1 len after one put                  " (:wat::cache::HolographicLru::len h))
      (:hd::say  "H1 get finds it                       " (:hd::hit? (:wat::cache::HolographicLru::get h k))))))

;; H2 -- THE CASE. The same key put a second time. Nothing was evicted; capacity is 8.
(:wat::core::defn :hd::h2 [] -> :wat::core::nil
  (:wat::core::let [h (:wat::cache::HolographicLru::new (:wat::holon::filter-accept-any) 8)
                    k (:wat::holon::leaf "alpha")
                    v1 (:wat::holon::leaf "one")
                    v2 (:wat::holon::leaf "two")
                    _1 (:wat::cache::HolographicLru::put h k v1)
                    l1 (:wat::cache::HolographicLru::len h)
                    _2 (:wat::cache::HolographicLru::put h k v2)
                    l2 (:wat::cache::HolographicLru::len h)]
    (:wat::core::do
      (:hd::sayi "H2 len after first put                " l1)
      (:hd::sayi "H2 len after RE-PUT of the same key   " l2)
      (:hd::say  "H2 get after re-put                   " (:hd::hit? (:wat::cache::HolographicLru::get h k))))))

;; H3 -- the invariant dual-eviction exists for: the Hologram must not outgrow the LRU's bound.
(:wat::core::defn :hd::h3 [] -> :wat::core::nil
  (:wat::core::let [h (:wat::cache::HolographicLru::new (:wat::holon::filter-accept-any) 2)
                    _1 (:wat::cache::HolographicLru::put h (:wat::holon::leaf "k1") (:wat::holon::leaf "v1"))
                    _2 (:wat::cache::HolographicLru::put h (:wat::holon::leaf "k2") (:wat::holon::leaf "v2"))
                    _3 (:wat::cache::HolographicLru::put h (:wat::holon::leaf "k3") (:wat::holon::leaf "v3"))]
    (:hd::sayi "H3 len after 3 distinct puts, cap 2   " (:wat::cache::HolographicLru::len h))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do (:hd::h1) (:hd::h2) (:hd::h3)))
