(define-constant err-unauthorized (err u600))
(define-constant err-vault-exists (err u601))
(define-constant err-vault-not-found (err u602))
(define-constant err-insufficient-vault-balance (err u603))
(define-constant err-invalid-amount (err u604))
(define-constant err-milestone-not-achieved (err u605))
(define-constant err-already-claimed (err u606))

(define-map bonus-vaults
  principal
  {
    total-deposited: uint,
    total-claimed: uint,
    active-milestones: uint,
    vault-active: bool
  }
)

(define-map employee-milestones
  { employer: principal, employee: principal, milestone-id: uint }
  {
    bonus-amount: uint,
    achieved: bool,
    achievement-block: uint,
    claimed: bool,
    description: (string-ascii 50)
  }
)

(define-map milestone-counters
  { employer: principal, employee: principal }
  uint
)

(define-read-only (get-vault-info (employer principal))
  (map-get? bonus-vaults employer)
)

(define-read-only (get-available-vault-balance (employer principal))
  (match (get-vault-info employer)
    vault (- (get total-deposited vault) (get total-claimed vault))
    u0
  )
)

(define-read-only (get-milestone (employer principal) (employee principal) (milestone-id uint))
  (map-get? employee-milestones { employer: employer, employee: employee, milestone-id: milestone-id })
)

(define-read-only (get-employee-milestone-count (employer principal) (employee principal))
  (default-to u0 (map-get? milestone-counters { employer: employer, employee: employee }))
)

(define-read-only (calculate-total-earned (employer principal) (employee principal))
  (let
    ((count (get-employee-milestone-count employer employee)))
    (fold check-and-sum-milestone (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9) 
      { employer: employer, employee: employee, total: u0, count: count })
  )
)

(define-private (check-and-sum-milestone (milestone-id uint) (context { employer: principal, employee: principal, total: uint, count: uint }))
  (if (< milestone-id (get count context))
    (match (get-milestone (get employer context) (get employee context) milestone-id)
      milestone
      (if (and (get achieved milestone) (not (get claimed milestone)))
        (merge context { total: (+ (get total context) (get bonus-amount milestone)) })
        context
      )
      context
    )
    context
  )
)

(define-public (create-bonus-vault (initial-deposit uint))
  (begin
    (asserts! (is-none (get-vault-info tx-sender)) err-vault-exists)
    (asserts! (> initial-deposit u0) err-invalid-amount)
    (try! (stx-transfer? initial-deposit tx-sender (as-contract tx-sender)))
    (map-set bonus-vaults tx-sender
      {
        total-deposited: initial-deposit,
        total-claimed: u0,
        active-milestones: u0,
        vault-active: true
      }
    )
    (ok initial-deposit)
  )
)

(define-public (deposit-to-vault (amount uint))
  (match (get-vault-info tx-sender)
    vault
    (begin
      (asserts! (> amount u0) err-invalid-amount)
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (map-set bonus-vaults tx-sender
        (merge vault { total-deposited: (+ (get total-deposited vault) amount) })
      )
      (ok amount)
    )
    err-vault-not-found
  )
)

(define-public (set-milestone (employee principal) (bonus-amount uint) (description (string-ascii 50)))
  (let
    (
      (counter-key { employer: tx-sender, employee: employee })
      (current-count (default-to u0 (map-get? milestone-counters counter-key)))
      (milestone-key { employer: tx-sender, employee: employee, milestone-id: current-count })
    )
    (asserts! (is-some (get-vault-info tx-sender)) err-vault-not-found)
    (asserts! (> bonus-amount u0) err-invalid-amount)
    (map-set employee-milestones milestone-key
      {
        bonus-amount: bonus-amount,
        achieved: false,
        achievement-block: u0,
        claimed: false,
        description: description
      }
    )
    (map-set milestone-counters counter-key (+ current-count u1))
    (ok current-count)
  )
)

(define-public (mark-milestone-achieved (employee principal) (milestone-id uint))
  (let
    ((milestone-key { employer: tx-sender, employee: employee, milestone-id: milestone-id }))
    (match (get-milestone tx-sender employee milestone-id)
      milestone
      (begin
        (asserts! (not (get achieved milestone)) err-already-claimed)
        (map-set employee-milestones milestone-key
          (merge milestone { achieved: true, achievement-block: stacks-block-height })
        )
        (ok true)
      )
      err-vault-not-found
    )
  )
)

(define-public (claim-milestone-bonus (employer principal) (milestone-id uint))
  (let
    ((milestone-key { employer: employer, employee: tx-sender, milestone-id: milestone-id }))
    (match (get-milestone employer tx-sender milestone-id)
      milestone
      (begin
        (asserts! (get achieved milestone) err-milestone-not-achieved)
        (asserts! (not (get claimed milestone)) err-already-claimed)
        (asserts! (>= (get-available-vault-balance employer) (get bonus-amount milestone)) err-insufficient-vault-balance)
        (try! (as-contract (stx-transfer? (get bonus-amount milestone) tx-sender tx-sender)))
        (map-set employee-milestones milestone-key
          (merge milestone { claimed: true })
        )
        (match (get-vault-info employer)
          vault
          (map-set bonus-vaults employer
            (merge vault { total-claimed: (+ (get total-claimed vault) (get bonus-amount milestone)) })
          )
          true
        )
        (ok (get bonus-amount milestone))
      )
      err-vault-not-found
    )
  )
)
