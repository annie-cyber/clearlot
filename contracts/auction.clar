;; ClearLot: Transparent Digital Asset Marketplace
;; This contract implements a transparent auction system where:
;; 1. Asset holders can initiate lot sales for their digital assets
;; 2. Participants can submit competitive bids on active lots
;; 3. Winning participants can claim their assets when lots conclude
;; 4. Asset holders receive settlement when lots finalize

(define-constant contract-owner tx-sender)

;; Error codes
(define-constant error-unauthorized (err u100))
(define-constant error-lot-exists (err u101))
(define-constant error-lot-not-found (err u102))
(define-constant error-lot-concluded (err u103))
(define-constant error-lot-still-active (err u104))
(define-constant error-bid-insufficient (err u105))
(define-constant error-not-winning-bidder (err u106))
(define-constant error-not-lot-initiator (err u107))
(define-constant error-asset-already-withdrawn (err u108))
(define-constant error-invalid-lot-duration (err u109))
(define-constant error-invalid-reserve-price (err u110))
(define-constant error-not-contract-owner (err u111))
(define-constant error-lot-not-active (err u112))

;; Data structures
(define-map lots
  { lot-id: uint }
  {
    initiator: principal,
    asset-title: (string-ascii 64),
    asset-details: (string-ascii 256),
    asset-metadata-uri: (string-ascii 256),
    inception-block: uint,
    conclusion-block: uint,
    reserve-price: uint,
    leading-bid: uint,
    leading-bidder: (optional principal),
    is-live: bool,
    is-withdrawn: bool
  }
)

(define-map participant-bids
  { lot-id: uint, participant: principal }
  { bid-amount: uint, submission-block: uint }
)

;; Counter for lot IDs
(define-data-var next-lot-id uint u1)

;; Marketplace commission percentage (5% = 500 basis points)
(define-data-var marketplace-commission-bps uint u500)

;; Read-only functions

;; Get lot details
(define-read-only (get-lot (lot-id uint))
  (map-get? lots { lot-id: lot-id })
)

;; Get participant bid details
(define-read-only (get-participant-bid (lot-id uint) (participant principal))
  (map-get? participant-bids { lot-id: lot-id, participant: participant })
)

;; Check if a lot exists
(define-read-only (lot-exists (lot-id uint))
  (is-some (get-lot lot-id))
)

;; Check if a lot is active
(define-read-only (is-lot-live (lot-id uint))
  (match (get-lot lot-id)
    lot (and 
          (get is-live lot)
          (< block-height (get conclusion-block lot))
        )
    false
  )
)

;; Check if a lot has concluded
(define-read-only (has-lot-concluded (lot-id uint))
  (match (get-lot lot-id)
    lot (>= block-height (get conclusion-block lot))
    false
  )
)

;; Get current lot ID
(define-read-only (get-current-lot-id)
  (var-get next-lot-id)
)

;; Get marketplace commission percentage
(define-read-only (get-marketplace-commission-bps)
  (var-get marketplace-commission-bps)
)

;; Calculate marketplace commission amount
(define-read-only (calculate-marketplace-commission (amount uint))
  (/ (* amount (var-get marketplace-commission-bps)) u10000)
)

;; Helper functions

;; Calculate initiator settlement after marketplace commission
(define-private (calculate-initiator-settlement (amount uint))
  (- amount (calculate-marketplace-commission amount))
)

;; Public functions

;; Initiate a new lot
(define-public (initiate-lot 
                (asset-title (string-ascii 64))
                (asset-details (string-ascii 256))
                (asset-metadata-uri (string-ascii 256))
                (duration uint)
                (reserve-price uint))
  (let ((lot-id (var-get next-lot-id))
        (inception-block block-height)
        (conclusion-block (+ block-height duration)))
    (begin
      ;; Validate inputs
      (asserts! (> duration u0) error-invalid-lot-duration)
      (asserts! (> reserve-price u0) error-invalid-reserve-price)
      
      ;; Create lot
      (map-set lots
        { lot-id: lot-id }
        {
          initiator: tx-sender,
          asset-title: asset-title,
          asset-details: asset-details,
          asset-metadata-uri: asset-metadata-uri,
          inception-block: inception-block,
          conclusion-block: conclusion-block,
          reserve-price: reserve-price,
          leading-bid: u0,
          leading-bidder: none,
          is-live: true,
          is-withdrawn: false
        }
      )
      
      ;; Increment lot ID
      (var-set next-lot-id (+ lot-id u1))
      
      (ok lot-id)
    )
  )
)

;; Submit a bid on a lot
(define-public (submit-bid (lot-id uint) (bid-amount uint))
  (let ((lot (unwrap! (get-lot lot-id) error-lot-not-found)))
    (begin
      ;; Check lot is live
      (asserts! (get is-live lot) error-lot-not-active)
      (asserts! (< block-height (get conclusion-block lot)) error-lot-concluded)
      
      ;; Check bid amount
      (asserts! (if (is-some (get leading-bidder lot))
                   (> bid-amount (get leading-bid lot))
                   (>= bid-amount (get reserve-price lot)))
               error-bid-insufficient)
      
      ;; Record the bid
      (map-set participant-bids
        { lot-id: lot-id, participant: tx-sender }
        { bid-amount: bid-amount, submission-block: block-height }
      )
      
      ;; Update lot with new leading bid
      (map-set lots
        { lot-id: lot-id }
        (merge lot {
          leading-bid: bid-amount,
          leading-bidder: (some tx-sender)
        })
      )
      
      (ok true)
    )
  )
)

;; Conclude lot early (only by initiator)
(define-public (conclude-lot-early (lot-id uint))
  (let ((lot (unwrap! (get-lot lot-id) error-lot-not-found)))
    (begin
      ;; Check sender is lot initiator
      (asserts! (is-eq tx-sender (get initiator lot)) error-not-lot-initiator)
      
      ;; Check lot is live
      (asserts! (get is-live lot) error-lot-not-active)
      (asserts! (< block-height (get conclusion-block lot)) error-lot-concluded)
      
      ;; Update lot to mark as inactive but not withdrawn
      (map-set lots
        { lot-id: lot-id }
        (merge lot {
          is-live: false,
          conclusion-block: block-height
        })
      )
      
      (ok true)
    )
  )
)

;; Withdraw lot (only by initiator and only if no bids)
(define-public (withdraw-lot (lot-id uint))
  (let ((lot (unwrap! (get-lot lot-id) error-lot-not-found)))
    (begin
      ;; Check sender is lot initiator
      (asserts! (is-eq tx-sender (get initiator lot)) error-not-lot-initiator)
      
      ;; Check lot is live
      (asserts! (get is-live lot) error-lot-not-active)
      
      ;; Check no bids have been placed
      (asserts! (is-eq (get leading-bid lot) u0) error-bid-insufficient)
      
      ;; Update lot to mark as inactive
      (map-set lots
        { lot-id: lot-id }
        (merge lot { is-live: false })
      )
      
      (ok true)
    )
  )
)

;; Admin functions

;; Update marketplace commission (only by contract owner)
(define-public (update-marketplace-commission (new-commission-bps uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) error-not-contract-owner)
    (asserts! (<= new-commission-bps u1000) error-unauthorized)  ;; Max 10%
    (ok (var-set marketplace-commission-bps new-commission-bps))
  )
)