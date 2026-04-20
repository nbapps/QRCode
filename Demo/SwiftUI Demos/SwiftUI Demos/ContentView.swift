//
//  ContentView.swift
//  SwiftUI Demos
//
//  Created by Darren Ford on 9/1/2023.
//

import SwiftUI
import QRCode

#if !os(macOS)
import CoreMotion
#endif

extension CGImage {
	/// Load a CGImage from an image resource
	@inlinable static func named(_ name: String) -> CGImage? {
		#if os(macOS)
		NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
		#else
		UIImage(named: name)?.cgImage
		#endif
	}
}

let doc1: QRCode.Document = {
	let d = try! QRCode.Document(engine: QRCodeEngineExternal())

	d.utf8String = "https://www.swift.org"

	d.design.backgroundColor(CGColor(gray: 0, alpha: 0))

    d.design.style.eye = QRCode.FillStyle.Solid(gray: 1)
    d.design.shape.eye = QRCode.EyeShape.UsePixelShape()
    d.design.shape.pupil = QRCode.PupilShape.UsePixelShape()
	d.design.style.eyeBackground = CGColor(gray: 0, alpha: 0.3)

	d.design.shape.onPixels = QRCode.PixelShape.Heart()//Square(insetFraction: 0.7)
	d.design.style.onPixels = QRCode.FillStyle.Solid(gray: 1)
	d.design.style.onPixelsBackground = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.3)

	d.design.shape.offPixels = QRCode.PixelShape.Square(insetFraction: 0.7)
	d.design.style.offPixels = QRCode.FillStyle.Solid(gray: 0)
	d.design.style.offPixelsBackground = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.3)

	d.design.style.background = QRCode.FillStyle.Image(CGImage.named("Apple_Swift_Logo"))

	return d
}()

struct ContentView: View {
	var body: some View {
		TabView {
			ScrollView(.vertical) {
				VStack {
					PixelBackgroundColorsView()
				}
				.frame(maxWidth: 100000)
			}
			.tabItem { Text("basic") }

			ItemView()
				.tabItem { Text("3d") }
		}
		.padding()
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

// -

struct PixelBackgroundColorsView: View {
	var body: some View {
		VStack {
			Text("A logo with an overlaid QRCode.")
			Text("Note: The Eye color must match the on pixel color")
			QRCodeDocumentUIView(document: doc1)
				.frame(width: 300, height: 300)
		}
	}
}

struct PixelBackgroundColorsView_Previews: PreviewProvider {
	static var previews: some View {
		PixelBackgroundColorsView()
	}
}


////

#if !os(macOS)
// MotionManager for iOS device tilt detection
class MotionManager: ObservableObject {
	private let motionManager = CMMotionManager()
	private var resetTimer: Timer?
	
	@Published var xRotation: Double = 0.0
	@Published var yRotation: Double = 0.0
	
	private var lastMotionTime: Date = Date()
	
	func startMotionUpdates() {
		guard motionManager.isDeviceMotionAvailable else { return }
		
		motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
		motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
			guard let motion = data else { return }
			
			// Use attitude (pitch and roll) for device tilt
			// pitch = rotation around X axis (forward/backward)
			// roll = rotation around Y axis (left/right)
			let pitch = motion.attitude.pitch
			let roll = motion.attitude.roll
			
			let newXRotation = min(max(roll * 180 / .pi * 2, -15), 15)
			let newYRotation = min(max(-pitch * 180 / .pi * 2, -15), 15)
			
			// Check if device is moving (threshold to detect significant movement)
			let isMoving = abs(newXRotation - (self?.xRotation ?? 0)) > 0.1 ||
			               abs(newYRotation - (self?.yRotation ?? 0)) > 0.1
			
			if isMoving {
				self?.lastMotionTime = Date()
			}
			
			withAnimation(.easeInOut(duration: 0.2)) {
				// Convert from radians to degrees and limit to ±15°
				self?.xRotation = newXRotation
				self?.yRotation = newYRotation
			}
		}
		
		// Start timer to check for inactivity
		resetTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
			guard let self = self else { return }
			let timeSinceLastMotion = Date().timeIntervalSince(self.lastMotionTime)
			
			// Reset to neutral position after 1 second of no movement
			if timeSinceLastMotion > 1.0 && (self.xRotation != 0 || self.yRotation != 0) {
				withAnimation(.easeInOut(duration: 0.5)) {
					self.xRotation = 0
					self.yRotation = 0
				}
			}
		}
	}
	
	func stopMotionUpdates() {
		motionManager.stopDeviceMotionUpdates()
		resetTimer?.invalidate()
		resetTimer = nil
	}
}
#endif

struct ItemView: View {
	@State var xdegrees = 0.0
	@State var ydegrees = 0.0
	
	#if !os(macOS)
	@StateObject private var motionManager = MotionManager()
	#endif

	var body: some View {
		VStack {
			Text("Example of using the SwiftUI shape component")
			try! QRCodeShape(
				text: "Wombling, wombling happy time",
				errorCorrection: .high,
				shape: QRCode.Shape(
					onPixels: QRCode.PixelShape.Heart(),
					eye: QRCode.EyeShape.Leaf()
				)
			)
			.fill(.blue)
			.aspectRatio(contentMode: .fit)
			#if os(macOS)
			.rotation3DEffect(.degrees(xdegrees), axis: (x: 0, y: 1, z: 0))
			.rotation3DEffect(.degrees(ydegrees), axis: (x: 1, y: 0, z: 0))
			#else
			.rotation3DEffect(.degrees(motionManager.xRotation), axis: (x: 0, y: 1, z: 0))
			.rotation3DEffect(.degrees(motionManager.yRotation), axis: (x: 1, y: 0, z: 0))
			#endif
			
			#if os(macOS)
			.overlay {
				GeometryReader { geo in
					Spacer()
						.onContinuousHover(coordinateSpace: .local, perform: { p in
							let r = geo.frame(in: .local)
							withAnimation(.easeInOut(duration: 0.2)) {
								switch p {
								case .active(let point):
									let offx = point.x - ((r.origin.x + r.width) / 2)
									xdegrees = (offx / r.width * 15)
									let offy = point.y - ((r.origin.y + r.height) / 2)
									ydegrees = (-offy / r.height * 15)
								case .ended:
									xdegrees = 0
									ydegrees = 0
								}
							}
						})
				}
			}
			#endif
		}
		.padding()
		#if !os(macOS)
		.onAppear {
			motionManager.startMotionUpdates()
		}
		.onDisappear {
			motionManager.stopMotionUpdates()
		}
		#endif
	}
}

#Preview("3d") {
	ItemView()
}
