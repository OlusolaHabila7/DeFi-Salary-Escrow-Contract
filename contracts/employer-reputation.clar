(define-constant err-not-found (err u400))
(define-constant err-invalid-score (err u401))

(define-map employer-reputation
  principal
  {
    total-score: uint,
    payment-streak: uint,
    agreements-completed: uint,
    platform-tenure: uint,
    last-updated: uint,
    reputation-tier: (string-ascii 10)
  }
)

(define-map reputation-rankings
  uint
  { employer: principal, score: uint }
)

(define-data-var ranking-count uint u0)
(define-data-var min-tier-scores { bronze: uint, silver: uint, gold: uint, platinum: uint } 
  { bronze: u250, silver: u500, gold: u750, platinum: u900 })

(define-read-only (get-employer-reputation (employer principal))
  (map-get? employer-reputation employer)
)

(define-read-only (get-reputation-score (employer principal))
  (match (get-employer-reputation employer)
    reputation (get total-score reputation)
    u0
  )
)

(define-read-only (get-reputation-tier (employer principal))
  (let
    (
      (score (get-reputation-score employer))
      (tier-thresholds (var-get min-tier-scores))
    )
    (if (>= score (get platinum tier-thresholds)) "platinum"
    (if (>= score (get gold tier-thresholds)) "gold"
    (if (>= score (get silver tier-thresholds)) "silver"
    (if (>= score (get bronze tier-thresholds)) "bronze" 
    "unranked"))))
  )
)

(define-read-only (get-top-employers (limit uint))
  (let
    (
      (total-rankings (var-get ranking-count))
      (max-return (if (<= limit total-rankings) limit total-rankings))
    )
    (ok max-return)
  )
)

(define-read-only (calculate-reputation-score (on-time-payments uint) (late-payments uint) (agreements-count uint) (tenure uint))
  (let
    (
      (total-payments (+ on-time-payments late-payments))
      (punctuality-score (if (> total-payments u0) (/ (* on-time-payments u400) total-payments) u0))
      (volume-bonus (* agreements-count u50))
      (tenure-bonus (* tenure u10))
      (streak-multiplier u100)
    )
    (+ punctuality-score volume-bonus tenure-bonus streak-multiplier)
  )
)

(define-public (update-employer-reputation (employer principal) (on-time bool) (agreement-completed bool))
  (let
    (
      (current-rep (default-to 
        { total-score: u100, payment-streak: u0, agreements-completed: u0, platform-tenure: u1, last-updated: stacks-block-height, reputation-tier: "unranked" }
        (get-employer-reputation employer)))
      (new-streak (if on-time (+ (get payment-streak current-rep) u1) u0))
      (new-agreements (if agreement-completed (+ (get agreements-completed current-rep) u1) (get agreements-completed current-rep)))
      (blocks-since-join (- stacks-block-height (get last-updated current-rep)))
      (tenure-weeks (/ blocks-since-join u1008))
      (new-score (calculate-reputation-score 
        (if on-time u1 u0) 
        (if on-time u0 u1) 
        new-agreements 
        tenure-weeks))
    )
    (map-set employer-reputation employer
      {
        total-score: (+ (get total-score current-rep) new-score),
        payment-streak: new-streak,
        agreements-completed: new-agreements,
        platform-tenure: (+ (get platform-tenure current-rep) tenure-weeks),
        last-updated: stacks-block-height,
        reputation-tier: (get-reputation-tier employer)
      }
    )
    (ok (get-reputation-score employer))
  )
)
