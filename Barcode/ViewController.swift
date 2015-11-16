//
//  ViewController.swift
//  Barcode
//
//  Created by Cameron Smith on 11/11/15.
//  Copyright © 2015 Cameron Smith. All rights reserved.
//

import AVFoundation
import UIKit
import CoreData

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    let listButton = UIButton()
    let scanButton = UIButton()
    let itemLabel = UILabel()
    var currentItems = [NSManagedObject]()
    
    var fillLayer:CAShapeLayer?
    var scannerBeep:AVAudioPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let scannerBeep = self.setupAudioPlayerWithFile("scanner-beep", type: "mp3") {
            self.scannerBeep = scannerBeep
        }
        
        captureSession = AVCaptureSession()
        
        let videoCaptureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed();
            return;
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
            metadataOutput.metadataObjectTypes = [AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypePDF417Code]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession);
        previewLayer.frame = view.layer.bounds;
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        let visibleOutput = previewLayer.metadataOutputRectOfInterestForRect(CGRectMake(50, 200, 275, 175))
        metadataOutput.rectOfInterest = visibleOutput
        view.layer.addSublayer(previewLayer);
        
        //Setup semi-opaque previewLayer mask
        let path:UIBezierPath = UIBezierPath(roundedRect: CGRectMake(0, 0, previewLayer.bounds.size.width, previewLayer.bounds.size.height), cornerRadius: 0)
        let innerRect = UIBezierPath(rect: CGRectMake(50, 200, 275, 175))
        path.appendPath(innerRect)
        path.usesEvenOddFillRule = true
        
        fillLayer = CAShapeLayer(layer: previewLayer)
        fillLayer!.path = path.CGPath
        fillLayer!.fillRule = kCAFillRuleEvenOdd
        fillLayer!.fillColor = UIColor.blackColor().CGColor
        fillLayer!.opacity = 0.5
        previewLayer.addSublayer(fillLayer!)
        
        //Setup List Button
        listButton.setImage(UIImage(named: "list-icon"), forState: UIControlState.Normal)
        listButton.frame = CGRectMake(30.0, 30.0, 48.0, 64.0)
        listButton.addTarget(self, action: "listIconPressed:", forControlEvents: .TouchUpInside)
        view.addSubview(listButton)
        
        //Setup Scan Button
        scanButton.setTitle("Scan", forState: .Normal)
        scanButton.frame = CGRectMake(100, 500, view.frame.size.width - 200, 50)
        scanButton.backgroundColor = UIColor.redColor()
        scanButton.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        scanButton.titleLabel!.font = UIFont.systemFontOfSize(30.0)
        scanButton.titleLabel!.textAlignment = NSTextAlignment.Center
        scanButton.addTarget(self, action: "scanButtonPressed:", forControlEvents: .TouchUpInside)
        view.addSubview(scanButton)
        
        //Setup Item Label
        itemLabel.frame = CGRectMake(10, 400, view.frame.size.width - 20, 80)
        itemLabel.numberOfLines = 0
        itemLabel.font = UIFont.systemFontOfSize(20.0)
        itemLabel.textAlignment = NSTextAlignment.Center
        view.addSubview(itemLabel)
        
        captureSession.startRunning();
    }
    
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .Alert)
        ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
        presentViewController(ac, animated: true, completion: nil)
        captureSession = nil
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if (captureSession?.running == false) {
            captureSession.startRunning();
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (captureSession?.running == true) {
            captureSession.stopRunning();
        }
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        captureSession.stopRunning()
        scanButton.hidden = false
        
        if let metadataObject = metadataObjects.first {
            let readableObject = metadataObject as! AVMetadataMachineReadableCodeObject;
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            self.scannerBeep?.play()
            foundCode(readableObject.stringValue);
        }
        
        dismissViewControllerAnimated(true, completion: nil)
    }

    
    func foundCode(code: String) {
        print(code)
        queryAPI(code, completion: {
            response, item, error in
            if item != nil && item != "" {
                dispatch_async(dispatch_get_main_queue(), {
                    self.fillLayer!.fillColor = UIColor.greenColor().CGColor
                    self.itemLabel.textColor = UIColor.blackColor()
                    self.itemLabel.text = item!
                    self.itemLabel.hidden = false
                })
                if self.checkIfItemExists(item!) {
                    print("Already exists")
                } else {
                    self.saveItem(item!)
                }
                print("Here's that item: \(item!)")
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    self.fillLayer!.fillColor = UIColor.redColor().CGColor
                    self.itemLabel.textColor = UIColor.blackColor()
                    self.itemLabel.text = "Can't find that one..."
                    self.itemLabel.hidden = false
                })
                print("Invalid item champ")
            }
        })
    }
    
    //MARK: CoreData
    func checkIfItemExists(name:String) -> Bool {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let managedContext = appDelegate.managedObjectContext
        let fetchRequest = NSFetchRequest(entityName: "Item")
        let predicate = NSPredicate(format: "name == %@", name as NSString)
        fetchRequest.predicate = predicate
        var exists:Bool?
        
        do {
            let results = try managedContext.executeFetchRequest(fetchRequest)
            currentItems = results as! [NSManagedObject]
            if currentItems.count > 0 {
                exists = true
            } else {
                exists = false
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        
        return exists!
    }
    
    func saveItem(name:String) {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let managedContext = appDelegate.managedObjectContext
        let entity = NSEntityDescription.entityForName("Item", inManagedObjectContext: managedContext)
        let item = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: managedContext)
        item.setValue(name, forKey: "name")
        
        do {
            try managedContext.save()
            
        } catch let error as NSError {
            print("Could not save \(error), \(error.userInfo)")
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return false
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .Portrait
    }
    
    //MARK: Sound methods
    func setupAudioPlayerWithFile(file:NSString, type:NSString) -> AVAudioPlayer? {
        let path = NSBundle.mainBundle().pathForResource(file as String, ofType: type as String)
        let url = NSURL.fileURLWithPath(path!)
        
        var audioPlayer:AVAudioPlayer?
        
        do {
            try audioPlayer = AVAudioPlayer(contentsOfURL: url)
        } catch {
            print("Audio player not available")
        }
        
        return audioPlayer
    }
    
    //MARK: Actions
    func listIconPressed(sender: UIButton!) {
        self.performSegueWithIdentifier("homeToListVCSegue", sender: self)
    }
    
    @IBAction func scanButtonPressed(sender: UIButton) {
        self.itemLabel.text = ""
        self.itemLabel.hidden = true
        self.fillLayer!.fillColor = UIColor.blackColor().CGColor
        self.captureSession.startRunning()
    }
}