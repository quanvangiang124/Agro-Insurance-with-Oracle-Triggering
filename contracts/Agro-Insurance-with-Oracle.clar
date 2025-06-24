(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_POLICY_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_PREMIUM (err u102))
(define-constant ERR_POLICY_EXPIRED (err u103))
(define-constant ERR_POLICY_ALREADY_CLAIMED (err u104))
(define-constant ERR_INVALID_ORACLE_DATA (err u105))
(define-constant ERR_CLAIM_CONDITIONS_NOT_MET (err u106))
(define-constant ERR_INSUFFICIENT_POOL_FUNDS (err u107))
(define-constant ERR_ORACLE_NOT_AUTHORIZED (err u108))

(define-data-var next-policy-id uint u1)
(define-data-var insurance-pool uint u0)
(define-data-var oracle-address principal tx-sender)

(define-map policies
  { policy-id: uint }
  {
    farmer: principal,
    crop-type: (string-ascii 50),
    coverage-amount: uint,
    premium-paid: uint,
    start-block: uint,
    end-block: uint,
    location: (string-ascii 100),
    min-rainfall: uint,
    max-temperature: uint,
    claimed: bool,
    active: bool
  }
)

(define-map weather-data
  { location: (string-ascii 100), block-height: uint }
  {
    rainfall: uint,
    temperature: uint,
    oracle: principal,
    timestamp: uint
  }
)

(define-map authorized-oracles
  { oracle: principal }
  { authorized: bool }
)

(define-public (set-oracle (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set oracle-address new-oracle)
    (map-set authorized-oracles { oracle: new-oracle } { authorized: true })
    (ok true)
  )
)

(define-public (authorize-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-oracles { oracle: oracle } { authorized: true })
    (ok true)
  )
)

(define-public (revoke-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-oracles { oracle: oracle } { authorized: false })
    (ok true)
  )
)

(define-public (fund-insurance-pool (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set insurance-pool (+ (var-get insurance-pool) amount))
    (ok true)
  )
)

(define-public (create-policy 
  (crop-type (string-ascii 50))
  (coverage-amount uint)
  (duration-blocks uint)
  (location (string-ascii 100))
  (min-rainfall uint)
  (max-temperature uint)
)
  (let
    (
      (policy-id (var-get next-policy-id))
      (premium (/ (* coverage-amount u10) u100))
      (current-block stacks-block-height)
    )
    (asserts! (>= (stx-get-balance tx-sender) premium) ERR_INSUFFICIENT_PREMIUM)
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    (map-set policies
      { policy-id: policy-id }
      {
        farmer: tx-sender,
        crop-type: crop-type,
        coverage-amount: coverage-amount,
        premium-paid: premium,
        start-block: current-block,
        end-block: (+ current-block duration-blocks),
        location: location,
        min-rainfall: min-rainfall,
        max-temperature: max-temperature,
        claimed: false,
        active: true
      }
    )
    (var-set insurance-pool (+ (var-get insurance-pool) premium))
    (var-set next-policy-id (+ policy-id u1))
    (ok policy-id)
  )
)

(define-public (submit-weather-data 
  (location (string-ascii 100))
  (rainfall uint)
  (temperature uint)
)
  (let
    (
      (current-block stacks-block-height)
      (oracle-auth (default-to { authorized: false } 
        (map-get? authorized-oracles { oracle: tx-sender })))
    )
    (asserts! (get authorized oracle-auth) ERR_ORACLE_NOT_AUTHORIZED)
    (map-set weather-data
      { location: location, block-height: current-block }
      {
        rainfall: rainfall,
        temperature: temperature,
        oracle: tx-sender,
        timestamp: current-block
      }
    )
    (ok true)
  )
)

