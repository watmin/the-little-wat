;; eopl/ch05-threads.wat — EOPL chapter 5's THREADS: the primitive wat does not have.
;;
;; This closes a loop across three findings:
;;
;;   C-053  wat's own services CANNOT lose an update. The actor serialises, so Downey's chapter-1
;;          hazard is structurally unrepresentable -- 1600/1600 on five runs.
;;   F-102  and wat CANNOT BLOCK A CALLER. `Outcome.NoReply` withholds a reply and nothing can
;;          ever release that caller, so every blocking primitive in wat must be a spin (C-054's
;;          barrier costs 18 poll round-trips for want of one).
;;   here   once a continuation is a DATA STRUCTURE, both are trivial. A thread is a continuation,
;;          the scheduler is a queue of them, blocking is "move this one to the blocked list and
;;          run someone else", waking is "move it back". Fourteen lines of `:thr::step`.
;;
;; So the interpreted language gets a real mutex while its host cannot express one -- and it also
;; gets the hazard back, on purpose: `get` and `put` are separate expressions, so a thread can be
;; preempted between reading the counter and writing it. That is the lost update, and the time
;; slice controls whether it happens.
;;
;; Run: wat eopl/ch05-threads.wat

(:wat::load-file! "lib/threads.wat")

(:wat::core::defn :t5::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

(:wat::core::defn :t5::n [] -> :wat::core::i64 40)

;; let v = get() in put(v + 1)   -- read and write are SEPARATE, so this can be preempted
(:wat::core::defn :t5::bump [] -> :thr::Exp
  (:thr::Exp.Let {:name "v" :e (:thr::Exp.Get {})
                  :body (:thr::Exp.Put {:e (:thr::Exp.Add {:a (:thr::Exp.Var {:name "v"})
                                                           :b (:thr::Exp.Lit {:n 1})})})}))

;; lock(); bump(); unlock()
(:wat::core::defn :t5::bump-locked [] -> :thr::Exp
  (:thr::Exp.Seq {:a (:thr::Exp.Lock {})
                  :b (:thr::Exp.Seq {:a (:t5::bump) :b (:thr::Exp.Unlock {})})}))

(:wat::core::defn :t5::worker [body <- :thr::Exp] -> :thr::Exp
  (:thr::Exp.Repeat {:times (:t5::n) :body body}))

;; spawn two workers and let the scheduler drain them
(:wat::core::defn :t5::program [body <- :thr::Exp] -> :thr::Exp
  (:thr::Exp.Seq {:a (:thr::Exp.Spawn {:body (:t5::worker body)})
                  :b (:thr::Exp.Seq {:a (:thr::Exp.Spawn {:body (:t5::worker body)})
                                     :b (:thr::Exp.Lit {:n 0})})}))

(:wat::core::defn :t5::row [label <- :wat::core::String body <- :thr::Exp slice <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let [got (:thr::run (:t5::program body) slice 2000000)
                    want (:wat::core::* 2 (:t5::n))]
    (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
      "  " label
      "  slice=" (:wat::i64::to-string slice)
      "   counter=" (:wat::i64::to-string got) " / " (:wat::i64::to-string want)
      "   " (:wat::core::if (:wat::core::= got want) "no lost update" "LOST UPDATES"))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- two threads, 40 increments each, read and write as separate steps ----")
    (:t5::row "no lock  " (:t5::bump) 1)
    (:t5::row "no lock  " (:t5::bump) 2)
    (:t5::row "no lock  " (:t5::bump) 1000)
    (:wat::kernel::println "---- the same, holding a mutex the host language cannot express (F-102) ----")
    (:t5::row "with lock" (:t5::bump-locked) 1)
    (:t5::row "with lock" (:t5::bump-locked) 2)))
