(define-constant err-not-insured (err u500))
(define-constant err-already-insured (err u501))
(define-constant err-insufficient-pool (err u502))
(define-constant err-invalid-contribution (err u503))
(define-constant err-claim-too-soon (err u504))
(define-constant err-already-claimed (err u505))

(define-data-var total-pool-balance uint u0)
(define-data-var total-claims-paid uint u0)
(define-data-var min-contribution-rate uint u2)
(define-data-var max-claim-percentage uint u70)

(define-map insurance-members
  principal
  {
    total-contributed: uint,
    enrollment-block: uint,
    active: bool,
    last-claim-block: uint,
    claims-received: uint
  }
)

(define-map pending-claims
  { employee: principal, claim-id: uint }
  {
    employer: principal,
    amount-requested: uint,
    amount-approved: uint,
    claim-block: uint,
    status: (string-ascii 10)
  }
)

(define-map claim-counters principal uint)

(define-read-only (get-pool-balance)
  (var-get total-pool-balance)
)

(define-read-only (get-member-info (member principal))
  (map-get? insurance-members member)
)

(define-read-only (is-member-active (member principal))
  (match (get-member-info member)
    info (get active info)
    false
  )
)

(define-read-only (calculate-claim-eligibility (member principal) (requested-amount uint))
  (match (get-member-info member)
    info
    (let
      (
        (pool-balance (var-get total-pool-balance))
        (max-claim (/ (* pool-balance (var-get max-claim-percentage)) u100))
        (contribution-multiplier (/ (get total-contributed info) u1000))
        (eligible-amount (* contribution-multiplier u5))
      )
      (if (and (get active info) (> pool-balance u0))
        (if (<= requested-amount eligible-amount) requested-amount eligible-amount)
        u0
      )
    )
    u0
  )
)

(define-public (enroll-in-insurance (initial-contribution uint))
  (let
    (
      (min-required (var-get min-contribution-rate))
    )
    (asserts! (>= initial-contribution min-required) err-invalid-contribution)
    (asserts! (is-none (get-member-info tx-sender)) err-already-insured)
    
    (try! (stx-transfer? initial-contribution tx-sender (as-contract tx-sender)))
    (var-set total-pool-balance (+ (var-get total-pool-balance) initial-contribution))
    (map-set insurance-members tx-sender
      {
        total-contributed: initial-contribution,
        enrollment-block: stacks-block-height,
        active: true,
        last-claim-block: u0,
        claims-received: u0
      }
    )
    (ok initial-contribution)
  )
)

(define-public (contribute-to-pool (amount uint))
  (match (get-member-info tx-sender)
    info
    (begin
      (asserts! (> amount u0) err-invalid-contribution)
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (var-set total-pool-balance (+ (var-get total-pool-balance) amount))
      (map-set insurance-members tx-sender
        (merge info { total-contributed: (+ (get total-contributed info) amount) })
      )
      (ok amount)
    )
    err-not-insured
  )
)

(define-public (file-claim (employer principal) (amount-requested uint))
  (let
    (
      (claim-count (default-to u0 (map-get? claim-counters tx-sender)))
      (eligible-amount (calculate-claim-eligibility tx-sender amount-requested))
    )
    (asserts! (is-member-active tx-sender) err-not-insured)
    (asserts! (> eligible-amount u0) err-insufficient-pool)
    
    (map-set pending-claims { employee: tx-sender, claim-id: claim-count }
      {
        employer: employer,
        amount-requested: amount-requested,
        amount-approved: eligible-amount,
        claim-block: stacks-block-height,
        status: "approved"
      }
    )
    (map-set claim-counters tx-sender (+ claim-count u1))
    (ok eligible-amount)
  )
)

(define-public (withdraw-claim (claim-id uint))
  (match (map-get? pending-claims { employee: tx-sender, claim-id: claim-id })
    claim
    (let
      (
        (approved-amount (get amount-approved claim))
        (current-pool (var-get total-pool-balance))
      )
      (asserts! (is-eq (get status claim) "approved") err-already-claimed)
      (asserts! (>= current-pool approved-amount) err-insufficient-pool)
      
      (try! (as-contract (stx-transfer? approved-amount tx-sender tx-sender)))
      (var-set total-pool-balance (- current-pool approved-amount))
      (var-set total-claims-paid (+ (var-get total-claims-paid) approved-amount))
      
      (match (get-member-info tx-sender)
        info
        (map-set insurance-members tx-sender
          (merge info 
            { 
              last-claim-block: stacks-block-height,
              claims-received: (+ (get claims-received info) u1)
            }
          )
        )
        true
      )
      
      (map-set pending-claims { employee: tx-sender, claim-id: claim-id }
        (merge claim { status: "paid" })
      )
      (ok approved-amount)
    )
    err-not-insured
  )
)
