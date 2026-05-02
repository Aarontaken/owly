import Cocoa
import IOKit
import IOKit.pwr_mgt
import IOKit.ps
import SwiftUI

// MARK: - Mode

enum CaffeinateMode: Int {
    case off = 0
    case idle = 1
    case strong = 2

    var menuTitle: String {
        switch self {
        case .off:    return "关闭"
        case .idle:   return "熄屏不睡（屏幕照常熄）"
        case .strong: return "强力模式（合盖也不睡）"
        }
    }

    var statusLine: String {
        switch self {
        case .off:    return "当前：关闭"
        case .idle:   return "当前：熄屏不睡"
        case .strong: return "当前：强力模式（合盖也不睡）"
        }
    }

    /// SF Symbol used in the SwiftUI About / Diagnostics dialogs (where
    /// the bigger canvas can comfortably show a generic icon). The menu
    /// bar uses a hand-drawn owl glyph instead — see `MenubarOwl`.
    var iconSymbol: String {
        switch self {
        case .off:    return "moon.zzz.fill"
        case .idle:   return "eye.fill"
        case .strong: return "bolt.fill"
        }
    }
}

// MARK: - Menubar owl glyph

/// Hand-drawn owl head rendered as an alpha-only template image, suitable
/// for an `NSStatusItem` button. Matches the App icon's character: ear
/// tufts, an outline head, and three expressions:
///   - off:    closed eyes (^^) plus a "Z" drifting in the corner
///   - idle:   open eyes (round dots) — Owly on watch
///   - strong: open eyes plus a small starburst around each eye
///
/// The image is `isTemplate = true`, so macOS auto-tints it to match the
/// menu bar theme (white in dark mode, black in light mode).
enum MenubarOwl {
    /// Returns a 22pt x 22pt template image for the given mode.
    static func image(for mode: CaffeinateMode) -> NSImage {
        let size: CGFloat = 22
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        defer { img.unlockFocus() }

        // Geometry tuned for a 22pt menu-bar render.
        let cx: CGFloat = size / 2
        let cy: CGFloat = size / 2
        let headW: CGFloat = 15
        let headH: CGFloat = 17
        let outlineWidth: CGFloat = 1.4

        NSColor.black.setFill()
        NSColor.black.setStroke()

        // 1. Head outline (stroke-only so the menu bar shows through and
        //    the silhouette doesn't dominate at small sizes).
        let headRect = NSRect(
            x: cx - headW / 2,
            y: cy - headH / 2,
            width: headW,
            height: headH
        )
        let headPath = NSBezierPath(ovalIn: headRect)
        headPath.lineWidth = outlineWidth
        headPath.stroke()

        // 2. Ear tufts (filled triangles, tips poking above the head)
        let earBaseY: CGFloat = cy + headH / 2 - 1.5
        let earTipY: CGFloat = cy + headH / 2 + 1.8
        let earOffset: CGFloat = 4.2
        let earBaseHalf: CGFloat = 1.3
        for sign: CGFloat in [-1, 1] {
            let earCx = cx + sign * earOffset
            let triangle = NSBezierPath()
            triangle.move(to: NSPoint(x: earCx - earBaseHalf, y: earBaseY))
            triangle.line(to: NSPoint(x: earCx + earBaseHalf, y: earBaseY))
            triangle.line(to: NSPoint(x: earCx, y: earTipY))
            triangle.close()
            triangle.fill()
        }

        // 3. Eyes (state-dependent)
        let eyeOffset: CGFloat = 3.4
        let eyeY: CGFloat = cy + 1.2
        let eyeR: CGFloat = 1.5

        switch mode {
        case .off:
            // Closed eyes: two upward arcs ("^^") drawn as round-cap strokes.
            for sign: CGFloat in [-1, 1] {
                let eyeCx = cx + sign * eyeOffset
                let arc = NSBezierPath()
                arc.lineWidth = 1.2
                arc.lineCapStyle = .round
                arc.appendArc(
                    withCenter: NSPoint(x: eyeCx, y: eyeY - 0.2),
                    radius: eyeR + 0.4,
                    startAngle: 25,
                    endAngle: 155
                )
                arc.stroke()
            }
            // Sleeping "Z" in the upper-right corner — three short strokes
            // forming a Z shape. Indicates "off duty".
            let zCx: CGFloat = size - 3.3
            let zCy: CGFloat = size - 3.3
            let zHalf: CGFloat = 1.7
            let z = NSBezierPath()
            z.lineWidth = 1.0
            z.lineCapStyle = .round
            z.lineJoinStyle = .round
            z.move(to: NSPoint(x: zCx - zHalf, y: zCy + zHalf))
            z.line(to: NSPoint(x: zCx + zHalf, y: zCy + zHalf))
            z.line(to: NSPoint(x: zCx - zHalf, y: zCy - zHalf))
            z.line(to: NSPoint(x: zCx + zHalf, y: zCy - zHalf))
            z.stroke()

        case .idle:
            // Open eyes: two filled dots (the pupils, against the head's
            // empty interior — read as round eyes at 22pt).
            for sign: CGFloat in [-1, 1] {
                let eyeCx = cx + sign * eyeOffset
                NSBezierPath(ovalIn: NSRect(
                    x: eyeCx - eyeR,
                    y: eyeY - eyeR,
                    width: eyeR * 2,
                    height: eyeR * 2
                )).fill()
            }

        case .strong:
            // Open eyes + small starburst around each.
            for sign: CGFloat in [-1, 1] {
                let eyeCx = cx + sign * eyeOffset
                NSBezierPath(ovalIn: NSRect(
                    x: eyeCx - eyeR,
                    y: eyeY - eyeR,
                    width: eyeR * 2,
                    height: eyeR * 2
                )).fill()

                // 3 short outward rays per eye (outer side only)
                let angles: [CGFloat] = sign > 0
                    ? [-35, 5, 45]      // right eye: SE, E-up, NE
                    : [135, 175, 215]   // left eye: NW, W, SW (mirror)
                for deg in angles {
                    let rad = deg * .pi / 180
                    let rayInner: CGFloat = eyeR + 0.5
                    let rayOuter: CGFloat = eyeR + 2.0
                    let dx = cos(rad)
                    let dy = sin(rad)
                    let ray = NSBezierPath()
                    ray.lineWidth = 0.9
                    ray.lineCapStyle = .round
                    ray.move(to: NSPoint(
                        x: eyeCx + dx * rayInner,
                        y: eyeY + dy * rayInner
                    ))
                    ray.line(to: NSPoint(
                        x: eyeCx + dx * rayOuter,
                        y: eyeY + dy * rayOuter
                    ))
                    ray.stroke()
                }
            }
        }

        // 4. Beak (tiny triangle pointing down, between/below the eyes)
        let beakTopY: CGFloat = cy - 2.0
        let beakTipY: CGFloat = beakTopY - 1.6
        let beakHalfW: CGFloat = 0.85
        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: cx - beakHalfW, y: beakTopY))
        beak.line(to: NSPoint(x: cx + beakHalfW, y: beakTopY))
        beak.line(to: NSPoint(x: cx, y: beakTipY))
        beak.close()
        beak.fill()

        img.isTemplate = true
        return img
    }
}

