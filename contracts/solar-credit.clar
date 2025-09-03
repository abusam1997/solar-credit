;; Quest System Smart Contract (Clarinet-ready)
;; - Admin (contract owner) can create quests.
;; - Quests can reward either FT or NFT.
;; - Players enroll and submit proofs to complete quests.
;; - Prevents double-claiming; supports explicit admin-verified completion.
;; - Includes simple local FT and NFT definitions for rewards.

;; Fixed contract owner definition to use proper syntax
(define-constant CONTRACT-OWNER tx-sender)

;; --- Token Definitions (local to this contract) ---
;; Fungible token used for FT-style quest rewards
(define-fungible-token QFT)

;; Simple NFT used for badge / visual reward
(define-non-fungible-token QNFT uint)

;; --- Errors ---
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-QUEST-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-ENROLLED (err u102))
(define-constant ERR-NOT-ENROLLED (err u103))
(define-constant ERR-ALREADY-COMPLETED (err u104))
(define-constant ERR-NOTHING-TO-CLAIM (err u105))
(define-constant ERR-ZERO (err u106))
(define-constant ERR-ALREADY-CLAIMED (err u107))
(define-constant ERR-NFT-MINT (err u108))
(define-constant ERR-FT-MINT (err u109))
;; Added missing error constant
(define-constant ERR-INVALID-INPUT (err u110))

;; --- Data Structures ---
(define-data-var next-quest-id uint u1)

;; Quest record:
;; reward-kind: u1 => FT, u2 => NFT
;; reward-value: for FT => amount (uint). For NFT => token-id (uint) (optionally predetermined)
(define-map quests
  { id: uint }
  {
    creator: principal,
    title: (string-utf8 128),
    description: (string-utf8 256),
    reward-kind: uint,
    reward-value: uint,
    active: bool,
    max-participants: (optional uint) ;; none => unlimited
  }
)

;; participants map: { quest-id, player } -> true
(define-map participants { quest-id: uint, player: principal } bool)

;; completion proofs: { quest-id, player } -> proof string
(define-map completions { quest-id: uint, player: principal } { proof: (string-utf8 256), timestamp: uint })

;; claimed: { quest-id, player } -> true
(define-map claimed { quest-id: uint, player: principal } bool)

;; --- Helpers ---
(define-read-only (only-owner (who principal))
  (ok (is-eq who CONTRACT-OWNER))
)

(define-private (is-owner (who principal))
  (is-eq who CONTRACT-OWNER)
)

;; --- Admin Functions ---

;; create-quest
(define-public (create-quest
  (title (string-utf8 128))
  (description (string-utf8 256))
  (reward-kind uint)        ;; 1 = FT, 2 = NFT
  (reward-value uint)       ;; amount for FT or reserved nft-id for NFT (optional)
  (max-participants (optional uint)))
  (begin
    ;; Fixed owner check to use proper comparison
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (let ((qid (var-get next-quest-id)))
      (map-set quests { id: qid }
        {
          creator: tx-sender,
          title: title,
          description: description,
          reward-kind: reward-kind,
          reward-value: reward-value,
          active: true,
          max-participants: max-participants
        })
      (var-set next-quest-id (+ qid u1))
      (ok qid)
    )
  )
)

;; set-quest-active (pause/unpause specific quest)
(define-public (set-quest-active (quest-id uint) (flag bool))
  (begin
    ;; only creator or contract owner can toggle
    (match (map-get? quests { id: quest-id })
      quest
        (let ((creator (get creator quest)))
          (asserts! (or (is-eq creator tx-sender) (is-eq tx-sender CONTRACT-OWNER)) ERR-UNAUTHORIZED)
          (map-set quests { id: quest-id }
            {
              creator: (get creator quest),
              title: (get title quest),
              description: (get description quest),
              reward-kind: (get reward-kind quest),
              reward-value: (get reward-value quest),
              active: flag,
              max-participants: (get max-participants quest)
            })
          (ok true)
        )
      ;; Replaced underscore with proper error handling
      ERR-QUEST-NOT-FOUND
    )
  )
)

