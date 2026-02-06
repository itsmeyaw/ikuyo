//
//  coordinate.swift
//  Ikuyo
//
//  Created by Yudhistira Wibowo on 23.01.26.
//

import Foundation
// Ubah ke class sama time


func webMercatorToLatLon(x: Double, y: Double) -> (lat: Double, lon: Double) {
    let R = 6378137.0

    let lon = (x / R) * 180 / .pi
    let lat = (2 * atan(exp(y / R)) - .pi / 2) * 180 / .pi

    return (lat, lon)
}