// MARK: - Idle assertion (≈ caffeinate -i)

final class IdleSleepAssertion {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive: Bool = false

    @discardableResult
    func enable() -> Bool {
        guard !isActive else { return true }
        let reason = "Owly: prevent idle sleep" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        if result == kIOReturnSuccess {
            isActive = true
            return true
        }
        return false
    }

    func disable() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
    }
}

// MARK: - System-wide sleep lock (`pmset -a disablesleep`)

enum SudoersInstallResult {
    case success
    case userCancelled
    case failed(String)
}

enum LidSleepLock {
    static let pmsetPath = "/usr/bin/pmset"
    static let sudoPath = "/usr/bin/sudo"
    static let sudoersPath = "/etc/sudoers.d/owly"

    /// Legacy filenames from earlier names of this project. Cleaned up
    /// whenever we install or uninstall sudoers, so users upgrading from
    /// the old "CaffeinateToggle" don't end up with multiple sudoers files.
    static let sudoersLegacyPaths = [
        "/etc/sudoers.d/caffeinatetoggle",
        "/etc/sudoers.d/com.user.caffeinatetoggle",
    ]

    static func isAuthorized() -> Bool {
        runSudoPmset(value: "0").exitCode == 0
    }

    static func authorizationFailureReason() -> String {
        let r = runSudoPmset(value: "0")
        return "exit=\(r.exitCode)  stderr=\(r.stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        runSudoPmset(value: enabled ? "1" : "0").exitCode == 0
    }

