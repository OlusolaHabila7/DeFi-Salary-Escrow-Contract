(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-invalid-period (err u105))
(define-constant err-already-exists (err u106))
(define-constant err-not-due (err u107))
(define-constant err-already-withdrawn (err u108))

(define-map escrow-agreements
  { employer: principal, employee: principal }
  {
    salary-amount: uint,
    payment-period: uint,
    start-block: uint,
    last-payment-block: uint,
    total-deposited: uint,
    total-withdrawn: uint,
    active: bool
  }
)

(define-map employer-balances principal uint)

(define-data-var total-escrows uint u0)

(define-read-only (get-escrow-agreement (employer principal) (employee principal))
  (map-get? escrow-agreements { employer: employer, employee: employee })
)

(define-read-only (get-employer-balance (employer principal))
  (default-to u0 (map-get? employer-balances employer))
)

(define-read-only (get-total-escrows)
  (var-get total-escrows)
)

(define-read-only (calculate-owed-payments (employer principal) (employee principal))
  (match (get-escrow-agreement employer employee)
    agreement
    (let
      (
        (current-block stacks-block-height)
        (last-payment (get last-payment-block agreement))
        (payment-period (get payment-period agreement))
        (salary-amount (get salary-amount agreement))
        (blocks-since-last (- current-block last-payment))
        (periods-owed (/ blocks-since-last payment-period))
      )
      (if (get active agreement)
        (* periods-owed salary-amount)
        u0
      )
    )
    u0
  )
)

(define-read-only (get-next-payment-block (employer principal) (employee principal))
  (match (get-escrow-agreement employer employee)
    agreement
    (+ (get last-payment-block agreement) (get payment-period agreement))
    u0
  )
)

(define-read-only (is-payment-due (employer principal) (employee principal))
  (>= stacks-block-height (get-next-payment-block employer employee))
)

(define-public (deposit-funds (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set employer-balances tx-sender (+ (get-employer-balance tx-sender) amount))
    (ok amount)
  )
)

(define-public (create-escrow-agreement 
  (employee principal) 
  (salary-amount uint) 
  (payment-period uint))
  (let
    (
      (agreement-key { employer: tx-sender, employee: employee })
      (current-block stacks-block-height)
    )
    (asserts! (> salary-amount u0) err-invalid-amount)
    (asserts! (> payment-period u0) err-invalid-period)
    (asserts! (is-none (get-escrow-agreement tx-sender employee)) err-already-exists)
    (asserts! (>= (get-employer-balance tx-sender) salary-amount) err-insufficient-funds)
    
    (map-set escrow-agreements agreement-key
      {
        salary-amount: salary-amount,
        payment-period: payment-period,
        start-block: current-block,
        last-payment-block: current-block,
        total-deposited: u0,
        total-withdrawn: u0,
        active: true
      }
    )
    (var-set total-escrows (+ (var-get total-escrows) u1))
    (ok agreement-key)
  )
)

(define-public (fund-escrow (employee principal) (amount uint))
  (let
    (
      (agreement-key { employer: tx-sender, employee: employee })
      (current-balance (get-employer-balance tx-sender))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (is-some (get-escrow-agreement tx-sender employee)) err-not-found)
    (asserts! (>= current-balance amount) err-insufficient-funds)
    
    (match (get-escrow-agreement tx-sender employee)
      agreement
      (begin
        (map-set employer-balances tx-sender (- current-balance amount))
        (map-set escrow-agreements agreement-key
          (merge agreement { total-deposited: (+ (get total-deposited agreement) amount) })
        )
        (ok amount)
      )
      err-not-found
    )
  )
)

