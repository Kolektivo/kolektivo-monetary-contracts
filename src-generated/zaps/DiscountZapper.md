# About the DiscountZapper

The `DiscountZapper` offers the possibility for the Kolektivo project to enable
discounted minting of KOL tokens for users.

These discounts are defined on a per asset basis. However, the `MAX_DISCOUNT`
constant in the `Reserve` defines an upper limit for discounts.

The `Reserve` offers the possiblity to allow one address (the `DiscountZapper`)
to mint discounted KOL tokens as long as the minimum backing requirement is met.

Setting the `discountZapper` variable in the Reserve to the zero address
disables the discount functionality.

To provide users the chance to deposit assets, that are supported by the
`Treasury`, in order to receive KOL tokens, the `DiscountZapper` needs
to first bond the assets into the `Treasury` and then deposit the resulting
KTT balance into the `Reserve`.

Therefore, the `DiscountZapper` needs to be eligible for bonding into the
`Treasury`, i.e. needs to be whitelisted in the `Treasury`.
