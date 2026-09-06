import AppKit
import NudgieCore

if CommandLine.arguments.contains("--probe") {
    ProbeRunner.run()
} else {
    if CommandLine.arguments.contains("--verbose") { setvbuf(stdout, nil, _IOLBF, 0) }
    NudgieApp.main()
}
