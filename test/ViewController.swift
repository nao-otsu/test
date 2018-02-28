//
//  ViewController.swift
//  test
//
//  Created by yamaken on 2017/12/03.
//  Copyright © 2017年 yamaken. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    var audioIO: AudioIO!
    var fft: Fft!
    
    let session = ARSession()
    var timer = Timer()
    var bgTimer = Timer()
    var measureTimer = Timer()
    
    let text: String = "Position.csv"
    var xyzPosition: String = ""
    
    var flag: Bool = true
    //BGフラグ
    var bgFlag: Bool = true
    var bgFlag0: Bool = true
    //測定フラグ
    var measureFlag:Bool = true
    
    let numSamples: Int = 2048
    
    let fileName:String = "fft.csv"
    
    let myBoundSize: CGSize = UIScreen.main.bounds.size
    var button: UIButton!
    var playButton: UIButton!
    var bgButton: UIButton!
    var measureButton: UIButton!
    var resultButton: UIButton!
    
    //新しく追加
    let SAMPLE_RATE: Float = 44100.0
    let AMPLITUDE: Float = 1.0
    let NUM_OF_FREQUENCIES: Int = 256
    let MAX_FREQUENCY: Float = 12920.0
    let MIN_FREQUENCY: Float = 7429.0
    let FFT_SIZE: Int = 2048
    
    var firstIndex: Int = 345
    var lastIndex: Int = 600
    
    var soundGenerator: SoundGenerator!
    var newAudioIO: NewAudioIO!
    var bgAudioIO: NewAudioIO!
    var newPlaybutton: UIButton!
    var newBGMeasuerButton: UIButton!
    
    var bgData = [Float]()
    var fftBgData = [Float]()
    
    

    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        if let url = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first {
            let file_url = url.appendingPathComponent(text)
            do {
                try "x , y ,z\n".write(to: file_url, atomically: true, encoding: String.Encoding.utf8)
            }catch let error as NSError {
                print(error)
            }
        }
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene

        newPlaybutton = UIButton(frame: CGRect(x: myBoundSize.width/8 + 5, y: myBoundSize.height - 300, width: myBoundSize.width/4 - 10, height: 50))
        newPlaybutton.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8)
        newPlaybutton.setTitleColor(UIColor.black, for: UIControlState.normal)
        newPlaybutton.setTitle("再生", for: .normal)
        newPlaybutton.addTarget(self, action: #selector(newPlayButton), for: .touchUpInside)
        
        newBGMeasuerButton = UIButton(frame: CGRect(x: myBoundSize.width/8 * 3 + 5, y: myBoundSize.height - 300, width: myBoundSize.width/4 - 10, height: 50))
        newBGMeasuerButton.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8)
        newBGMeasuerButton.setTitleColor(UIColor.black, for: UIControlState.normal)
        newBGMeasuerButton.setTitle("BGPW", for: .normal)
        newBGMeasuerButton.addTarget(self, action: #selector(getBGData), for: .touchUpInside)
        
        resultButton = UIButton(frame: CGRect(x: myBoundSize.width/8 * 5 + 5, y: myBoundSize.height - 300, width: myBoundSize.width/4 - 10, height: 50))
        resultButton.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8)
        resultButton.setTitleColor(UIColor.black, for: UIControlState.normal)
        resultButton.setTitle("Result", for: .normal)
        resultButton.addTarget(self, action: #selector(result), for: .touchUpInside)
        
        
        button = UIButton(frame: CGRect(x: myBoundSize.width/8 + 5, y: myBoundSize.height - 200, width: myBoundSize.width/4 - 10, height: 50))
        button.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8)
        button.setTitleColor(UIColor.black, for: UIControlState.normal)
        button.setTitle("BG", for: .normal)
        button.addTarget(self, action: #selector(bgPlayButton), for: .touchUpInside)
    
        playButton = UIButton(frame: CGRect(x: myBoundSize.width/8 + 5, y: myBoundSize.height - 100, width: myBoundSize.width/4 - 10, height: 50))
        playButton.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8)
        playButton.setTitleColor(UIColor.black, for: UIControlState.normal)
        playButton.setTitle("再生", for: .normal)
        playButton.addTarget(self, action: #selector(touchPlayButton), for: .touchUpInside)
        
        bgButton = UIButton(frame: CGRect(x: myBoundSize.width/8 * 3 + 5, y: myBoundSize.height - 100, width: myBoundSize.width/4 - 10, height: 50))
        bgButton.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8)
        bgButton.setTitleColor(UIColor.black, for: UIControlState.normal)
        bgButton.setTitle("BG処理", for: .normal)
        bgButton.isEnabled = false
        bgButton.alpha = 0.1
        bgButton.addTarget(self, action: #selector(touchBGButton), for: .touchUpInside)
        
        measureButton = UIButton(frame: CGRect(x: myBoundSize.width/8 * 5 + 5, y: myBoundSize.height - 100, width: myBoundSize.width/4 - 10, height: 50))
        measureButton.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8)
        measureButton.setTitleColor(UIColor.black, for: UIControlState.normal)
        measureButton.setTitle("測定", for: .normal)
        measureButton.isEnabled = false
        measureButton.alpha = 0.1
        measureButton.addTarget(self, action: #selector(touchMeasureButton), for: .touchUpInside)
        
        sceneView.addSubview(button)
        sceneView.addSubview(playButton)
        sceneView.addSubview(bgButton)
        sceneView.addSubview(measureButton)
        sceneView.addSubview(newPlaybutton)
        sceneView.addSubview(newBGMeasuerButton)
        sceneView.addSubview(resultButton)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        fft = Fft()
        //audioIO = AudioIO(numsamples: numSamples)
        soundGenerator = SoundGenerator()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @objc func bgPlayButton(){
        audioIO.createBGData(fft: fft)
        button.isEnabled = false
        button.alpha = 0.1
        audioIO.bgFlag0 = true
        bgTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.BGFlagcheck0), userInfo: nil, repeats: true)
    }
    
    @objc func touchPlayButton(){
        if playButton.currentTitle == "再生" {
            playButton.setTitle("停止", for: UIControlState.normal)
            bgButton.isEnabled = true
            bgButton.alpha = 0.8
            audioIO.bgFlag = true
            //measureButton.isEnabled = true
            
            
            audioIO.play(fft: fft)
        }else {
            playButton.setTitle("再生", for: UIControlState.normal)
            audioIO.stop()
            let fftData: String = fft.fftData()
            if let url = FileManager.default.urls(for: .documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first{
                let file_url = url.appendingPathComponent(fileName)
                
                do {
                    try fftData.write(to: file_url, atomically: true, encoding: String.Encoding.utf8)
                }catch let error as NSError{
                    print(error)
                }
            }
            bgButton.isEnabled = false
            bgButton.alpha = 0.1
            measureButton.isEnabled = false
            measureButton.alpha = 0.1
        }
    }
    @objc func touchBGButton(){
        if bgFlag {
            bgFlag = false
            bgButton.isEnabled = false
            bgButton.alpha = 0.1
            audioIO.bgFlag = true
            bgTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.BGFlagcheck), userInfo: nil, repeats: true)
        }
    }
    
    @objc func touchMeasureButton(){
        if measureFlag {
            measureFlag = false
            measureButton.isEnabled = false
            measureButton.alpha = 0.1
            audioIO.measureFlag = true
            measureTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.MeasureFlagcheck), userInfo: nil, repeats: true)
        }
    }
    
    
    /////////////////////////////////////////////////////////////////
    
    @objc func newPlayButton(){
        let sinBuffer = soundGenerator.getSendWave()
        newAudioIO = NewAudioIO()
        newAudioIO.play(buffer:sinBuffer)
    }
    
    
    @objc func getBGData(){
        bgAudioIO = NewAudioIO()
        bgAudioIO.microphoneBool()
        bgAudioIO.noObjectFalg = true
    }
    
    @objc func result(){
        bgAudioIO.objectFlag = true
    }
    
    
    
    
    
    
    
    
    
    
    
    
    @objc func updateTime(){
//        print(sceneView.session.currentFrame?.camera.transform.columns.3.x)
//        print(sceneView.session.currentFrame?.camera.transform.columns.3.y)
//        print(sceneView.session.currentFrame?.camera.transform.columns.3.z)
        guard let cameraPositionX = sceneView.session.currentFrame?.camera.transform.columns.3.x else {
            return
        }
        guard let cameraPositionY = sceneView.session.currentFrame?.camera.transform.columns.3.y else {
            return
        }
        guard let cameraPositionZ = sceneView.session.currentFrame?.camera.transform.columns.3.z else {
            return
        }
        //print("\(cameraPositionX),\(cameraPositionY),\(cameraPositionZ)")
        xyzPosition += "\(cameraPositionX),\(cameraPositionY),\(cameraPositionZ)\n"
    }
    

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        
        if flag == true {
            print("データ取得")
            flag = false
            timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
        } else {
            flag = true
            timer.invalidate()
            if let url = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first {
                let file_url = url.appendingPathComponent(text)
                do {
                    let fileHandle = try FileHandle(forWritingTo: file_url)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(xyzPosition.data(using: String.Encoding.utf8)!)
                    print("書き込み")
                }catch let error as NSError{
                    print(error)
                }
            }
        }
        
        
