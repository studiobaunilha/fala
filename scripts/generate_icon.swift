#!/usr/bin/env swift

import SwiftUI
import AppKit

@available(macOS 13.0, *)
struct GlowBorder: View {
    let colors: [Color] = [
        .blue, .cyan, .purple, .pink, .orange, .yellow, .blue
    ]
    
    // We are generating a static image, no phase animation needed
    var gradient: AngularGradient {
        AngularGradient(
            colors: colors,
            center: .center,
            startAngle: .degrees(45),
            endAngle: .degrees(405)
        )
    }
    
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 236, style: .continuous)
        
        ZStack {
            // Diffuse glow
            shape
                .stroke(gradient, lineWidth: 36)
                .blur(radius: 64)
                .opacity(0.8)
            
            // Sharp inner edge
            shape
                .stroke(gradient, lineWidth: 16)
                .opacity(0.9)
        }
    }
}

@available(macOS 13.0, *)
struct AppIconView: View {
    let baseImage: NSImage
    
    var body: some View {
        ZStack {
            // macOS App Icons usually have a slight drop shadow inside the asset if they are not standard Big Sur squircle wrappers.
            // But Apple handles squircle masking for us. Wait, for macOS standard icons, we should provide the squircle.
            // Actually, we can just supply the squircle inside the 1024 frame.
            
            Color.clear
            
            ZStack {
                // The base icon (already squircled in the png, but let's make sure it fills)
                Image(nsImage: baseImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 236, style: .continuous))
                
                // The AI Glow
                GlowBorder()
            }
            .frame(width: 824, height: 824) // Leaves 100px padding all around for the glow to diffuse normally in macOS
            .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
        }
        .frame(width: 1024, height: 1024)
        .background(Color.clear)
    }
}

@MainActor
func generateIcon() {
    guard #available(macOS 13.0, *) else {
        print("macOS 13.0+ required")
        return
    }
    
    // Path to the base icon, we will pass it as an arg or hardcode
    let args = CommandLine.arguments
    guard args.count >= 3 else {
        print("Usage: generate_icon <input-png> <output-png>")
        return
    }
    
    let inputPath = args[1]
    let outputPath = args[2]
    
    guard let baseImage = NSImage(contentsOfFile: inputPath) else {
        print("Failed to load image from \(inputPath)")
        return
    }
    
    let view = AppIconView(baseImage: baseImage)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1.0
    // Transparent background
    renderer.isOpaque = false
    
    if let nsImage = renderer.nsImage,
       let tiffData = nsImage.tiffRepresentation,
       let bitmapImage = NSBitmapImageRep(data: tiffData),
       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: outputPath)
        do {
            try pngData.write(to: url)
            print("Successfully generated icon at \(outputPath)")
        } catch {
            print("Failed to write to \(outputPath): \(error)")
        }
    } else {
        print("Failed to render image")
    }
}

Task { @MainActor in
    generateIcon()
    exit(0)
}

RunLoop.main.run()
