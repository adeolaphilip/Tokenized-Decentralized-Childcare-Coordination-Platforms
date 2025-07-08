;; Activity Planning Contract
;; Coordinates age-appropriate learning experiences

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_NOT_FOUND (err u401))
(define-constant ERR_ALREADY_EXISTS (err u402))
(define-constant ERR_INVALID_INPUT (err u403))
(define-constant ERR_CAPACITY_FULL (err u404))

;; Data Variables
(define-data-var platform-active bool true)
(define-data-var total-activities uint u0)
(define-data-var total-schedules uint u0)

;; Data Maps
(define-map activities
  { activity-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 300),
    age-min: uint,
    age-max: uint,
    duration-minutes: uint,
    max-participants: uint,
    required-materials: (string-ascii 200),
    learning-objectives: (string-ascii 300),
    safety-requirements: (string-ascii 200),
    created-by: principal,
    approved: bool
  }
)

(define-map activity-schedules
  { schedule-id: uint }
  {
    activity-id: uint,
    caregiver-id: uint,
    scheduled-date: uint,
    start-time: uint,
    end-time: uint,
    location: (string-ascii 100),
    current-participants: uint,
    status: (string-ascii 20),
    notes: (string-ascii 300)
  }
)

(define-map activity-participants
  { schedule-id: uint, child-id: uint }
  {
    enrolled-at: uint,
    attendance-status: (string-ascii 20),
    engagement-score: uint,
    completion-status: bool,
    parent-feedback: (string-ascii 300)
  }
)

(define-map activity-resources
  { activity-id: uint, resource-type: (string-ascii 50) }
  {
    resource-name: (string-ascii 100),
    quantity-needed: uint,
    quantity-available: uint,
    cost-per-unit: uint,
    supplier: (string-ascii 100)
  }
)

;; Public Functions

;; Create new activity
(define-public (create-activity
  (name (string-ascii 100))
  (description (string-ascii 300))
  (age-min uint)
  (age-max uint)
  (duration-minutes uint)
  (max-participants uint)
  (required-materials (string-ascii 200))
  (learning-objectives (string-ascii 300))
  (safety-requirements (string-ascii 200))
)
  (let
    (
      (activity-id (+ (var-get total-activities) u1))
    )
    (asserts! (var-get platform-active) ERR_UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_INPUT)
    (asserts! (< age-min age-max) ERR_INVALID_INPUT)
    (asserts! (> duration-minutes u0) ERR_INVALID_INPUT)
    (asserts! (> max-participants u0) ERR_INVALID_INPUT)

    (map-set activities
      { activity-id: activity-id }
      {
        name: name,
        description: description,
        age-min: age-min,
        age-max: age-max,
        duration-minutes: duration-minutes,
        max-participants: max-participants,
        required-materials: required-materials,
        learning-objectives: learning-objectives,
        safety-requirements: safety-requirements,
        created-by: tx-sender,
        approved: false
      }
    )

    (var-set total-activities activity-id)
    (ok activity-id)
  )
)

