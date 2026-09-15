;; SICP §3.3 (mutable data), in wat: a queue, and a table.
;;
;; The book's queue is two pointers into one list, and inserting at the rear is a set-cdr! on
;; the last pair. wat has no mutable pairs, so the same shape would need the Arena of the
;; Seasoned Schemer (C-016). Here each is what wat's doctrine asks for instead: a service
;; holding the whole sequence, and a service holding the whole table. The operations are its
;; messages.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch33-mutable-data.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch33-mutable-data.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :sicp::Ints (:wat::core::Vector :- [:wat::core::i64]))

;; ---- a queue: a service holding the whole sequence

(:wat::core::defsurface :sicp::Queue :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :sicp::Queue::InsertRequest [item <- :wat::core::i64])
   (:wat::core::defenum :sicp::Queue::InsertResponse :wat::enum::Pure
     :Ok               [items <- (:wat::core::Vector :- [:wat::core::i64])]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :sicp::Queue::DeleteRequest [])
   (:wat::core::defenum :sicp::Queue::DeleteResponse :wat::enum::Pure
     :Ok               [items <- (:wat::core::Vector :- [:wat::core::i64])]
     :Empty            []
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :sicp::Queue::ItemsRequest [])
   (:wat::core::defenum :sicp::Queue::ItemsResponse :wat::enum::Pure
     :Ok               [items <- (:wat::core::Vector :- [:wat::core::i64])]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(insert [self <- :sicp::Queue  req <- :sicp::Queue::InsertRequest] -> :sicp::Queue::InsertResponse :max-request-bytes 524288)
   (delete [self <- :sicp::Queue  req <- :sicp::Queue::DeleteRequest] -> :sicp::Queue::DeleteResponse :max-request-bytes 524288)
   (items  [self <- :sicp::Queue  req <- :sicp::Queue::ItemsRequest]  -> :sicp::Queue::ItemsResponse  :max-request-bytes 524288)])

(:wat::service::defservice :sicp::queue
  :satisfies :sicp::Queue
  :durable [items <- (:wat::core::Vector :- [:wat::core::i64])]
  :ephemeral []
  :impls
  [(insert [s ctx req]
     (:wat::core::let [items (:wat::core::conj (:sicp::queue::Record/items (:sicp::queue::State/durable s)) (:sicp::Queue::InsertRequest/item req))]
       (:wat::service::Outcome.Reply
         {:state (:sicp::queue::State :durable (:sicp::queue::Record :items items))
          :reply (:sicp::Queue::InsertResponse.Ok {:items items})})))
   (delete [s ctx req]
     (:wat::core::let [items (:sicp::queue::Record/items (:sicp::queue::State/durable s))]
       (:wat::core::if (:wat::core::empty? items)
         (:wat::service::Outcome.Reply {:state s :reply (:sicp::Queue::DeleteResponse.Empty {})})
         (:wat::core::let [left (:wat::core::rest items)]
           (:wat::service::Outcome.Reply
             {:state (:sicp::queue::State :durable (:sicp::queue::Record :items left))
              :reply (:sicp::Queue::DeleteResponse.Ok {:items left})})))))
   (items [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:sicp::Queue::ItemsResponse.Ok {:items (:sicp::queue::Record/items (:sicp::queue::State/durable s))})}))])

(:wat::core::defstruct :sicp::QueueRef
  [handle <- :sicp::queue::Handle
   peer   <- :sicp::Queue])

(:wat::core::defn :sicp::make-queue [] -> :sicp::QueueRef
  (:wat::core::let [h (:sicp::queue/start :locus (:wat::spawn::thread) :record (:sicp::queue::Record :items (:wat::core::Vector :- [:wat::core::i64])))
                    p (:wat::core::match (:wat::kernel::connect (:sicp::queue::Handle/addr h))
                        [:wat::kernel::ConnectOutcome.Connected {:peer c} c]
                        [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:sicp::QueueRef :handle h :peer p)))

(:wat::core::defn :sicp::queue-insert! [q <- :sicp::QueueRef item <- :wat::core::i64] -> :sicp::Ints
  (:wat::core::match (:sicp::Queue/insert (:sicp::QueueRef/peer q) (:sicp::Queue::InsertRequest :item item))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:sicp::Queue::InsertResponse.Ok {:items xs} xs]
        [:sicp::Queue::InsertResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "queue insert: request too large")]
        [:sicp::Queue::InsertResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "queue insert: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "queue insert: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "queue insert: closed")]))

