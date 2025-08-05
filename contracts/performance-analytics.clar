(define-constant err-unauthorized (err u300))
(define-constant err-invalid-data (err u301))

(define-map platform-metrics
  uint
  {
    total-agreements: uint,
    active-agreements: uint,
    total-volume: uint,
    successful-payments: uint,
    failed-payments: uint,
    avg-salary: uint
  }
)

(define-map employer-metrics
  principal
  {
    agreements-created: uint,
    total-deposited: uint,
    on-time-payments: uint,
    late-payments: uint,
    reliability-score: uint
  }
)

(define-map weekly-stats
  uint
  {
    new-agreements: uint,
    payment-volume: uint,
    unique-employers: uint,
    unique-employees: uint
  }
)

(define-data-var current-week uint u0)
(define-data-var total-platform-volume uint u0)

(define-read-only (get-platform-metrics (period uint))
  (map-get? platform-metrics period)
)

(define-read-only (get-employer-score (employer principal))
  (match (map-get? employer-metrics employer)
    metrics (get reliability-score metrics)
    u0
  )
)

(define-read-only (get-weekly-growth-rate)
  (let
    (
      (current (var-get current-week))
      (last-week (if (> current u0) (- current u1) u0))
      (current-stats (default-to { new-agreements: u0, payment-volume: u0, unique-employers: u0, unique-employees: u0 } 
        (map-get? weekly-stats current)))
      (last-stats (default-to { new-agreements: u0, payment-volume: u0, unique-employers: u0, unique-employees: u0 } 
        (map-get? weekly-stats last-week)))
    )
    (if (> (get payment-volume last-stats) u0)
      (/ (* (- (get payment-volume current-stats) (get payment-volume last-stats)) u100) 
         (get payment-volume last-stats))
      u0
    )
  )
)

(define-public (record-agreement-created (employer principal))
  (let
    (
      (current-metrics (default-to 
        { agreements-created: u0, total-deposited: u0, on-time-payments: u0, late-payments: u0, reliability-score: u50 }
        (map-get? employer-metrics employer)))
      (week (var-get current-week))
      (week-stats (default-to 
        { new-agreements: u0, payment-volume: u0, unique-employers: u0, unique-employees: u0 }
        (map-get? weekly-stats week)))
    )
    (map-set employer-metrics employer
      (merge current-metrics { agreements-created: (+ (get agreements-created current-metrics) u1) })
    )
    (map-set weekly-stats week
      (merge week-stats { new-agreements: (+ (get new-agreements week-stats) u1) })
    )
    (ok true)
  )
)

(define-public (record-analytics-payment (employer principal) (amount uint) (on-time bool))
  (let
    (
      (current-metrics (default-to 
        { agreements-created: u0, total-deposited: u0, on-time-payments: u0, late-payments: u0, reliability-score: u50 }
        (map-get? employer-metrics employer)))
    )
    (var-set total-platform-volume (+ (var-get total-platform-volume) amount))
    (map-set employer-metrics employer
      (merge current-metrics 
        { 
          on-time-payments: (+ (get on-time-payments current-metrics) (if on-time u1 u0)),
          late-payments: (+ (get late-payments current-metrics) (if on-time u0 u1))
        }
      )
    )
    (ok amount)
  )
)
