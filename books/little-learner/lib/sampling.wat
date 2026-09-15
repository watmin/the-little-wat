;; books/little-learner/lib/sampling.wat: malt's sampling (malted/J-stochastic.rkt), ported
;; to wat. Ported from malt (https://github.com/themetaschemer/malt), MIT License,
;; Copyright (c) 2021 Anurag Mendhekar, Daniel P. Friedman (vendor/malt/LICENSE).
;; Needs ../../seasoned-schemer/lib/counter.wat and lib/malt.wat loaded first; kept apart from
;; malt.wat so the chapters that never sample need no service.

;; ---- sampling
;;
;; malt draws each batch with Racket's (random n), from a mutable global generator. wat has
;; no random numbers (F-036) and keeps mutable state on services, so here the draws malt
;; makes are recorded by the oracle (NAME.draws) and replayed: a Draws is that sequence plus
;; a counter service (the Seasoned Schemer's, books/seasoned-schemer/lib/counter.wat) holding
;; how many have been used. The runner must load counter.wat.

(:wat::core::defstruct :ll::Draws
  [seq <- :ll::Ints
   used <- :ss::CounterRef])

;; (trefs t b): the rows of t at the indices in b, in b's order.
(:wat::core::defn :ll::trefs [t <- :ll::V b <- :ll::Ints] -> :ll::V
  (:ll::tensor (:wat::core::mapv (:wat::core::fn [i <- :wat::core::i64] -> :ll::V (:ll::tref t i)) b)))

;; (samples n s): the next s draws, below n, reversed, as malt's sampled conses them.
(:wat::core::defn :ll::samples [d <- :ll::Draws s <- :wat::core::i64] -> :ll::Ints
  (:wat::core::let [end (:ss::counter-add! (:ll::Draws/used d) s)
                    start (:wat::core::- end s)]
    (:wat::core::reverse
      (:wat::core::mapv (:wat::core::fn [j <- :wat::core::i64] -> :wat::core::i64 (:wat::core::nth (:ll::Draws/seq d) j))
                        (:wat::core::range start end)))))

;; (sampling-obj expectant xs ys): an objective whose every call is the expectant's loss over
;; a fresh batch of batch-size rows.
(:wat::core::defn :ll::sampling-obj
  [h <- :ll::Hypers
   d <- :ll::Draws
   expectant <- [:ll::V :ll::V :-> [:ll::V :-> :ll::V]]
   xs <- :ll::V
   ys <- :ll::V]
  -> [:ll::V :-> :ll::V]
  (:wat::core::fn [theta <- :ll::V] -> :ll::V
    (:wat::core::let [b (:ll::samples d (:ll::Hypers/batch-size h))]
      ((expectant (:ll::trefs xs b) (:ll::trefs ys b)) theta))))
