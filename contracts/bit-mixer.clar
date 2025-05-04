;; Title: BitMixer - Decentralized Privacy Protocol for STX
;;
;; Summary: Secure, compliant mixing service for STX tokens enabling privacy-preserving transactions
;;
;; Description:
;; BitMixer is a regulatory-compliant privacy protocol built on Stacks that enables users to
;; protect their financial privacy while maintaining full transparency for compliance purposes.
;; The protocol implements a non-custodial pool-based mixing service with built-in rate limiting,
;; safety checks, and protocol fees to ensure long-term sustainability.
;;
;; Features:
;; - Self-custodial deposits and withdrawals
;; - Multi-participant mixing pools with configurable parameters
;; - Daily transaction limits for regulatory compliance
;; - Protocol fees to sustain development
;; - Emergency pause functionality for security incidents
;; - Transparent pool creation and distribution mechanisms

;; Constants

;; Contract Owner
(define-constant CONTRACT-OWNER tx-sender)

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-AMOUNT (err u1001))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1002))
(define-constant ERR-CONTRACT-NOT-INITIALIZED (err u1003))
(define-constant ERR-ALREADY-INITIALIZED (err u1004))
(define-constant ERR-POOL-FULL (err u1005))
(define-constant ERR-DAILY-LIMIT-EXCEEDED (err u1006))
(define-constant ERR-INVALID-POOL (err u1007))
(define-constant ERR-DUPLICATE-PARTICIPANT (err u1008))
(define-constant ERR-INSUFFICIENT-POOL-FUNDS (err u1009))
(define-constant ERR-POOL-NOT-READY (err u1010))

;; Contract Configuration Constants
(define-constant MAX-DAILY-LIMIT u10000000000)          ;; Maximum daily transaction limit
(define-constant MAX-POOL-PARTICIPANTS u10)             ;; Maximum participants per mixing pool
(define-constant MAX-TRANSACTION-AMOUNT u1000000000000) ;; Maximum amount per transaction
(define-constant MIN-POOL-AMOUNT u100000)               ;; Minimum amount to join a pool
(define-constant MIXING-FEE-PERCENTAGE u2)              ;; 2% mixing fee

;; State Variables

(define-data-var is-contract-initialized bool false)
(define-data-var is-contract-paused bool false)
(define-data-var total-protocol-fees uint u0)

;; Data Maps

;; Track user balances within the contract
(define-map user-balances 
    principal 
    uint
)

;; Track daily transaction totals for regulatory compliance
(define-map daily-tx-totals 
    {user: principal, day: uint}
    uint
)

;; Mixing pool configuration and state
(define-map mixer-pools 
    uint 
    {
        total-amount: uint,
        participant-count: uint,
        is-active: bool,
        participants: (list 10 principal),
        pool-creator: principal
    }
)

;; Track participation status by pool and user
(define-map pool-participant-status 
    {pool-id: uint, user: principal}
    bool
)

;; Public Functions

;; Initialize the contract - can only be called once by contract owner
(define-public (initialize)
    (begin
        (asserts! (not (var-get is-contract-initialized)) ERR-ALREADY-INITIALIZED)
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set is-contract-initialized true)
        (ok true)
    )
)

