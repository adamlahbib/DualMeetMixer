import XCTest
@testable import DualMeetMixer

final class PreferencesTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "DualMeetMixerTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_defaultLabels_areGeneric() {
        let prefs = Preferences(defaults: defaults)
        XCTAssertEqual(prefs.labelA, "Window A")
        XCTAssertEqual(prefs.labelB, "Window B")
    }

    func test_settingLabels_persistsAcrossInstances() {
        let prefs1 = Preferences(defaults: defaults)
        prefs1.labelA = "Google"
        prefs1.labelB = "Apple"

        let prefs2 = Preferences(defaults: defaults)
        XCTAssertEqual(prefs2.labelA, "Google")
        XCTAssertEqual(prefs2.labelB, "Apple")
    }

    func test_keepAliveSeconds_defaultsTo10() {
        let prefs = Preferences(defaults: defaults)
        XCTAssertEqual(prefs.keepAliveSeconds, 10)
    }

    func test_cmdDBeltAndSuspenders_defaultsToFalse() {
        let prefs = Preferences(defaults: defaults)
        XCTAssertEqual(prefs.cmdDBeltAndSuspenders, false)
    }

    func test_emptyLabel_fallsBackToDefault() {
        let prefs = Preferences(defaults: defaults)
        prefs.labelA = ""
        XCTAssertEqual(prefs.labelA, "Window A",
                       "Empty user input should not produce a blank label in UI; fall back to default.")
    }
}
