//
//  UPCApi.swift
//  Barcode
//
//  Created by Cameron Smith on 11/12/15.
//  Copyright © 2015 Cameron Smith. All rights reserved.
//

import Foundation

struct OutpanAPI {
//    private static let baseURLString = "https://api.outpan.com/v2/products/"
//    private static let apiKey = "9d200f6fb3142f9502471d343c5054dc"
    private static let baseURLString = "http://api.upcdatabase.org/json/c7aafb0a99b82440917b72d52b679c13/"
}

enum ApiError:ErrorType {
    case AttributeEmpty
    case BadRequest
    case EmptyResponse
}

struct ResponseObj {
    let productName:String
}

let session = NSURLSession.sharedSession()

func queryAPI(upc:String, completion:(response: NSURLResponse?, item:String?, error:NSError?) -> ()) {
    let urlString = "\(OutpanAPI.baseURLString)\(upc)"
    let url = NSURL(string: urlString)
    let request = NSMutableURLRequest(URL: url!)
    
    let task = session.dataTaskWithRequest(request, completionHandler: {
        data, response, error in
        
        do {
            let res = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as? NSDictionary
//            guard res!.valueForKey("description") as? String != "" else {throw ApiError.EmptyResponse }
            if let blank = nullToNil(res!.valueForKey("name")) {
                completion(response: response, item: blank as? String, error: error)
            } else {
                completion(response: response, item: res!.valueForKey("description") as? String, error: error)
            }
            
        } catch {
            print("UPC API error: \(error)")
        }
    })
    task.resume()
}

func nullToNil(value : AnyObject?) -> AnyObject? {
    if value is NSNull {
        return "INVALID"
    } else {
        return nil
    }
}
