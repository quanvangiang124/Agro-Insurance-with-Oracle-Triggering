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

(define-constant ERR_INVALID_RISK_DATA (err u112))
(define-constant ERR_RISK_CALCULATION_FAILED (err u113))
(define-constant MAX_RISK_SCORE u1000)
(define-constant BASE_RISK_SCORE u500)
(define-constant RISK_ADJUSTMENT_FACTOR u50)

(define-constant MAX_REPUTATION_SCORE u1000)
(define-constant BASE_REPUTATION_SCORE u500)
(define-constant LOYALTY_TIER_BRONZE u300)
(define-constant LOYALTY_TIER_SILVER u600)
(define-constant LOYALTY_TIER_GOLD u800)

(define-constant ERR_BUNDLE_NOT_FOUND (err u116))
(define-constant ERR_BUNDLE_LOCATION_NOT_FOUND (err u117))
(define-constant ERR_MAX_BUNDLE_LOCATIONS_EXCEEDED (err u118))
(define-constant ERR_BUNDLE_LOCATION_ALREADY_CLAIMED (err u119))
(define-constant MAX_BUNDLE_LOCATIONS u5)
(define-constant MIN_DIVERSIFICATION_DISCOUNT u10)
(define-constant MAX_DIVERSIFICATION_DISCOUNT u20)

(define-constant ERR_INVALID_YIELD_DATA (err u114))
(define-constant ERR_YIELD_THRESHOLD_NOT_MET (err u115))
(define-constant MIN_YIELD_THRESHOLD u50)
(define-constant MAX_YIELD_THRESHOLD u95)

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

(define-constant ERR_INSUFFICIENT_APPROVALS (err u109))
(define-constant ERR_ALREADY_APPROVED (err u110))
(define-constant ERR_NOT_AUTHORIZED_SIGNER (err u111))
(define-constant APPROVAL_THRESHOLD u500000)
(define-constant REQUIRED_APPROVALS u3)

(define-data-var total-authorized-signers uint u0)

(define-map authorized-signers
  { signer: principal }
  { authorized: bool, added-at: uint }
)

(define-map policy-approvals
  { policy-id: uint }
  { 
    approvals: uint,
    approved-by: (list 10 principal),
    requires-approval: bool,
    fully-approved: bool
  }
)

(define-public (add-authorized-signer (signer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-signers 
      { signer: signer } 
      { authorized: true, added-at: stacks-block-height })
    (var-set total-authorized-signers (+ (var-get total-authorized-signers) u1))
    (ok true)
  )
)

(define-public (remove-authorized-signer (signer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-signers 
      { signer: signer } 
      { authorized: false, added-at: u0 })
    (var-set total-authorized-signers (- (var-get total-authorized-signers) u1))
    (ok true)
  )
)

(define-public (approve-policy (policy-id uint))
  (let
    (
      (signer-info (map-get? authorized-signers { signer: tx-sender }))
      (policy-approval (default-to 
        { approvals: u0, approved-by: (list), requires-approval: false, fully-approved: false }
        (map-get? policy-approvals { policy-id: policy-id })))
      (already-approved (is-some (index-of (get approved-by policy-approval) tx-sender)))
    )
    (asserts! (is-some signer-info) ERR_NOT_AUTHORIZED_SIGNER)
    (asserts! (get authorized (unwrap-panic signer-info)) ERR_NOT_AUTHORIZED_SIGNER)
    (asserts! (not already-approved) ERR_ALREADY_APPROVED)
    (asserts! (get requires-approval policy-approval) ERR_POLICY_NOT_FOUND)
    
    (let
      (
        (new-approvals (+ (get approvals policy-approval) u1))
        (new-approved-by (unwrap-panic (as-max-len? 
          (append (get approved-by policy-approval) tx-sender) u10)))
        (is-fully-approved (>= new-approvals REQUIRED_APPROVALS))
      )
      (map-set policy-approvals
        { policy-id: policy-id }
        {
          approvals: new-approvals,
          approved-by: new-approved-by,
          requires-approval: true,
          fully-approved: is-fully-approved
        }
      )
      (ok is-fully-approved)
    )
  )
)

