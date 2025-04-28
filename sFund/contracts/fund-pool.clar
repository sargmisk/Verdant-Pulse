;; Community Watershed Protection Smart Contract (Basic Version)
;; Initial implementation with core donation and site management capabilities

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SITE-ALREADY-REGISTERED (err u101))
(define-constant ERR-SITE-NOT-REGISTERED (err u102))
(define-constant ERR-RESOURCES-UNAVAILABLE (err u103))
(define-constant ERR-DONATION-TOO-SMALL (err u104))

;; Core Program Variables
(define-data-var watershed-coordinator principal tx-sender)
(define-data-var conservation-fund uint u0)
(define-data-var donation-minimum uint u1000000) ;; 1 STX

;; Data Storage
(define-map conservation-sites 
    principal 
    {
        site-active: bool,
        resources-allocated: uint,
        last-allocation-block: uint
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

;; Public Functions
(define-public (contribute-to-watershed)
    (let (
        (donation-amount (stx-get-balance tx-sender))
    )
    (asserts! (>= donation-amount (var-get donation-minimum)) ERR-DONATION-TOO-SMALL)
    
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
                last-allocation-block: u0
            }
        )
        (ok true)
    )
)

(define-public (allocate-resources (site-address principal) (resource-amount uint))
    (begin
        (asserts! (is-coordinator) ERR-NOT-AUTHORIZED)
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
                last-allocation-block: block-height
            }
        )
        (ok resource-amount))
    )
)

;; Administrative Functions
(define-public (set-donation-minimum (new-minimum uint))
    (begin
        (asserts! (is-coordinator) ERR-NOT-AUTHORIZED)
        (asserts! (> new-minimum u0) ERR-DONATION-TOO-SMALL)
        (var-set donation-minimum new-minimum)
        (ok true)
    )
)

;; Governance Function
(define-public (change-coordinator (new-coordinator-address principal))
    (begin
        (asserts! (is-coordinator) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq new-coordinator-address (var-get watershed-coordinator))) ERR-NOT-AUTHORIZED)
        (var-set watershed-coordinator new-coordinator-address)
        (ok true)
    )
)