import IOKit.pwr_mgt

extension App {
    // MARK: sleep
    func setKeepAwake(_ on: Bool) {
        if on && sleepAssertion == 0 {
            IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn), "Second Display active" as CFString, &sleepAssertion)
        } else if !on && sleepAssertion != 0 {
            IOPMAssertionRelease(sleepAssertion); sleepAssertion = 0
        }
        keepAwake = on
        defaults.set(on, forKey: "keepAwake")
    }
}
