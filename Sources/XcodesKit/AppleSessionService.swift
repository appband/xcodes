import PromiseKit
import Foundation
import AppleAPI

public class AppleSessionService {

    private let xcodesUsername = "XCODES_USERNAME"
    private let xcodesPassword = "XCODES_PASSWORD"

    var configuration: Configuration
    public var twoFactorAuthenticationCallback: TwoFactorAuthenticationCallback?

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    private func findUsername() -> String? {
        if let username = Current.shell.env(xcodesUsername) {
            return username
        }
        else if let username = configuration.defaultUsername {
            return username
        }
        return nil
    }

    private func findPassword(withUsername username: String) -> String? {
        if let password = Current.shell.env(xcodesPassword) {
            return password
        }
        else if let password = try? Current.keychain.getString(username){
            return password
        } else if let password = configuration.defaultPassword {
            return password
        }
        return nil
    }

    func validateADCSession(path: String) -> Promise<Void> {
        return Current.network.dataTask(with: URLRequest.downloadADCAuth(path: path)).asVoid()
    }

    private func requestCredentials(
        providedUsername: String?,
        shouldPromptForPassword: Bool,
        callback: TwoFactorAuthenticationCallback?
    ) -> Promise<(username: String, password: String)> {

        if let callback = callback {
            return callback(.requestLoginAndPassword)
                .map { result in
                    guard case let .login(login, password: password) = result else { throw Error.missingUsernameOrPassword }
                    return (login, password)
                }
        }

        return Promise { seal in
            var username = providedUsername ?? self.findUsername()
            var hasPromptedForUsername = false

            if username == nil {
                username = Current.shell.readLine(prompt: "Apple ID: ")
                hasPromptedForUsername = true
            }
            guard let user = username else {
                seal.reject(Error.missingUsernameOrPassword); return
            }

            let prompt = hasPromptedForUsername
                ? "Apple ID Password: "
                : "Apple ID Password (\(user)): "

            var password = self.findPassword(withUsername: user)
            if password == nil || shouldPromptForPassword {
                password = Current.shell.readSecureLine(prompt: prompt)
            }
            guard let pass = password else {
                seal.reject(Error.missingUsernameOrPassword); return
            }

            seal.fulfill((user, pass))
        }
    }


    func loginIfNeeded(
        withUsername providedUsername: String? = nil,
        shouldPromptForPassword: Bool = false
    ) -> Promise<Void> {
        return firstly { () -> Promise<Void> in
            return Current.network.validateSession()
        }
        // Don't have a valid session, so we'll need to log in
        .recover { error -> Promise<Void> in
            firstly { [unowned self] in
                return self.requestCredentials(
                    providedUsername: providedUsername,
                    shouldPromptForPassword: shouldPromptForPassword,
                    callback: self.twoFactorAuthenticationCallback
                )
            }.then { (username, password) in
                self.login(username, password: password)
            }
            .recover { error -> Promise<Void> in
                Current.logging.log(error.legibleLocalizedDescription.red)

                if case Client.Error.invalidUsernameOrPassword = error {
                    Current.logging.log("Try entering your password again")
                    // Prompt for the password next time to avoid being stuck in a loop of using an incorrect XCODES_PASSWORD environment variable
                    return self.loginIfNeeded(withUsername: providedUsername, shouldPromptForPassword: true)
                }
                else {
                    return Promise(error: error)
                }
            }
        }
    }

    func login(_ username: String, password: String) -> Promise<Void> {
        return firstly { () -> Promise<Void> in
            Current.network.login(
                accountName: username,
                password: password,
                twoFactorAuthenticationCallback: self.twoFactorAuthenticationCallback
            )
        }
        .recover { error -> Promise<Void> in

            if let error = error as? Client.Error {
                switch error  {
                    case .invalidUsernameOrPassword(_):
                        // remove any keychain password if we fail to log with an invalid username or password so it doesn't try again.
                        try? Current.keychain.remove(username)
                    default:
                        break
                }
            }

            return Promise(error: error)
        }
        .done { _ in
            try? Current.keychain.set(password, key: username)

            if self.configuration.defaultUsername != username {
                self.configuration.defaultUsername = username
                try? self.configuration.save()
            }
        }
    }

    public func logout() -> Promise<Void> {
        guard let username = findUsername() else { return Promise<Void>(error: Client.Error.notAuthenticated) }

        return Promise { seal in
            // Remove cookies in the shared URLSession
            AppleAPI.Current.network.session.reset {
                seal.fulfill(())
            }
        }
        .done {
            // Remove all keychain items
            try Current.keychain.remove(username)

            // Set `defaultUsername` in Configuration to nil
            self.configuration.defaultUsername = nil
            try self.configuration.save()
        }
    }
}

extension AppleSessionService {
    enum Error: LocalizedError, Equatable {
        case missingUsernameOrPassword

        public var errorDescription: String? {
            switch self {
                case .missingUsernameOrPassword:
                    return "Missing username or a password. Please try again."
            }
        }

    }
}
