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
(define-constant ERR_DISPUTE_NOT_FOUND (err u111))
(define-constant ERR_DISPUTE_ALREADY_EXISTS (err u112))
(define-constant ERR_DISPUTE_NOT_OPEN (err u113))
(define-constant ERR_ALREADY_ARBITRATOR (err u114))
(define-constant ERR_INSUFFICIENT_ARBITRATORS (err u115))
(define-constant ERR_CANNOT_ARBITRATE_OWN_DISPUTE (err u116))
(define-constant ERR_DISPUTE_ALREADY_RESOLVED (err u117))
(define-constant ERR_NOT_ARBITRATOR (err u118))
(define-constant ERR_ALREADY_RULED (err u119))
(define-constant ERR_INVALID_RULING (err u120))

(define-data-var delivery-counter uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var dao-treasury uint u0)
(define-data-var platform-fee-percentage uint u5)
(define-data-var dispute-counter uint u0)
(define-data-var minimum-arbitrators uint u3)
(define-data-var arbitration-reward uint u1000000)

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

(define-map disputes
  uint
  {
    delivery-id: uint,
    complainant: principal,
    respondent: principal,
    reason: (string-ascii 200),
    status: (string-ascii 20),
    created-at: uint,
    resolved-at: (optional uint),
    arbitrators: (list 5 principal),
    ruling: (optional (string-ascii 20)),
    votes-for-complainant: uint,
    votes-for-respondent: uint,
    escrowed-amount: uint
  }
)

(define-map arbitration-pool
  principal
  {
    available: bool,
    disputes-arbitrated: uint,
    reputation-score: uint
  }
)

(define-map arbitration-votes
  { dispute-id: uint, arbitrator: principal }
  { vote: (string-ascii 20), timestamp: uint }
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

(define-public (register-arbitrator)
  (let
    (
      (driver-info (unwrap! (map-get? drivers tx-sender) ERR_NOT_AUTHORIZED))
    )
    (asserts! (>= (get total-deliveries driver-info) u10) ERR_NOT_AUTHORIZED)
    (asserts! (>= (get rating driver-info) u4) ERR_NOT_AUTHORIZED)
    (map-set arbitration-pool tx-sender {
      available: true,
      disputes-arbitrated: u0,
      reputation-score: u100
    })
    (ok true)
  )
)

(define-public (toggle-arbitrator-availability)
  (let
    (
      (arbitrator-info (unwrap! (map-get? arbitration-pool tx-sender) ERR_NOT_AUTHORIZED))
    )
    (map-set arbitration-pool tx-sender (merge arbitrator-info {
      available: (not (get available arbitrator-info))
    }))
    (ok true)
  )
)

(define-public (create-dispute (delivery-id uint) (reason (string-ascii 200)))
  (let
    (
      (delivery (unwrap! (map-get? deliveries delivery-id) ERR_DELIVERY_NOT_FOUND))
      (dispute-id (+ (var-get dispute-counter) u1))
      (complainant tx-sender)
      (respondent (if (is-eq tx-sender (get customer delivery))
                     (unwrap! (get driver delivery) ERR_NOT_DELIVERY_DRIVER)
                     (get customer delivery)))
      (escrowed-amount (get payment delivery))
    )
    (asserts! (or (is-eq tx-sender (get customer delivery))
                  (is-eq (some tx-sender) (get driver delivery))) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status delivery) "completed") ERR_DELIVERY_NOT_ASSIGNED)
    (map-set disputes dispute-id {
      delivery-id: delivery-id,
      complainant: complainant,
      respondent: respondent,
      reason: reason,
      status: "open",
      created-at: stacks-block-height,
      resolved-at: none,
      arbitrators: (list),
      ruling: none,
      votes-for-complainant: u0,
      votes-for-respondent: u0,
      escrowed-amount: escrowed-amount
    })
    (var-set dispute-counter dispute-id)
    (ok dispute-id)
  )
)

(define-public (join-arbitration (dispute-id uint))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
      (arbitrator-info (unwrap! (map-get? arbitration-pool tx-sender) ERR_NOT_AUTHORIZED))
      (current-arbitrators (get arbitrators dispute))
    )
    (asserts! (get available arbitrator-info) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status dispute) "open") ERR_DISPUTE_NOT_OPEN)
    (asserts! (not (is-eq tx-sender (get complainant dispute))) ERR_CANNOT_ARBITRATE_OWN_DISPUTE)
    (asserts! (not (is-eq tx-sender (get respondent dispute))) ERR_CANNOT_ARBITRATE_OWN_DISPUTE)
    (asserts! (is-none (index-of current-arbitrators tx-sender)) ERR_ALREADY_ARBITRATOR)
    (asserts! (< (len current-arbitrators) u5) ERR_INSUFFICIENT_ARBITRATORS)
    (map-set disputes dispute-id (merge dispute {
      arbitrators: (unwrap! (as-max-len? (append current-arbitrators tx-sender) u5) ERR_INSUFFICIENT_ARBITRATORS)
    }))
    (ok true)
  )
)

