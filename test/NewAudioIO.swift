//
//  NewAudioIO.swift
//  test
//
//  Created by yamaken on 2018/02/11.
//  Copyright © 2018年 yamaken. All rights reserved.
//


import AVFoundation
import GameplayKit

class NewAudioIO {
    
    //サンプリングレート
    let SAMPLE_RATE: Float = 44100.0
    let DATA_LENGTH: Int = 2048
    let DATA_OF_FREQUENCIES = 256
    let MAX_FREQUENCY: Float = 12920.0
    let MIN_FREQUENCY: Float = 7429.0
    var firstIndex: Int = 345
    var lastIndex: Int = 600
    var audioEngine: AVAudioEngine!
    var audioInputNode : AVAudioInputNode!
    var audioPlayerNode: AVAudioPlayerNode!
    var audioMixerNode: AVAudioMixerNode!
    var audioBuffer: AVAudioPCMBuffer!
    var audioFormat: AVAudioFormat!
    
    var fft: Fft!
    
    //オーディオサンプルフレーム内のbuffer容量
    var frameLength: UInt32 = 0
    var bufferSize: Int = 0
    var bufferData = [Float]()
    var noFFTBufferData = [Float]()
    var fftBufferData = [Float]()
    var tmpFFTData = [Float]()
    var bgFFTData = [Float]()
    var targetFFTData = [Float]()
    var resultData = [Float]()
    var resultFFTData = [Float]()
    var ave: Float = 0.0
    var tmpAve: Float = 0.0
    
    
    //対象物の有無
    var objectFlag: Bool = false
    var noObjectFalg: Bool = false
    
    
    
    
    
    //マイクのデータ
    var microphoneData = [Float]()
    
    init(){
        fft = Fft()
        audioEngine = AVAudioEngine()
        audioMixerNode = AVAudioMixerNode()
        audioPlayerNode = AVAudioPlayerNode()
        audioEngine.attach(audioMixerNode)
        audioEngine.attach(audioPlayerNode)
        
        
        tmpFFTData = [Float](repeating:0, count:DATA_LENGTH/2)
        bgFFTData = [Float](repeating:0, count:DATA_LENGTH/2)
        targetFFTData = [Float](repeating:0, count:DATA_LENGTH/2)
        resultData = [Float](repeating:0, count:DATA_LENGTH/2)
        microphoneData = [Float](repeating:0,count: self.DATA_LENGTH)
        
        frameLength = 3 * UInt32(SAMPLE_RATE)
        
        //        let session = AVAudioSession.sharedInstance()
        //        do {
        //            //下のスピーカーを使ったまま再生録音可能
        //            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with:AVAudioSessionCategoryOptions.defaultToSpeaker)
        //            //スピーカー上
        //            //try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
        //            //スピーカー下
        //            //try session.setCategory(AVAudioSessionCategoryAmbient)
        //            try session.setActive(true)
        //        }catch let error {
        //            print(error)
        //        }
        
        
    }
    
    //マイク
    func microphoneBool(){
        
        let session = AVAudioSession.sharedInstance()
        do {
            //下のスピーカーを使ったまま再生録音可能
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try session.setActive(true)
        }catch let error {
            print(error)
        }
        
        audioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32,
                                    sampleRate: Double(SAMPLE_RATE),
                                    channels: 1,
                                    interleaved: true)
        //        print("audioFormat interleaved:\(audioFormat.isInterleaved)")
        //        print("audioFormat channeCount:\(audioFormat.channelCount)")
        audioInputNode = audioEngine.inputNode
        
