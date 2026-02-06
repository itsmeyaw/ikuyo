//
//  time.swift
//  Ikuyo
//
//  Created by Yudhistira Wibowo on 24.01.26.
//

import Foundation

enum TimeFormatError: LocalizedError {
    case invalidString(String)

    var errorDescription: String? {
        switch self {
        case .invalidString(let value):
            return "Invalid time format: \(value)"
        }
    }
}

/// Convert a HH:mm string to today time in local timezone
func timeStringToDate(timeString: String) throws -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current

    guard let time = formatter.date(from: timeString) else {
        print("ERROR - Invalid time string: <\(timeString)>")
        throw TimeFormatError.invalidString(timeString)
    }

    let calendar = Calendar.current
    let now = Date()

    let date = calendar.date(
        bySettingHour: calendar.component(.hour, from: time),
        minute: calendar.component(.minute, from: time),
        second: 0,
        of: now
    )!
    
    return date
}

/// Convert a yyyyMMdd date string and HH:mm time string to a Date in the local timezone
func dateAndTimeStringToDate(dateString: String, timeString: String) throws -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd HH:mm"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current

    let combined = "\(dateString) \(timeString)"

    guard let date = formatter.date(from: combined) else {
        print("ERROR - Invalid date/time string: <\(combined)>")
        throw TimeFormatError.invalidString(combined)
    }

    return date
}
