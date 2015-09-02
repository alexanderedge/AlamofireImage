// UIImageView+AlamofireImage.swift
//
// Copyright (c) 2015 Alamofire Software Foundation (http://alamofire.org/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Alamofire
import Foundation
import UIKit

public extension UIImageView {

    // MARK: - ImageTransition

    public enum ImageTransition {
        case None
        case CrossDissolve(NSTimeInterval)
        case CurlDown(NSTimeInterval)
        case CurlUp(NSTimeInterval)
        case FlipFromBottom(NSTimeInterval)
        case FlipFromLeft(NSTimeInterval)
        case FlipFromRight(NSTimeInterval)
        case FlipFromTop(NSTimeInterval)

        var duration: NSTimeInterval {
            switch self {
            case None:                         return 0.0
            case CrossDissolve(let duration):  return duration
            case CurlDown(let duration):       return duration
            case CurlUp(let duration):         return duration
            case FlipFromBottom(let duration): return duration
            case FlipFromLeft(let duration):   return duration
            case FlipFromRight(let duration):  return duration
            case FlipFromTop(let duration):    return duration
            }
        }

        var animationOptions: UIViewAnimationOptions {
            switch self {
            case None:           return .TransitionNone
            case CrossDissolve:  return .TransitionCrossDissolve
            case CurlDown:       return .TransitionCurlDown
            case CurlUp:         return .TransitionCurlUp
            case FlipFromBottom: return .TransitionFlipFromBottom
            case FlipFromLeft:   return .TransitionFlipFromLeft
            case FlipFromRight:  return .TransitionFlipFromRight
            case FlipFromTop:    return .TransitionFlipFromTop
            }
        }
    }

    // MARK: - Private - AssociatedKeys

    private struct AssociatedKeys {
        static var SharedImageDownloaderKey = "af_UIImageView.SharedImageDownloader"
        static var ActiveRequestKey = "af_UIImageView.ActiveRequest"
    }

    // MARK: - Properties

    public class var af_sharedImageDownloader: ImageDownloader {
        get {
            if let downloader = objc_getAssociatedObject(self, &AssociatedKeys.SharedImageDownloaderKey) as? ImageDownloader {
                return downloader
            } else {
                return ImageDownloader.defaultInstance
            }
        }
        set(downloader) {
            objc_setAssociatedObject(self, &AssociatedKeys.SharedImageDownloaderKey, downloader, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var af_activeRequest: Request? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.ActiveRequestKey) as? Request
        }
        set(request) {
            objc_setAssociatedObject(self, &AssociatedKeys.ActiveRequestKey, request, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - Image Download Methods

    public func af_setImageWithURL(URL: NSURL, placeholderImage: UIImage? = nil) {
        af_setImageWithURLRequest(
            URLRequestWithURL(URL),
            placeholderImage: placeholderImage,
            filter: nil,
            imageTransition: .None,
            completion: nil
        )
    }

    public func af_setImageWithURL(URL: NSURL, placeholderImage: UIImage? = nil, filter: ImageFilter) {
        af_setImageWithURLRequest(
            URLRequestWithURL(URL),
            placeholderImage: placeholderImage,
            filter: filter,
            imageTransition: .None,
            completion: nil
        )
    }

    public func af_setImageWithURL(URL: NSURL, placeholderImage: UIImage? = nil, imageTransition: ImageTransition) {
        af_setImageWithURLRequest(
            URLRequestWithURL(URL),
            placeholderImage: placeholderImage,
            filter: nil,
            imageTransition: imageTransition,
            completion: nil
        )
    }

    public func af_setImageWithURL(
        URL: NSURL,
        placeholderImage: UIImage?,
        filter: ImageFilter?,
        imageTransition: ImageTransition)
    {
        af_setImageWithURLRequest(
            URLRequestWithURL(URL),
            placeholderImage: placeholderImage,
            filter: filter,
            imageTransition: imageTransition,
            completion: nil
        )
    }

    public func af_setImageWithURLRequest(
        URLRequest: URLRequestConvertible,
        placeholderImage: UIImage?,
        filter: ImageFilter?,
        imageTransition: ImageTransition,
        completion: ((NSURLRequest?, NSHTTPURLResponse?, Result<UIImage>) -> Void)?)
    {
        af_cancelImageRequest()

        let imageDownloader = UIImageView.af_sharedImageDownloader
        let imageCache = imageDownloader.imageCache

        // Use the image from the image cache if it exists
        if let image = imageCache?.imageForRequest(URLRequest.URLRequest, withIdentifier: filter?.identifier) {
            if let completion = completion {
                completion(URLRequest.URLRequest, nil, .Success(image))
            } else {
                self.image = image
            }

            return
        }

        // Set the placeholder since we're going to have to download
        if let placeholderImage = placeholderImage {
            self.image = placeholderImage
        }

        // Download the image, then run the image transition or completion handler
        let request = UIImageView.af_sharedImageDownloader.downloadImage(
            URLRequest: URLRequest,
            filter: filter,
            completion: { [weak self] request, response, result in
                guard let strongSelf = self else { return }

                // Ignore the event if the response request does not match the current request
                guard let
                    currentRequest = strongSelf.af_activeRequest?.task.currentRequest
                    where currentRequest.URLString == request?.URLString else
                {
                    return
                }

                strongSelf.af_activeRequest = nil

                guard completion == nil else {
                    completion?(request, response, result)
                    return
                }

                if let image = result.value {
                    switch imageTransition {
                    case .None:
                        strongSelf.image = image
                    default:
                        UIView.transitionWithView(
                            strongSelf,
                            duration: imageTransition.duration,
                            options: imageTransition.animationOptions,
                            animations: {
                                strongSelf.image = image
                            },
                            completion: nil
                        )
                    }
                }
            }
        )

        af_activeRequest = request
    }

    // MARK: - Image Download Cancellation Methods

    public func af_cancelImageRequest() {
        af_activeRequest?.cancel()
    }

    // MARK: - Private - URL Request Helper Methods

    private func URLRequestWithURL(URL: NSURL) -> NSURLRequest {
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.addValue("image/*", forHTTPHeaderField: "Accept")

        return mutableURLRequest
    }
}