        var count: Int = 0
        audioInputNode.installTap(onBus: 0, bufferSize:2048, format: audioInputNode.outputFormat(forBus: 0)){(buffer: AVAudioPCMBuffer, time: AVAudioTime) in
            let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
            let bufferData = UnsafeBufferPointer(start: channels[0], count: self.DATA_LENGTH)
            for i in stride(from: 0, to: self.DATA_LENGTH, by: 1){
                self.microphoneData[i] = bufferData[i]
            }
            self.fftBufferData = self.fft.fft(numSamples: self.DATA_LENGTH, samples: self.microphoneData)
            
            //対象物がない時のパワースペクトル100個の平均
            if self.noObjectFalg{
                if count < 100 {
                    for i in 0..<self.DATA_OF_FREQUENCIES{
                        self.tmpFFTData[i + self.firstIndex - 1] = self.tmpFFTData[i + self.firstIndex - 1] + self.fftBufferData[i + self.firstIndex - 1]
                    }
                    count = count + 1
                }else{
                    for i in 0..<self.DATA_OF_FREQUENCIES{
                        self.bgFFTData[i + self.firstIndex - 1] = self.tmpFFTData[i + self.firstIndex - 1] / 100
                        //print(self.bgFFTData[i + self.firstIndex - 1])
                    }
                    count = 0
                    self.noObjectFalg = false
                    print("noObject")
                }
            } //対象物がある時のパワースペクトル100個の平均
            else if self.objectFlag {
                if count < 100 {
                    for i in 0..<self.DATA_OF_FREQUENCIES{
                        self.tmpFFTData[i + self.firstIndex - 1] = self.tmpFFTData[i + self.firstIndex - 1] + self.fftBufferData[i + self.firstIndex - 1]
                    }
                    count = count + 1
                }else{
                    var width: Float = 0.0
                    for i in 0..<self.DATA_OF_FREQUENCIES{
                        width = width + Float(i) * (self.SAMPLE_RATE / Float(self.DATA_LENGTH))
                        self.tmpAve = self.tmpAve + self.tmpFFTData[i + self.firstIndex - 1] * width
                        self.targetFFTData[i + self.firstIndex - 1] = self.tmpFFTData[i + self.firstIndex - 1] / 100
                    }
                    self.ave = self.tmpAve / (self.MAX_FREQUENCY - self.MIN_FREQUENCY)
                    
                    for i in 0..<self.DATA_OF_FREQUENCIES{
                        self.resultData[i + self.firstIndex - 1] = self.targetFFTData[i + self.firstIndex - 1] - self.bgFFTData[i + self.firstIndex - 1]
                    }
                    self.resultFFTData = self.fft.fft(numSamples: self.DATA_LENGTH/2, samples: self.resultData)
                    count = 0
                    self.objectFlag = false
                    print("object")
                    for i in 0..<512{
                        print(self.resultFFTData[i])
                    }
                }
            }

        }
        
        do {
            try audioEngine.start()
        } catch let err as NSError {
            print(err)
        }
    }
    
    //マイクからのデータを返す
    func getMicrophoneData() -> [Float]{
        if objectFlag {
            return microphoneData
        } else {
            return [0]
        }
    }
    
    func play(buffer: [Float]){
        bufferSize = buffer.count
        bufferData = buffer
        
        let session = AVAudioSession.sharedInstance()
        do {
            //下のスピーカーを使ったまま再生録音可能
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
            //スピーカー上
            //try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
            //スピーカー下
            //try session.setCategory(AVAudioSessionCategoryAmbient)
            try session.setActive(true)
        }catch let error {
            print(error)
        }
        
        audioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32,
                                    sampleRate: Double(SAMPLE_RATE),
                                    channels: 2,
                                    interleaved: false)
        audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameLength)!
        audioBuffer.frameLength = frameLength
        audioMixerNode = audioEngine.mainMixerNode
        
        //データをセット
        for i in 0..<Int(self.audioBuffer.frameLength){
            self.audioBuffer.floatChannelData?.pointee[i] = bufferData[i]
            self.audioBuffer.floatChannelData?.pointee[i + Int(self.audioBuffer.frameLength)] = bufferData[i]
        }
        audioEngine.connect(audioPlayerNode, to: audioMixerNode, format: audioFormat)
        do {
            try audioEngine.start()
        } catch let err as NSError {
            print(err)
        }
        audioPlayerNode.play()
        audioPlayerNode.scheduleBuffer(audioBuffer, at: nil, options: .loops, completionHandler: nil)
    }
    
    func stop(){
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }
    
    func calculateMedian(array: [Float]) -> Float {
        let sorted = array.sorted()
        if sorted.count % 2 == 0 {
            return Float((sorted[(sorted.count / 2)] + sorted[(sorted.count / 2) - 1])) / 2
        } else {
            return Float(sorted[(sorted.count - 1) / 2])
        }
    }
}

