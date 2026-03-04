import Foundation

enum PaddleConfig {
    static let vendorID = EnvLoader.get("PADDLE_VENDOR_ID", fallback: "YOUR_VENDOR_ID")
    static let productID = EnvLoader.get("PADDLE_PRODUCT_ID", fallback: "YOUR_PRODUCT_ID")
    static let vendorAuthCode = EnvLoader.get("PADDLE_VENDOR_AUTH_CODE", fallback: "YOUR_VENDOR_AUTH_CODE")
    static let checkoutURL = EnvLoader.get("PADDLE_CHECKOUT_URL", fallback: "https://buy.paddle.com/product/YOUR_PRODUCT_ID")

    static let verifyURL = "https://v3.paddleapis.com/3.2/license/verify"
    static let activateURL = "https://v3.paddleapis.com/3.2/license/activate"
}
