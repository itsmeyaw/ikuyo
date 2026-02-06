//
//  SmallSpinner.swift
//  Ikuyo
//
//  Created by Yudhistira Wibowo on 05.02.26.
//

import SwiftUI

struct SmallSpinner: NSViewRepresentable {
    func makeNSView(context: Context) -> NSProgressIndicator {
        let indicator = NSProgressIndicator()
        indicator.isIndeterminate = true
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.startAnimation(nil)
        return indicator
    }

    func updateNSView(_ nsView: NSProgressIndicator, context: Context) {}
}
