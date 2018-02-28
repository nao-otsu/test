//
//  SoundGenerator.swift
//  test
//
//  Created by yamaken on 2018/02/09.
//  Copyright © 2018年 yamaken. All rights reserved.
//

import Foundation
import GameplayKit

class SoundGenerator {
    
    let SAMPLE_RATE: Float = 44100.0
    let AMPLITUDE: Float = 1.0
    let NUM_OF_FREQUENCIES: Int = 256
    let MAX_FREQUENCY: Float = 12920.0
    let MIN_FREQUENCY: Float = 7429.0
    let FFT_SIZE: Int = 2048
    
    var buffer = [Float]()
    var phase = [Float]()
    var frameLength: Int = 0
    
    //sin波生成して返す
    func getSendWave() -> [Float]{
        //3秒
        frameLength = 3 * Int(SAMPLE_RATE)
        buffer = [Float](repeating:0, count:frameLength)
        phase = [Float](repeating:0, count:frameLength)
        //位相をランダムで生成
        let randomPhase = GKRandomDistribution(lowestValue: 0, highestValue: 62831)
        let resolution: Float = SAMPLE_RATE / Float(FFT_SIZE)
        
        for i in 0..<frameLength {
            let period: Float = Float(i) / SAMPLE_RATE
            
            //0~2πの一様乱数による位相
            for j in 0..<NUM_OF_FREQUENCIES{
                if i == 0 {
                    phase[j] = Float(randomPhase.nextInt()) / 10000.0
                }
                //7429~12920の周波数で作成
                let frequency = MIN_FREQUENCY + resolution * Float(j)
                //振幅*sin(2*π*周波数*時刻t)
                //buffer[i] = buffer[i] + AMPLITUDE * sin(2*Float(Double.pi) * frequency * period + Float(randomPhase.nextInt()) / 10000.0)//phase[j])
                buffer[i] = buffer[i] + AMPLITUDE * sin(2*Float(Double.pi) * frequency * period + phase[j])
            }
        }
        print("sin波生成")
        //print(buffer)
        return buffer
    }
    
    
}