;; Schedule activity
(define-public (schedule-activity
  (activity-id uint)
  (caregiver-id uint)
  (scheduled-date uint)
  (start-time uint)
  (end-time uint)
  (location (string-ascii 100))
)
  (let
    (
      (activity (unwrap! (map-get? activities { activity-id: activity-id }) ERR_NOT_FOUND))
      (schedule-id (+ (var-get total-schedules) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (get approved activity) ERR_UNAUTHORIZED)
    (asserts! (> scheduled-date current-time) ERR_INVALID_INPUT)
    (asserts! (< start-time end-time) ERR_INVALID_INPUT)

    (map-set activity-schedules
      { schedule-id: schedule-id }
      {
        activity-id: activity-id,
        caregiver-id: caregiver-id,
        scheduled-date: scheduled-date,
        start-time: start-time,
        end-time: end-time,
        location: location,
        current-participants: u0,
        status: "scheduled",
        notes: ""
      }
    )

    (var-set total-schedules schedule-id)
    (ok schedule-id)
  )
)

;; Enroll child in activity
(define-public (enroll-child (schedule-id uint) (child-id uint))
  (let
    (
      (schedule (unwrap! (map-get? activity-schedules { schedule-id: schedule-id }) ERR_NOT_FOUND))
      (activity (unwrap! (map-get? activities { activity-id: (get activity-id schedule) }) ERR_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (< (get current-participants schedule) (get max-participants activity)) ERR_CAPACITY_FULL)
    (asserts! (is-none (map-get? activity-participants { schedule-id: schedule-id, child-id: child-id })) ERR_ALREADY_EXISTS)

    (map-set activity-participants
      { schedule-id: schedule-id, child-id: child-id }
      {
        enrolled-at: current-time,
        attendance-status: "enrolled",
        engagement-score: u0,
        completion-status: false,
        parent-feedback: ""
      }
    )

    (map-set activity-schedules
      { schedule-id: schedule-id }
      (merge schedule { current-participants: (+ (get current-participants schedule) u1) })
    )

    (ok true)
  )
)

;; Record attendance
(define-public (record-attendance
  (schedule-id uint)
  (child-id uint)
  (attendance-status (string-ascii 20))
  (engagement-score uint)
)
  (let
    (
      (participant (unwrap! (map-get? activity-participants { schedule-id: schedule-id, child-id: child-id }) ERR_NOT_FOUND))
    )
    (asserts! (<= engagement-score u100) ERR_INVALID_INPUT)

    (map-set activity-participants
      { schedule-id: schedule-id, child-id: child-id }
      (merge participant {
        attendance-status: attendance-status,
        engagement-score: engagement-score,
        completion-status: (is-eq attendance-status "completed")
      })
    )
    (ok true)
  )
)

;; Approve activity (admin only)
(define-public (approve-activity (activity-id uint))
  (let
    (
      (activity (unwrap! (map-get? activities { activity-id: activity-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set activities
      { activity-id: activity-id }
      (merge activity { approved: true })
    )
    (ok true)
  )
)

;; Add activity resource
(define-public (add-activity-resource
  (activity-id uint)
  (resource-type (string-ascii 50))
  (resource-name (string-ascii 100))
  (quantity-needed uint)
  (quantity-available uint)
  (cost-per-unit uint)
  (supplier (string-ascii 100))
)
  (let
    (
      (activity (unwrap! (map-get? activities { activity-id: activity-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get created-by activity)) ERR_UNAUTHORIZED)

    (map-set activity-resources
      { activity-id: activity-id, resource-type: resource-type }
      {
        resource-name: resource-name,
        quantity-needed: quantity-needed,
        quantity-available: quantity-available,
        cost-per-unit: cost-per-unit,
        supplier: supplier
      }
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get activity details
(define-read-only (get-activity (activity-id uint))
  (map-get? activities { activity-id: activity-id })
)

;; Get activity schedule
(define-read-only (get-activity-schedule (schedule-id uint))
  (map-get? activity-schedules { schedule-id: schedule-id })
)

;; Get participant info
(define-read-only (get-participant-info (schedule-id uint) (child-id uint))
  (map-get? activity-participants { schedule-id: schedule-id, child-id: child-id })
)

;; Get activity resource
(define-read-only (get-activity-resource (activity-id uint) (resource-type (string-ascii 50)))
  (map-get? activity-resources { activity-id: activity-id, resource-type: resource-type })
)

;; Check if activity is age-appropriate
(define-read-only (is-age-appropriate (activity-id uint) (child-age uint))
  (match (map-get? activities { activity-id: activity-id })
    activity (and
      (>= child-age (get age-min activity))
      (<= child-age (get age-max activity))
    )
    false
  )
)

;; Get total activities
(define-read-only (get-total-activities)
  (var-get total-activities)
)

;; Get total schedules
(define-read-only (get-total-schedules)
  (var-get total-schedules)
)
