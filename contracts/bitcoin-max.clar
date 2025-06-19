;; Title: BitcoinMax Yield Optimizer Protocol
;;
;; Summary: Advanced multi-protocol yield optimization engine for Bitcoin assets
;;          on Stacks Layer 2, maximizing returns through intelligent allocation
;;          and automated rebalancing strategies.
;;
;; Description: BitcoinMax is a sophisticated DeFi yield optimizer that automatically
;;              allocates user Bitcoin deposits across multiple yield-generating
;;              protocols to maximize returns. The system continuously monitors
;;              protocol performance, automatically rebalances funds to the highest
;;              yielding opportunities, and provides users with tokenized shares
;;              representing their proportional ownership of the optimized yield pool.
;;
;;              Key Features:
;;              - Automated yield farming across multiple Bitcoin protocols
;;              - Dynamic rebalancing based on real-time yield analysis
;;              - Tokenized share system for seamless deposits/withdrawals
;;              - Permissionless protocol integration with governance controls
;;              - Gas-optimized operations with configurable thresholds
;;              - Full Bitcoin Layer 2 compliance and security standards

;; ERROR CONSTANTS

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1001))
(define-constant ERR_TRANSFER_FAILED (err u1002))
(define-constant ERR_INVALID_AMOUNT (err u1003))
(define-constant ERR_PROTOCOL_NOT_FOUND (err u1004))
(define-constant ERR_REBALANCE_THRESHOLD_NOT_MET (err u1005))

;; DATA STORAGE

;; Contract Governance
(define-data-var contract-owner principal tx-sender)

;; Global Protocol State
(define-data-var total-deposits uint u0)
(define-data-var total-shares uint u0)
(define-data-var last-rebalance-block uint stacks-block-height)
(define-data-var rebalance-threshold uint u100) ;; 1% in basis points
(define-data-var protocol-count uint u0)

;; Yield Optimization Engine Variables
(define-data-var best-protocol-name (string-ascii 64) "")
(define-data-var best-protocol-yield uint u0)
(define-data-var remaining-amount uint u0)
(define-data-var withdrawal-result (response bool uint) (ok true))
(define-data-var rebalance-result (response bool uint) (ok true))

;; DATA MAPS

;; User Account Management
(define-map user-deposits
  principal
  uint
)
(define-map user-shares
  principal
  uint
)

;; Protocol Registry and Management
(define-map protocol-allocations
  (string-ascii 64)
  uint
)

(define-map protocol-yields
  (string-ascii 64)
  uint
) ;; APY in basis points

(define-map protocol-addresses
  (string-ascii 64)
  principal
)

(define-map protocol-enabled
  (string-ascii 64)
  bool
)

(define-map protocol-registry
  uint
  (string-ascii 64)
)

;; READ-ONLY FUNCTIONS - USER QUERIES

(define-read-only (get-user-balance (user principal))
  ;; Returns the total Bitcoin deposit balance for a specific user
  (default-to u0 (map-get? user-deposits user))
)

(define-read-only (get-user-shares (user principal))
  ;; Returns the total shares owned by a specific user
  (default-to u0 (map-get? user-shares user))
)

;; READ-ONLY FUNCTIONS - PROTOCOL QUERIES

(define-read-only (get-protocol-allocation (protocol-name (string-ascii 64)))
  ;; Returns the current allocation amount for a specific protocol
  (default-to u0 (map-get? protocol-allocations protocol-name))
)

(define-read-only (get-protocol-yield (protocol-name (string-ascii 64)))
  ;; Returns the current yield rate for a specific protocol in basis points
  (default-to u0 (map-get? protocol-yields protocol-name))
)

;; READ-ONLY FUNCTIONS - GLOBAL STATE

(define-read-only (get-total-deposits)
  ;; Returns the total Bitcoin deposits across all users
  (var-get total-deposits)
)

(define-read-only (get-total-shares)
  ;; Returns the total shares in circulation
  (var-get total-shares)
)

(define-read-only (get-share-value)
  ;; Calculates the current value of one share with 6 decimal precision
  (let (
      (total-shares-value (var-get total-shares))
      (total-deposits-value (var-get total-deposits))
    )
    (if (is-eq total-shares-value u0)
      u1000000 ;; Initial share price: 1.0 with 6 decimal places
      (/ (* total-deposits-value u1000000) total-shares-value)
    )
  )
)

;; READ-ONLY FUNCTIONS - SHARE CALCULATIONS

(define-read-only (calculate-shares-amount (deposit-amount uint))
  ;; Converts a Bitcoin deposit amount to equivalent shares
  (let ((share-price (get-share-value)))
    (if (is-eq share-price u0)
      deposit-amount
      (/ (* deposit-amount u1000000) share-price)
    )
  )
)