    /// Triggers macOS's native admin authorization dialog, then installs a
    /// sudoers entry granting passwordless execution of the two exact pmset
    /// commands we use. Also cleans up the legacy filename.
    static func installSudoersInteractively() -> SudoersInstallResult {
        let username = NSUserName()
        let sudoersContent = """
        # Owly — passwordless toggle of system-wide sleep lock.
        # Installed by the menu bar app via osascript admin authorization.
        \(username) ALL=(root) NOPASSWD: \(pmsetPath) -a disablesleep 0
        \(username) ALL=(root) NOPASSWD: \(pmsetPath) -a disablesleep 1
        """
        let base64 = Data(sudoersContent.utf8).base64EncodedString()
        let legacyCleanup = sudoersLegacyPaths.map { "/bin/rm -f \($0)" }.joined(separator: "\n")

        // Run as one shell command via `do shell script with administrator
        // privileges`. base64-encoded payload avoids any shell-quoting surprises.
        let shellCommand = """
        set -e
        TMP=$(/usr/bin/mktemp -t owly.sudoers)
        /bin/echo '\(base64)' | /usr/bin/base64 -D > "$TMP"
        /usr/sbin/visudo -c -f "$TMP" >/dev/null
        /usr/bin/install -m 0440 -o root -g wheel "$TMP" \(sudoersPath)
        \(legacyCleanup)
        /bin/rm -f "$TMP"
        """

        return runWithAdminPrivileges(
            shell: shellCommand,
            prompt: "Owly 想要启用「强力模式」。\n\n会安装一份 sudoers 规则到 /etc/sudoers.d/owly，只授权以下两条精确命令免密执行（不会获得任何其他 root 权限）：\n\n  pmset -a disablesleep 0\n  pmset -a disablesleep 1"
        )
    }

    /// Removes the sudoers entry (including any legacy filenames from
    /// earlier project names). Triggers a separate admin authorization.
    static func uninstallSudoersInteractively() -> SudoersInstallResult {
        let allPaths = ([sudoersPath] + sudoersLegacyPaths)
            .map { "/bin/rm -f \($0)" }
            .joined(separator: "\n")
        let shellCommand = """
        \(allPaths)
        /usr/bin/pmset -a disablesleep 0 || true
        """
        return runWithAdminPrivileges(
            shell: shellCommand,
            prompt: "Owly 想要撤销「强力模式」授权，并把 disablesleep 复位为 0。"
        )
    }

    private static func runWithAdminPrivileges(shell: String, prompt: String) -> SudoersInstallResult {
        let escapedShell = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedPrompt = prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let source = """
        do shell script "\(escapedShell)" with administrator privileges with prompt "\(escapedPrompt)"
        """

        guard let script = NSAppleScript(source: source) else {
            return .failed("Failed to construct AppleScript")
        }

        var errorInfo: NSDictionary?
        _ = script.executeAndReturnError(&errorInfo)

        if let error = errorInfo {
            let errNum = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            // -128 = userCanceledErr (user clicked Cancel in the auth dialog)
            if errNum == -128 {
                return .userCancelled
            }
            let msg = (error[NSAppleScript.errorMessage] as? String)
                ?? error.description
            return .failed("errno=\(errNum)  \(msg)")
        }
        return .success
    }

    static func isCurrentlyEnabled() -> Bool {
        for args in [["-g"], ["-g", "custom"]] {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: pmsetPath)
            task.arguments = args
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                continue
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { continue }

            for line in output.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let keyMatch =
                    trimmed.hasPrefix("disablesleep") ||
                    trimmed.hasPrefix("SleepDisabled")
                guard keyMatch else { continue }

                let parts = trimmed
                    .split { $0 == " " || $0 == "\t" }
                    .filter { !$0.isEmpty }
                if parts.count >= 2, let value = Int(parts[1]), value != 0 {
                    return true
                }
            }
        }
        return false
    }

    private static func runSudoPmset(value: String) -> (exitCode: Int32, stderr: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: sudoPath)
        task.arguments = ["-n", pmsetPath, "-a", "disablesleep", value]
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return (1, "spawn failed: \(error)")
        }
        let stderr = String(
            data: errPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        return (task.terminationStatus, stderr)
    }
}

// MARK: - Power source monitor

/// Watches macOS power source state via the IOPS framework. Fires
/// `onPowerUnplugged` exactly once per AC → battery transition. Used to
/// nudge the user toward strong-mode if they yank the adapter while a
/// long-running task is in flight (a common precursor to "I'll just close
/// the lid for a sec…" disasters).
final class PowerSourceMonitor {
    private var runLoopSource: CFRunLoopSource?
    private var lastIsOnAC: Bool?

