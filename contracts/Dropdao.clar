(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_DELIVERY (err u101))
(define-constant ERR_INSUFFICIENT_FUNDS (err u102))
(define-constant ERR_DELIVERY_NOT_FOUND (err u103))
(define-constant ERR_DELIVERY_ALREADY_ASSIGNED (err u104))
(define-constant ERR_DELIVERY_NOT_ASSIGNED (err u105))
(define-constant ERR_DELIVERY_ALREADY_COMPLETED (err u106))
(define-constant ERR_NOT_DELIVERY_DRIVER (err u107))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u108))
(define-constant ERR_ALREADY_VOTED (err u109))
(define-constant ERR_VOTING_ENDED (err u110))

(define-data-var delivery-counter uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var dao-treasury uint u0)
(define-data-var platform-fee-percentage uint u5)

(define-map deliveries
  uint
  {
    customer: principal,
    pickup-location: (string-ascii 100),
    delivery-location: (string-ascii 100),
    payment: uint,
    driver: (optional principal),
    status: (string-ascii 20),
    created-at: uint,
    completed-at: (optional uint)
  }
)

(define-map drivers
  principal
  {
    name: (string-ascii 50),
    rating: uint,
    total-deliveries: uint,
    earnings: uint,
    active: bool
  }
)

(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    votes-for: uint,
    votes-against: uint,
    voting-ends: uint,
    executed: bool
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: bool }
)

(define-map driver-ratings
  { delivery-id: uint }
  { rating: uint, rated-by: principal }
)

(define-public (register-driver (name (string-ascii 50)))
  (begin
    (map-set drivers tx-sender {
      name: name,
      rating: u5,
      total-deliveries: u0,
      earnings: u0,
      active: true
    })
    (ok true)
  )
)

(define-public (create-delivery (pickup-location (string-ascii 100)) (delivery-location (string-ascii 100)) (payment uint))
  (let
    (
      (delivery-id (+ (var-get delivery-counter) u1))
    )
    (asserts! (> payment u0) ERR_INVALID_DELIVERY)
    (try! (stx-transfer? payment tx-sender (as-contract tx-sender)))
    (map-set deliveries delivery-id {
      customer: tx-sender,
      pickup-location: pickup-location,
      delivery-location: delivery-location,
      payment: payment,
      driver: none,
      status: "pending",
      created-at: stacks-block-height,
      completed-at: none
    })
    (var-set delivery-counter delivery-id)
    (ok delivery-id)
  )
)

(define-public (accept-delivery (delivery-id uint))
  (let
    (
      (delivery (unwrap! (map-get? deliveries delivery-id) ERR_DELIVERY_NOT_FOUND))
      (driver-info (unwrap! (map-get? drivers tx-sender) ERR_NOT_AUTHORIZED))
    )
    (asserts! (get active driver-info) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status delivery) "pending") ERR_DELIVERY_ALREADY_ASSIGNED)
    (map-set deliveries delivery-id (merge delivery {
      driver: (some tx-sender),
      status: "assigned"
    }))
    (ok true)
  )
)

(define-public (complete-delivery (delivery-id uint))
  (let
    (
      (delivery (unwrap! (map-get? deliveries delivery-id) ERR_DELIVERY_NOT_FOUND))
      (driver-info (unwrap! (map-get? drivers tx-sender) ERR_NOT_DELIVERY_DRIVER))
      (platform-fee (/ (* (get payment delivery) (var-get platform-fee-percentage)) u100))
      (driver-payment (- (get payment delivery) platform-fee))
    )
    (asserts! (is-eq (some tx-sender) (get driver delivery)) ERR_NOT_DELIVERY_DRIVER)
    (asserts! (is-eq (get status delivery) "assigned") ERR_DELIVERY_NOT_ASSIGNED)
    (try! (as-contract (stx-transfer? driver-payment tx-sender tx-sender)))
    (var-set dao-treasury (+ (var-get dao-treasury) platform-fee))
    (map-set deliveries delivery-id (merge delivery {
      status: "completed",
      completed-at: (some stacks-block-height)
    }))
    (map-set drivers tx-sender (merge driver-info {
      total-deliveries: (+ (get total-deliveries driver-info) u1),
      earnings: (+ (get earnings driver-info) driver-payment)
    }))
    (ok true)
  )
)
(define-public (rate-driver (delivery-id uint) (rating uint))
  (let
    (
      (delivery (unwrap! (map-get? deliveries delivery-id) ERR_DELIVERY_NOT_FOUND))
      (driver-principal (unwrap! (get driver delivery) ERR_NOT_DELIVERY_DRIVER))
      (driver-info (unwrap! (map-get? drivers driver-principal) ERR_NOT_DELIVERY_DRIVER))
    )
    (asserts! (is-eq tx-sender (get customer delivery)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status delivery) "completed") ERR_DELIVERY_NOT_ASSIGNED)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_DELIVERY)
    (map-set driver-ratings { delivery-id: delivery-id } {
      rating: rating,
      rated-by: tx-sender
    })
    (let
      (
        (current-rating (get rating driver-info))
        (total-deliveries (get total-deliveries driver-info))
        (new-rating (/ (+ (* current-rating (- total-deliveries u1)) rating) total-deliveries))
      )
      (map-set drivers driver-principal (merge driver-info {
        rating: new-rating
      }))
    )
    (ok true)
  )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
  (let
    (
      (proposal-id (+ (var-get proposal-counter) u1))
    )
    (asserts! (is-some (map-get? drivers tx-sender)) ERR_NOT_AUTHORIZED)
    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      votes-for: u0,
      votes-against: u0,
      voting-ends: (+ stacks-block-height u144),
      executed: false
    })
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (voter-key { proposal-id: proposal-id, voter: tx-sender })
    )
    (asserts! (is-some (map-get? drivers tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (< stacks-block-height (get voting-ends proposal)) ERR_VOTING_ENDED)
    (asserts! (is-none (map-get? votes voter-key)) ERR_ALREADY_VOTED)
    (map-set votes voter-key { vote: vote })
    (if vote
      (map-set proposals proposal-id (merge proposal {
        votes-for: (+ (get votes-for proposal) u1)
      }))
      (map-set proposals proposal-id (merge proposal {
        votes-against: (+ (get votes-against proposal) u1)
      }))
    )
    (ok true)
  )
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee u20) ERR_INVALID_DELIVERY)
    (var-set platform-fee-percentage new-fee)
    (ok true)
  )
)

(define-read-only (get-delivery (delivery-id uint))
  (map-get? deliveries delivery-id)
)

(define-read-only (get-driver (driver-principal principal))
  (map-get? drivers driver-principal)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-dao-treasury)
  (var-get dao-treasury)
)

(define-read-only (get-platform-fee)
  (var-get platform-fee-percentage)
)

(define-read-only (get-delivery-count)
  (var-get delivery-counter)
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? votes { proposal-id: proposal-id, voter: voter }))
)

(define-read-only (get-driver-rating (delivery-id uint))
  (map-get? driver-ratings { delivery-id: delivery-id })
)