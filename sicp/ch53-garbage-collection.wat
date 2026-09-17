;; SICP §5.3 (storage allocation and garbage collection), in wat.
;;
;; Memory is two parallel tables of cars and cdrs, `cons` bumps a free pointer, and the collector
;; is STOP-AND-COPY: two semispaces, a set of roots, and BROKEN HEARTS so that a cell reachable by
;; two paths is copied once and stays shared.
;;
;; The claim worth checking is not that collection frees memory -- that is obvious -- but that
;; copying PRESERVES SHARING. Two lists sharing a tail must still share it afterwards, or the
;; collector has silently turned one structure into two. The broken heart is the only thing that
;; makes that true, and the check below is the equality of two cdr pointers AFTER the copy.
;;
;; Two wat notes, both already in the ledger and both landing here for structural reasons:
;;
;;   F-104: memory is a `PersistentMap` keyed by cell index, not a vector, because neither vector
;;   type has a positional update. A garbage collector indexing dense integers is about the purest
;;   case for the missing operation there is -- this is the fifth workload to route around it.
;;
;;   Nothing is mutated. SICP's collector writes through `vector-set!`; here every step threads a
;;   new memory and a new forwarding table and returns them. The broken heart is still written
;;   BEFORE the recursive call, exactly as in the book, because that ordering is what makes
;;   sharing work -- it is a property of the algorithm, not of mutation.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch53-garbage-collection.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch53-garbage-collection.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :sicp::Cells (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))
(:wat::core::typealias :sicp::Ints (:wat::core::Vector :- [:wat::core::i64]))

;; `Mem` is a defrecord, not a defstruct. A defstruct is impure -- it may not cross an address
;; boundary (F-040) -- and the containment rule then refuses to let a Pure enum hold one:
;;   "containment rule: Pure enum :sicp::Consed may only hold pure variant fields -- variant C
;;    field mem has impure type :sicp::Mem"
;; Every result below is carried out of a step inside a Pure enum, so the carrier has to be a
;; record. It holds only maps and integers, so F-098's deep-copy of user-enum fields does not
;; apply here. This is the sixth time in this repository that the aggregate KIND, rather than the
;; field types, decided the shape of a program.
(:wat::core::defrecord :sicp::Mem [cars <- :sicp::Cells  cdrs <- :sicp::Cells  free <- :wat::core::i64])

(:wat::core::defn :sicp::mk-mem [] -> :sicp::Mem
  (:sicp::Mem :cars (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64])
              :cdrs (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64])
              :free 0))

(:wat::core::defn :sicp::cell-at [t <- :sicp::Cells i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:wat::map::get t i)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} 0]))

(:wat::core::defn :sicp::mcar [m <- :sicp::Mem p <- :wat::core::i64] -> :wat::core::i64
  (:sicp::cell-at (:sicp::Mem/cars m) p))

(:wat::core::defn :sicp::mcdr [m <- :sicp::Mem p <- :wat::core::i64] -> :wat::core::i64
  (:sicp::cell-at (:sicp::Mem/cdrs m) p))

;; a cons: write car and cdr at `free`, then bump it
(:wat::core::defenum :sicp::Consed :wat::enum::Pure
  :C [p <- :wat::core::i64  mem <- :sicp::Mem])

(:wat::core::defn :sicp::mcons [m <- :sicp::Mem a <- :wat::core::i64 d <- :wat::core::i64] -> :sicp::Consed
  (:wat::core::let [i (:sicp::Mem/free m)]
    (:sicp::Consed.C {:p i
                      :mem (:sicp::Mem :cars (:wat::map::assoc (:sicp::Mem/cars m) i a)
                                       :cdrs (:wat::map::assoc (:sicp::Mem/cdrs m) i d)
                                       :free (:wat::core::+ i 1))})))

;; build a chain from a vector of values; -1 is nil
(:wat::core::defn :sicp::build-list [m <- :sicp::Mem vals <- :sicp::Ints i <- :wat::core::i64] -> :sicp::Consed
  (:wat::core::if (:wat::core::>= i (:wat::core::length vals)) (:sicp::Consed.C {:p -1 :mem m})
    (:wat::core::match (:sicp::build-list m vals (:wat::core::+ i 1))
      [:sicp::Consed.C {:p tail :mem m1} (:sicp::mcons m1 (:wat::core::nth vals i) tail)])))

(:wat::core::defn :sicp::mlist->vec [m <- :sicp::Mem p <- :wat::core::i64 acc <- :sicp::Ints] -> :sicp::Ints
  (:wat::core::if (:wat::core::= p -1) acc
    (:sicp::mlist->vec m (:sicp::mcdr m p) (:wat::core::conj acc (:sicp::mcar m p)))))

;; ---- stop and copy
;; `fwd` is the broken-heart table: old index -> new index, for cells already copied
(:wat::core::defenum :sicp::Reloc :wat::enum::Pure
  :R [p <- :wat::core::i64  mem <- :sicp::Mem  fwd <- :sicp::Cells])

(:wat::core::defn :sicp::forwarded [fwd <- :sicp::Cells p <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:wat::map::get fwd p)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} -1]))

