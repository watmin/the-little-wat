;; SICP §3.2 (the environment model of evaluation), in wat.
;;
;; §3.2 is the one section of chapter 3 that is not about mutation. It is about what a procedure
;; IS: code plus the frame it was created in, so applying one makes a new frame whose enclosing
;; frame is the PROCEDURE'S and not the caller's. That single rule is where lexical scoping comes
;; from, and it is the rule §3.1's local state (C-014, ch31) silently depends on.
;;
;; The section is usually taught with diagrams. Here the frames are DATA, so the claims are things
;; the model computes rather than things the reader is asked to see:
;;
;;   - a name resolves at the first enclosing frame that binds it, and `depth-of` says how far out;
;;   - a closure made in the global frame and applied "inside" another frame still sees the
;;     GLOBAL binding -- x is 10, not 99, and at depth 1;
;;   - two procedures from one maker have SEPARATE frames -- 100 and 200, not equal -- which is
;;     the whole reason a maker works at all.
;;
;; It also happens to be the smallest environment implementation in this repository, next to
;; EOPL's (C-061) and the three representations of §2.2's exercise (C-077). Nothing here needs
;; mutation, so nothing here needs a service.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch32-environment-model.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch32-environment-model.wat

(:wat::load-file! "lib/check.wat")

;; a frame is a list of bindings plus the enclosing frame; Empty is the end of the chain
(:wat::core::defenum :sicp::Env :wat::enum::Pure
  :Empty []
  :Frame [binds <- :sicp::Binds  enclosing <- :sicp::Env])

(:wat::core::defenum :sicp::Binds :wat::enum::Pure
  :BNil  []
  :BCons [name <- :wat::core::String  value <- :wat::core::i64  rest <- :sicp::Binds])

(:wat::core::defenum :sicp::Found :wat::enum::Pure
  :Hit  [value <- :wat::core::i64]
  :Miss [])

(:wat::core::defn :sicp::in-frame? [bs <- :sicp::Binds name <- :wat::core::String] -> :sicp::Found
  (:wat::core::match bs
    [:sicp::Binds.BNil {} (:sicp::Found.Miss {})]
    [:sicp::Binds.BCons {:name n :value v :rest rest}
      (:wat::core::if (:wat::core::= n name) (:sicp::Found.Hit {:value v})
        (:sicp::in-frame? rest name))]))

;; lookup walks OUT, and stops at the first frame that binds the name
(:wat::core::defn :sicp::lookup [name <- :wat::core::String env <- :sicp::Env] -> :sicp::Found
  (:wat::core::match env
    [:sicp::Env.Empty {} (:sicp::Found.Miss {})]
    [:sicp::Env.Frame {:binds bs :enclosing outer}
      (:wat::core::match (:sicp::in-frame? bs name)
        [:sicp::Found.Hit {:value v} (:sicp::Found.Hit {:value v})]
        [:sicp::Found.Miss {} (:sicp::lookup name outer)])]))

;; how many frames out did the name come from? -- lexical scoping, measured
(:wat::core::defn :sicp::depth-of [name <- :wat::core::String env <- :sicp::Env d <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match env
    [:sicp::Env.Empty {} -1]
    [:sicp::Env.Frame {:binds bs :enclosing outer}
      (:wat::core::match (:sicp::in-frame? bs name)
        [:sicp::Found.Hit {:value v} d]
        [:sicp::Found.Miss {} (:sicp::depth-of name outer (:wat::core::+ d 1))])]))

(:wat::core::defn :sicp::bind1 [n <- :wat::core::String v <- :wat::core::i64] -> :sicp::Binds
  (:sicp::Binds.BCons {:name n :value v :rest (:sicp::Binds.BNil {})}))

(:wat::core::defn :sicp::bind2 [n1 <- :wat::core::String v1 <- :wat::core::i64
                                n2 <- :wat::core::String v2 <- :wat::core::i64] -> :sicp::Binds
  (:sicp::Binds.BCons {:name n1 :value v1 :rest (:sicp::bind1 n2 v2)}))

