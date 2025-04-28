;; Community Watershed Protection Smart Contract (Full Feature)

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SITE-ALREADY-REGISTERED (err u101))
(define-constant ERR-SITE-NOT-REGISTERED (err u102))
(define-constant ERR-RESOURCES-UNAVAILABLE (err u103))
(define-constant ERR-DONATION-TOO-SMALL (err u104))
(define-constant ERR-PROGRAM-PAUSED (err u105))
(define-constant ERR-DONATION-INVALID (err u106))
(define-constant ERR-CONDITION-CODE-INVALID (err u107))
(define-constant ERR-INVALID-COORDINATOR-ADDRESS (err u108))

;; Core Program Variables
(define-data-var watershed-coordinator principal tx-sender)
(define-data-var conservation-fund uint u0)
(define-data-var program-is-active bool true)
(define-data-var donation-minimum uint u1000000) ;; 1 STX
(define-data-var emergency-mode-active bool false)

;; Data Storage
(define-map conservation-sites 
    principal 
    {
        site-active: bool,
        resources-allocated: uint,
        last-allocation-block: uint,
        current-condition: (string-ascii 20)
    }
)

(define-map steward-registry
    principal
    {
        total-contributions: uint,
        latest-contribution-block: uint
    }
)

;; Read-only Functions
(define-read-only (get-watershed-coordinator)
    (var-get watershed-coordinator)
)

(define-read-only (get-conservation-fund)
    (var-get conservation-fund)
)

(define-read-only (get-site-info (site-address principal))
    (map-get? conservation-sites site-address)
)

(define-read-only (get-steward-info (steward-address principal))
    (map-get? steward-registry steward-address)
)

(define-read-only (check-program-status)
    (and (var-get program-is-active) (not (var-get emergency-mode-active)))
)

;; Helper Functions
(define-private (is-coordinator)
    (is-eq tx-sender (var-get watershed-coordinator))
)

(define-private (record-donation (steward-address principal) (donation-amount uint))
    (let (
        (steward-record (default-to 
            { total-contributions: u0, latest-contribution-block: u0 } 
            (map-get? steward-registry steward-address)
        ))
    )
    (map-set steward-registry
        steward-address
        {
            total-contributions: (+ (get total-contributions steward-record) donation-amount),
            latest-contribution-block: block-height
        }
    ))
)

;; Validation Functions
(define-private (is-donation-valid (amount uint))
    (and 
        (> amount u0)
        (<= amount u1000000000000) ;; Upper limit for sanity check
    )
)

(define-private (is-condition-valid (condition-code (string-ascii 20)))
    (or 
        (is-eq condition-code "restored")
        (is-eq condition-code "in-progress")
        (is-eq condition-code "degraded")
        (is-eq condition-code "stabilized")
    )
)

(define-private (can-be-coordinator (candidate-address principal))
    (and 
        (not (is-eq candidate-address (var-get watershed-coordinator)))
        (not (is-eq candidate-address (as-contract tx-sender)))
    )
)

;; Public Functions
(define-public (contribute-to-watershed)
    (let (
        (donation-amount (stx-get-balance tx-sender))
    )
    (asserts! (>= donation-amount (var-get donation-minimum)) ERR-DONATION-TOO-SMALL)
    (asserts! (check-program-status) ERR-PROGRAM-PAUSED)
    
    (try! (stx-transfer? donation-amount tx-sender (as-contract tx-sender)))
    (var-set conservation-fund (+ (var-get conservation-fund) donation-amount))
    (record-donation tx-sender donation-amount)
    (ok donation-amount))
)

;; Site Management
(define-public (register-conservation-site (site-address principal))
    (begin
        (asserts! (is-coordinator) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? conservation-sites site-address)) ERR-SITE-ALREADY-REGISTERED)
        
        (map-set conservation-sites 
            site-address
            {
                site-active: true,
                resources-allocated: u0,
                last-allocation-block: u0,
                current-condition: "degraded"
            }
        )
        (ok true)
    )
)

(define-public (allocate-resources (site-address principal) (resource-amount uint))
    (begin
        (asserts! (is-coordinator) ERR-NOT-AUTHORIZED)
        (asserts! (check-program-status) ERR-PROGRAM-PAUSED)
        (asserts! (>= (var-get conservation-fund) resource-amount) ERR-RESOURCES-UNAVAILABLE)
        (asserts! 
            (is-some (map-get? conservation-sites site-address)) 
            ERR-SITE-NOT-REGISTERED
        )
        
        (try! (as-contract (stx-transfer? resource-amount tx-sender site-address)))
        (var-set conservation-fund (- (var-get conservation-fund) resource-amount))
        
        (let (
            (site-info (unwrap! (map-get? conservation-sites site-address) ERR-SITE-NOT-REGISTERED))
        )
        (map-set conservation-sites
            site-address
            {
                site-active: (get site-active site-info),
                resources-allocated: (+ (get resources-allocated site-info) resource-amount),
                last-allocation-block: block-height,
                current-condition: (get current-condition site-info)
            }
        )
        (ok resource-amount))
    )
)

;; Administrative Functions
(define-public (set-donation-minimum (new-minimum uint))
    (begin
        (asserts! (is-coordinator) ERR-NOT-AUTHORIZED)
        (asserts! (is-donation-valid new-minimum) ERR-DONATION-INVALID)
        (var-set donation-minimum new-minimum)
        (ok true)
    )
)

(define-public (toggle-program-status)
    (begin
        (asserts! (is-coordinator) ERR-NOT-AUTHORIZED)
        (var-set program-is-active (not (var-get program-is-active)))
        (ok true)
    )
)

(define-public (set-emergency-mode-on)
    (begin
        (asserts! (is-coordinator) ERR-NOT-AUTHORIZED)
        (var-set emergency-mode-active true)
        (ok true)
    )
)

(define-public (set-emergency-mode-off)
    (begin
        (asserts! (is-coordinator) ERR-NOT-AUTHORIZED)
        (var-set emergency-mode-active false)
        (ok true)
    )
)

(define-public (update-site-condition (site-address principal) (new-condition (string-ascii 20)))
    (begin
        (asserts! (is-coordinator) ERR-NOT-AUTHORIZED)
        (asserts! (is-condition-valid new-condition) ERR-CONDITION-CODE-INVALID)
        (asserts! 
            (is-some (map-get? conservation-sites site-address)) 
            ERR-SITE-NOT-REGISTERED
        )
        
        (let (
            (current-info (unwrap! (map-get? conservation-sites site-address) ERR-SITE-NOT-REGISTERED))
        )
        (map-set conservation-sites
            site-address
            {
                site-active: (get site-active current-info),
                resources-allocated: (get resources-allocated current-info),
                last-allocation-block: (get last-allocation-block current-info),
                current-condition: new-condition
            }
        )
        (ok true))
    )
)

;; Governance Function
(define-public (change-coordinator (new-coordinator-address principal))
    (begin
        (asserts! (is-coordinator) ERR-NOT-AUTHORIZED)
        (asserts! (can-be-coordinator new-coordinator-address) ERR-INVALID-COORDINATOR-ADDRESS)
        (var-set watershed-coordinator new-coordinator-address)
        (ok true)
    )
)