(define-read-only (get-policy-approvals (policy-id uint))
  (map-get? policy-approvals { policy-id: policy-id })
)

(define-read-only (is-signer-authorized (signer principal))
  (default-to false (get authorized (map-get? authorized-signers { signer: signer })))
)

(define-read-only (policy-needs-approval (coverage-amount uint))
  (>= coverage-amount APPROVAL_THRESHOLD)
)


(define-map regional-risk-data
  { location: (string-ascii 100) }
  {
    total-policies: uint,
    successful-claims: uint,
    weather-volatility: uint,
    last-updated: uint,
    risk-score: uint
  }
)

(define-map historical-weather-patterns
  { location: (string-ascii 100), season: uint }
  {
    avg-rainfall: uint,
    avg-temperature: uint,
    volatility-index: uint,
    data-points: uint
  }
)

(define-public (update-regional-risk 
  (location (string-ascii 100))
  (claim-success bool)
  (weather-volatility uint)
)
  (let
    (
      (current-data (default-to 
        { total-policies: u0, successful-claims: u0, weather-volatility: u0, 
          last-updated: u0, risk-score: BASE_RISK_SCORE }
        (map-get? regional-risk-data { location: location })))
      (new-total (+ (get total-policies current-data) u1))
      (new-claims (if claim-success 
        (+ (get successful-claims current-data) u1)
        (get successful-claims current-data)))
      (calculated-risk (calculate-risk-score new-total new-claims weather-volatility))
    )
    (map-set regional-risk-data
      { location: location }
      {
        total-policies: new-total,
        successful-claims: new-claims,
        weather-volatility: weather-volatility,
        last-updated: stacks-block-height,
        risk-score: calculated-risk
      }
    )
    (ok calculated-risk)
  )
)

(define-private (calculate-risk-score 
  (total-policies uint)
  (successful-claims uint)
  (weather-volatility uint)
)
  (if (is-eq total-policies u0)
    BASE_RISK_SCORE
    (let
      (
        (claim-rate (/ (* successful-claims u100) total-policies))
        (volatility-factor (/ (* weather-volatility RISK_ADJUSTMENT_FACTOR) u100))
        (base-adjustment (if (> claim-rate u20) 
          (+ BASE_RISK_SCORE (* (- claim-rate u20) u10))
          (- BASE_RISK_SCORE (* (- u20 claim-rate) u5))))
        (final-risk (+ base-adjustment volatility-factor))
      )
      (if (> final-risk MAX_RISK_SCORE) MAX_RISK_SCORE final-risk)
    )
  )
)

(define-public (calculate-dynamic-premium 
  (coverage-amount uint)
  (location (string-ascii 100))
)
  (let
    (
      (risk-data (map-get? regional-risk-data { location: location }))
      (risk-score (match risk-data
        data (get risk-score data)
        BASE_RISK_SCORE))
      (base-premium (/ (* coverage-amount u10) u100))
      (risk-multiplier (/ risk-score u100))
      (adjusted-premium (/ (* base-premium risk-multiplier) u5))
    )
    (ok adjusted-premium)
  )
)

(define-read-only (get-regional-risk (location (string-ascii 100)))
  (map-get? regional-risk-data { location: location })
)

(define-read-only (get-location-risk-score (location (string-ascii 100)))
  (default-to BASE_RISK_SCORE 
    (get risk-score (map-get? regional-risk-data { location: location })))
)


(define-map farmer-reputation
  { farmer: principal }
  {
    total-policies: uint,
    valid-claims: uint,
    fraudulent-claims: uint,
    reputation-score: uint,
    loyalty-tier: uint,
    join-block: uint,
    last-updated: uint
  }
)

(define-map loyalty-benefits
  { tier: uint }
  {
    discount-percentage: uint,
    max-coverage-multiplier: uint,
    priority-processing: bool
  }
)

