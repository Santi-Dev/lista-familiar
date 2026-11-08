import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Uso: make2 <entrada.png> <salida.png> <tamañoRegión>
// Repinta el fondo con un degradado suave y conserva el dibujo blanco y la insignia del check.
let args = CommandLine.arguments
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let w = img.width, h = img.height
var px = [UInt8](repeating: 0, count: w*h*4)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
typealias RGB = (Double, Double, Double)
func c(_ x: Int, _ y: Int) -> RGB { let i = (min(max(y,0),h-1)*w+min(max(x,0),w-1))*4; return (Double(px[i]), Double(px[i+1]), Double(px[i+2])) }
func isGreen(_ v: RGB) -> Bool { v.1 > v.0 + 40 && v.1 > v.2 + 30 }

// Límites de la cara verde.
let left = (0..<w).first { isGreen(c($0, 500)) }!
let right = (0..<w).last { isGreen(c($0, 500)) }!
let top = (0..<h).first { isGreen(c(512, $0)) }!
var bottom = (0..<h).last { isGreen(c(512, $0)) }!
while bottom > top && c(512, bottom).1 < 160 { bottom -= 1 }

// Insignia: píxeles blancos en el cuadrante inferior derecho del dibujo -> círculo.
var bx0 = w, bx1 = 0, by0 = h, by1 = 0
for y in 440..<760 { for x in 560..<860 {
    let v = c(x, y)
    if v.0 > 230 && v.1 > 230 && v.2 > 230 {
        // Solo el disco: descartamos la cesta exigiendo blanco a ambos lados horizontalmente a 40 px.
        if c(x-40, y).0 > 230 || c(x+40, y).0 > 230 { bx0 = min(bx0, x); bx1 = max(bx1, x); by0 = min(by0, y); by1 = max(by1, y) }
    }
} }
let bcx = Double(bx0 + bx1) / 2, bcy = Double(by0 + by1) / 2
// Radio: desde el centro en diagonal abajo-derecha, primer tramo blanco y su final.
var br = 0.0
do {
    var seenWhite = false
    for t in 0..<300 {
        let v = c(Int(bcx) + t, Int(bcy) + t)
        let white = v.0 > 200 && v.1 > 200 && v.2 > 200
        if white { seenWhite = true } else if seenWhite { br = Double(t) * 2.0.squareRoot(); break }
    }
}
print("cara", left, right, top, bottom, "insignia", Int(bcx), Int(bcy), Int(br))
func inBadge(_ x: Double, _ y: Double, _ shrink: Double) -> Bool {
    let dx = x - bcx, dy = y - bcy; return (dx*dx + dy*dy).squareRoot() < br - shrink
}

// Ajuste cuadrático del fondo con píxeles verdes del interior (lejos del borde, sin dibujo ni insignia).
let nx = Double(w), ny = Double(h)
func feats(_ x: Double, _ y: Double) -> [Double] { let u = x/nx - 0.5, v = y/ny - 0.5; return [1, u, v, u*u, u*v, v*v] }
let n = 6
var ata = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
var atb = [[Double]](repeating: [0, 0, 0], count: n)
for y in stride(from: top + 40, through: bottom - 40, by: 2) { for x in stride(from: left + 40, through: right - 40, by: 2) {
    let v = c(x, y)
    guard isGreen(v), v.0 < 90, !inBadge(Double(x), Double(y), -30) else { continue }
    let f = feats(Double(x), Double(y)); let rgb = [v.0, v.1, v.2]
    for i in 0..<n { for j in 0..<n { ata[i][j] += f[i]*f[j] }; for k in 0..<3 { atb[i][k] += f[i]*rgb[k] } }
} }
func solve(_ m: [[Double]], _ v: [Double]) -> [Double] {
    var a = m, b = v
    for i in 0..<n {
        let p = (i..<n).max { abs(a[$0][i]) < abs(a[$1][i]) }!
        a.swapAt(i, p); b.swapAt(i, p)
        for k in (i+1)..<n { let f = a[k][i] / a[i][i]; for j in i..<n { a[k][j] -= f*a[i][j] }; b[k] -= f*b[i] }
    }
    var x = [Double](repeating: 0, count: n)
    for i in stride(from: n-1, through: 0, by: -1) { x[i] = (b[i] - (i+1..<n).reduce(0) { $0 + a[i][$1]*x[$1] }) / a[i][i] }
    return x
}
let coef = (0..<3).map { k in solve(ata, (0..<n).map { atb[$0][k] }) }
func bg(_ x: Double, _ y: Double) -> RGB {
    // Fuera de la cara se usa el color del borde más cercano: sin extrapolar el ajuste.
    let f = feats(min(max(x, Double(left) + 40), Double(right) - 40), min(max(y, Double(top) + 40), Double(bottom) - 40))
    func ch(_ k: Int) -> Double { min(max(zip(coef[k], f).reduce(0) { $0 + $1.0*$1.1 }, 0), 255) }
    return (ch(0), ch(1), ch(2))
}