    /// Called on the main thread on every AC → battery transition.
    /// Stays silent for the initial state and for AC ↔ AC noise.
    var onPowerUnplugged: (() -> Void)?

    func start() {
        guard runLoopSource == nil else { return }
        let info = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context = context else { return }
            let monitor = Unmanaged<PowerSourceMonitor>
                .fromOpaque(context)
                .takeUnretainedValue()
            DispatchQueue.main.async { monitor.handleChange() }
        }

        guard let unmanagedSource = IOPSNotificationCreateRunLoopSource(callback, info)
        else { return }
        let source = unmanagedSource.takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source

        // Seed last-known state so the first real transition is detectable.
        lastIsOnAC = Self.isOnAC()
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        runLoopSource = nil
    }

    func currentlyOnAC() -> Bool { Self.isOnAC() }

    private func handleChange() {
        let now = Self.isOnAC()
        let prev = lastIsOnAC
        lastIsOnAC = now
        if prev == true && now == false {
            onPowerUnplugged?()
        }
    }

    /// Returns true if any reported power source is currently AC-powered.
    /// Desktops without a battery report AC and never transition, which is
    /// fine — they'll never trigger `onPowerUnplugged`.
    private static func isOnAC() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return false
        }
        guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue()
                as? [CFTypeRef]
        else { return false }
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?
                    .takeUnretainedValue() as? [String: Any]
            else { continue }
            if let state = desc[kIOPSPowerSourceStateKey as String] as? String,
               state == (kIOPSACPowerValue as String) {
                return true
            }
        }
        return false
    }
}

// MARK: - LaunchAgent helpers

enum LaunchAgent {
    static let label = "com.aarontaken.owly"

    /// Plist labels used by older versions of this project. We delete these
    /// during uninstall so users upgrading from the original "CaffeinateToggle"
    /// don't end up with stale launchd registrations.
    static let legacyLabels = ["com.user.caffeinatetoggle"]

