;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))

;; Define data maps
(define-map user-balances principal uint)
(define-map sustainable-products (string-ascii 64) {carbon-impact: uint, price: uint})
(define-map eco-friendly-products (string-ascii 64) uint)
(define-map user-stats principal {total-credits: uint, streak: uint})
(define-map user-nfts principal (list 10 uint))
(define-map user-preferences principal (list 5 (string-ascii 64)))

;; Define variables
(define-data-var community-impact uint u0)

;; Define functions

;; Initialize or update a sustainable product
(define-public (set-sustainable-product (product-id (string-ascii 64)) (carbon-impact uint) (price uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set sustainable-products product-id {carbon-impact: carbon-impact, price: price}))
    )
)

;; Initialize or update an eco-friendly product for redemption
(define-public (set-eco-product (product-id (string-ascii 64)) (credit-cost uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set eco-friendly-products product-id credit-cost))
    )
)

;; Calculate carbon credits based on product impact and price
(define-private (calculate-carbon-credits (product-id (string-ascii 64)))
    (let (
        (product (unwrap-panic (map-get? sustainable-products product-id)))
        (impact (get carbon-impact product))
        (price (get price product))
    )
        (/ (* impact u100) price)
    )
)

;; Record a sustainable purchase and reward user
(define-public (record-purchase (user principal) (product-id (string-ascii 64)))
    (let (
        (credits (calculate-carbon-credits product-id))
        (current-stats (default-to {total-credits: u0, streak: u0} (map-get? user-stats user)))
        (new-total (+ (get total-credits current-stats) credits))
        (new-streak (+ (get streak current-stats) u1))
    )
        (map-set user-balances user (+ (default-to u0 (map-get? user-balances user)) credits))
        (map-set user-stats user {total-credits: new-total, streak: new-streak})
        (var-set community-impact (+ (var-get community-impact) credits))
        (if (and (> new-total u10000) (is-eq (mod new-total u10000) u0))
            (mint-achievement-nft user)
            (ok true)
        )
    )
)

;; Mint an NFT for user achievements
(define-private (mint-achievement-nft (user principal))
    (let (
        (current-nfts (default-to (list) (map-get? user-nfts user)))
    )
        (ok (map-set user-nfts user (unwrap-panic (as-max-len? (append current-nfts u1) u10))))
    )
)

;; Get user's carbon credit balance
(define-read-only (get-balance (user principal))
    (ok (default-to u0 (map-get? user-balances user)))
)

;; Transfer carbon credits between users
(define-public (transfer-credits (recipient principal) (amount uint))
    (let (
        (sender-balance (default-to u0 (map-get? user-balances tx-sender)))
    )
        (asserts! (>= sender-balance amount) err-insufficient-balance)
        (map-set user-balances tx-sender (- sender-balance amount))
        (map-set user-balances recipient (+ (default-to u0 (map-get? user-balances recipient)) amount))
        (ok true)
    )
)

;; Redeem carbon credits for eco-friendly products
(define-public (redeem-credits (product-id (string-ascii 64)))
    (let (
        (user-balance (default-to u0 (map-get? user-balances tx-sender)))
        (product-cost (default-to u0 (map-get? eco-friendly-products product-id)))
    )
        (asserts! (>= user-balance product-cost) err-insufficient-balance)
        (asserts! (> product-cost u0) err-not-found)
        (map-set user-balances tx-sender (- user-balance product-cost))
        (ok true)
    )
)

;; Get user stats
(define-read-only (get-user-stats (user principal))
    (ok (default-to {total-credits: u0, streak: u0} (map-get? user-stats user)))
)

;; Get community impact
(define-read-only (get-community-impact)
    (ok (var-get community-impact))
)

;; Get user's NFTs
(define-read-only (get-user-nfts (user principal))
    (ok (default-to (list) (map-get? user-nfts user)))
)

;; Update user preferences
(define-public (update-user-preferences (preferences (list 5 (string-ascii 64))))
    (ok (map-set user-preferences tx-sender preferences))
)

;; Get recommendations based on user preferences
(define-read-only (get-recommendations (user principal))
    (let (
        (prefs (default-to (list) (map-get? user-preferences user)))
    )
        (ok prefs)
    )
)