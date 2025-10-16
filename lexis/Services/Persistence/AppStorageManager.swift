import SwiftUI

final class AppStorageManager {
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @AppStorage("preferredTheme") var preferredTheme: String = "dark"
}