    static var plistURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// Writes ~/Library/LaunchAgents/<label>.plist pointing at the currently
    /// running executable. Does NOT call `launchctl` — the agent will be
    /// auto-loaded by macOS at the next login.
    ///
    /// Why no `launchctl load`: it would either spawn a *second* instance of
    /// the app (if RunAtLoad triggers while we're already running), or, if
    /// our current process is already managed by launchd, conflict with the
    /// existing service. Pure file-write semantics match what users expect
    /// from a "Launch at login" toggle.
    static func install() throws {
        let executablePath = Bundle.main.executablePath
            ?? Bundle.main.bundlePath + "/Contents/MacOS/Owly"

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>ProcessType</key>
            <string>Interactive</string>
            <key>StandardOutPath</key>
            <string>/tmp/\(label).out.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/\(label).err.log</string>
        </dict>
        </plist>
        """

        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try plist.write(to: plistURL, atomically: true, encoding: .utf8)
    }

    /// Removes the plist. Does NOT call `launchctl unload` — that would send
    /// SIGTERM to the currently running process if it was launched by
    /// launchd, killing the app the user is interacting with.
    ///
    /// The agent's launchd registration (if any) survives until logout. That
    /// is fine: the app is still running normally; only the auto-launch on
    /// next login is disabled, which is the user's intent.
    static func uninstall() throws {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
        // Best-effort cleanup of legacy plist names from earlier versions.
        let agentsDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        for legacyLabel in legacyLabels {
            let legacyURL = agentsDir.appendingPathComponent("\(legacyLabel).plist")
            try? FileManager.default.removeItem(at: legacyURL)
        }
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let modeKey = "currentMode"

    private var statusItem: NSStatusItem!
    private let assertion = IdleSleepAssertion()
    private var currentMode: CaffeinateMode = .off

    private var headerItem: NSMenuItem!
    private var modeItems: [CaffeinateMode: NSMenuItem] = [:]
    private var autostartItem: NSMenuItem!
    private var resetAuthItem: NSMenuItem!

    private let powerMonitor = PowerSourceMonitor()
    private let unplugPopover = UnplugAlertPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bail out if another instance is already running (prevents accidental
        // double-launch when launchd starts one and the user double-clicks
        // another, or vice versa).
        if let bid = Bundle.main.bundleIdentifier {
            let myPID = ProcessInfo.processInfo.processIdentifier
            let others = NSRunningApplication
                .runningApplications(withBundleIdentifier: bid)
                .filter { $0.processIdentifier != myPID }
            if !others.isEmpty {
                NSLog("CaffeinateToggle: another instance is already running, exiting.")
                NSApp.terminate(nil)
                return
            }
        }

        // Recover from a possible crash that left disablesleep=1 behind.
        if LidSleepLock.isAuthorized() && LidSleepLock.isCurrentlyEnabled() {
            LidSleepLock.setEnabled(false)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Restore the mode from last session.
        let savedRaw = UserDefaults.standard.integer(forKey: Self.modeKey)
        let saved = CaffeinateMode(rawValue: savedRaw) ?? .off
        applyMode(saved, persist: false)

        // Watch for AC → battery transitions. If the user yanks the
        // adapter while we're NOT in strong mode, surface a quiet
        // suggestion under the menu bar icon.
        powerMonitor.onPowerUnplugged = { [weak self] in
            self?.handlePowerUnplugged()
        }
        powerMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if currentMode == .strong {
            LidSleepLock.setEnabled(false)
        }
        assertion.disable()
        powerMonitor.stop()
    }

    // MARK: Power-source change handler

    private func handlePowerUnplugged() {
        // Already covering for clamshell sleep — no need to nag.
        guard currentMode != .strong else { return }
        // No status-bar button means the menu bar isn't visible
        // (rare — e.g. setup flake). Fail quietly.
        guard let button = statusItem.button else { return }

        unplugPopover.show(from: button) { [weak self] in
            guard let self else { return }
            // If the user already had sudoers authorized, this is a no-op
            // password-wise; otherwise applyMode will trigger the native
            // admin dialog through the normal strong-mode pathway.
            self.applyMode(.strong, persist: true)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshUI()
    }

    // MARK: Build menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        headerItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        for (i, mode) in [CaffeinateMode.off, .idle, .strong].enumerated() {
            let item = NSMenuItem(
                title: mode.menuTitle,
                action: #selector(modeMenuItemClicked(_:)),
                keyEquivalent: "\(i)"
            )
            item.target = self
            item.tag = mode.rawValue
            menu.addItem(item)
            modeItems[mode] = item
        }

        menu.addItem(.separator())

        autostartItem = NSMenuItem(
            title: "开机自启",
            action: #selector(toggleAutostart),
            keyEquivalent: ""
        )
        autostartItem.target = self
        menu.addItem(autostartItem)

        resetAuthItem = NSMenuItem(
            title: "撤销强力模式授权…",
            action: #selector(resetAuthorizationClicked),
            keyEquivalent: ""
        )
        resetAuthItem.target = self
        menu.addItem(resetAuthItem)

        let aboutItem = NSMenuItem(
            title: "关于 / 状态详情…",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let diagnosticsItem = NSMenuItem(
            title: "诊断信息…",
            action: #selector(showDiagnostics),
            keyEquivalent: ""
        )
        diagnosticsItem.target = self
        menu.addItem(diagnosticsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(NSApp.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    // MARK: Mode handling

    @objc private func modeMenuItemClicked(_ sender: NSMenuItem) {
        guard let mode = CaffeinateMode(rawValue: sender.tag) else { return }
        applyMode(mode, persist: true)
    }

    /// Shows a confirmation alert, then triggers macOS's native admin dialog
    /// to install the sudoers entry. Returns true if installation succeeded
    /// and the caller should continue switching to .strong mode.
    private func promptInstallSudoersAndRetry() -> Bool {
        let alert = NSAlert()
        alert.messageText = "启用强力模式（合盖也不睡）"
        alert.informativeText = """
        强力模式需要一次性管理员授权，之后切换永久免密。

        点击「立即授权」会弹出 macOS 原生的管理员对话框，输入登录密码即可。

        授权范围被严格限制为：
          • pmset -a disablesleep 0
          • pmset -a disablesleep 1

        不会获得其他任何 root 权限。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "立即授权…")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return false }

        let result = LidSleepLock.installSudoersInteractively()
        switch result {
        case .success:
            return true
        case .userCancelled:
            return false
        case .failed(let detail):
            presentAlert(
                title: "授权安装失败",
                message: """
                请尝试改用命令行：

                  cd ~/a-idea/owly
                  ./scripts/enable-lid-lock.sh

                技术细节：\(detail)
                """
            )
            return false
        }
    }

    @objc private func resetAuthorizationClicked() {
        let alert = NSAlert()
        alert.messageText = "撤销强力模式授权？"
        alert.informativeText = "会删除 /etc/sudoers.d/owly（以及任何遗留的旧版本 sudoers 文件）并把 disablesleep 复位为 0。需要再次输入管理员密码。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "撤销授权")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let result = LidSleepLock.uninstallSudoersInteractively()
        switch result {
        case .success:
            // If we were in strong mode, fall back to off.
            if currentMode == .strong {
                applyMode(.off, persist: true)
            }
            refreshUI()
        case .userCancelled:
            break
        case .failed(let detail):
            presentAlert(title: "撤销失败", message: detail)
        }
    }

    /// Switches into `target` mode: cleanly tears down whatever the current
    /// mode owns, then sets up the new mode's side-effects.
    private func applyMode(_ target: CaffeinateMode, persist: Bool) {
        if target == .strong && !LidSleepLock.isAuthorized() {
            // Try to install sudoers interactively (one-time, native auth dialog).
            let proceed = promptInstallSudoersAndRetry()
            if !proceed { return }
            // After installation, fall through and continue applying mode.
        }

        // Tear down current mode.
        switch currentMode {
        case .idle:   assertion.disable()
        case .strong: LidSleepLock.setEnabled(false)
        case .off:    break
        }

        // Apply target mode.
        switch target {
        case .idle:
            if !assertion.enable() {
                presentAlert(
                    title: "切换失败",
                    message: "IOKit 拒绝创建电源 assertion。"
                )
                currentMode = .off
                refreshUI()
                return
            }
        case .strong:
            if !LidSleepLock.setEnabled(true) {
                presentAlert(
                    title: "切换失败",
                    message: "执行 sudo pmset 失败。请检查 sudoers 配置。"
                )
                currentMode = .off
                refreshUI()
                return
            }
        case .off:
            break
        }

        currentMode = target
        if persist {
            UserDefaults.standard.set(target.rawValue, forKey: Self.modeKey)
        }
        refreshUI()
    }

    // MARK: UI refresh

    private func refreshUI() {
        if let button = statusItem.button {
            // Hand-drawn owl glyph (auto-tinted by macOS to match the menu
            // bar theme via `isTemplate = true`). Each mode = a different
            // owl expression: closed eyes / open eyes / open + starburst.
            button.image = MenubarOwl.image(for: currentMode)
        }

        headerItem.title = currentMode.statusLine

        for (mode, item) in modeItems {
            item.state = (mode == currentMode) ? .on : .off
            if mode == .strong && !LidSleepLock.isAuthorized() {
                item.title = "\(mode.menuTitle) — 未授权"
            } else {
                item.title = mode.menuTitle
            }
        }

        autostartItem.state = LaunchAgent.isInstalled ? .on : .off
        resetAuthItem.isHidden = !LidSleepLock.isAuthorized()
    }

    // MARK: Other actions

    @objc private func toggleAutostart() {
        let wasInstalled = LaunchAgent.isInstalled
        do {
            if wasInstalled {
                try LaunchAgent.uninstall()
            } else {
                try LaunchAgent.install()
            }
        } catch {
            presentAlert(
                title: "切换开机自启失败",
                message: "\(error)"
            )
            refreshUI()
            return
        }

        // Subtle, non-intrusive feedback only the first time the user toggles
        // it on, so they understand "next login" semantics.
        let key = "shownAutostartHint"
        if !wasInstalled && !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            presentAlert(
                title: "开机自启已启用",
                message: "下次开机或注销重新登录时，App 会自动启动。\n\n当前正在运行的实例不会受影响。"
            )
        }

        refreshUI()
    }

    private var infoWindowController: NSWindowController?

    @objc private func showAbout() {
        let snapshot = AppSnapshot(
            currentMode: currentMode,
            lidAuthorized: LidSleepLock.isAuthorized(),
            autostartConfigured: LaunchAgent.isInstalled,
            idleAssertionActive: assertion.isActive,
            disablesleepActive: LidSleepLock.isCurrentlyEnabled(),
            lidAuthFailureReason: LidSleepLock.authorizationFailureReason(),
            bundlePath: Bundle.main.bundlePath,
            pid: ProcessInfo.processInfo.processIdentifier
        )
        showInfoWindow(content: AnyView(AboutView(snapshot: snapshot)), title: "关于 / 状态详情")
    }

    @objc private func showDiagnostics() {
        let snapshot = AppSnapshot(
            currentMode: currentMode,
            lidAuthorized: LidSleepLock.isAuthorized(),
            autostartConfigured: LaunchAgent.isInstalled,
            idleAssertionActive: assertion.isActive,
            disablesleepActive: LidSleepLock.isCurrentlyEnabled(),
            lidAuthFailureReason: LidSleepLock.authorizationFailureReason(),
            bundlePath: Bundle.main.bundlePath,
            pid: ProcessInfo.processInfo.processIdentifier
        )
        showInfoWindow(content: AnyView(DiagnosticsView(snapshot: snapshot)), title: "诊断信息")
    }

    private func showInfoWindow(content: AnyView, title: String) {
        // Reuse existing window if open, just swap content.
        if let controller = infoWindowController, let window = controller.window {
            window.title = title
            window.contentView = NSHostingView(rootView: content)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        infoWindowController = controller

        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

// MARK: - SwiftUI snapshot

struct AppSnapshot {
    let currentMode: CaffeinateMode
    let lidAuthorized: Bool
    let autostartConfigured: Bool
    let idleAssertionActive: Bool
    let disablesleepActive: Bool
    let lidAuthFailureReason: String
    let bundlePath: String
    let pid: Int32
}

// MARK: - SwiftUI shared building blocks

struct InfoCardHeader: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(width: 56, height: 56)
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct StatusRow: View {
    let symbol: String
    let label: String
    let value: String
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(highlighted ? Color.accentColor : Color.secondary)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(highlighted ? .primary : .secondary)
        }
    }
}

