import Foundation
import Flutter
import AVFoundation
import UIKit

class VideoHelper: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.thanAngus.playwave/video",
                                           binaryMessenger: registrar.messenger())
        let instance = VideoHelper()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getVideoThumbnail" {
            guard let args = call.arguments as? [String: Any],
                  let videoPath = args["videoPath"] as? String,
                  let thumbnailPath = args["thumbnailPath"] as? String else {
                result(FlutterError(code: "Invalid args",
                                    message: nil,
                                    details: nil))
                return
            }
            getVideoThumbnail(url: URL(fileURLWithPath: videoPath), at: CMTime(seconds: 0, preferredTimescale: 600), outputPath: thumbnailPath, completion: result)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    func getVideoThumbnail(url: URL, at time: CMTime, outputPath: String, completion: @escaping FlutterResult) {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, error in
            if let image = image {
                let uiImage = UIImage(cgImage: image)
                if let data = uiImage.jpegData(compressionQuality: 0.9) {
                    do {
                        try data.write(to: URL(fileURLWithPath: outputPath))
                        completion(true)
                    } catch {
                        completion(FlutterError(code: "Write Error",
                                                message: error.localizedDescription,
                                                details: nil))
                    }
                } else {
                    completion(FlutterError(code: "Compression Error",
                                            message: "Failed to compress image",
                                            details: nil))
                }
            } else {
                completion(FlutterError(code: "Image Generation Error",
                                        message: error?.localizedDescription,
                                        details: nil))
            }
        }
    }
}
