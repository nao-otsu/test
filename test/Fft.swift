//
//  Fft.swift
//  WhiteNoise
//
//  Created by yamaken on 2017/12/19.
//  Copyright © 2017年 yamaken. All rights reserved.
//

import Foundation
import Accelerate
class Fft{
    
    var strData: String
    
    init(){
        strData = ""
    }
    
    func fft(numSamples: Int,samples: [Float]) -> [Float]{
        //var reals = [Float](repeating: 0, count: numSamples/2)
        var imgs  = [Float](repeating: 0, count: numSamples/2)
        //var splitComplex = DSPSplitComplex(realp: &reals, imagp: &imgs)
        //let samplesPtr:UnsafePointer<DSPComplex>  = UnsafeRawPointer(samples).bindMemory(to: DSPComplex.self, capacity: samples.count)
        
        //窓関数
        var windowData = [Float](repeating: 0, count: numSamples)
        var windowOutput = [Float](repeating: 0, count: numSamples)
        
        vDSP_hann_window(&windowData, vDSP_Length(numSamples), Int32(0))
        vDSP_vmul(samples, 1, &windowData, 1, &windowOutput, 1, vDSP_Length(numSamples))
        
        var splitComplex = DSPSplitComplex(realp: &windowOutput, imagp: &imgs)
        //var ctozinput = UnsafePointer<DSPComplex>(windowOutput)
        let ctozinput: UnsafePointer<DSPComplex> = UnsafeRawPointer(windowOutput).bindMemory(to: DSPComplex.self, capacity: windowOutput.count)
        vDSP_ctoz(ctozinput, 2, &splitComplex, 1, vDSP_Length(numSamples/2))
        
        //vDSP_ctoz(samplesPtr, 2, &splitComplex, 1, vDSP_Length(numSamples/2))
        
        //  Create FFT setup
        // __Log2nは log2(64) = 6 より、6 を指定
        let setup = vDSP_create_fftsetup(vDSP_Length(log2(Float(numSamples))), FFTRadix(FFT_RADIX2))
        
        // Perform FFT
        vDSP_fft_zrip(setup!, &splitComplex, 1, vDSP_Length(log2(Float(numSamples))), FFTDirection(FFT_FORWARD))
        
        // splitComplex.realp, splitComplex.imagpの各要素を1/2倍する
        var scale:Float = 1 / 2
        vDSP_vsmul(splitComplex.realp, 1, &scale, splitComplex.realp, 1, vDSP_Length(numSamples/2))
        vDSP_vsmul(splitComplex.imagp, 1, &scale, splitComplex.imagp, 1, vDSP_Length(numSamples/2))
        // 複素数の実部と虚部を取得する
        let r = Array(UnsafeBufferPointer(start: splitComplex.realp, count: numSamples/2))
        let i = Array(UnsafeBufferPointer(start: splitComplex.imagp, count: numSamples/2))
        var result = [Float](repeating: 0, count: numSamples/2)
        for n in 0..<numSamples/2 {
            let rel = r[n]
            let img = i[n]
            let mag = sqrtf(rel * rel + img * img)
            result[n] = mag
            //strData += String(mag) + "\n"
            //print(mag)
            //let log = "[%02d]: Mag: %5.2f, Rel: %5.2f, Img: %5.2f"
            //print(String(format: log, n, mag, rel, img))
        }
        //print(strData)
        
        // setupを解放
        vDSP_destroy_fftsetup(setup)
        
        return result
    }
    
    func fftData() -> String{
        //print(strData)
        let data:String = strData
        strData = ""
        return data
    }
    
    
    
}