func sample(_ x: Double, _ y: Double) -> RGB {
    let x0 = Int(x.rounded(.down)), y0 = Int(y.rounded(.down)); let fx = x - Double(x0), fy = y - Double(y0)
    let a = c(x0, y0), b = c(x0+1, y0), cc = c(x0, y0+1), d = c(x0+1, y0+1)
    func l(_ p: Double, _ q: Double, _ t: Double) -> Double { p + (q-p)*t }
    return (l(l(a.0,b.0,fx), l(cc.0,d.0,fx), fy), l(l(a.1,b.1,fx), l(cc.1,d.1,fx), fy), l(l(a.2,b.2,fx), l(cc.2,d.2,fx), fy))
}
// Forma de la cara: rectángulo redondeado (radio de las esquinas del original ≈ 151 px).
func faceSDF(_ x: Double, _ y: Double) -> Double {
    let r = 151.0
    let fcx = Double(left + right) / 2, fcy = Double(top + bottom) / 2
    let hx = Double(right - left) / 2 - r, hy = Double(bottom - top) / 2 - r
    let qx = abs(x - fcx) - hx, qy = abs(y - fcy) - hy
    let ox = max(qx, 0), oy = max(qy, 0)
    return (ox*ox + oy*oy).squareRoot() + min(max(qx, qy), 0) - r
}
let inFace = { (x: Double, y: Double) in faceSDF(x, y) < -25 }

/// Color final en coordenadas de la imagen original.
func shade(_ x: Double, _ y: Double) -> RGB {
    let b = bg(x, y)
    guard inFace(x, y) else { return b }
    let o = sample(x, y)
    if inBadge(x, y, 3) { return o }
    // Cuánto blanco hay en el píxel, a partir del canal rojo (el fondo es casi sin rojo).
    let alpha = min(max((o.0 - b.0) / (255 - b.0), 0), 1)
    let a = alpha < 0.08 ? 0 : alpha
    return (a*255 + (1-a)*b.0, a*255 + (1-a)*b.1, a*255 + (1-a)*b.2)
}

let region = Double(args[3])!
let cx = Double(left + right) / 2, cy = Double(top + bottom) / 2
let ox = cx - region/2, oy = cy - region/2
let out = 1024, scale = region / Double(out)
var outPx = [UInt8](repeating: 255, count: out*out*4)
for yy in 0..<out { for xx in 0..<out {
    var acc: RGB = (0, 0, 0)
    for sy in 0..<2 { for sx in 0..<2 {
        let s = shade(ox + (Double(xx) + (Double(sx)+0.5)/2)*scale, oy + (Double(yy) + (Double(sy)+0.5)/2)*scale)
        acc.0 += s.0; acc.1 += s.1; acc.2 += s.2
    } }
    let i = (yy*out + xx)*4
    outPx[i] = UInt8((acc.0/4).rounded()); outPx[i+1] = UInt8((acc.1/4).rounded()); outPx[i+2] = UInt8((acc.2/4).rounded()); outPx[i+3] = 255
} }
let octx = CGContext(data: &outPx, width: out, height: out, bitsPerComponent: 8, bytesPerRow: out*4, space: space,
                     bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, octx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("ok", args[2])