(define-private (initialize-loyalty-tiers)
  (begin
    (map-set loyalty-benefits { tier: u0 } 
      { discount-percentage: u0, max-coverage-multiplier: u100, priority-processing: false })
    (map-set loyalty-benefits { tier: u1 } 
      { discount-percentage: u5, max-coverage-multiplier: u120, priority-processing: false })
    (map-set loyalty-benefits { tier: u2 } 
      { discount-percentage: u10, max-coverage-multiplier: u150, priority-processing: true })
    (map-set loyalty-benefits { tier: u3 } 
      { discount-percentage: u15, max-coverage-multiplier: u200, priority-processing: true })
  )
)

(define-public (update-farmer-reputation (farmer principal) (claim-valid bool))
  (let
    (
      (current-rep (default-to 
        { total-policies: u0, valid-claims: u0, fraudulent-claims: u0, 
          reputation-score: BASE_REPUTATION_SCORE, loyalty-tier: u0, 
          join-block: stacks-block-height, last-updated: u0 }
        (map-get? farmer-reputation { farmer: farmer })))
      (new-policies (+ (get total-policies current-rep) u1))
      (new-valid (if claim-valid (+ (get valid-claims current-rep) u1) (get valid-claims current-rep)))
      (new-fraud (if claim-valid (get fraudulent-claims current-rep) (+ (get fraudulent-claims current-rep) u1)))
      (calculated-score (calculate-reputation-score new-policies new-valid new-fraud))
      (new-tier (determine-loyalty-tier calculated-score))
    )
    (map-set farmer-reputation
      { farmer: farmer }
      {
        total-policies: new-policies,
        valid-claims: new-valid,
        fraudulent-claims: new-fraud,
        reputation-score: calculated-score,
        loyalty-tier: new-tier,
        join-block: (get join-block current-rep),
        last-updated: stacks-block-height
      }
    )
    (ok calculated-score)
  )
)

(define-private (calculate-reputation-score (total uint) (valid uint) (fraud uint))
  (if (is-eq total u0)
    BASE_REPUTATION_SCORE
    (let
      (
        (success-rate (/ (* valid u100) total))
        (fraud-penalty (* fraud u50))
        (base-score (+ BASE_REPUTATION_SCORE (* (- success-rate u50) u5)))
        (final-score (if (>= base-score fraud-penalty) (- base-score fraud-penalty) u0))
      )
      (if (> final-score MAX_REPUTATION_SCORE) MAX_REPUTATION_SCORE final-score)
    )
  )
)

(define-private (determine-loyalty-tier (reputation-score uint))
  (if (>= reputation-score LOYALTY_TIER_GOLD) u3
    (if (>= reputation-score LOYALTY_TIER_SILVER) u2
      (if (>= reputation-score LOYALTY_TIER_BRONZE) u1 u0)
    )
  )
)

(define-public (calculate-loyalty-premium (base-premium uint) (farmer principal))
  (let
    (
      (rep-data (map-get? farmer-reputation { farmer: farmer }))
      (tier (match rep-data data (get loyalty-tier data) u0))
      (benefits (default-to 
        { discount-percentage: u0, max-coverage-multiplier: u100, priority-processing: false }
        (map-get? loyalty-benefits { tier: tier })))
      (discount (get discount-percentage benefits))
      (discounted-premium (- base-premium (/ (* base-premium discount) u100)))
    )
    (ok discounted-premium)
  )
)

(define-read-only (get-farmer-reputation (farmer principal))
  (map-get? farmer-reputation { farmer: farmer })
)

(define-read-only (get-loyalty-tier-benefits (tier uint))
  (map-get? loyalty-benefits { tier: tier })
)


(define-map regional-yield-index
  { location: (string-ascii 100), crop-type: (string-ascii 50), season: uint }
  {
    historical-avg-yield: uint,
    current-yield: uint,
    yield-variance: uint,
    data-points-collected: uint,
    last-updated: uint
  }
)