(define-read-only (calculate-withdrawal-amount (share-amount uint))
  ;; Converts shares to equivalent Bitcoin withdrawal amount
  (let ((share-price (get-share-value)))
    (/ (* share-amount share-price) u1000000)
  )
)

;; YIELD OPTIMIZATION ENGINE

(define-private (find-best-protocol)
  ;; Analyzes all active protocols and identifies the highest yielding option
  (begin
    ;; Initialize optimization variables
    (var-set best-protocol-name "")
    (var-set best-protocol-yield u0)
    ;; Scan all registered protocols
    (check-protocol-index u0)
    (check-protocol-index u1)
    (check-protocol-index u2)
    (check-protocol-index u3)
    (check-protocol-index u4)
    ;; Return optimization results
    {
      best-name: (var-get best-protocol-name),
      best-yield: (var-get best-protocol-yield),
    }
  )
)

(define-private (check-protocol-index (protocol-index uint))
  ;; Evaluates a protocol at given index and updates best if superior yield found
  (let ((protocol-name (default-to "" (map-get? protocol-registry protocol-index))))
    (if (not (is-eq protocol-name ""))
      (let (
          (protocol-yield (default-to u0 (map-get? protocol-yields protocol-name)))
          (protocol-active (default-to false (map-get? protocol-enabled protocol-name)))
          (current-best-yield (var-get best-protocol-yield))
        )
        (if (and protocol-active (> protocol-yield current-best-yield))
          (begin
            (var-set best-protocol-name protocol-name)
            (var-set best-protocol-yield protocol-yield)
            true
          )
          false
        )
      )
      false
    )
  )
)

(define-public (get-best-protocol)
  ;; Public interface to retrieve the current highest yielding protocol
  (let ((best-protocol (find-best-protocol)))
    (var-set best-protocol-name (get best-name best-protocol))
    (var-set best-protocol-yield (get best-yield best-protocol))
    (ok (get best-name best-protocol))
  )
)

;; CORE USER FUNCTIONS

(define-public (deposit (amount uint))
  ;; Deposits Bitcoin into the yield optimizer and mints corresponding shares
  (let (
      (sender tx-sender)
      (current-deposit (default-to u0 (map-get? user-deposits sender)))
      (share-amount (calculate-shares-amount amount))
    )
    ;; Validate deposit amount
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    ;; Execute Bitcoin transfer from user to contract
    (asserts!
      (is-ok (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        transfer amount sender (as-contract tx-sender) none
      ))
      ERR_TRANSFER_FAILED
    )
    ;; Update user account balances
    (map-set user-deposits sender (+ current-deposit amount))
    (map-set user-shares sender
      (+ (default-to u0 (map-get? user-shares sender)) share-amount)
    )
    ;; Update global protocol state
    (var-set total-deposits (+ (var-get total-deposits) amount))
    (var-set total-shares (+ (var-get total-shares) share-amount))
    ;; Execute intelligent allocation to optimal protocol
    (try! (allocate-deposit amount))
    (ok share-amount)
  )
)

(define-public (withdraw (share-amount uint))
  ;; Burns shares and withdraws corresponding Bitcoin amount
  (let (
      (sender tx-sender)
      (user-share-balance (default-to u0 (map-get? user-shares sender)))
      (withdrawal-amount (calculate-withdrawal-amount share-amount))
    )
    ;; Validate sufficient share balance
    (asserts! (>= user-share-balance share-amount) ERR_INSUFFICIENT_BALANCE)
    ;; Update user share balance
    (map-set user-shares sender (- user-share-balance share-amount))
    (var-set total-shares (- (var-get total-shares) share-amount))
    ;; Execute withdrawal from protocols
    (try! (withdraw-from-protocols withdrawal-amount))
    ;; Update user and global deposit tracking
    (map-set user-deposits sender
      (- (default-to u0 (map-get? user-deposits sender)) withdrawal-amount)
    )
    (var-set total-deposits (- (var-get total-deposits) withdrawal-amount))
    ;; Transfer Bitcoin back to user
    (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer withdrawal-amount tx-sender sender none
    ))
  )
)

;; AUTOMATED REBALANCING SYSTEM

(define-public (rebalance)
  ;; Triggers intelligent rebalancing of funds across protocols for optimal yield
  (begin
    ;; Enforce minimum rebalancing interval (100 blocks)
    (asserts! (> (- stacks-block-height (var-get last-rebalance-block)) u100)
      ERR_REBALANCE_THRESHOLD_NOT_MET
    )
    ;; Update rebalancing timestamp
    (var-set last-rebalance-block stacks-block-height)
    ;; Identify optimal protocol for rebalancing
    (try! (get-best-protocol))
    ;; Execute rebalancing strategy
    (try! (perform-rebalance (var-get best-protocol-name)))
    (ok true)
  )
)

;; PROTOCOL ADMINISTRATION

