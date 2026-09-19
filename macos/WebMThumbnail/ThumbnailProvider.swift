import Cocoa
import QuickLookThumbnailing

class ThumbnailProvider: QLThumbnailProvider {
  override func provideThumbnail(
    for request: QLFileThumbnailRequest,
    _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
  ) {
    let accessing = request.fileURL.startAccessingSecurityScopedResource()
    defer {
      if accessing {
        request.fileURL.stopAccessingSecurityScopedResource()
      }
    }

    let path = request.fileURL.path
    let maxDim = Int(max(request.maximumSize.width, request.maximumSize.height) *
      request.scale)
    var rgba: UnsafeMutablePointer<UInt8>?
    var width: Int32 = 0
    var height: Int32 = 0

    guard fik_extract_first_frame(path, Int32(max(maxDim, 32)), &rgba, &width, &height),
          let rgba,
          width > 0,
          height > 0
    else {
      handler(nil, nil)
      return
    }
    defer { fik_free_frame(rgba) }

    let w = Int(width)
    let h = Int(height)
    let buffer = UnsafeBufferPointer(start: rgba, count: w * h * 4)
    let data = Data(buffer: buffer)

    guard let provider = CGDataProvider(data: data as CFData),
          let cgImage = CGImage(
            width: w,
            height: h,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
          )
    else {
      handler(nil, nil)
      return
    }

    let size = CGSize(width: w, height: h)
    let image = cgImage
    let reply = QLThumbnailReply(contextSize: size, currentContextDrawing: {
      guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
      ctx.interpolationQuality = .high
      ctx.draw(image, in: CGRect(origin: .zero, size: size))
      return true
    })
    handler(reply, nil)
  }
}
