import AppKit

@main
enum UncordexApplication {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.finishLaunching()
            delegate.startApplication()
            application.run()
        }
    }
}