(define-public (withdraw-salary (employer principal))
  (let
    (
      (agreement-key { employer: employer, employee: tx-sender })
      (owed-amount (calculate-owed-payments employer tx-sender))
    )
    (asserts! (> owed-amount u0) err-not-due)
    (asserts! (is-some (get-escrow-agreement employer tx-sender)) err-not-found)
    
    (match (get-escrow-agreement employer tx-sender)
      agreement
      (let
        (
          (available-funds (- (get total-deposited agreement) (get total-withdrawn agreement)))
          (payment-amount (if (<= owed-amount available-funds) owed-amount available-funds))
        )
        (asserts! (> payment-amount u0) err-insufficient-funds)
        (asserts! (get active agreement) err-unauthorized)
        
        (try! (as-contract (stx-transfer? payment-amount tx-sender tx-sender)))
        (map-set escrow-agreements agreement-key
          (merge agreement 
            { 
              total-withdrawn: (+ (get total-withdrawn agreement) payment-amount),
              last-payment-block: stacks-block-height
            }
          )
        )
        (ok payment-amount)
      )
      err-not-found
    )
  )
)

(define-public (terminate-agreement (employee principal))
  (let
    (
      (agreement-key { employer: tx-sender, employee: employee })
    )
    (asserts! (is-some (get-escrow-agreement tx-sender employee)) err-not-found)
    
    (match (get-escrow-agreement tx-sender employee)
      agreement
      (begin
        (map-set escrow-agreements agreement-key
          (merge agreement { active: false })
        )
        (ok true)
      )
      err-not-found
    )
  )
)

(define-public (withdraw-remaining-funds (employee principal))
  (let
    (
      (agreement-key { employer: tx-sender, employee: employee })
    )
    (asserts! (is-some (get-escrow-agreement tx-sender employee)) err-not-found)
    
    (match (get-escrow-agreement tx-sender employee)
      agreement
      (let
        (
          (remaining-funds (- (get total-deposited agreement) (get total-withdrawn agreement)))
        )
        (asserts! (not (get active agreement)) err-unauthorized)
        (asserts! (> remaining-funds u0) err-insufficient-funds)
        
        (try! (as-contract (stx-transfer? remaining-funds tx-sender tx-sender)))
        (map-set escrow-agreements agreement-key
          (merge agreement { total-withdrawn: (get total-deposited agreement) })
        )
        (ok remaining-funds)
      )
      err-not-found
    )
  )
)

(define-public (emergency-withdraw (employer principal) (employee principal))
  (let
    (
      (agreement-key { employer: employer, employee: employee })
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (get-escrow-agreement employer employee)) err-not-found)
    
    (match (get-escrow-agreement employer employee)
      agreement
      (let
        (
          (remaining-funds (- (get total-deposited agreement) (get total-withdrawn agreement)))
        )
        (asserts! (> remaining-funds u0) err-insufficient-funds)
        
        (try! (as-contract (stx-transfer? remaining-funds employer tx-sender)))
        (map-set escrow-agreements agreement-key
          (merge agreement 
            { 
              total-withdrawn: (get total-deposited agreement),
              active: false
            }
          )
        )
        (ok remaining-funds)
      )
      err-not-found
    )
  )
)

(define-public (update-salary-amount (employee principal) (new-amount uint))
  (let
    (
      (agreement-key { employer: tx-sender, employee: employee })
    )
    (asserts! (> new-amount u0) err-invalid-amount)
    (asserts! (is-some (get-escrow-agreement tx-sender employee)) err-not-found)
    
    (match (get-escrow-agreement tx-sender employee)
      agreement
      (begin
        (asserts! (get active agreement) err-unauthorized)
        (map-set escrow-agreements agreement-key
          (merge agreement { salary-amount: new-amount })
        )
        (ok new-amount)
      )
      err-not-found
    )
  )
)

(define-public (update-payment-period (employee principal) (new-period uint))
  (let
    (
      (agreement-key { employer: tx-sender, employee: employee })
    )
    (asserts! (> new-period u0) err-invalid-period)
    (asserts! (is-some (get-escrow-agreement tx-sender employee)) err-not-found)
    
    (match (get-escrow-agreement tx-sender employee)
      agreement
      (begin
        (asserts! (get active agreement) err-unauthorized)
        (map-set escrow-agreements agreement-key
          (merge agreement { payment-period: new-period })
        )
        (ok new-period)
      )
      err-not-found
    )
  )
)