(define-public (claim-insurance (policy-id uint))
  (let
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq (get farmer policy) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (get active policy) ERR_POLICY_NOT_FOUND)
    (asserts! (<= current-block (get end-block policy)) ERR_POLICY_EXPIRED)
    (asserts! (not (get claimed policy)) ERR_POLICY_ALREADY_CLAIMED)
    (asserts! (>= (var-get insurance-pool) (get coverage-amount policy)) ERR_INSUFFICIENT_POOL_FUNDS)
    
    (let
      (
        (weather-conditions (check-claim-conditions policy-id))
      )
      (asserts! weather-conditions ERR_CLAIM_CONDITIONS_NOT_MET)
      (try! (as-contract (stx-transfer? (get coverage-amount policy) tx-sender (get farmer policy))))
      (var-set insurance-pool (- (var-get insurance-pool) (get coverage-amount policy)))
      (map-set policies
        { policy-id: policy-id }
        (merge policy { claimed: true, active: false })
      )
      (ok (get coverage-amount policy))
    )
  )
)

(define-private (check-claim-conditions (policy-id uint))
  (let
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) false))
      (location (get location policy))
      (min-rainfall (get min-rainfall policy))
      (max-temp (get max-temperature policy))
      (start-block (get start-block policy))
      (end-block (get end-block policy))
    )
    (check-weather-conditions location min-rainfall max-temp start-block end-block)
  )
)

(define-private (check-weather-conditions 
  (location (string-ascii 100))
  (min-rainfall uint)
  (max-temp uint)
  (start-block uint)
  (end-block uint)
)
  (let
    (
      (weather-1 (map-get? weather-data { location: location, block-height: start-block }))
      (weather-2 (map-get? weather-data { location: location, block-height: (+ start-block u100) }))
      (weather-3 (map-get? weather-data { location: location, block-height: (+ start-block u200) }))
    )
    (or
      (match weather-1 weather
        (or 
          (< (get rainfall weather) min-rainfall)
          (> (get temperature weather) max-temp)
        )
        false
      )
      (match weather-2 weather
        (or 
          (< (get rainfall weather) min-rainfall)
          (> (get temperature weather) max-temp)
        )
        false
      )
      (match weather-3 weather
        (or 
          (< (get rainfall weather) min-rainfall)
          (> (get temperature weather) max-temp)
        )
        false
      )
    )
  )
)

(define-public (cancel-policy (policy-id uint))
  (let
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (current-block stacks-block-height)
      (refund-amount (/ (get premium-paid policy) u2))
    )
    (asserts! (is-eq (get farmer policy) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (get active policy) ERR_POLICY_NOT_FOUND)
    (asserts! (< current-block (+ (get start-block policy) u50)) ERR_POLICY_EXPIRED)
    (asserts! (not (get claimed policy)) ERR_POLICY_ALREADY_CLAIMED)
    
    (try! (as-contract (stx-transfer? refund-amount tx-sender (get farmer policy))))
    (var-set insurance-pool (- (var-get insurance-pool) refund-amount))
    (map-set policies
      { policy-id: policy-id }
      (merge policy { active: false })
    )
    (ok refund-amount)
  )
)

(define-read-only (get-policy (policy-id uint))
  (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-weather-data (location (string-ascii 100)) (height uint))
  (map-get? weather-data { location: location, block-height: height })
)

(define-read-only (get-insurance-pool)
  (var-get insurance-pool)
)

(define-read-only (get-next-policy-id)
  (var-get next-policy-id)
)

(define-read-only (is-oracle-authorized (oracle principal))
  (default-to false (get authorized (map-get? authorized-oracles { oracle: oracle })))
)

(define-read-only (calculate-premium (coverage-amount uint))
  (/ (* coverage-amount u10) u100)
)

(define-read-only (get-policy-status (policy-id uint))
  (match (map-get? policies { policy-id: policy-id })
    policy
    (if (get active policy)
      (if (get claimed policy)
        "claimed"
        (if (<= stacks-block-height (get end-block policy))
          "active"
          "expired"
        )
      )
      "cancelled"
    )
    "not-found"
  )
)
