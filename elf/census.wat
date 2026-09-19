;; elf/census.wat -- how far is the compiler from compiling itself?
;;
;; Self-hosting is the objective, so it deserves a number rather than a feeling. This walks the
;; AST of every wat file the compiler is made of, asks of every form "could :c::form translate
;; this?", and tallies the ones it could not, most frequent first.
;;
;; The supported set below is read off elf/compile.wat's dispatch cond by hand, so it can drift;
;; the number it produces is a floor on the work, not a proof. What it is good for is ordering:
;; the top of the table is what to build next, and the length of the table is the distance.
;;
;; Run from the repository root:
;;   wat elf/census.wat

(:wat::load-file! "lib/asm.wat")

(:wat::core::typealias :cn::Tally (:wat::core::HashMap :- [:wat::core::String :wat::core::i64]))
(:wat::core::typealias :cn::Kids (:wat::core::Vector :- [:wat::WatAST]))

;; ---------------------------------------------------------------- what the compiler accepts
;;
;; Both spellings of each, because the reader keeps whichever the source used.

(:wat::core::defn :cn::supported [] -> (:wat::core::Vector :- [:wat::core::String])
  (:wat::core::Vector :- [:wat::core::String]
    "wat.core/defn" "wat.core/if" "wat.core/let" "wat.core/do"
    "wat.core/cond" "wat.core/and" "wat.core/or" "wat.core/not" ":wat::core::/"
    "wat.string/subs" "wat.string/starts-with?" "wat.string/contains?" "wat.i64/to-string"
    ":wat::string::subs" ":wat::string::starts-with?" ":wat::string::contains?"
    ":wat::i64::to-string"
    "wat.core/nth" "wat.core/length" "wat.core/conj" "wat.core/assoc" "wat.core/Vector"
    "wat.core/defrecord" "wat.core/typealias"
    ":wat::core::nth" ":wat::core::length" ":wat::core::conj" ":wat::core::assoc"
    ":wat::core::Vector" ":wat::core::defrecord" ":wat::core::typealias"
    "wat.core/+" "wat.core/-" "wat.core/*" "wat.core/quot" "wat.core/rem"
    "wat.core/<" "wat.core/>" "wat.core/<=" "wat.core/>=" "wat.core/=" "wat.core/not="
    "wat.string/concat" "wat.string/length" "wat.kernel/println"
    "wat.os/getpid" "wat.os/getppid" "wat.os/fork" "wat.os/exit" "wat.os/wait"
    "wat.os/mmap" "wat.os/clone" "wat.os/peek" "wat.os/poke"
    ":wat::core::defn" ":wat::core::if" ":wat::core::let" ":wat::core::do"
    ":wat::core::+" ":wat::core::-" ":wat::core::*" ":wat::core::quot" ":wat::core::rem"
    ":wat::core::<" ":wat::core::>" ":wat::core::<=" ":wat::core::>=" ":wat::core::=" ":wat::core::not="
    ":wat::core::cond" ":wat::core::and" ":wat::core::or" ":wat::core::not"
    ":wat::string::concat" ":wat::string::length" ":wat::kernel::println"))

(:wat::core::defn :cn::in? [v <- (:wat::core::Vector :- [:wat::core::String])
                            s <- :wat::core::String i <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length v)) false)
    ((:wat::core::= (:wat::core::nth v i) s) true)
    (:else (:cn::in? v s (:wat::core::+ i 1)))))

;; a call to something this program defines is compilable; the compiler resolves those itself.
;;
;; `:c::Out/code` is a defrecord accessor rather than a function the program defines -- and as of
;; C-124 the compiler generates those too, so both count as translatable.
(:wat::core::defn :cn::own-ns? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::string::starts-with? s "user/")
    (:wat::core::or (:wat::string::starts-with? s ":user::")
      (:wat::core::or (:wat::string::starts-with? s ":c::")
        (:wat::core::or (:wat::string::starts-with? s ":asm::") (:wat::string::starts-with? s ":cn::"))))))

(:wat::core::defn :cn::local-call? [s <- :wat::core::String] -> :wat::core::bool
  (:cn::own-ns? s))

;; ---------------------------------------------------------------- the walk

(:wat::core::defn :cn::bump [t <- :cn::Tally k <- :wat::core::String] -> :cn::Tally
  (:wat::hashmap::assoc t k
    (:wat::core::match (:wat::hashmap::get t k)
      [:wat::core::Option.Some {:value n} (:wat::core::+ n 1)]
      [:wat::core::Option.None {} 1])))

(:wat::core::defn :cn::kind [a <- :wat::WatAST] -> :wat::core::String
  (:wat::core::str (:wat::core::ast-kind a)))