;; Deposit STX into the contract with safety checks
(define-public (deposit (amount uint))
    (begin
        (asserts! (var-get is-contract-initialized) ERR-CONTRACT-NOT-INITIALIZED)
        (asserts! (not (var-get is-contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (and (> amount u0) (<= amount MAX-TRANSACTION-AMOUNT)) ERR-INVALID-AMOUNT)
        
        (let ((current-day (/ stacks-block-height u144))
              (current-total (default-to u0 
                (map-get? daily-tx-totals {user: tx-sender, day: current-day}))))
            (asserts! (<= (+ current-total amount) MAX-DAILY-LIMIT) ERR-DAILY-LIMIT-EXCEEDED)
            
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            
            (map-set user-balances 
                tx-sender 
                (+ (default-to u0 (map-get? user-balances tx-sender)) amount))
            
            (map-set daily-tx-totals 
                {user: tx-sender, day: current-day}
                (+ current-total amount))
            
            (ok true))
    )
)

;; Withdraw STX from the contract with security checks
(define-public (withdraw (amount uint))
    (begin
        (asserts! (var-get is-contract-initialized) ERR-CONTRACT-NOT-INITIALIZED)
        (asserts! (not (var-get is-contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (and (> amount u0) (<= amount MAX-TRANSACTION-AMOUNT)) ERR-INVALID-AMOUNT)
        
        (let ((current-balance (default-to u0 (map-get? user-balances tx-sender)))
              (current-day (/ stacks-block-height u144))
              (current-total (default-to u0 
                (map-get? daily-tx-totals {user: tx-sender, day: current-day}))))
            
            (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
            (asserts! (<= (+ current-total amount) MAX-DAILY-LIMIT) ERR-DAILY-LIMIT-EXCEEDED)
            
            (map-set user-balances 
                tx-sender 
                (- current-balance amount))
            
            (map-set daily-tx-totals 
                {user: tx-sender, day: current-day}
                (+ current-total amount))
            
            (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
            
            (ok true))
    )
)

;; Create a new mixing pool with initial deposit
(define-public (create-mixer-pool (pool-id uint) (initial-amount uint))
    (begin
        (asserts! (var-get is-contract-initialized) ERR-CONTRACT-NOT-INITIALIZED)
        (asserts! (not (var-get is-contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (>= initial-amount MIN-POOL-AMOUNT) ERR-INVALID-AMOUNT)
        
        (asserts! (< pool-id u1000) ERR-INVALID-POOL)
        (asserts! (is-none (map-get? mixer-pools pool-id)) ERR-INVALID-POOL)
        
        (let ((user-balance (default-to u0 (map-get? user-balances tx-sender))))
            (asserts! (>= user-balance initial-amount) ERR-INSUFFICIENT-BALANCE)
            
            (map-set mixer-pools pool-id {
                total-amount: initial-amount,
                participant-count: u1,
                is-active: true,
                participants: (list tx-sender),
                pool-creator: tx-sender
            })
            
            (map-set pool-participant-status 
                {pool-id: pool-id, user: tx-sender} 
                true)
            
            (map-set user-balances 
                tx-sender 
                (- user-balance initial-amount))
            
            (ok true))
    )
)

;; Join an existing mixing pool
(define-public (join-mixer-pool (pool-id uint) (amount uint))
    (begin
        (asserts! (var-get is-contract-initialized) ERR-CONTRACT-NOT-INITIALIZED)
        (asserts! (not (var-get is-contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (>= amount MIN-POOL-AMOUNT) ERR-INVALID-AMOUNT)
        
        (let ((pool (unwrap! (map-get? mixer-pools pool-id) ERR-INVALID-POOL))
              (user-balance (default-to u0 (map-get? user-balances tx-sender))))
            
            (asserts! (get is-active pool) ERR-INVALID-POOL)
            (asserts! (< (get participant-count pool) MAX-POOL-PARTICIPANTS) ERR-POOL-FULL)
            (asserts! (>= user-balance amount) ERR-INSUFFICIENT-BALANCE)
            (asserts! (is-none (map-get? pool-participant-status {pool-id: pool-id, user: tx-sender})) ERR-DUPLICATE-PARTICIPANT)
            
            (map-set mixer-pools pool-id {
                total-amount: (+ (get total-amount pool) amount),
                participant-count: (+ (get participant-count pool) u1),
                is-active: true,
                participants: (unwrap! (as-max-len? (append (get participants pool) tx-sender) u10) ERR-POOL-FULL),
                pool-creator: (get pool-creator pool)
            })
            
            (map-set pool-participant-status 
                {pool-id: pool-id, user: tx-sender} 
                true)
            
            (map-set user-balances 
                tx-sender 
                (- user-balance amount))
            
            (ok true))
    )
)

;; Distribute pooled funds to all participants with privacy-preserving logic
(define-public (distribute-pool-funds (pool-id uint))
    (let ((pool (unwrap! (map-get? mixer-pools pool-id) ERR-INVALID-POOL))
          (participants (get participants pool))
          (total-pool-amount (get total-amount pool))
          (participant-count (get participant-count pool)))
        
        (asserts! (get is-active pool) ERR-POOL-NOT-READY)
        (asserts! (is-eq participant-count (len participants)) ERR-POOL-NOT-READY)
        
        (let ((mixing-fee (/ (* total-pool-amount MIXING-FEE-PERCENTAGE) u100))
              (distributable-amount (- total-pool-amount mixing-fee))
              (per-participant (/ distributable-amount participant-count)))
            
            ;; Add mixing fee to protocol fees
            (var-set total-protocol-fees (+ (var-get total-protocol-fees) mixing-fee))
            
            ;; Distribute funds to participants
            (try! (fold distribute-to-participant participants (ok u0)))
            
            ;; Mark pool as inactive
            (map-set mixer-pools pool-id (merge pool {is-active: false}))
            
            (ok true))
    )
)

;; Emergency pause functionality for security incidents
(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set is-contract-paused (not (var-get is-contract-paused)))
        (ok (var-get is-contract-paused))
    )
)

;; Withdraw accumulated protocol fees to treasury
(define-public (withdraw-protocol-fees)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (let ((fees (var-get total-protocol-fees)))
            (try! (as-contract (stx-transfer? fees (as-contract tx-sender) CONTRACT-OWNER)))
            (var-set total-protocol-fees u0)
            (ok fees))
    )
)

;; Read-Only Functions

;; Get user's balance within the contract
(define-read-only (get-user-balance (user principal))
    (default-to u0 (map-get? user-balances user))
)

;; Get user's remaining daily transaction limit
(define-read-only (get-daily-limit-remaining (user principal))
    (let ((current-day (/ stacks-block-height u144))
          (current-total (default-to u0 
            (map-get? daily-tx-totals {user: user, day: current-day}))))
        (- MAX-DAILY-LIMIT current-total)
    )
)

;; Get current contract status information
(define-read-only (get-contract-status)
    {
        is-paused: (var-get is-contract-paused),
        is-initialized: (var-get is-contract-initialized),
        total-protocol-fees: (var-get total-protocol-fees)
    }
)