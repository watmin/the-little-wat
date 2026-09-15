;; koans/idiom/16-refs.wat: the refs koans (koans/literal/16-refs.tsv), each said the way wat
;; says it, or marked as having no wat route. Keyword spelling throughout, so the checker sees
;; every call (F-014). Markers as in koans/idiom/01-equalities.wat.
;;
;; A ref is state, and state lives on a service (C-014). Here a StrCell holds one String, the
;; service written out as every shape of state is (P-002), and the Seasoned Schemer's counter
;; holds the rows' numbers: a cell holds one type, where the koans' ref holds a String, then a
;; number, then a map. A get and a put are two messages, so alter is not atomic, and there are
;; no transactions.
;;
;; Run from the repository root: wat koans/idiom/16-refs.wat

(:wat::load-file! "../../books/seasoned-schemer/lib/counter.wat")

(:wat::core::defsurface :koan::StrCell :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :koan::StrCell::GetRequest [])
   (:wat::core::defenum :koan::StrCell::GetResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::String]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :koan::StrCell::PutRequest [value <- :wat::core::String])
   (:wat::core::defenum :koan::StrCell::PutResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::String]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(get [self <- :koan::StrCell  req <- :koan::StrCell::GetRequest] -> :koan::StrCell::GetResponse :max-request-bytes 524288)
   (put [self <- :koan::StrCell  req <- :koan::StrCell::PutRequest] -> :koan::StrCell::PutResponse :max-request-bytes 524288)])

(:wat::service::defservice :koan::str-cell
  :satisfies :koan::StrCell
  :durable [value <- :wat::core::String]
  :ephemeral []
  :impls
  [(get [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:koan::StrCell::GetResponse.Ok {:value (:koan::str-cell::Record/value (:koan::str-cell::State/durable s))})}))
   (put [s ctx req]
     (:wat::core::let [v (:koan::StrCell::PutRequest/value req)]
       (:wat::service::Outcome.Reply
         {:state (:koan::str-cell::State :durable (:koan::str-cell::Record :value v))
          :reply (:koan::StrCell::PutResponse.Ok {:value v})})))])

(:wat::core::defstruct :koan::StrCellRef
  [handle <- :koan::str-cell::Handle
   peer   <- :koan::StrCell])

(:wat::core::defn :koan::new-str-cell [v <- :wat::core::String] -> :koan::StrCellRef
  (:wat::core::let
    [h (:koan::str-cell/start :locus (:wat::spawn::thread) :record (:koan::str-cell::Record :value v))
     peer (:wat::core::match (:wat::kernel::connect (:koan::str-cell::Handle/addr h))
            [:wat::kernel::ConnectOutcome.Connected {:peer c} c]
            [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
            [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
            [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:koan::StrCellRef :handle h :peer peer)))

(:wat::core::defn :koan::cell-get [c <- :koan::StrCellRef] -> :wat::core::String
  (:wat::core::match (:koan::StrCell/get (:koan::StrCellRef/peer c) (:koan::StrCell::GetRequest))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:koan::StrCell::GetResponse.Ok {:value v} v]
        [:koan::StrCell::GetResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "str cell get: request too large")]
        [:koan::StrCell::GetResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "str cell get: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "str cell get: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "str cell get: closed")]))

(:wat::core::defn :koan::cell-put! [c <- :koan::StrCellRef v <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:koan::StrCell/put (:koan::StrCellRef/peer c) (:koan::StrCell::PutRequest :value v))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:koan::StrCell::PutResponse.Ok {:value x} x]
        [:koan::StrCell::PutResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "str cell put: request too large")]
        [:koan::StrCell::PutResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "str cell put: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "str cell put: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "str cell put: closed")]))

;; alter: get, apply, put (two messages, not atomic)
(:wat::core::defn :koan::alter! [c <- :koan::StrCellRef f <- [:wat::core::String :-> :wat::core::String]] -> :wat::core::String
  (:koan::cell-put! c (f (:koan::cell-get c))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [planet (:koan::new-str-cell "earth")
                    number (:ss::new-counter 0)
                    bang (:wat::core::fn [x <- :wat::core::String] -> :wat::core::String (:wat::string::concat x "!"))]
    (:wat::core::do
      (:wat::test::assert-eq (:koan::cell-get planet) "earth") ; row 1
      (:wat::test::assert-eq (:koan::cell-get planet) "earth") ; row 2
      (:wat::test::assert-eq (:wat::core::do (:koan::cell-put! planet "mars") (:koan::cell-get planet)) "mars") ; row 3
      (:wat::test::assert-eq (:wat::core::do (:koan::cell-put! planet "mars") (:koan::alter! planet bang) (:koan::alter! planet bang) (:koan::cell-get planet)) "mars!!") ; row 4
      ;; a number, in its own cell: a cell holds one type
      (:wat::test::assert-eq (:wat::core::do (:ss::counter-reset! number 0) (:ss::counter-get number)) 0) ; row 5
      (:wat::test::assert-eq (:wat::core::do (:ss::counter-reset! number 10) (:ss::counter-reset! number (:wat::core::* 2 (:ss::counter-get number)))) 20) ; row 6
      ;; row 7 refused: there are no transactions; two services change one message at a time, and nothing makes the pair atomic
      (:wat::kernel::println "koans idiom 16-refs: ok"))))
