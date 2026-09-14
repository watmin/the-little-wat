;; cell-handle-drop.wat: start a Cell, connect, then let the HANDLE go out of scope and
;; keep only the connected peer. Does the service survive? Prints the value if so, or the
;; outcome arm reached otherwise.
(:wat::load-file! "../books/seasoned-schemer/lib/cell.wat")
(:wat::core::defn :u::peer-only [v <- :wat::WatAST] -> :ss::Cell
  (:wat::core::let
    [h (:ss::cell/start :locus (:wat::spawn::thread) :record (:ss::cell::Record :value v))]
    (:wat::core::match (:wat::kernel::connect (:ss::cell::Handle/addr h))
      [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
      [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message "refused")]
      [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message "rejected")]
      [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message "failed")])))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [p (:u::peer-only 'pear)]
    (:wat::core::match (:ss::Cell/get p (:ss::Cell::GetRequest))
      [:wat::kernel::RecvOutcome.Message {:msg m}
        (:wat::core::match m
          [:ss::Cell::GetResponse.Ok {:value v} (:wat::kernel::println v)]
          [:ss::Cell::GetResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::println "RequestTooLarge")]
          [:ss::Cell::GetResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::println "RequestMalformed")])]
      [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::println "Lost")]
      [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::println "Stopped")]
      [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::println "Closed")])))