(:wat::core::defn :sicp::relocate
  [old <- :sicp::Mem p <- :wat::core::i64 new <- :sicp::Mem fwd <- :sicp::Cells] -> :sicp::Reloc
  (:wat::core::if (:wat::core::= p -1) (:sicp::Reloc.R {:p -1 :mem new :fwd fwd})
    (:wat::core::let [already (:sicp::forwarded fwd p)]
      (:wat::core::if (:wat::core::>= already 0)
        ;; a broken heart: this cell has already been copied, so point at the copy
        (:sicp::Reloc.R {:p already :mem new :fwd fwd})
        (:wat::core::let [i (:sicp::Mem/free new)
                          ;; the car is copied and the heart is broken BEFORE recurring, which is
                          ;; what makes a shared tail copy once
                          new1 (:sicp::Mem :cars (:wat::map::assoc (:sicp::Mem/cars new) i (:sicp::mcar old p))
                                           :cdrs (:sicp::Mem/cdrs new)
                                           :free (:wat::core::+ i 1))
                          fwd1 (:wat::map::assoc fwd p i)]
          (:wat::core::match (:sicp::relocate old (:sicp::mcdr old p) new1 fwd1)
            [:sicp::Reloc.R {:p tail :mem new2 :fwd fwd2}
              (:sicp::Reloc.R {:p i
                               :mem (:sicp::Mem :cars (:sicp::Mem/cars new2)
                                                :cdrs (:wat::map::assoc (:sicp::Mem/cdrs new2) i tail)
                                                :free (:sicp::Mem/free new2))
                               :fwd fwd2})]))))))

(:wat::core::defenum :sicp::Collected :wat::enum::Pure
  :G [roots <- :sicp::Ints  mem <- :sicp::Mem])

(:wat::core::defn :sicp::collect-from
  [old <- :sicp::Mem roots <- :sicp::Ints i <- :wat::core::i64
   new <- :sicp::Mem fwd <- :sicp::Cells acc <- :sicp::Ints] -> :sicp::Collected
  (:wat::core::if (:wat::core::>= i (:wat::core::length roots)) (:sicp::Collected.G {:roots acc :mem new})
    (:wat::core::match (:sicp::relocate old (:wat::core::nth roots i) new fwd)
      [:sicp::Reloc.R {:p p :mem new2 :fwd fwd2}
        (:sicp::collect-from old roots (:wat::core::+ i 1) new2 fwd2 (:wat::core::conj acc p))])))

(:wat::core::defn :sicp::collect [old <- :sicp::Mem roots <- :sicp::Ints] -> :sicp::Collected
  (:sicp::collect-from old roots 0 (:sicp::mk-mem)
    (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64])
    (:wat::core::Vector :- [:wat::core::i64])))

;; ---- printing, as the Scheme oracle prints
(:wat::core::defn :sicp::show-ints [xs <- :sicp::Ints] -> :wat::core::String
  (:wat::string::concat "("
    (:wat::string::join " " (:wat::core::mapv (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String
                                                (:wat::i64::to-string n)) xs)) ")"))

(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :sicp::show-list [m <- :sicp::Mem p <- :wat::core::i64] -> :wat::core::String
  (:sicp::show-ints (:sicp::mlist->vec m p (:wat::core::Vector :- [:wat::core::i64]))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [k <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string k))
                    built (:sicp::build-list (:sicp::mk-mem) (:wat::core::Vector :- [:wat::core::i64] 1 2 3) 0)
                    lst (:wat::core::match built [:sicp::Consed.C {:p p :mem m} p])
                    mem1 (:wat::core::match built [:sicp::Consed.C {:p p :mem m} m])
                    ;; a second list SHARING the tail of the first
                    built2 (:sicp::mcons mem1 99 (:sicp::mcdr mem1 lst))
                    shared (:wat::core::match built2 [:sicp::Consed.C {:p p :mem m} p])
                    mem2 (:wat::core::match built2 [:sicp::Consed.C {:p p :mem m} m])
                    ;; collect with BOTH live
                    c1 (:sicp::collect mem2 (:wat::core::Vector :- [:wat::core::i64] lst shared))
                    r1 (:wat::core::match c1 [:sicp::Collected.G {:roots r :mem m} r])
                    m3 (:wat::core::match c1 [:sicp::Collected.G {:roots r :mem m} m])
                    ;; collect with only the FIRST live
                    c2 (:sicp::collect mem2 (:wat::core::Vector :- [:wat::core::i64] lst))
                    r2 (:wat::core::match c2 [:sicp::Collected.G {:roots r :mem m} r])
                    m4 (:wat::core::match c2 [:sicp::Collected.G {:roots r :mem m} m])
                    ;; collect with NOTHING live
                    c3 (:sicp::collect mem2 (:wat::core::Vector :- [:wat::core::i64]))
                    m5 (:wat::core::match c3 [:sicp::Collected.G {:roots r :mem m} m])]
    (:sicp::check-chapter "oracle/sicp/ch53-garbage-collection.expected"
                          "sicp ch53 garbage collection"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:sicp::show-list mem1 lst)
                            (int (:sicp::Mem/free mem1))
                            (:sicp::show-list mem2 shared)
                            (int (:sicp::Mem/free mem2))
                            (:sicp::b (:wat::core::= (:sicp::mcdr mem2 shared) (:sicp::mcdr mem2 lst)))
                            (:sicp::show-list m3 (:wat::core::nth r1 0))
                            (:sicp::show-list m3 (:wat::core::nth r1 1))
                            (int (:sicp::Mem/free m3))
                            ;; the shared tail is STILL shared -- this is what broken hearts buy
                            (:sicp::b (:wat::core::= (:sicp::mcdr m3 (:wat::core::nth r1 1))
                                                     (:sicp::mcdr m3 (:wat::core::nth r1 0))))
                            (:sicp::show-list m4 (:wat::core::nth r2 0))
                            (int (:sicp::Mem/free m4))
                            (int (:wat::core::- (:sicp::Mem/free mem2) (:sicp::Mem/free m4)))
                            (int (:sicp::Mem/free m5))))))
