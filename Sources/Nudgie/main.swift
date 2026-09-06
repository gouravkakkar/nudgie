import AppKit
import NudgieCore

if CommandLine.arguments.contains("--probe") {
    ProbeRunner.run()
} else {
    NudgieApp.main()
}