(:wat::core::defn :cn::walk [a <- :wat::WatAST t <- :cn::Tally] -> :cn::Tally
  (:wat::core::cond
    ;; a `let`'s bindings, a `defn`'s parameters and a `match`'s patterns are VECTORS, and the
    ;; expressions inside them are ordinary expressions -- so they are walked, just with no head
    ((:wat::core::= (:cn::kind a) "vector") (:cn::kids (:wat::core::ast->children a) 0 t))
    ((:wat::core::not= (:cn::kind a) "list") t)
    (:else
      (:wat::core::let [ks (:wat::core::ast->children a)]
        (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) t
          (:wat::core::let
            [h (:wat::core::nth ks 0)
             head (:wat::core::ast->source h)
             ;; a call's head is a symbol (`wat.core/+`) or a keyword (`:wat::core::+`), since
             ;; the two spellings read differently. A `cond` clause is a list whose head is the
             ;; TEST, and an `:else` clause's head is the keyword `:else` -- neither is a call.
             call? (:wat::core::and
                     (:wat::core::or (:wat::core::= (:cn::kind h) "symbol")
                                     (:wat::core::= (:cn::kind h) "keyword"))
                     (:wat::core::not= head ":else"))
             t2 (:wat::core::if (:wat::core::or (:wat::core::not call?)
                                  (:wat::core::or (:cn::in? (:cn::supported) head 0)
                                                  (:cn::local-call? head)))
                  t (:cn::bump t head))]
            (:cn::kids ks 0 t2)))))))

(:wat::core::defn :cn::kids [ks <- :cn::Kids i <- :wat::core::i64 t <- :cn::Tally] -> :cn::Tally
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) t
    (:cn::kids ks (:wat::core::+ i 1) (:cn::walk (:wat::core::nth ks i) t))))

(:wat::core::defn :cn::forms-of [src <- :wat::core::String] -> :wat::WatAST
  (:wat::core::match (:wat::core::read-string src)
    [:wat::core::ReadOutcome.Forms {:forms fs} fs]
    [:wat::core::ReadOutcome.Malformed {:cause e}
      (:wat::kernel::assertion-failed! :message (:wat::core::Error/message e))]))

(:wat::core::defn :cn::file [path <- :wat::core::String t <- :cn::Tally] -> :cn::Tally
  (:cn::kids (:wat::core::ast->children (:cn::forms-of (:wat::io::read-file path))) 0 t))

;; ---------------------------------------------------------------- reporting
;;
;; Sorted by count, descending. `:wat::core::sort` orders a Vector, so the counts are sorted and
;; then each name is matched back to one -- there is no sort-by, and no positional update to
;; build an index with either (F-104).

(:wat::core::defn :cn::total [ks <- (:wat::core::Vector :- [:wat::core::String]) t <- :cn::Tally
                              i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) acc
    (:cn::total ks t (:wat::core::+ i 1)
      (:wat::core::+ acc (:wat::core::match (:wat::hashmap::get t (:wat::core::nth ks i))
                           [:wat::core::Option.Some {:value n} n]
                           [:wat::core::Option.None {} 0])))))

(:wat::core::defn :cn::count-of [t <- :cn::Tally k <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::hashmap::get t k)
    [:wat::core::Option.Some {:value n} n]
    [:wat::core::Option.None {} 0]))

;; print every name whose count is exactly `n`, in whatever order the keys came out
(:wat::core::defn :cn::print-at [ks <- (:wat::core::Vector :- [:wat::core::String]) t <- :cn::Tally
                                 n <- :wat::core::i64 i <- :wat::core::i64
                                 rank <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) rank
    (:wat::core::let [k (:wat::core::nth ks i)]
      (:wat::core::if (:wat::core::not= (:cn::count-of t k) n)
        (:cn::print-at ks t n (:wat::core::+ i 1) rank)
        (:wat::core::do
          (:wat::kernel::println
            (:wat::string::concat "  " (:asm::pad (:wat::i64::to-string rank) 4)
              (:asm::pad (:wat::i64::to-string n) 7) "  " k))
          (:cn::print-at ks t n (:wat::core::+ i 1) (:wat::core::+ rank 1)))))))

;; walk the distinct counts from highest to lowest
(:wat::core::defn :cn::report [ks <- (:wat::core::Vector :- [:wat::core::String]) t <- :cn::Tally
                               n <- :wat::core::i64 rank <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::<= n 0) nil
    (:cn::report ks t (:wat::core::- n 1) (:cn::print-at ks t n 0 rank))))

(:wat::core::defn :cn::max-count [ks <- (:wat::core::Vector :- [:wat::core::String]) t <- :cn::Tally
                                  i <- :wat::core::i64 best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) best
    (:wat::core::let [n (:cn::count-of t (:wat::core::nth ks i))]
      (:cn::max-count ks t (:wat::core::+ i 1) (:wat::core::if (:wat::core::> n best) n best)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [t (:cn::file "elf/lib/asm.wat" (:cn::file "elf/compile.wat"
         (:wat::core::HashMap :- [:wat::core::String :wat::core::i64])))
     ks (:wat::hashmap::keys t)]
    (:wat::core::do
      (:wat::kernel::println "self-hosting census: forms elf/compile.wat + elf/lib/asm.wat use")
      (:wat::kernel::println "that the compiler cannot yet translate, most frequent first")
      (:wat::kernel::println "  rank  count  form")
      (:cn::report ks t (:cn::max-count ks t 0 0) 1)
      (:wat::kernel::println
        (:wat::string::concat "  " (:wat::i64::to-string (:wat::core::length ks))
          " distinct forms, " (:wat::i64::to-string (:cn::total ks t 0 0))
          " occurrences -- that is the distance to self-hosting")))))
