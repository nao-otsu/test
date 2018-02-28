
//
//  AudioIO.swift
//  WhiteNoise
//
//  Created by yamaken on 2017/12/16.
//  Copyright © 2017年 yamaken. All rights reserved.
//

import AVFoundation
import GameplayKit

class AudioIO {
    var audioEngine: AVAudioEngine!
    var audioInputNode : AVAudioInputNode!
    var audioPlayerNode: AVAudioPlayerNode!
    var audioMixerNode: AVAudioMixerNode!
    var audioBuffer: AVAudioPCMBuffer!
    var audioFormat: AVAudioFormat!
    //iirfilterの係数
    let b:[Float] = [1.0,  -1.4, 1.0]
    let a:[Float] = [1.0, -1.3, 0.5]
    var v1m1 : Float = 0.0, v2m1 :Float = 0.0, v1m:Float = 0.0, v2m :Float = 0.0
    //BGフラグ
    var bgFlag0: Bool = false
    //BGフラグ
    var bgFlag: Bool = false
    //測定フラグ
    var measureFlag: Bool = false
    
    
    //バックグランド除去用データ
    var backgroundData = [Float]()
    //観測データ
    var receiveData = [Float]()
    var sentData = [Float]()
    
    var frameLength: UInt32
    var numSamples: Int
    var i: Int = 0
    //fft
    var bgData = [Float]()
    var result = [Float]()
    var sentFFT = [Float]()
    
    var distance = [Float]()
    var results0 = [[Float]]()
    var results = [[Float]]()
    var power = [Float]()
    var power0 = [Float]()
    var diffPowr = [Float]()
    var fftData = [Float]()
    var totalSum = [Float]()
    
    //sin
    var sinBuffer = [Float]()
    
    
    func iirfilter(x1:Float) -> Float {
        let y1 = (b[0] * x1 + v1m1) / a[0];
        v1m = (b[1] * x1 + v2m1) - a[1] * y1;
        v2m = b[2] * x1 - a[2] * y1;
        v1m1 = v1m;
        v2m1 = v2m;
        return y1;
    }
    
    init(numsamples: Int){
        
        frameLength = UInt32(44100)
        numSamples = 44100
        backgroundData = [Float](repeating: 0, count: 2048)
        receiveData = [Float](repeating: 0, count: 2048)
        sentData = [Float](repeating: 0, count: 2048)
        self.power = [Float](repeating:0, count: 2048/2)
        self.power0 = [Float](repeating:0, count: 2048/2)
        self.diffPowr = [Float](repeating:0, count: 2048/2)
        //totalSum = [Float](repeating:0, count: numSamples)
        
        let session = AVAudioSession.sharedInstance()
        do {
            //下のスピーカーを使ったまま再生録音可能
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with:AVAudioSessionCategoryOptions.defaultToSpeaker)
            //スピーカー上
            //try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
            //スピーカー下
            //try session.setCategory(AVAudioSessionCategoryAmbient)
            try session.setActive(true)
        }catch let error {
            print(error)
        }
        
        let soundGenerator = SoundGenerator()
        self.sinBuffer = soundGenerator.getSendWave()
        
    }
    //バックグランド用データ作成
    func createBGData(fft: Fft){
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        audioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32,
                                    sampleRate: 44100.0,
                                    channels: 2,
                                    interleaved: false)
        audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(numSamples))!
   
        audioBuffer.frameLength = frameLength
        audioInputNode = audioEngine.inputNode
        audioMixerNode = audioEngine.mainMixerNode
        
        
        let anotherGaussian = GKGaussianDistribution(lowestValue: -30000, highestValue: 30000)

