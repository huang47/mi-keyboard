import UIKit
import os

// SWFULL: isolated profiling only, never part of shipping sources.
private let switchProfileLog = Logger(subsystem: "com.shh.mi.switchprofile", category: "path")
func switchProfile(_ event: String, _ details: String = "") {
    let time = ProcessInfo.processInfo.systemUptime
    let log = switchProfileLog
    let warmed = ProcessInfo.processInfo.systemUptime
    log.notice("SWFULL t=\(time, privacy: .public) event=\(event, privacy: .public) \(details, privacy: .public)")
    if warmed - time > 0.001 { log.notice("SWFULL t=\(warmed, privacy: .public) event=logger.warmup begin=\(time, privacy: .public)") }
}