(define-public (submit-ruling (dispute-id uint) (ruling (string-ascii 20)))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
      (arbitrator-info (unwrap! (map-get? arbitration-pool tx-sender) ERR_NOT_AUTHORIZED))
      (vote-key { dispute-id: dispute-id, arbitrator: tx-sender })
    )
    (asserts! (is-eq (get status dispute) "open") ERR_DISPUTE_NOT_OPEN)
    (asserts! (is-some (index-of (get arbitrators dispute) tx-sender)) ERR_NOT_ARBITRATOR)
    (asserts! (>= (len (get arbitrators dispute)) (var-get minimum-arbitrators)) ERR_INSUFFICIENT_ARBITRATORS)
    (asserts! (is-none (map-get? arbitration-votes vote-key)) ERR_ALREADY_RULED)
    (asserts! (or (is-eq ruling "complainant") (is-eq ruling "respondent")) ERR_INVALID_RULING)
    (map-set arbitration-votes vote-key {
      vote: ruling,
      timestamp: stacks-block-height
    })
    (if (is-eq ruling "complainant")
      (map-set disputes dispute-id (merge dispute {
        votes-for-complainant: (+ (get votes-for-complainant dispute) u1)
      }))
      (map-set disputes dispute-id (merge dispute {
        votes-for-respondent: (+ (get votes-for-respondent dispute) u1)
      }))
    )
    (try! (check-and-resolve-dispute dispute-id))
    (ok true)
  )
)

(define-private (check-and-resolve-dispute (dispute-id uint))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
      (total-votes (+ (get votes-for-complainant dispute) (get votes-for-respondent dispute)))
      (required-votes (/ (len (get arbitrators dispute)) u2))
      (majority-threshold (+ required-votes u1))
    )
    (if (>= total-votes majority-threshold)
      (begin
        (if (> (get votes-for-complainant dispute) (get votes-for-respondent dispute))
          (try! (resolve-dispute dispute-id "complainant"))
          (try! (resolve-dispute dispute-id "respondent"))
        )
        (ok true)
      )
      (ok false)
    )
  )
)

(define-private (resolve-dispute (dispute-id uint) (winner (string-ascii 20)))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
      (escrowed-amount (get escrowed-amount dispute))
      (arbitration-fee (var-get arbitration-reward))
      (total-fee (* arbitration-fee (len (get arbitrators dispute))))
      (remaining-amount (- escrowed-amount total-fee))
      (winner-principal (if (is-eq winner "complainant")
                          (get complainant dispute)
                          (get respondent dispute)))
    )
    (asserts! (is-eq (get status dispute) "open") ERR_DISPUTE_ALREADY_RESOLVED)
    (try! (distribute-arbitration-rewards dispute-id))
    (try! (as-contract (stx-transfer? remaining-amount tx-sender winner-principal)))
    (map-set disputes dispute-id (merge dispute {
      status: "resolved",
      resolved-at: (some stacks-block-height),
      ruling: (some winner)
    }))
    (ok true)
  )
)

(define-private (distribute-arbitration-rewards (dispute-id uint))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
      (arbitrators (get arbitrators dispute))
      (reward-per-arbitrator (var-get arbitration-reward))
    )
    (try! (distribute-to-arbitrators arbitrators reward-per-arbitrator))
    (ok true)
  )
)

(define-private (distribute-to-arbitrators (arbitrators (list 5 principal)) (reward uint))
  (fold distribute-single-reward arbitrators (ok true))
)

(define-private (distribute-single-reward (arbitrator principal) (prev-result (response bool uint)))
  (match prev-result
    success (begin
      (try! (as-contract (stx-transfer? (var-get arbitration-reward) tx-sender arbitrator)))
      (match (map-get? arbitration-pool arbitrator)
        some-info (begin
          (map-set arbitration-pool arbitrator (merge some-info {
            disputes-arbitrated: (+ (get disputes-arbitrated some-info) u1),
            reputation-score: (+ (get reputation-score some-info) u10)
          }))
          (ok true)
        )
        (ok true)
      )
    )
    error (err error)
  )
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id)
)

(define-read-only (get-arbitrator (arbitrator principal))
  (map-get? arbitration-pool arbitrator)
)

(define-read-only (get-arbitration-vote (dispute-id uint) (arbitrator principal))
  (map-get? arbitration-votes { dispute-id: dispute-id, arbitrator: arbitrator })
)

(define-read-only (get-dispute-count)
  (var-get dispute-counter)
)

(define-read-only (get-arbitration-settings)
  {
    minimum-arbitrators: (var-get minimum-arbitrators),
    arbitration-reward: (var-get arbitration-reward)
  }
)