//        var bgVector:Float = 0.0
//        var xVector:Float = 0.0
        
        audioInputNode.installTap(onBus: 0, bufferSize:2048, format: audioInputNode.outputFormat(forBus: 0), block: {(buffer, time) in
            let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
            let floats = UnsafeBufferPointer(start: channels[0], count: 2048)
            
            //var val = [Float](repeating: 0,count:self.numSamples)
            //print(result)
            
        
            for i:Int in stride(from: 0, to: 2048, by: 1){
                //print("interleaved:\(self.audioFormat.isInterleaved)")

                self.backgroundData[i] = floats[i]

            }
            for i in 0..<Int(self.audioBuffer.frameLength){
                //self.backgroundData[i] = floats[i]
                self.audioBuffer.floatChannelData?.pointee[i] = self.sinBuffer[i]//Float(anotherGaussian.nextInt()) / 30000//  self.totalSum[i]
                self.audioBuffer.floatChannelData?.pointee[i + Int(self.audioBuffer.frameLength)] = self.sinBuffer[i]// Float(anotherGaussian.nextInt()) / 30000//self.totalSum[i]
                //print(i)
            }
            
            //常にFFT
            self.bgData = fft.fft(numSamples: 2048, samples: self.backgroundData)
            if self.bgFlag0 {
                if self.results.count < 100 {
                    self.results.append(self.bgData)
                } else {
                    var tmp1 = [Float](repeating: 0,count: 100)
                    //self.power.removeAll()
                    print("BG")
                    for i in 0..<2048/2 {
                        for j in 0..<100{
                            tmp1[j] = self.results[j][i]
                        }
                        //中央値計算
                        if i < 345 {
                            self.power0[i] = 0
                        } else if i > 600 {
                            self.power0[i] = 0
                        } else {
                            self.power0[i] = self.calculateMedian(array: tmp1)
                        }
                        //print(self.power0[i])
                        //bgVector = bgVector + pow(self.power[i],2)
                        //print(self.power0[i])
                    }
                    self.results.removeAll()
                    self.bgFlag0 = false
                }
            } else {
                self.results.removeAll()
            }
            
        })
        audioEngine.attach(audioPlayerNode)
        //        audioEngine.connect(audioPlayerNode, to: audioMixerNode, format: audioPlayerNode.outputFormat(forBus: 0))
        audioEngine.connect(audioPlayerNode, to: audioMixerNode, format: audioFormat)
        
        do {
            try audioEngine.start()
        } catch let err as NSError {
            print(err)
        }
        
        
        
        
        // play player and buffer
        audioPlayerNode.play()
        audioPlayerNode.scheduleBuffer(audioBuffer, at: nil, options: .loops, completionHandler: nil)
    }
    
    func play(fft: Fft){
        
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        audioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32,
                                    sampleRate: 44100.0,
                                    channels: 2,
                                    interleaved: false)
        audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(numSamples))!
        audioBuffer.frameLength = frameLength
        audioInputNode = audioEngine.inputNode
        audioMixerNode = audioEngine.mainMixerNode
        
        
        //        var turnOff: UInt32 = 0;
        //        print(kAUVoiceIOProperty_VoiceProcessingEnableAGC)
        //        AudioUnitSetProperty(audioUnit, kAUVoiceIOProperty_VoiceProcessingEnableAGC, kAudioUnitScope_Global, 0, &turnOff, (UInt32(MemoryLayout.size(ofValue: turnOff))))
        //        print(kAUVoiceIOProperty_VoiceProcessingEnableAGC)
        //ホワイトノイズの生成
        let anotherGaussian = GKGaussianDistribution(lowestValue: -30000, highestValue: 30000)
        var bgVector:Float = 0.0
        var xVector:Float = 0.0
        
        audioInputNode.installTap(onBus: 0, bufferSize:self.audioBuffer.frameLength, format: audioInputNode.outputFormat(forBus: 0), block: {(buffer, time) in
            let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
            let floats = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
        
            //var val = [Float](repeating: 0,count:self.numSamples)
            //print(result)
            
            for i:Int in stride(from: 0, to: 2048, by: 1){
                //print("interleaved:\(self.audioFormat.isInterleaved)")
                
                self.receiveData[i] = floats[i]
            }
            for i in 0..<Int(self.audioBuffer.frameLength){
                self.audioBuffer.floatChannelData?.pointee[i] = self.sinBuffer[i]//self.sentData[i]//self.totalSum[i]
                self.audioBuffer.floatChannelData?.pointee[i + Int(self.audioBuffer.frameLength)] = self.sinBuffer[i]//self.sentData[i]//self.totalSum[i]
                //print(i)
            }
            //self.sentFFT = fft.fft(numSamples: self.2048, samples: self.sentData)
            //常にFFT
            self.result = fft.fft(numSamples: 2048, samples: self.receiveData)
            //BGのFFT
            /*if self.bgFlag {
                if self.results.count < 100 {
                    self.results.append(self.sentFFT)
                    //                    print(self.results.count)
                } else {
                    var tmp1 = [Float](repeating: 0,count: 100)
                    //self.power.removeAll()
                    for i in 0..<self.numSamples/2 {
                        for j in 0..<100{
                            tmp1[j] = self.results[j][i]
                        }
                        //中央値計算
                        self.power[i] = self.calculateAve(array: tmp1)
                        bgVector = bgVector + pow(self.power[i],2)
                        //                        print(self.power[i])
                    }
                    self.bgFlag = false
                }
                //測定のFFT
            }else*/
            if self.bgFlag {
                if self.results.count < 10{
                    self.results.append(self.result)
                    //self.results0.append(self.sentFFT)
                    //                    print(self.results.count)
                } else {
                    var tmp1 = [Float](repeating: 0,count: 10)
                    //var tmp2 = [Float](repeating: 0,count: 100)
                    //var sum : Float = 0.0
                    //self.diffPowr.removeAll()
                    print("観測信号")
                    for i in 0..<2048/2 {
                        //print("\(self.result[i]),\(self.sentFFT[i])")
                        
                        for j in 0..<10{
                            tmp1[j] = self.results[j][i]
                            //tmp2[j] = self.results0[j][i]
                            //                            print(tmp1[j])
                            //                            print(tmp2[j])
                            
                        }
                        //中央値計算
                        //self.diffPowr[i] = self.calculateAve(array: tmp2)// - self.power[i]
                        //print(self.diffPowr[i])
                        
                        if i < 345 {
                            self.power[i] = 0
                        } else if i > 600 {
                            self.power[i] = 0
                        } else {
                            self.power[i] = self.calculateMedian(array: tmp1)
                        }
                        
                        
                        //print(self.power[i])
                        //sum = sum + self.power[i]
                        //print("\(self.diffPowr[i]), \(self.power[i])")
                        // print(self.diffPowr[i])
                        //xVector = xVector + pow(self.diffPowr[i],2)
                        //bgVector = bgVector + pow(self.power[i],2)
                    }
                    
                    
                    //self.power.removeAll()

                    self.bgFlag = false
                    
                    //let k:Float = sqrt(xVector)/sqrt(bgVector)
                    var ss = [Float](repeating: 0,count: 2048/2)
                    print("差")
                    for i in 0..<256{
                        //ss[i] = self.diffPowr[i] - k * self.power[i]
                        //ss[i] = self.power[i] - sum / Float(self.numSamples/2) - self.power0[i]
                        //ss[i] = self.power[i] - sum / Float(self.numSamples/2)
                        //ss[i] = self.power[i] - self.diffPowr[i] - self.power0[i]
                        ss[i] = self.power[i + 335] - self.power0[i + 335]
                        //print(ss[i])
                    }
                    //var f7000 = [Float](repeating: 0,count: 232)
//                    for i in 0..<f7000.count{
//                        f7000[i] = ss[i+325]
//                    }
                    self.distance = fft.fft(numSamples: 1024, samples: ss)
                    print("距離")
                    for i in 0..<self.distance.count {
                        print(self.distance[i])
                    }
                    self.measureFlag = false
                    self.results.removeAll()
                    self.results0.removeAll()
                }
            } else {
                self.results.removeAll()
                self.results0.removeAll()
            }
        })
        audioEngine.attach(audioPlayerNode)
        //        audioEngine.connect(audioPlayerNode, to: audioMixerNode, format: audioPlayerNode.outputFormat(forBus: 0))
        audioEngine.connect(audioPlayerNode, to: audioMixerNode, format: audioFormat)
        
        do {
            try audioEngine.start()
        } catch let err as NSError {
            print(err)
        }
        
        
        
        
        // play player and buffer
        audioPlayerNode.play()
        audioPlayerNode.scheduleBuffer(audioBuffer, at: nil, options: .loops, completionHandler: nil)
    }
    
    func stop(){
        audioEngine.stop()
        audioPlayerNode.stop()
    }
    
    func fft(){
        print(result)
    }
    
    func calculateMedian(array: [Float]) -> Float {
        let sorted = array.sorted()
        if sorted.count % 2 == 0 {
            return Float((sorted[(sorted.count / 2)] + sorted[(sorted.count / 2) - 1])) / 2
        } else {
            return Float(sorted[(sorted.count - 1) / 2])
        }
    }
    
    func calculateAve(array:[Float]) -> Float{
        var sum: Float = 0.0
        for i in 0..<array.count {
            sum = sum + array[i]
        }
        return sum / Float(array.count)
    }
    
}