(define-map yield-based-policies
  { policy-id: uint }
  {
    yield-threshold-percent: uint,
    baseline-yield: uint,
    season: uint,
    yield-verified: bool
  }
)

(define-public (submit-regional-yield 
  (location (string-ascii 100))
  (crop-type (string-ascii 50))
  (season uint)
  (yield-value uint)
)
  (let
    (
      (oracle-auth (default-to { authorized: false } 
        (map-get? authorized-oracles { oracle: tx-sender })))
      (existing-data (map-get? regional-yield-index 
        { location: location, crop-type: crop-type, season: season }))
    )
    (asserts! (get authorized oracle-auth) ERR_ORACLE_NOT_AUTHORIZED)
    (asserts! (> yield-value u0) ERR_INVALID_YIELD_DATA)
    
    (match existing-data
      current-index
        (let
          (
            (total-points (get data-points-collected current-index))
            (old-avg (get historical-avg-yield current-index))
            (new-avg (/ (+ (* old-avg total-points) yield-value) (+ total-points u1)))
            (variance (if (> yield-value new-avg) (- yield-value new-avg) (- new-avg yield-value)))
          )
          (map-set regional-yield-index
            { location: location, crop-type: crop-type, season: season }
            {
              historical-avg-yield: new-avg,
              current-yield: yield-value,
              yield-variance: variance,
              data-points-collected: (+ total-points u1),
              last-updated: stacks-block-height
            }
          )
          (ok new-avg)
        )
      (begin
        (map-set regional-yield-index
          { location: location, crop-type: crop-type, season: season }
          {
            historical-avg-yield: yield-value,
            current-yield: yield-value,
            yield-variance: u0,
            data-points-collected: u1,
            last-updated: stacks-block-height
          }
        )
        (ok yield-value)
      )
    )
  )
)

(define-public (attach-yield-protection 
  (policy-id uint)
  (yield-threshold-percent uint)
  (season uint)
)
  (let
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (yield-data (map-get? regional-yield-index 
        { location: (get location policy), crop-type: (get crop-type policy), season: season }))
    )
    (asserts! (is-eq (get farmer policy) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (and (>= yield-threshold-percent MIN_YIELD_THRESHOLD) 
                   (<= yield-threshold-percent MAX_YIELD_THRESHOLD)) ERR_INVALID_YIELD_DATA)
    (asserts! (is-some yield-data) ERR_INVALID_YIELD_DATA)
    
    (map-set yield-based-policies
      { policy-id: policy-id }
      {
        yield-threshold-percent: yield-threshold-percent,
        baseline-yield: (get historical-avg-yield (unwrap-panic yield-data)),
        season: season,
        yield-verified: false
      }
    )
    (ok true)
  )
)

(define-read-only (check-yield-claim-eligibility (policy-id uint))
  (let
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) (err false)))
      (yield-policy (unwrap! (map-get? yield-based-policies { policy-id: policy-id }) (err false)))
      (yield-data (unwrap! (map-get? regional-yield-index 
        { location: (get location policy), crop-type: (get crop-type policy), 
          season: (get season yield-policy) }) (err false)))
      (threshold-yield (/ (* (get baseline-yield yield-policy) 
                            (get yield-threshold-percent yield-policy)) u100))
    )
    (ok (< (get current-yield yield-data) threshold-yield))
  )
)

(define-read-only (get-regional-yield-index 
  (location (string-ascii 100))
  (crop-type (string-ascii 50))
  (season uint)
)
  (map-get? regional-yield-index { location: location, crop-type: crop-type, season: season })
)

(define-read-only (get-yield-policy-details (policy-id uint))
  (map-get? yield-based-policies { policy-id: policy-id })
)

(define-read-only (calculate-yield-adjusted-premium 
  (base-premium uint)
  (location (string-ascii 100))
  (crop-type (string-ascii 50))
  (season uint)
)
  (match (map-get? regional-yield-index 
    { location: location, crop-type: crop-type, season: season })
    yield-data
      (let
        (
          (volatility-factor (/ (get yield-variance yield-data) u10))
          (adjustment (/ (* base-premium volatility-factor) u100))
        )
        (ok (+ base-premium adjustment))
      )
    (ok base-premium)
  )
)

