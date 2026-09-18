;; lox/lib/v-intern.wat — Crafting Interpreters chapter 20's portable half: string interning.
;;
;; The chapter itself builds a hash table from scratch -- open addressing, linear probing, a
;; tombstone scheme for deletion, a 75% load factor. wat has `HashMap` and `PersistentMap` and
;; C-078 already measured what they cost, so there is nothing to learn from writing a third one.
;;
;; What the chapter DOES that is about Lox rather than about hash tables is intern every string:
;; the VM keeps a set of every string it has made, and a new one that is already in the set is
;; discarded in favour of the existing pointer. Two consequences, and they are different in kind:
;;
;;   CORRECTNESS  `==` on two strings becomes a pointer comparison. In wat this buys nothing --
;;                `=` on a String is already structural, so `"ab" == "a"+"b"` was true in
;;                chapter 19, before the chapter that makes it true in C.
;;   COST         a comparison stops being O(length) and becomes O(1), and a constant pool stops
;;                holding one copy per occurrence. Both are measurable, and lox/ch20-hash-tables.wat
;;                measures them.
;;
;; An interner is a map from text to a small integer plus the vector back. The integer is the
;; "pointer": it is what an interned value would carry instead of characters.

(:wat::load-file! "v-value.wat")

(:wat::core::defrecord :loxv::Interner
  [ids <- (:wat::core::HashMap :- [:wat::core::String :wat::core::i64])
   texts <- (:wat::core::Vector :- [:wat::core::String])])

(:wat::core::defn :loxv::new-interner [] -> :loxv::Interner
  (:loxv::Interner :ids (:wat::core::HashMap :- [:wat::core::String :wat::core::i64])
                   :texts (:wat::core::Vector :- [:wat::core::String])))

(:wat::core::defn :loxv::interned? [t <- :loxv::Interner s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::contains? (:loxv::Interner/ids t) s))

;; the id `s` already has, or -1
(:wat::core::defn :loxv::id-of [t <- :loxv::Interner s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::core::get (:loxv::Interner/ids t) s)
    [:wat::core::Option.Some {:value i} i]
    [:wat::core::Option.None {} -1]))

;; add if absent. The table grows; the id of an existing string never changes.
(:wat::core::defn :loxv::intern [t <- :loxv::Interner s <- :wat::core::String] -> :loxv::Interner
  (:wat::core::if (:loxv::interned? t s) t
    (:wat::core::assoc
      (:wat::core::assoc t :ids (:wat::core::assoc (:loxv::Interner/ids t) s
                                  (:wat::core::length (:loxv::Interner/texts t))))
      :texts (:wat::core::conj (:loxv::Interner/texts t) s))))

(:wat::core::defn :loxv::text-of [t <- :loxv::Interner i <- :wat::core::i64] -> :wat::core::String
  (:wat::core::nth (:loxv::Interner/texts t) i))

(:wat::core::defn :loxv::interner-size [t <- :loxv::Interner] -> :wat::core::i64
  (:wat::core::length (:loxv::Interner/texts t)))

;; intern a whole list of literals, as a compiler would while walking a source file
(:wat::core::defn :loxv::intern-all [t <- :loxv::Interner
                                     xs <- (:wat::core::Vector :- [:wat::core::String])
                                     i <- :wat::core::i64] -> :loxv::Interner
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs)) t
    (:loxv::intern-all (:loxv::intern t (:wat::core::nth xs i)) xs (:wat::core::+ i 1))))
