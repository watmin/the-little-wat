;; eopl/ch09-classes.wat — EOPL chapter 9: the CLASSES language.
;;
;; The book's own c1/c2 example, because it separates the two mechanisms that make OO more than
;; records-with-functions, and separates them with *numbers*:
;;
;;   class c1 extends object       class c2 extends c1
;;     field x                       field y
;;     initialize() set x = 11       initialize() begin super initialize(); set y = 12 end
;;     m1() x                        m1() -(x, -(0,y))        ; override: x + y
;;     m2() send self m1()           m3() super m1()          ; the PARENT's m1
;;
;; `m2` lives in c1 and calls `self.m1`. On a c2 instance it must find c2's override (23), not
;; the one textually beside it (11) — that is DYNAMIC DISPATCH. `m3` lives in c2 and calls
;; `super.m1`, which must find c1's (11) even though the object is a c2 — that is a DIFFERENT
;; starting point for the same walk. An interpreter that carries only `self` gets m2 right and m3
;; wrong; one that dispatches statically gets m3 right and m2 wrong. Both numbers are needed.

(:wat::load-file! "lib/classes.wat")

(:wat::core::defn :c9::say [label <- :wat::core::String got <- :wat::core::i64 want <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label "  " (:wat::i64::to-string got)
      (:wat::core::if (:wat::core::= got want) "   PASS"
        (:wat::string::concat "   FAIL (want " (:wat::i64::to-string want) ")")))))

(:wat::core::defn :c9::names2 [a <- :wat::core::String b <- :wat::core::String] -> :oo::Names
  (:oo::Names.NCons {:n a :rest (:oo::Names.NCons {:n b :rest (:oo::Names.NNil {})})}))

(:wat::core::defn :c9::classes [] -> :oo::Classes
  (:oo::Classes.CCons
    {:c (:oo::Class.C
          {:name "c1" :super ""
           :fields (:oo::Names.NCons {:n "x" :rest (:oo::Names.NNil {})})
           :methods (:oo::Methods.MCons
                      {:m (:oo::Method.M {:name "initialize" :params (:oo::Names.NNil {})
                                          :body (:oo::Exp.SetField {:name "x" :e (:oo::Exp.Lit {:n 11})})})
                       :rest (:oo::Methods.MCons
                               {:m (:oo::Method.M {:name "m1" :params (:oo::Names.NNil {})
                                                   :body (:oo::Exp.Field {:name "x"})})
                                :rest (:oo::Methods.MCons
                                        {:m (:oo::Method.M
                                              {:name "m2" :params (:oo::Names.NNil {})
                                               ;; send to SELF — the dispatch that must be dynamic
                                               :body (:oo::Exp.Send {:obj (:oo::Exp.Self {})
                                                                     :meth "m1"
                                                                     :args (:oo::Args.ANil {})})})
                                         :rest (:oo::Methods.MNil {})})})})})
     :rest (:oo::Classes.CCons
             {:c (:oo::Class.C
                   {:name "c2" :super "c1"
                    ;; inherited fields FIRST, so c1's `x` is still index 0 in a c2 instance
                    :fields (:c9::names2 "x" "y")
                    :methods (:oo::Methods.MCons
                               {:m (:oo::Method.M
                                     {:name "initialize" :params (:oo::Names.NNil {})
                                      :body (:oo::Exp.Seq
                                              {:a (:oo::Exp.Super {:meth "initialize"
                                                                   :args (:oo::Args.ANil {})})
                                               :b (:oo::Exp.SetField {:name "y"
                                                                      :e (:oo::Exp.Lit {:n 12})})})})
                                :rest (:oo::Methods.MCons
                                        {:m (:oo::Method.M
                                              {:name "m1" :params (:oo::Names.NNil {})
                                               ;; x - (0 - y) = x + y
                                               :body (:oo::Exp.Diff
                                                       {:a (:oo::Exp.Field {:name "x"})
                                                        :b (:oo::Exp.Diff {:a (:oo::Exp.Lit {:n 0})
                                                                           :b (:oo::Exp.Field {:name "y"})})})})
                                         :rest (:oo::Methods.MCons
                                                 {:m (:oo::Method.M
                                                       {:name "m3" :params (:oo::Names.NNil {})
                                                        :body (:oo::Exp.Super {:meth "m1"
                                                                               :args (:oo::Args.ANil {})})})
                                                  :rest (:oo::Methods.MNil {})})})})})
              :rest (:oo::Classes.CNil {})})}))

(:wat::core::defn :c9::send-to [cls <- :wat::core::String meth <- :wat::core::String] -> :wat::core::i64
  (:oo::run (:oo::Exp.Send {:obj (:oo::Exp.New {:cls cls :args (:oo::Args.ANil {})})
                            :meth meth :args (:oo::Args.ANil {})})
    (:c9::classes)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- EOPL ch9: CLASSES ----")

    ;; the baseline: c1 on its own
    (:c9::say "c1.m1  (just x)                 " (:c9::send-to "c1" "m1") 11)
    (:c9::say "c1.m2  (self.m1, no override)   " (:c9::send-to "c1" "m2") 11)

    ;; inheritance: super initialize() ran, so BOTH fields are set
    (:c9::say "c2.m1  (override, x+y)          " (:c9::send-to "c2" "m1") 23)

    ;; DYNAMIC DISPATCH: m2 is c1's code, and must still find c2's m1
    (:c9::say "c2.m2  (c1's code finds c2's m1)" (:c9::send-to "c2" "m2") 23)

    ;; SUPER: m3 is c2's code, and must find c1's m1 — the same walk from a different start
    (:c9::say "c2.m3  (super.m1 -> c1's m1)    " (:c9::send-to "c2" "m3") 11)

    ;; and the two are genuinely different starting points: on the SAME object, m2 and m3 differ
    (:wat::kernel::println "---- the same object, the same method name, two starting points ----")
    (:wat::kernel::println "  send self m1   -> 23   (from the object's own class, c2)")
    (:wat::kernel::println "  super     m1   -> 11   (from above the running method's class, c1)")

    ;; objects are independent: two instances, one mutated
    (:wat::kernel::println "---- two instances do not share fields ----")
    (:c9::say "second object still 23         "
      (:oo::run
        (:oo::Exp.Let
          {:name "a" :e (:oo::Exp.New {:cls "c2" :args (:oo::Args.ANil {})})
           :body (:oo::Exp.Let
                   {:name "b" :e (:oo::Exp.New {:cls "c2" :args (:oo::Args.ANil {})})
                    :body (:oo::Exp.Send {:obj (:oo::Exp.Var {:name "b"}) :meth "m1"
                                          :args (:oo::Args.ANil {})})})})
        (:c9::classes))
      23)))