(define-map bundle-policies
  { bundle-id: uint }
  {
    farmer: principal,
    total-coverage: uint,
    total-premium-paid: uint,
    location-count: uint,
    diversification-score: uint,
    start-block: uint,
    end-block: uint,
    active: bool,
    remaining-coverage: uint
  }
)

(define-map bundle-locations
  { bundle-id: uint, location-index: uint }
  {
    location: (string-ascii 100),
    crop-type: (string-ascii 50),
    allocated-coverage: uint,
    min-rainfall: uint,
    max-temperature: uint,
    claimed: bool
  }
)

(define-public (create-bundle-policy
  (locations (list 5 (string-ascii 100)))
  (crop-types (list 5 (string-ascii 50)))
  (coverages (list 5 uint))
  (min-rainfalls (list 5 uint))
  (max-temperatures (list 5 uint))
  (duration-blocks uint)
)
  (let
    (
      (bundle-id (var-get next-policy-id))
      (location-count (len locations))
      (total-coverage (fold + coverages u0))
      (base-premium (/ (* total-coverage u10) u100))
      (diversification-score (calculate-diversification-score location-count))
      (discount-percent (calculate-bundle-discount diversification-score))
      (final-premium (- base-premium (/ (* base-premium discount-percent) u100)))
      (current-block stacks-block-height)
    )
    (asserts! (<= location-count MAX_BUNDLE_LOCATIONS) ERR_MAX_BUNDLE_LOCATIONS_EXCEEDED)
    (asserts! (>= (stx-get-balance tx-sender) final-premium) ERR_INSUFFICIENT_PREMIUM)
    (try! (stx-transfer? final-premium tx-sender (as-contract tx-sender)))
    
    (map-set bundle-policies
      { bundle-id: bundle-id }
      {
        farmer: tx-sender,
        total-coverage: total-coverage,
        total-premium-paid: final-premium,
        location-count: location-count,
        diversification-score: diversification-score,
        start-block: current-block,
        end-block: (+ current-block duration-blocks),
        active: true,
        remaining-coverage: total-coverage
      }
    )
    
    (fold store-location-helper 
      (list 
        { loc: (unwrap-panic (element-at locations u0)), crop: (unwrap-panic (element-at crop-types u0)), 
          cov: (unwrap-panic (element-at coverages u0)), rain: (unwrap-panic (element-at min-rainfalls u0)), 
          temp: (unwrap-panic (element-at max-temperatures u0)), idx: u0 }
        { loc: (default-to "" (element-at locations u1)), crop: (default-to "" (element-at crop-types u1)), 
          cov: (default-to u0 (element-at coverages u1)), rain: (default-to u0 (element-at min-rainfalls u1)), 
          temp: (default-to u0 (element-at max-temperatures u1)), idx: u1 }
        { loc: (default-to "" (element-at locations u2)), crop: (default-to "" (element-at crop-types u2)), 
          cov: (default-to u0 (element-at coverages u2)), rain: (default-to u0 (element-at min-rainfalls u2)), 
          temp: (default-to u0 (element-at max-temperatures u2)), idx: u2 }
        { loc: (default-to "" (element-at locations u3)), crop: (default-to "" (element-at crop-types u3)), 
          cov: (default-to u0 (element-at coverages u3)), rain: (default-to u0 (element-at min-rainfalls u3)), 
          temp: (default-to u0 (element-at max-temperatures u3)), idx: u3 }
        { loc: (default-to "" (element-at locations u4)), crop: (default-to "" (element-at crop-types u4)), 
          cov: (default-to u0 (element-at coverages u4)), rain: (default-to u0 (element-at min-rainfalls u4)), 
          temp: (default-to u0 (element-at max-temperatures u4)), idx: u4 }
      )
      { bundle-id: bundle-id, count: location-count }
    )
    (var-set insurance-pool (+ (var-get insurance-pool) final-premium))
    (var-set next-policy-id (+ bundle-id u1))
    (ok bundle-id)
  )
)

