;; eopl/lib/exceptions.wat — EOPL chapter 5.4: exceptions as continuation frames.
;;
;; The same move as the threads chapter, aimed at a different wat finding. F-063: wat's ONLY
;; general catch is `:wat::test::run-thread`, which expands to `spawn-thread-program` and costs
;; about 1.3 ms -- recovery in wat means starting a thread. Here a handler is just a frame in the
;; continuation, and `raise` walks the chain to the nearest one. No thread, no allocation beyond
;; the frame itself.
;;
;; A separate little language rather than an extension of `:eopl::Exp`, because adding a variant
;; there would break the exhaustive matches in direct.wat, cps.wat and types.wat -- which is wat's
;; exhaustiveness checking doing its job, and the reason each chapter here gets its own syntax.

(:wat::core::defenum :exn::Exp :wat::enum::Pure
  :Lit   [n <- :wat::core::i64]
  :Var   [name <- :wat::core::String]
  :Add   [a <- :exn::Exp  b <- :exn::Exp]
  :Div   [a <- :exn::Exp  b <- :exn::Exp]
  :Let   [name <- :wat::core::String  e <- :exn::Exp  body <- :exn::Exp]
  :Raise [e <- :exn::Exp]
  :Try   [body <- :exn::Exp  var <- :wat::core::String  handler <- :exn::Exp]
  :Rep   [times <- :wat::core::i64  body <- :exn::Exp])

(:wat::core::defenum :exn::Env :wat::enum::Pure
  :E0 []
  :E1 [name <- :wat::core::String  v <- :wat::core::i64  rest <- :exn::Env])

(:wat::core::defn :exn::look [env <- :exn::Env name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match env
    [:exn::Env.E0 {} 0]
    [:exn::Env.E1 {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:exn::look rest name))]))

(:wat::core::defenum :exn::K :wat::enum::Pure
  :KEnd  []
  :KAdd1 [b <- :exn::Exp  env <- :exn::Env  k <- :exn::K]
  :KAdd2 [v <- :wat::core::i64  k <- :exn::K]
  :KDiv1 [b <- :exn::Exp  env <- :exn::Env  k <- :exn::K]
  :KDiv2 [v <- :wat::core::i64  k <- :exn::K]
  :KLet  [name <- :wat::core::String  body <- :exn::Exp  env <- :exn::Env  k <- :exn::K]
  :KRaise [k <- :exn::K]
  :KRep  [left <- :wat::core::i64  body <- :exn::Exp  env <- :exn::Env  k <- :exn::K]
  ;; THE HANDLER FRAME. This is the whole mechanism.
  :KTry  [var <- :wat::core::String  handler <- :exn::Exp  env <- :exn::Env  k <- :exn::K])

(:wat::core::defenum :exn::St :wat::enum::Pure
  :Ev   [e <- :exn::Exp  env <- :exn::Env  k <- :exn::K]
  :Ap   [k <- :exn::K  v <- :wat::core::i64]
  ;; unwinding: carry the raised value up the continuation until a KTry is found
  :Un   [k <- :exn::K  v <- :wat::core::i64]
  :Done [v <- :wat::core::i64  caught <- :wat::core::bool])

