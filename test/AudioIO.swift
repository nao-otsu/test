
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
    var bgFlag: Bool = false
    //測定フラグ
    var measureFlag: Bool = false
    
    //バックグランド除去用データ
    var backgroundData = [Float]()
    //観測データ
    var receiveData = [Float]()
    
    var frameLength: UInt32
    var numSamples: Int
    var i: Int = 0
    var result = [Float]()
    var results = [[Float]]()
    var power = [Float]()
    var diffPowr = [Float]()
    var fftData = [Float]()
    
    func iirfilter(x1:Float) -> Float {
        let y1 = (b[0] * x1 + v1m1) / a[0];
        v1m = (b[1] * x1 + v2m1) - a[1] * y1;
        v2m = b[2] * x1 - a[2] * y1;
        v1m1 = v1m;
        v2m1 = v2m;
        return y1;
    }
    
    init(numsamples: Int){
        
        frameLength = UInt32(numsamples)
        numSamples = numsamples
        //        backgroundData = [Float](repeating: 0, count: numSamples)
        receiveData = [Float](repeating: 0, count: numSamples)
        self.power = [Float](repeating:0, count: self.numSamples/2)
        self.diffPowr = [Float](repeating:0, count: self.numSamples/2)
        
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
        let anotherGaussian = GKGaussianDistribution(lowestValue: -10000, highestValue: 10000)
        var bgVector:Float = 0.0
        var xVector:Float = 0.0
        
        audioInputNode.installTap(onBus: 0, bufferSize:frameLength, format: audioInputNode.outputFormat(forBus: 0), block: {(buffer, time) in
            let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
            let floats = UnsafeBufferPointer(start: channels[0], count: Int(self.audioBuffer.frameLength))
            
            //var val = [Float](repeating: 0,count:self.numSamples)
            //print(result)
            
            for i:Int in stride(from: 0, to: Int(self.audioBuffer.frameLength), by: 1){
                //print("interleaved:\(self.audioFormat.isInterleaved)")
                self.receiveData[i] = floats[i] + Float(anotherGaussian.nextInt())/10000
                self.audioBuffer.floatChannelData?.pointee[i] = self.receiveData[i]
                self.audioBuffer.floatChannelData?.pointee[i + Int(self.audioBuffer.frameLength)] = self.receiveData[i]
                //print(i)
            }
            //常にFFT
            self.result = fft.fft(numSamples: self.receiveData.count, samples: self.receiveData)
            //BGのFFT
            if self.bgFlag {
                if self.results.count < 100 {
                    self.results.append(self.result)
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
                        print(self.power[i])
                    }
                    self.bgFlag = false
                }
            //測定のFFT
            }else if self.measureFlag {
                if self.results.count < 10{
                    self.results.append(self.result)
//                    print(self.results.count)
                } else {
                    var tmp2 = [Float](repeating: 0,count: 10)
                    //self.diffPowr.removeAll()
                    for i in 0..<self.numSamples/2 {
                        for j in 0..<10{
                            tmp2[j] = self.results[j][i]
                        }
                        //中央値計算
                        self.diffPowr[i] = self.calculateAve(array: tmp2)// - self.power[i]
                       // print(self.diffPowr[i])
                        xVector = xVector + pow(self.diffPowr[i],2)
                    }
                    let k:Float = sqrt(xVector)/sqrt(bgVector)
                    var ss = [Float](repeating: 0,count: self.numSamples/2)
                    for i in 0..<self.numSamples/2{
                        ss[i] = self.diffPowr[i] - k * self.power[i]
                        print(ss[i])
                    }
                    self.measureFlag = false
                    self.results.removeAll()
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

