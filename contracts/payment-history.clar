(define-constant err-no-payments (err u200))
(define-constant err-invalid-index (err u201))

(define-map payment-history
  { employer: principal, employee: principal, payment-id: uint }
  { 
    amount: uint,
    block-height: uint,
    timestamp: uint
  }
)

(define-map payment-counters
  { employer: principal, employee: principal }
  uint
)

(define-map payment-totals
  { employer: principal, employee: principal }
  { total-amount: uint, payment-count: uint }
)

(define-read-only (get-payment-count (employer principal) (employee principal))
  (default-to u0 (map-get? payment-counters { employer: employer, employee: employee }))
)

(define-read-only (get-payment-record (employer principal) (employee principal) (payment-id uint))
  (map-get? payment-history { employer: employer, employee: employee, payment-id: payment-id })
)

(define-read-only (get-payment-totals (employer principal) (employee principal))
  (default-to { total-amount: u0, payment-count: u0 } 
    (map-get? payment-totals { employer: employer, employee: employee }))
)

(define-read-only (calculate-average-payment (employer principal) (employee principal))
  (let
    (
      (totals (get-payment-totals employer employee))
      (total-amount (get total-amount totals))
      (payment-count (get payment-count totals))
    )
    (if (> payment-count u0)
      (/ total-amount payment-count)
      u0
    )
  )
)

(define-read-only (get-latest-payment (employer principal) (employee principal))
  (let
    (
      (count (get-payment-count employer employee))
    )
    (if (> count u0)
      (get-payment-record employer employee (- count u1))
      none
    )
  )
)

(define-read-only (get-payment-range (employer principal) (employee principal) (start-index uint) (end-index uint))
  (let
    (
      (total-payments (get-payment-count employer employee))
    )
    (asserts! (<= start-index end-index) err-invalid-index)
    (asserts! (< end-index total-payments) err-invalid-index)
    (ok { 
      start: start-index, 
      end: end-index, 
      total: total-payments 
    })
  )
)

(define-public (record-payment (employer principal) (employee principal) (amount uint))
  (let
    (
      (current-count (get-payment-count employer employee))
      (current-totals (get-payment-totals employer employee))
      (payment-key { employer: employer, employee: employee, payment-id: current-count })
      (totals-key { employer: employer, employee: employee })
    )
    (map-set payment-history payment-key
      {
        amount: amount,
        block-height: stacks-block-height,
        timestamp: stacks-block-height
      }
    )
    (map-set payment-counters totals-key (+ current-count u1))
    (map-set payment-totals totals-key
      {
        total-amount: (+ (get total-amount current-totals) amount),
        payment-count: (+ (get payment-count current-totals) u1)
      }
    )
    (ok current-count)
  )
)
