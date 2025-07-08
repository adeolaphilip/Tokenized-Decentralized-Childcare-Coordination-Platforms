;; Child Development Tracking Contract
;; Tracks educational and growth milestones

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_ALREADY_EXISTS (err u202))
(define-constant ERR_INVALID_INPUT (err u203))

;; Data Variables
(define-data-var platform-active bool true)
(define-data-var total-children uint u0)
(define-data-var total-milestones uint u0)

;; Data Maps
(define-map children
  { child-id: uint }
  {
    parent: principal,
    name: (string-ascii 100),
    birth-date: uint,
    enrollment-date: uint,
    active: bool,
    current-caregiver: uint
  }
)

(define-map milestones
  { milestone-id: uint }
  {
    child-id: uint,
    milestone-type: (string-ascii 50),
    description: (string-ascii 200),
    achieved-date: uint,
    age-at-achievement: uint,
    recorded-by: principal,
    verified: bool
  }
)

(define-map assessments
  { child-id: uint, assessment-date: uint }
  {
    cognitive-score: uint,
    physical-score: uint,
    social-score: uint,
    emotional-score: uint,
    overall-rating: uint,
    assessor: principal,
    notes: (string-ascii 500)
  }
)

(define-map learning-progress
  { child-id: uint, subject: (string-ascii 50) }
  {
    current-level: uint,
    progress-percentage: uint,
    last-updated: uint,
    goals: (string-ascii 200)
  }
)

;; Public Functions

;; Register a new child
(define-public (register-child (name (string-ascii 100)) (birth-date uint) (caregiver-id uint))
  (let
    (
      (child-id (+ (var-get total-children) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (var-get platform-active) ERR_UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_INPUT)
    (asserts! (< birth-date current-time) ERR_INVALID_INPUT)

    (map-set children
      { child-id: child-id }
      {
        parent: tx-sender,
        name: name,
        birth-date: birth-date,
        enrollment-date: current-time,
        active: true,
        current-caregiver: caregiver-id
      }
    )

    (var-set total-children child-id)
    (ok child-id)
  )
)

;; Record a milestone
(define-public (record-milestone
  (child-id uint)
  (milestone-type (string-ascii 50))
  (description (string-ascii 200))
)
  (let
    (
      (child (unwrap! (map-get? children { child-id: child-id }) ERR_NOT_FOUND))
      (milestone-id (+ (var-get total-milestones) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (age-at-achievement (- current-time (get birth-date child)))
    )
    (asserts! (or
      (is-eq tx-sender (get parent child))
      (is-eq tx-sender CONTRACT_OWNER)
    ) ERR_UNAUTHORIZED)

    (map-set milestones
      { milestone-id: milestone-id }
      {
        child-id: child-id,
        milestone-type: milestone-type,
        description: description,
        achieved-date: current-time,
        age-at-achievement: age-at-achievement,
        recorded-by: tx-sender,
        verified: false
      }
    )

    (var-set total-milestones milestone-id)
    (ok milestone-id)
  )
)

;; Record assessment
(define-public (record-assessment
  (child-id uint)
  (cognitive-score uint)
  (physical-score uint)
  (social-score uint)
  (emotional-score uint)
  (notes (string-ascii 500))
)
  (let
    (
      (child (unwrap! (map-get? children { child-id: child-id }) ERR_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (overall-rating (/ (+ cognitive-score physical-score social-score emotional-score) u4))
    )
    (asserts! (or
      (is-eq tx-sender (get parent child))
      (is-eq tx-sender CONTRACT_OWNER)
    ) ERR_UNAUTHORIZED)
    (asserts! (and
      (<= cognitive-score u100)
      (<= physical-score u100)
      (<= social-score u100)
      (<= emotional-score u100)
    ) ERR_INVALID_INPUT)

    (map-set assessments
      { child-id: child-id, assessment-date: current-time }
      {
        cognitive-score: cognitive-score,
        physical-score: physical-score,
        social-score: social-score,
        emotional-score: emotional-score,
        overall-rating: overall-rating,
        assessor: tx-sender,
        notes: notes
      }
    )
    (ok true)
  )
)

;; Update learning progress
(define-public (update-learning-progress
  (child-id uint)
  (subject (string-ascii 50))
  (current-level uint)
  (progress-percentage uint)
  (goals (string-ascii 200))
)
  (let
    (
      (child (unwrap! (map-get? children { child-id: child-id }) ERR_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (or
      (is-eq tx-sender (get parent child))
      (is-eq tx-sender CONTRACT_OWNER)
    ) ERR_UNAUTHORIZED)
    (asserts! (<= progress-percentage u100) ERR_INVALID_INPUT)

    (map-set learning-progress
      { child-id: child-id, subject: subject }
      {
        current-level: current-level,
        progress-percentage: progress-percentage,
        last-updated: current-time,
        goals: goals
      }
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get child details
(define-read-only (get-child (child-id uint))
  (map-get? children { child-id: child-id })
)

;; Get milestone
(define-read-only (get-milestone (milestone-id uint))
  (map-get? milestones { milestone-id: milestone-id })
)

;; Get assessment
(define-read-only (get-assessment (child-id uint) (assessment-date uint))
  (map-get? assessments { child-id: child-id, assessment-date: assessment-date })
)

;; Get learning progress
(define-read-only (get-learning-progress (child-id uint) (subject (string-ascii 50)))
  (map-get? learning-progress { child-id: child-id, subject: subject })
)

;; Get child age in days
(define-read-only (get-child-age (child-id uint))
  (match (map-get? children { child-id: child-id })
    child (some (- (unwrap-panic (get-block-info? time (- block-height u1))) (get birth-date child)))
    none
  )
)

;; Get total children
(define-read-only (get-total-children)
  (var-get total-children)
)

;; Get total milestones
(define-read-only (get-total-milestones)
  (var-get total-milestones)
)