struct ModeBlurb: View {
    let symbol: String
    let title: String
    let summary: String
    let highlighted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 22)
                .foregroundStyle(highlighted ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(highlighted ? Color.accentColor.opacity(0.10) : Color.gray.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(highlighted ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Unplug-alert popover

/// Tiny SwiftUI card shown under the menu bar icon when the user yanks
/// the power adapter while NOT in strong mode. Goal: low-friction nudge,
/// not a system notification, not a modal dialog.
private struct UnplugAlertView: View {
    let onSwitchToStrong: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.orange)
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 2) {
                    Text("电源拔了")
                        .font(.system(size: 13, weight: .semibold))
                    Text("当前是「熄屏不睡」")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Text("合盖会触发系统睡眠 — 任务/agent 会被打断。要切到「强力模式」吗？")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: onSwitchToStrong) {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                        Text("切到强力模式").font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.regular)

                Button(action: onDismiss) {
                    Text("保持当前").font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .controlSize(.regular)
            }
        }
        .padding(14)
        .frame(width: 296)
    }
}

/// Manages the lifecycle of the unplug-alert NSPopover anchored under the
/// status item. Throttles repeats so the user isn't pestered.
final class UnplugAlertPopover {
    /// Don't re-show within this many seconds, even on repeated unplugs.
    private static let throttleSeconds: TimeInterval = 30 * 60

