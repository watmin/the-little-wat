;; mutual-recursive-enums.wat: The Little MLer's mutually recursive datatypes,
;;   'a slist = Empty | Scons of 'a sexp * 'a slist
;;   'a sexp  = An_atom of 'a | A_slist of 'a slist
;; as two generic enums that refer to each other, and two mutually recursive fns over them.
;; Expected: 3
(:wat::core::defenum :u::Slist :- [A] :wat::enum::Pure
  :Empty []
  :Scons [head <- (:u::Sexp :- [A]) tail <- (:u::Slist :- [A])])
(:wat::core::defenum :u::Sexp :- [A] :wat::enum::Pure
  :Atom  [v <- A]
  :Slist [l <- (:u::Slist :- [A])])
(:wat::core::defn :u::count-slist :- [A] [l <- (:u::Slist :- [A])] -> :wat::core::i64
  (:wat::core::match l
    [:u::Slist.Empty {} 0]
    [:u::Slist.Scons {:head h :tail t} (:wat::core::+ (:u::count-sexp h) (:u::count-slist t))]))
(:wat::core::defn :u::count-sexp :- [A] [s <- (:u::Sexp :- [A])] -> :wat::core::i64
  (:wat::core::match s
    [:u::Sexp.Atom {:v _v} 1]
    [:u::Sexp.Slist {:l l} (:u::count-slist l)]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  ;; (1 (2 3)) as an slist of i64: three atoms
  (:wat::kernel::println
    (:u::count-slist
      (:u::Slist.Scons {:head (:u::Sexp.Atom {:v 1})
                        :tail (:u::Slist.Scons {:head (:u::Sexp.Slist {:l (:u::Slist.Scons {:head (:u::Sexp.Atom {:v 2})
                                                                                          :tail (:u::Slist.Scons {:head (:u::Sexp.Atom {:v 3})
                                                                                                                  :tail (:u::Slist.Empty {})})})})
                                                :tail (:u::Slist.Empty {})})}))))