(define-public (add-protocol
    (protocol-name (string-ascii 64))
    (protocol-address principal)
    (initial-yield uint)
  )
  ;; Adds a new yield protocol to the optimization engine
  (let ((protocol-index (var-get protocol-count)))
    ;; Enforce admin privileges
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    ;; Register new protocol in system
    (map-set protocol-registry protocol-index protocol-name)
    (map-set protocol-addresses protocol-name protocol-address)
    (map-set protocol-yields protocol-name initial-yield)
    (map-set protocol-enabled protocol-name true)
    (map-set protocol-allocations protocol-name u0)
    ;; Update protocol counter
    (var-set protocol-count (+ protocol-index u1))
    (ok true)
  )
)

(define-public (update-protocol-yield
    (protocol-name (string-ascii 64))
    (new-yield uint)
  )
  ;; Updates yield information for optimal allocation decisions
  (begin
    ;; Enforce admin privileges
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    ;; Validate protocol exists
    (asserts!
      (not (is-eq (default-to none (map-get? protocol-addresses protocol-name)) none))
      ERR_PROTOCOL_NOT_FOUND
    )
    ;; Update yield data
    (map-set protocol-yields protocol-name new-yield)
    (ok true)
  )
)

(define-public (toggle-protocol
    (protocol-name (string-ascii 64))
    (enabled bool)
  )
  ;; Enables or disables a protocol for yield optimization
  (begin
    ;; Enforce admin privileges
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    ;; Validate protocol exists
    (asserts!
      (not (is-eq (default-to none (map-get? protocol-addresses protocol-name)) none))
      ERR_PROTOCOL_NOT_FOUND
    )
    ;; Update protocol status
    (map-set protocol-enabled protocol-name enabled)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  ;; Transfers contract ownership to a new administrator
  (begin
    ;; Enforce current owner privileges
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    ;; Execute ownership transfer
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; INTERNAL ALLOCATION LOGIC

(define-private (allocate-deposit (amount uint))
  ;; Intelligently allocates new deposits to the highest yielding protocol
  (begin
    ;; Identify optimal protocol
    (try! (get-best-protocol))
    (let ((best-protocol (var-get best-protocol-name)))
      (if (is-eq best-protocol "")
        (ok true) ;; Hold in contract if no protocols available
        (let ((protocol-address (unwrap! (map-get? protocol-addresses best-protocol)
            ERR_PROTOCOL_NOT_FOUND
          )))
          ;; Update allocation tracking
          (map-set protocol-allocations best-protocol
            (+ (default-to u0 (map-get? protocol-allocations best-protocol))
              amount
            ))
          ;; Execute deposit to optimal protocol
          (as-contract (try! (contract-call? protocol-address deposit amount (as-contract tx-sender))))
          (ok true)
        )
      )
    )
  )
)

(define-private (withdraw-from-protocols (amount uint))
  ;; Strategically withdraws funds from protocols based on current allocations
  (begin
    (var-set remaining-amount amount)
    (var-set withdrawal-result (ok true))
    ;; Attempt withdrawal from each protocol until amount satisfied
    (map try-withdraw-from-protocol (list u0 u1 u2 u3 u4))
    (var-get withdrawal-result)
  )
)

(define-private (try-withdraw-from-protocol (protocol-index uint))
  ;; Attempts to withdraw from a specific protocol if funds are allocated
  (let (
      (remaining (var-get remaining-amount))
      (current-result (var-get withdrawal-result))
    )
    (if (or (<= remaining u0) (is-err current-result))
      false
      (let ((protocol-name (default-to "" (map-get? protocol-registry protocol-index))))
        (if (is-eq protocol-name "")
          false
          (let (
              (protocol-allocation (default-to u0 (map-get? protocol-allocations protocol-name)))
              (protocol-address-opt (map-get? protocol-addresses protocol-name))
            )
            (if (or (<= protocol-allocation u0) (is-none protocol-address-opt))
              false
              (let ((protocol-address (unwrap! protocol-address-opt
                  (begin
                    (var-set withdrawal-result ERR_PROTOCOL_NOT_FOUND)
                    false
                  ))))
                (let ((withdrawal-amount (if (< remaining protocol-allocation)
                    remaining
                    protocol-allocation
                  )))
                  ;; Execute protocol withdrawal
                  (let ((withdraw-result (as-contract (contract-call? protocol-address withdraw withdrawal-amount
                      (as-contract tx-sender)
                    ))))
                    (if (is-ok withdraw-result)
                      (begin
                        ;; Update allocation tracking
                        (map-set protocol-allocations protocol-name
                          (- protocol-allocation withdrawal-amount)
                        )
                        (var-set remaining-amount (- remaining withdrawal-amount))
                        true
                      )
                      (begin
                        (var-set withdrawal-result ERR_TRANSFER_FAILED)
                        false
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)