;; ---- a procedure is code plus the frame it was MADE in
(:wat::core::defstruct :sicp::Proc [params <- :sicp::Binds  env <- :sicp::Env])

;; applying it extends the PROCEDURE'S frame, never the caller's -- this is the whole section
(:wat::core::defn :sicp::apply-proc [p <- :sicp::Proc args <- :sicp::Binds] -> :sicp::Env
  (:sicp::Env.Frame {:binds args :enclosing (:sicp::Proc/env p)}))

;; (define (make-counter start) (lambda () start)), called twice with different starts
(:wat::core::defn :sicp::make-counter [start <- :wat::core::i64 global <- :sicp::Env] -> :sicp::Proc
  (:sicp::Proc :params (:sicp::Binds.BNil {})
               :env (:sicp::Env.Frame {:binds (:sicp::bind1 "start" start) :enclosing global})))

;; ---- printing, as the Scheme oracle prints ('unbound is a symbol, so it prints bare)
(:wat::core::defn :sicp::show-found [f <- :sicp::Found] -> :wat::core::String
  (:wat::core::match f
    [:sicp::Found.Hit {:value v} (:wat::i64::to-string v)]
    [:sicp::Found.Miss {} "unbound"]))

(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :sicp::same? [a <- :sicp::Found b <- :sicp::Found] -> :wat::core::bool
  (:wat::core::match a
    [:sicp::Found.Hit {:value x}
      (:wat::core::match b
        [:sicp::Found.Hit {:value y} (:wat::core::= x y)]
        [:sicp::Found.Miss {} false])]
    [:sicp::Found.Miss {}
      (:wat::core::match b
        [:sicp::Found.Miss {} true]
        [:sicp::Found.Hit {:value y} false])]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [k <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string k))
                    global (:sicp::Env.Frame {:binds (:sicp::bind2 "x" 10 "y" 20)
                                              :enclosing (:sicp::Env.Empty {})})
                    inner (:sicp::Env.Frame {:binds (:sicp::bind2 "x" 99 "z" 5) :enclosing global})
                    ;; a procedure MADE in `global`, then applied while `inner` is in play
                    p1 (:sicp::Proc :params (:sicp::Binds.BNil {}) :env global)
                    call-frame (:sicp::apply-proc p1 (:sicp::bind1 "a" 7))
                    c1 (:sicp::make-counter 100 global)
                    c2 (:sicp::make-counter 200 global)]
    (:sicp::check-chapter "oracle/sicp/ch32-environment-model.expected"
                          "sicp ch32 environment model"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:sicp::show-found (:sicp::lookup "x" global))
                            (:sicp::show-found (:sicp::lookup "y" global))
                            (:sicp::show-found (:sicp::lookup "q" global))
                            (:sicp::show-found (:sicp::lookup "x" inner))
                            (:sicp::show-found (:sicp::lookup "y" inner))
                            (:sicp::show-found (:sicp::lookup "z" inner))
                            (int (:sicp::depth-of "x" inner 0))
                            (int (:sicp::depth-of "y" inner 0))
                            (int (:sicp::depth-of "q" inner 0))
                            (:sicp::show-found (:sicp::lookup "a" call-frame))
                            (:sicp::show-found (:sicp::lookup "x" call-frame))
                            (int (:sicp::depth-of "x" call-frame 0))
                            (:sicp::show-found (:sicp::lookup "start" (:sicp::Proc/env c1)))
                            (:sicp::show-found (:sicp::lookup "start" (:sicp::Proc/env c2)))
                            (:sicp::b (:sicp::same? (:sicp::lookup "start" (:sicp::Proc/env c1))
                                                    (:sicp::lookup "start" (:sicp::Proc/env c2))))
                            (:sicp::show-found (:sicp::lookup "y" (:sicp::Proc/env c1)))
                            (int (:sicp::depth-of "start" (:sicp::Proc/env c1) 0))
                            (int (:sicp::depth-of "y" (:sicp::Proc/env c1) 0))))))