;; the queue left, or None when there was nothing to delete
(:wat::core::defn :sicp::queue-delete! [q <- :sicp::QueueRef] -> (:wat::core::Option :- [:sicp::Ints])
  (:wat::core::match (:sicp::Queue/delete (:sicp::QueueRef/peer q) (:sicp::Queue::DeleteRequest))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:sicp::Queue::DeleteResponse.Ok {:items xs} (:wat::core::Option.Some {:value xs})]
        [:sicp::Queue::DeleteResponse.Empty {} (:wat::core::Option.None {})]
        [:sicp::Queue::DeleteResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "queue delete: request too large")]
        [:sicp::Queue::DeleteResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "queue delete: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "queue delete: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "queue delete: closed")]))

(:wat::core::defn :sicp::queue-items [q <- :sicp::QueueRef] -> :sicp::Ints
  (:wat::core::match (:sicp::Queue/items (:sicp::QueueRef/peer q) (:sicp::Queue::ItemsRequest))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:sicp::Queue::ItemsResponse.Ok {:items xs} xs]
        [:sicp::Queue::ItemsResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "queue items: request too large")]
        [:sicp::Queue::ItemsResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "queue items: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "queue items: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "queue items: closed")]))

;; ---- a table: a service holding the whole table, keys and values in the order they arrived

(:wat::core::defsurface :sicp::Table :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :sicp::Table::LookupRequest [key <- :wat::core::String])
   (:wat::core::defenum :sicp::Table::LookupResponse :wat::enum::Pure
     :Found            [value <- :wat::core::i64]
     :Missing          []
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :sicp::Table::InsertRequest [key <- :wat::core::String  value <- :wat::core::i64])
   (:wat::core::defenum :sicp::Table::InsertResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(lookup [self <- :sicp::Table  req <- :sicp::Table::LookupRequest] -> :sicp::Table::LookupResponse :max-request-bytes 524288)
   (insert [self <- :sicp::Table  req <- :sicp::Table::InsertRequest] -> :sicp::Table::InsertResponse :max-request-bytes 524288)])

(:wat::service::defservice :sicp::table
  :satisfies :sicp::Table
  :durable [entries <- (:wat::core::HashMap :- [:wat::core::String :wat::core::i64])]
  :ephemeral []
  :impls
  [(lookup [s ctx req]
     (:wat::service::Outcome.Reply
       {:state s
        :reply (:wat::core::match (:wat::hashmap::get (:sicp::table::Record/entries (:sicp::table::State/durable s)) (:sicp::Table::LookupRequest/key req))
                 [:wat::core::Option.Some {:value v} (:sicp::Table::LookupResponse.Found {:value v})]
                 [:wat::core::Option.None {} (:sicp::Table::LookupResponse.Missing {})])}))
   (insert [s ctx req]
     (:wat::core::let [v (:sicp::Table::InsertRequest/value req)
                       entries (:wat::hashmap::assoc (:sicp::table::Record/entries (:sicp::table::State/durable s)) (:sicp::Table::InsertRequest/key req) v)]
       (:wat::service::Outcome.Reply
         {:state (:sicp::table::State :durable (:sicp::table::Record :entries entries))
          :reply (:sicp::Table::InsertResponse.Ok {:value v})})))])

(:wat::core::defstruct :sicp::TableRef
  [handle <- :sicp::table::Handle
   peer   <- :sicp::Table])

(:wat::core::defn :sicp::make-table [] -> :sicp::TableRef
  (:wat::core::let [h (:sicp::table/start :locus (:wat::spawn::thread)
                                          :record (:sicp::table::Record :entries (:wat::core::HashMap :- [:wat::core::String :wat::core::i64])))
                    p (:wat::core::match (:wat::kernel::connect (:sicp::table::Handle/addr h))
                        [:wat::kernel::ConnectOutcome.Connected {:peer c} c]
                        [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:sicp::TableRef :handle h :peer p)))

(:wat::core::defn :sicp::table-lookup [t <- :sicp::TableRef key <- :wat::core::String] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::match (:sicp::Table/lookup (:sicp::TableRef/peer t) (:sicp::Table::LookupRequest :key key))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:sicp::Table::LookupResponse.Found {:value v} (:wat::core::Option.Some {:value v})]
        [:sicp::Table::LookupResponse.Missing {} (:wat::core::Option.None {})]
        [:sicp::Table::LookupResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "table lookup: request too large")]
        [:sicp::Table::LookupResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "table lookup: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "table lookup: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "table lookup: closed")]))