    /// Auto-dismiss the popover after this many seconds of no interaction.
    private static let autoDismissSeconds: TimeInterval = 12

    private var popover: NSPopover?
    private var hideTimer: Timer?
    private var lastShownAt: Date?

    /// Show the popover anchored under the given status-bar button.
    /// `onSwitchToStrong` is invoked on the main thread when the user taps
    /// the primary CTA. The popover is dismissed automatically afterward.
    func show(
        from button: NSStatusBarButton,
        onSwitchToStrong: @escaping () -> Void
    ) {
        if let last = lastShownAt,
           Date().timeIntervalSince(last) < Self.throttleSeconds {
            return
        }
        lastShownAt = Date()

        // If already on screen, do nothing — don't stack.
        if popover != nil { return }

        let p = NSPopover()
        p.behavior = .transient
        p.animates = true
        let view = UnplugAlertView(
            onSwitchToStrong: { [weak self] in
                onSwitchToStrong()
                self?.dismiss()
            },
            onDismiss: { [weak self] in self?.dismiss() }
        )
        p.contentViewController = NSHostingController(rootView: view)
        p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = p

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: Self.autoDismissSeconds,
            repeats: false
        ) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        hideTimer?.invalidate()
        hideTimer = nil
        popover?.performClose(nil)
        popover = nil
    }
}

// MARK: - About view