(:wat::core::defn :exn::step [s <- :exn::St] -> :exn::St
  (:wat::core::match s
    [:exn::St.Done {:v v :caught c} s]
    [:exn::St.Ev {:e e :env env :k k}
      (:wat::core::match e
        [:exn::Exp.Lit {:n n} (:exn::St.Ap {:k k :v n})]
        [:exn::Exp.Var {:name name} (:exn::St.Ap {:k k :v (:exn::look env name)})]
        [:exn::Exp.Add {:a a :b b} (:exn::St.Ev {:e a :env env :k (:exn::K.KAdd1 {:b b :env env :k k})})]
        [:exn::Exp.Div {:a a :b b} (:exn::St.Ev {:e a :env env :k (:exn::K.KDiv1 {:b b :env env :k k})})]
        [:exn::Exp.Let {:name name :e rhs :body body}
          (:exn::St.Ev {:e rhs :env env :k (:exn::K.KLet {:name name :body body :env env :k k})})]
        [:exn::Exp.Raise {:e inner} (:exn::St.Ev {:e inner :env env :k (:exn::K.KRaise {:k k})})]
        [:exn::Exp.Try {:body body :var var :handler handler}
          (:exn::St.Ev {:e body :env env :k (:exn::K.KTry {:var var :handler handler :env env :k k})})]
        [:exn::Exp.Rep {:times times :body body}
          (:wat::core::if (:wat::core::<= times 0)
            (:exn::St.Ap {:k k :v 0})
            (:exn::St.Ev {:e body :env env
                          :k (:exn::K.KRep {:left (:wat::core::- times 1) :body body :env env :k k})}))])]
    [:exn::St.Ap {:k k :v v}
      (:wat::core::match k
        [:exn::K.KEnd {} (:exn::St.Done {:v v :caught false})]
        [:exn::K.KAdd1 {:b b :env env :k k2} (:exn::St.Ev {:e b :env env :k (:exn::K.KAdd2 {:v v :k k2})})]
        [:exn::K.KAdd2 {:v v1 :k k2} (:exn::St.Ap {:k k2 :v (:wat::core::+ v1 v)})]
        [:exn::K.KDiv1 {:b b :env env :k k2} (:exn::St.Ev {:e b :env env :k (:exn::K.KDiv2 {:v v :k k2})})]
        ;; division by zero RAISES, which is what makes the handler worth having
        [:exn::K.KDiv2 {:v v1 :k k2}
          (:wat::core::if (:wat::core::= v 0)
            (:exn::St.Un {:k k2 :v -1})
            (:exn::St.Ap {:k k2 :v (:wat::core::/ v1 v)}))]
        [:exn::K.KLet {:name name :body body :env env :k k2}
          (:exn::St.Ev {:e body :env (:exn::Env.E1 {:name name :v v :rest env}) :k k2})]
        [:exn::K.KRaise {:k k2} (:exn::St.Un {:k k2 :v v})]
        [:exn::K.KRep {:left left :body body :env env :k k2}
          (:wat::core::if (:wat::core::<= left 0)
            (:exn::St.Ap {:k k2 :v v})
            (:exn::St.Ev {:e body :env env
                          :k (:exn::K.KRep {:left (:wat::core::- left 1) :body body :env env :k k2})}))]
        ;; a Try whose body finished normally: drop the handler frame
        [:exn::K.KTry {:var var :handler handler :env env :k k2} (:exn::St.Ap {:k k2 :v v})])]
    ;; UNWINDING: walk the continuation to the nearest handler frame
    [:exn::St.Un {:k k :v v}
      (:wat::core::match k
        [:exn::K.KEnd {} (:exn::St.Done {:v v :caught false})]
        [:exn::K.KTry {:var var :handler handler :env env :k k2}
          (:exn::St.Ev {:e handler :env (:exn::Env.E1 {:name var :v v :rest env}) :k k2})]
        [:exn::K.KAdd1 {:b b :env env :k k2} (:exn::St.Un {:k k2 :v v})]
        [:exn::K.KAdd2 {:v v1 :k k2} (:exn::St.Un {:k k2 :v v})]
        [:exn::K.KDiv1 {:b b :env env :k k2} (:exn::St.Un {:k k2 :v v})]
        [:exn::K.KDiv2 {:v v1 :k k2} (:exn::St.Un {:k k2 :v v})]
        [:exn::K.KLet {:name name :body body :env env :k k2} (:exn::St.Un {:k k2 :v v})]
        [:exn::K.KRaise {:k k2} (:exn::St.Un {:k k2 :v v})]
        [:exn::K.KRep {:left left :body body :env env :k k2} (:exn::St.Un {:k k2 :v v})])]))

(:wat::core::defn :exn::drive [s <- :exn::St] -> :exn::St
  (:wat::core::match s
    [:exn::St.Done {:v v :caught c} s]
    [:exn::St.Ev {:e e :env env :k k} (:exn::drive (:exn::step s))]
    [:exn::St.Ap {:k k :v v} (:exn::drive (:exn::step s))]
    [:exn::St.Un {:k k :v v} (:exn::drive (:exn::step s))]))

(:wat::core::defn :exn::run [e <- :exn::Exp] -> :wat::core::i64
  (:wat::core::match (:exn::drive (:exn::St.Ev {:e e :env (:exn::Env.E0 {}) :k (:exn::K.KEnd {})}))
    [:exn::St.Done {:v v :caught c} v]
    [:exn::St.Ev {:e e :env env :k k} -99]
    [:exn::St.Ap {:k k :v v} -99]
    [:exn::St.Un {:k k :v v} -99]))

;; transition counter -- the machine-independent cost of a catch. The wall-clock cost of the guest
;; is dominated by wat interpreting it (~14 us per transition, measured in the CEK notes), so a
;; wall-clock comparison against wat's own catch measures the interpreter, not the mechanism.
(:wat::core::defn :exn::drive-count [s <- :exn::St n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match s
    [:exn::St.Done {:v v :caught c} n]
    [:exn::St.Ev {:e e :env env :k k} (:exn::drive-count (:exn::step s) (:wat::core::+ n 1))]
    [:exn::St.Ap {:k k :v v} (:exn::drive-count (:exn::step s) (:wat::core::+ n 1))]
    [:exn::St.Un {:k k :v v} (:exn::drive-count (:exn::step s) (:wat::core::+ n 1))]))

(:wat::core::defn :exn::steps [e <- :exn::Exp] -> :wat::core::i64
  (:exn::drive-count (:exn::St.Ev {:e e :env (:exn::Env.E0 {}) :k (:exn::K.KEnd {})}) 0))