(:wat::core::defn :sicp::table-insert! [t <- :sicp::TableRef key <- :wat::core::String value <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:sicp::Table/insert (:sicp::TableRef/peer t) (:sicp::Table::InsertRequest :key key :value value))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:sicp::Table::InsertResponse.Ok {:value v} v]
        [:sicp::Table::InsertResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "table insert: request too large")]
        [:sicp::Table::InsertResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "table insert: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "table insert: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "table insert: closed")]))

;; ---- printing, as the Scheme oracle prints

(:wat::core::defn :sicp::show-bool [b <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if b "#t" "#f"))

(:wat::core::defn :sicp::show-items [xs <- :sicp::Ints] -> :wat::core::String
  (:wat::string::concat "(" (:wat::string::join " " (:wat::core::mapv (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n)) xs)) ")"))

;; a queue that had nothing to delete answers the symbol the Scheme oracle answers
(:wat::core::defn :sicp::show-delete [o <- (:wat::core::Option :- [:sicp::Ints])] -> :wat::core::String
  (:wat::core::match o
    [:wat::core::Option.Some {:value xs} (:sicp::show-items xs)]
    [:wat::core::Option.None {} "empty"]))

(:wat::core::defn :sicp::show-front [xs <- :sicp::Ints] -> :wat::core::String
  (:wat::core::if (:wat::core::empty? xs) "empty" (:wat::i64::to-string (:wat::core::first xs))))

(:wat::core::defn :sicp::show-lookup [o <- (:wat::core::Option :- [:wat::core::i64])] -> :wat::core::String
  (:wat::core::match o
    [:wat::core::Option.Some {:value v} (:wat::i64::to-string v)]
    [:wat::core::Option.None {} "missing"]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [q (:sicp::make-queue)
                    q2 (:sicp::make-queue)
                    t (:sicp::make-table)
                    int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:sicp::check-chapter "oracle/sicp/ch33-mutable-data.expected"
                          "sicp ch33 mutable-data"
                          (:wat::core::Vector :- [:wat::core::String]
                            ;; the queue
                            (:sicp::show-bool (:wat::core::empty? (:sicp::queue-items q)))
                            (:sicp::show-front (:sicp::queue-items q))
                            (:sicp::show-delete (:sicp::queue-delete! q))
                            (:sicp::show-items (:sicp::queue-insert! q 1))
                            (:sicp::show-items (:sicp::queue-insert! q 2))
                            (:sicp::show-items (:sicp::queue-insert! q 3))
                            (:sicp::show-front (:sicp::queue-items q))
                            (:sicp::show-bool (:wat::core::empty? (:sicp::queue-items q)))
                            (:sicp::show-delete (:sicp::queue-delete! q))
                            (:sicp::show-delete (:sicp::queue-delete! q))
                            (:sicp::show-items (:sicp::queue-insert! q 4))
                            (:sicp::show-delete (:sicp::queue-delete! q))
                            (:sicp::show-delete (:sicp::queue-delete! q))
                            (:sicp::show-bool (:wat::core::empty? (:sicp::queue-items q)))
                            ;; a second queue is its own
                            (:sicp::show-items (:sicp::queue-insert! q2 9))
                            (:sicp::show-front (:sicp::queue-items q))
                            ;; the table
                            (:sicp::show-lookup (:sicp::table-lookup t "a"))
                            (int (:sicp::table-insert! t "a" 1))
                            (:sicp::show-lookup (:sicp::table-lookup t "a"))
                            (int (:sicp::table-insert! t "b" 2))
                            (:sicp::show-lookup (:sicp::table-lookup t "b"))
                            (int (:sicp::table-insert! t "a" 11))
                            (:sicp::show-lookup (:sicp::table-lookup t "a"))
                            (:sicp::show-lookup (:sicp::table-lookup t "b"))
                            (:sicp::show-lookup (:sicp::table-lookup t "c"))))))