//        guard let touch = touches.first else {
//            print("1")
//            return
//        }
//        let result = sceneView.hitTest(touch.location(in: sceneView), types: ARHitTestResult.ResultType.featurePoint)
//        guard let hitResult = result.last else {
//            print("2")
//            return
//        }
//        print("positionX:\(hitResult.worldTransform.columns.3.x)")
//        print("positionY:\(hitResult.worldTransform.columns.3.y)")
////        print(hitResult.worldTransform.columns.3.z)
//        let hitTransform = SCNMatrix4(hitResult.worldTransform)
//        let hitVector = SCNVector3Make(hitTransform.m41, hitTransform.m42, hitTransform.m43)
//        createBall(position: hitVector)
    }
    
    func createBall(position: SCNVector3){
        let ballShape = SCNSphere(radius: 0.01)
        let ballNode = SCNNode(geometry: ballShape)
        ballNode.position = position
        sceneView.scene.rootNode.addChildNode(ballNode)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    
    @objc func BGFlagcheck(){
        if !audioIO.bgFlag {
            bgButton.isEnabled = true
            bgButton.alpha = 0.8
            measureButton.isEnabled = true
            measureButton.alpha = 0.8
            bgFlag = true
            
        }
    }
    
    @objc func BGFlagcheck0(){
        if !audioIO.bgFlag0 {
            button.isEnabled = true
            button.alpha = 0.8
            bgFlag0 = true
            bgTimer.invalidate()
            audioIO.stop()
            
        }
    }
    
    @objc func MeasureFlagcheck(){
        if !audioIO.measureFlag {
            measureButton.isEnabled = true
            measureButton.alpha = 0.8
            measureFlag = true
        }
    }
}
