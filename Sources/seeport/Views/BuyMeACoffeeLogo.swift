import SwiftUI

struct BuyMeACoffeeLogo: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Yellow rounded background
                RoundedRectangle(cornerRadius: s * 0.233)
                    .fill(Color(red: 1.0, green: 0.867, blue: 0.0))

                // Cup shape using SVG path data scaled to fit
                CupShape()
                    .fill(Color(red: 0.05, green: 0.05, blue: 0.13))
                    .frame(width: s * 0.55, height: s * 0.65)
            }
        }
    }
}

private struct CupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Steam (simple curve)
        let steamX = w * 0.5
        path.move(to: CGPoint(x: steamX - w * 0.08, y: h * 0.0))
        path.addQuadCurve(
            to: CGPoint(x: steamX - w * 0.04, y: h * 0.15),
            control: CGPoint(x: steamX - w * 0.16, y: h * 0.07)
        )

        path.move(to: CGPoint(x: steamX + w * 0.08, y: h * 0.0))
        path.addQuadCurve(
            to: CGPoint(x: steamX + w * 0.04, y: h * 0.15),
            control: CGPoint(x: steamX + w * 0.16, y: h * 0.07)
        )

        // Cup body
        let cupTop = h * 0.22
        let cupBottom = h * 0.92
        let cupLeft = w * 0.1
        let cupRight = w * 0.9
        let bottomLeft = w * 0.22
        let bottomRight = w * 0.78
        let cornerRadius = w * 0.08

        path.move(to: CGPoint(x: cupLeft, y: cupTop))
        path.addLine(to: CGPoint(x: cupRight, y: cupTop))
        path.addLine(to: CGPoint(x: bottomRight, y: cupBottom - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: bottomRight - cornerRadius, y: cupBottom),
            control: CGPoint(x: bottomRight, y: cupBottom)
        )
        path.addLine(to: CGPoint(x: bottomLeft + cornerRadius, y: cupBottom))
        path.addQuadCurve(
            to: CGPoint(x: bottomLeft, y: cupBottom - cornerRadius),
            control: CGPoint(x: bottomLeft, y: cupBottom)
        )
        path.closeSubpath()

        // Cup rim (wider top)
        let rimHeight = h * 0.05
        path.addRoundedRect(
            in: CGRect(x: w * 0.05, y: cupTop - rimHeight, width: w * 0.9, height: rimHeight),
            cornerSize: CGSize(width: cornerRadius * 0.5, height: cornerRadius * 0.5)
        )

        // Base
        path.addRoundedRect(
            in: CGRect(x: w * 0.2, y: h * 0.93, width: w * 0.6, height: h * 0.07),
            cornerSize: CGSize(width: cornerRadius * 0.5, height: cornerRadius * 0.5)
        )

        return path
    }
}