;; admin-complete: admin can mark a player's quest as complete and optionally auto-claim reward
(define-public (admin-complete (quest-id uint) (player principal) (auto-claim bool) (proof (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (match (map-get? quests { id: quest-id })
      quest
        (let ((already (map-get? completions { quest-id: quest-id, player: player })))
          (asserts! (is-none already) ERR-ALREADY-COMPLETED)
          ;; Fixed block-info function call
          (map-set completions { quest-id: quest-id, player: player }
            { proof: proof, timestamp: stacks-block-height })
          (if auto-claim
              (claim-reward-impl quest-id player)
              (ok true)
          )
        )
      ;; Replaced underscore with proper error handling
      ERR-QUEST-NOT-FOUND
    )
  )
)

;; --- Player Functions ---

;; enroll in quest
(define-public (enroll (quest-id uint))
  (begin
    (match (map-get? quests { id: quest-id })
      quest
        (let ((active (get active quest)))
          (asserts! (is-eq active true) ERR-QUEST-NOT-FOUND)
          (let ((already (map-get? participants { quest-id: quest-id, player: tx-sender })))
            (asserts! (is-none already) ERR-ALREADY-ENROLLED)
            ;; if max-participants set, optionally check count (simple naive approach)
            (map-set participants { quest-id: quest-id, player: tx-sender } true)
            (ok true)
          )
        )
      ;; Replaced underscore with proper error handling
      ERR-QUEST-NOT-FOUND
    )
  )
)

;; submit-proof: player submits proof of completion (string)
(define-public (submit-proof (quest-id uint) (proof (string-utf8 256)))
  (begin
    ;; must be enrolled
    (let ((enrolled (map-get? participants { quest-id: quest-id, player: tx-sender })))
      (asserts! (is-some enrolled) ERR-NOT-ENROLLED)
      (let ((already (map-get? completions { quest-id: quest-id, player: tx-sender })))
        (asserts! (is-none already) ERR-ALREADY-COMPLETED)
        ;; Fixed block-info function call
        (map-set completions { quest-id: quest-id, player: tx-sender }
          { proof: proof, timestamp: stacks-block-height })
        (ok true)
      )
    )
  )
)

;; claim-reward: player claims reward after completion
(define-public (claim-reward (quest-id uint))
  (begin
    (claim-reward-impl quest-id tx-sender)
  )
)

;; Fixed return type consistency in claim-reward-impl function
;; internal implementation used by admin auto-claim and claim-reward
(define-private (claim-reward-impl (quest-id uint) (who principal))
  (begin
    ;; verify quest exists
    (match (map-get? quests { id: quest-id })
      quest
        (let ((comp (map-get? completions { quest-id: quest-id, player: who }))
              (already-claimed (map-get? claimed { quest-id: quest-id, player: who })))
          (asserts! (is-some comp) ERR-NOTHING-TO-CLAIM)
          (asserts! (is-none already-claimed) ERR-ALREADY-CLAIMED)
          (let ((rk (get reward-kind quest))
                (rv (get reward-value quest)))
            ;; Replaced cond with if statements for proper Clarity syntax
            ;; mint reward depending on kind - fixed return type consistency
            (if (is-eq rk u1)
              ;; FT reward
              (begin
                (asserts! (> rv u0) ERR-ZERO)
                (try! (ft-mint? QFT rv who))
                (map-set claimed { quest-id: quest-id, player: who } true)
                (ok true)
              )
              ;; Check if NFT reward
              (if (is-eq rk u2)
                ;; NFT reward  
                (begin
                  ;; mint an NFT with id = (if rv > 0 then rv else generate id)
                  (let ((token-id (if (> rv u0) rv (var-get next-quest-id))))
                    (try! (nft-mint? QNFT token-id who))
                    (map-set claimed { quest-id: quest-id, player: who } true)
                    (ok true)
                  )
                )
                ;; Invalid reward kind
                (ok false)
              )
            )
          )
        )
      ;; Replaced underscore with proper error handling
      ERR-QUEST-NOT-FOUND
    )
  )
)

;; --- Read-only Views ---

(define-read-only (get-quest (quest-id uint))
  (map-get? quests { id: quest-id })
)

(define-read-only (has-enrolled (quest-id uint) (player principal))
  (ok (is-some (map-get? participants { quest-id: quest-id, player: player })))
)

(define-read-only (has-completed (quest-id uint) (player principal))
  (ok (is-some (map-get? completions { quest-id: quest-id, player: player })))
)

(define-read-only (has-claimed (quest-id uint) (player principal))
  (ok (is-some (map-get? claimed { quest-id: quest-id, player: player })))
)

(define-read-only (get-next-quest-id)
  (ok (var-get next-quest-id))
)