struct AboutView: View {
    let snapshot: AppSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                InfoCardHeader(
                    title: "Owly",
                    subtitle: "v1.0  ·  菜单栏防睡眠工具",
                    symbol: "powersleep",
                    tint: .accentColor
                )

                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(
                        symbol: snapshot.currentMode.iconSymbol,
                        label: "当前模式",
                        value: snapshot.currentMode.menuTitle,
                        highlighted: snapshot.currentMode != .off
                    )
                    Divider()
                    StatusRow(
                        symbol: snapshot.lidAuthorized
                            ? "checkmark.shield.fill"
                            : "exclamationmark.shield",
                        label: "强力模式授权",
                        value: snapshot.lidAuthorized ? "已授权" : "未授权",
                        highlighted: snapshot.lidAuthorized
                    )
                    Divider()
                    StatusRow(
                        symbol: snapshot.autostartConfigured ? "power.circle.fill" : "power.circle",
                        label: "开机自启",
                        value: snapshot.autostartConfigured ? "已配置" : "未配置",
                        highlighted: snapshot.autostartConfigured
                    )
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("模式说明")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)

                    ModeBlurb(
                        symbol: CaffeinateMode.off.iconSymbol,
                        title: "关闭",
                        summary: "系统按默认电源策略走。",
                        highlighted: snapshot.currentMode == .off
                    )

                    ModeBlurb(
                        symbol: CaffeinateMode.idle.iconSymbol,
                        title: "熄屏不睡（≈ caffeinate -i）",
                        summary: "屏幕到时间照常熄灭省电，但系统不会因空闲而睡，任务继续跑。合盖仍会触发系统级睡眠。",
                        highlighted: snapshot.currentMode == .idle
                    )

                    ModeBlurb(
                        symbol: CaffeinateMode.strong.iconSymbol,
                        title: "强力模式（pmset disablesleep=1）",
                        summary: "系统级硬开关，连合盖都不睡（强力模式是熄屏不睡的超集）。",
                        highlighted: snapshot.currentMode == .strong
                    )
                }

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("App 退出时会自动复位 disablesleep=0，避免遗留状态。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(width: 520, height: 600)
        .background(.ultraThickMaterial)
    }
}

// MARK: - Diagnostics view

struct DiagnosticsView: View {
    let snapshot: AppSnapshot

    private var assertionRows: [(String, String, String, Bool)] {
        [
            ("当前模式（内存）",   snapshot.currentMode.menuTitle, snapshot.currentMode.iconSymbol,
             snapshot.currentMode != .off),
            ("IOKit assertion", snapshot.idleAssertionActive ? "active" : "inactive",
             snapshot.idleAssertionActive ? "checkmark.seal.fill" : "circle.dashed",
             snapshot.idleAssertionActive),
            ("pmset disablesleep", snapshot.disablesleepActive ? "1 (no sleep)" : "0 (default)",
             snapshot.disablesleepActive ? "lock.shield.fill" : "lock.open",
             snapshot.disablesleepActive),
            ("强力模式 sudoers", snapshot.lidAuthorized ? "OK (passwordless sudo)" : "FAILED",
             snapshot.lidAuthorized ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
             snapshot.lidAuthorized),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InfoCardHeader(
                    title: "诊断信息",
                    subtitle: "实时读取的 App 与系统状态",
                    symbol: "stethoscope",
                    tint: snapshot.lidAuthorized ? .green : .orange
                )

                VStack(spacing: 10) {
                    ForEach(Array(assertionRows.enumerated()), id: \.offset) { _, row in
                        StatusRow(symbol: row.2, label: row.0, value: row.1, highlighted: row.3)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

                if !snapshot.lidAuthorized {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("sudoers 未生效")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(snapshot.lidAuthFailureReason)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("修复：菜单点击「强力模式」会自动弹出原生授权对话框，或运行命令行脚本 `scripts/enable-lid-lock.sh`")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange.opacity(0.10))
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("进程信息")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .foregroundStyle(.secondary)
                        Text("PID")
                            .foregroundStyle(.secondary)
                        Text("\(snapshot.pid)")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .font(.system(size: 12))
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "shippingbox")
                            .foregroundStyle(.secondary)
                        Text("Bundle")
                            .foregroundStyle(.secondary)
                        Text(snapshot.bundlePath)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 12))
                }
            }
            .padding(20)
        }
        .frame(width: 520, height: 540)
        .background(.ultraThickMaterial)
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
