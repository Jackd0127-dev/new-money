import XCTest
@testable import NewMoneyIPhone

final class AuthEmailFormValidationTests: XCTestCase {
    func testSignUpModeUsesCreateAccountCopyAndFourFieldLayout() {
        XCTAssertEqual(AuthScreenMode.signUp.heroTitle, AuthEntryPresentationPolicy.brandTitle)
        XCTAssertEqual(AuthScreenMode.signUp.heroSubtitle, "")
        XCTAssertEqual(AuthScreenMode.signUp.primaryTitle, "Create account")
        XCTAssertEqual(AuthScreenMode.signUp.emailLabel, "Your email")
        XCTAssertEqual(AuthScreenMode.signUp.passwordLabel, "Your password")
        XCTAssertEqual(AuthScreenMode.signUp.footerPrompt, "Already have an account?")
        XCTAssertEqual(AuthScreenMode.signUp.footerActionTitle, "Sign in")
        XCTAssertTrue(AuthScreenMode.signUp.showsNameField)
        XCTAssertTrue(AuthScreenMode.signUp.showsConfirmPasswordField)
    }

    func testSignInModeUsesSignInCopyAndTwoFieldLayout() {
        XCTAssertEqual(AuthScreenMode.signIn.heroTitle, AuthEntryPresentationPolicy.brandTitle)
        XCTAssertEqual(AuthScreenMode.signIn.heroSubtitle, "")
        XCTAssertEqual(AuthScreenMode.signIn.primaryTitle, "Sign in")
        XCTAssertEqual(AuthScreenMode.signIn.emailLabel, "Enter your email")
        XCTAssertEqual(AuthScreenMode.signIn.passwordLabel, "Enter your password")
        XCTAssertEqual(AuthScreenMode.signIn.footerPrompt, "Don't have an account yet?")
        XCTAssertEqual(AuthScreenMode.signIn.footerActionTitle, "Sign up")
        XCTAssertFalse(AuthScreenMode.signIn.showsNameField)
        XCTAssertFalse(AuthScreenMode.signIn.showsConfirmPasswordField)
    }

    func testSignUpRequiresValidEmailPasswordAndMatchingConfirmation() {
        XCTAssertFalse(AuthEmailFormValidation.canCreateAccount(email: "jack", password: "abcdef", confirmPassword: "abcdef"))
        XCTAssertFalse(AuthEmailFormValidation.canCreateAccount(email: "jack@example.com", password: "abcde", confirmPassword: "abcde"))
        XCTAssertFalse(AuthEmailFormValidation.canCreateAccount(email: "jack@example.com", password: "abcdef", confirmPassword: "different"))

        XCTAssertTrue(AuthEmailFormValidation.canCreateAccount(email: " jack@example.com ", password: "abcdef", confirmPassword: "abcdef"))
    }

    func testSignInRequiresValidEmailAndPassword() {
        XCTAssertFalse(AuthEmailFormValidation.canSignIn(email: "", password: "abcdef"))
        XCTAssertFalse(AuthEmailFormValidation.canSignIn(email: "jack@example.com", password: ""))

        XCTAssertTrue(AuthEmailFormValidation.canSignIn(email: "jack@example.com", password: "abcdef"))
    }

    func testAuthEntryUsesCenteredBrandHeaderInlinePhoneModeAndPolicyLinks() {
        XCTAssertEqual(AuthEntryPresentationPolicy.brandTitle, "MUNO MONEY")
        XCTAssertTrue(AuthEntryPresentationPolicy.hidesModeHeroCopy)
        XCTAssertTrue(AuthEntryPresentationPolicy.usesInlinePhoneMode)
        XCTAssertTrue(AuthEntryPresentationPolicy.showsBottomPolicyLinks)
    }

    func testProviderCancellationErrorsAreSuppressed() {
        let googleCancel = NSError(
            domain: AuthProviderCancellationPolicy.googleSignInErrorDomain,
            code: AuthProviderCancellationPolicy.googleSignInCanceledCode
        )

        XCTAssertTrue(AuthProviderCancellationPolicy.suppressesProviderCancellationErrors)
        XCTAssertTrue(AuthProviderCancellationPolicy.shouldSuppress(googleCancel))
        XCTAssertFalse(AuthProviderCancellationPolicy.shouldSuppress(NSError(domain: "example", code: 1)))
    }
}