(define-private (store-location-helper 
  (item { loc: (string-ascii 100), crop: (string-ascii 50), cov: uint, rain: uint, temp: uint, idx: uint })
  (state { bundle-id: uint, count: uint })
)
  (begin
    (if (and (< (get idx item) (get count state)) (> (len (get loc item)) u0))
      (map-set bundle-locations
        { bundle-id: (get bundle-id state), location-index: (get idx item) }
        {
          location: (get loc item),
          crop-type: (get crop item),
          allocated-coverage: (get cov item),
          min-rainfall: (get rain item),
          max-temperature: (get temp item),
          claimed: false
        }
      )
      false
    )
    state
  )
)

(define-public (claim-bundle-location (bundle-id uint) (location-index uint))
  (let
    (
      (bundle (unwrap! (map-get? bundle-policies { bundle-id: bundle-id }) ERR_BUNDLE_NOT_FOUND))
      (location-data (unwrap! (map-get? bundle-locations { bundle-id: bundle-id, location-index: location-index }) ERR_BUNDLE_LOCATION_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq (get farmer bundle) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (get active bundle) ERR_BUNDLE_NOT_FOUND)
    (asserts! (<= current-block (get end-block bundle)) ERR_POLICY_EXPIRED)
    (asserts! (not (get claimed location-data)) ERR_BUNDLE_LOCATION_ALREADY_CLAIMED)
    (asserts! (>= (var-get insurance-pool) (get allocated-coverage location-data)) ERR_INSUFFICIENT_POOL_FUNDS)
    
    (let
      (
        (weather-conditions (check-weather-conditions 
          (get location location-data)
          (get min-rainfall location-data)
          (get max-temperature location-data)
          (get start-block bundle)
          (get end-block bundle)))
        (payout-amount (get allocated-coverage location-data))
        (new-remaining (- (get remaining-coverage bundle) payout-amount))
      )
      (asserts! weather-conditions ERR_CLAIM_CONDITIONS_NOT_MET)
      (try! (as-contract (stx-transfer? payout-amount tx-sender (get farmer bundle))))
      (var-set insurance-pool (- (var-get insurance-pool) payout-amount))
      
      (map-set bundle-locations
        { bundle-id: bundle-id, location-index: location-index }
        (merge location-data { claimed: true })
      )
      
      (map-set bundle-policies
        { bundle-id: bundle-id }
        (merge bundle { remaining-coverage: new-remaining, active: (> new-remaining u0) })
      )
      (ok payout-amount)
    )
  )
)

(define-private (calculate-diversification-score (location-count uint))
  (if (>= location-count u5) u100
    (if (>= location-count u4) u80
      (if (>= location-count u3) u60
        (if (>= location-count u2) u40 u20)
      )
    )
  )
)

(define-private (calculate-bundle-discount (diversification-score uint))
  (+ MIN_DIVERSIFICATION_DISCOUNT (/ (* (- diversification-score u20) MAX_DIVERSIFICATION_DISCOUNT) u80))
)

(define-read-only (get-bundle-policy (bundle-id uint))
  (map-get? bundle-policies { bundle-id: bundle-id })
)

(define-read-only (get-bundle-location (bundle-id uint) (location-index uint))
  (map-get? bundle-locations { bundle-id: bundle-id, location-index: location-index })
)

(define-read-only (calculate-bundle-savings 
  (total-coverage uint)
  (location-count uint)
)
  (let
    (
      (base-premium (/ (* total-coverage u10) u100))
      (diversification-score (calculate-diversification-score location-count))
      (discount-percent (calculate-bundle-discount diversification-score))
      (savings (/ (* base-premium discount-percent) u100))
    )
    (ok { base-premium: base-premium, final-premium: (- base-premium savings), savings: savings, discount-percent: discount-percent })
  )
)