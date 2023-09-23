//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int = 1024*4
    // MARK: Assignment add two new property
    private var FFT_BUFFER_SIZE:Int
    private var EQUALIZER_SIZE:Int = 20  // for the equalize array
    private var EQUALIZER_WINDOW_SIZE:Int // for the equalizer from fftdata
    private var WITH_FPS:Double = 20.0
    private var timerStarted:Bool = false
    
    // thse properties are for interfaceing with the API
    // the user can access these arrays at any time and plot them if they like
    var timeData:[Float]
    var fftData:[Float]
    // MARK: Assignment add new array for the new graph
    var equalizedData:[Float]
    var status:Bool = false  //false means buffer from microphon, true means buffer from song
    var isFileReaded:Bool
    // MARK: Assignment , using sharedinstance for pause and replay
    static var ShareInstance=AudioModel()

    
    // MARK: Public Methods
    // rewrite the init method to using static BUFFERSIZE
    init() {
        FFT_BUFFER_SIZE = BUFFER_SIZE / 2
        EQUALIZER_WINDOW_SIZE = FFT_BUFFER_SIZE / EQUALIZER_SIZE
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: FFT_BUFFER_SIZE)
        equalizedData = Array.init(repeating: 0.0, count: EQUALIZER_SIZE)
        isFileReaded=false
    }

    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(){
        // setup the microphone to copy to circualr buffer
        if let manager = self.audioManager{
            manager.inputBlock = self.handleMicrophone
            manager.outputBlock=nil
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            if !timerStarted{
                timerStarted = true
                
                Timer.scheduledTimer(withTimeInterval: 1.0/WITH_FPS, repeats: true) { _ in
                    self.runEveryInterval()
                }
            }
            status = false
            
        }
    }
    
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager{
            manager.play()
        }
    }
    
    // MARK: Assignment add pause
    // add pause function for the Assginment
    func pause(){
        if let manager=self.audioManager, let reader=self.fileReader{
            manager.pause()
            reader.pause()
        }
    }
    
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        //var c = self.audioManager!.numInputChannels
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    // NONE for this model
    
    //==========================================
    // MARK: Model Callback Methods
    private func runEveryInterval(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData,
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            
            
            //some description for my understanding about the fftdata , every items in fftdata means the magnitude of certain frequncy
            //such like the 0khz 1khz 2khz ....2048khz,the item is the magnitude of the certain frequncy
            
            // MARK: Assignment  for new graph array data
            //Calculate equalized data
            for i in 0..<EQUALIZER_SIZE{
                //use vDSP to pick up the maxima of the windows
                let subFftDataPrt = fftData.withUnsafeBufferPointer({$0.baseAddress})!+i*EQUALIZER_WINDOW_SIZE
                vDSP_maxv(subFftDataPrt, 1, &equalizedData[i], vDSP_Length(EQUALIZER_WINDOW_SIZE))
            }
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
        }
    }
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    
    // MARK: Assignment for below several func
    // Here for the load the mp3 file
    private lazy var fileReader:AudioFileReader?={
        if let url=Bundle.main.url(forResource: "satisfaction", withExtension: "mp3"){
            var tempFileReader:AudioFileReader?=AudioFileReader.init(audioFileURL: url, samplingRate: Float(audioManager!.samplingRate), numChannels: audioManager!.numOutputChannels)
            tempFileReader!.currentTime=0.0
            isFileReaded=true
            print("Audio file succesfully loaded for\(url)")
            return tempFileReader
        }else{
            print("Could not initialize audio input file")
            return nil
        }
    }()
    
    // add func for hadleSpeaker for play songs
    private func handleSpeakerQueryWithAudioFile(data:Optional<UnsafeMutablePointer<Float>>,numFrames:UInt32,numChannels:UInt32){
        if let file = self.fileReader,
           let arrayData = data{
            
            //read from file, loading into data
            file.retrieveFreshAudio(arrayData, numFrames: numFrames, numChannels: numChannels)
            //new buffer for the graph
            self.inputBuffer?.addNewFloatData(arrayData, withNumSamples: Int64(numFrames*numChannels))
        }
    }
    
    // add func for callback of processing audiofile
    func startProcesingAudioFileForPlayback(){
        if let manager=self.audioManager,let fileReader=self.fileReader{
            manager.inputBlock = nil
            manager.outputBlock=self.handleSpeakerQueryWithAudioFile
            fileReader.play()
            //update the data
            if !timerStarted{
                timerStarted = true
                Timer.scheduledTimer(withTimeInterval: 1.0/WITH_FPS, repeats: true) { _ in
                    self.runEveryInterval()
                }
            }
            status = true
        }
    }
    
    // change the audio status for playing song or detect sounds
    func togglePlaying(){
        if let manager=self.audioManager, let reader=self.fileReader{
            if manager.playing{
                if status{
                    manager.pause()
                    reader.pause()
                    self.startMicrophoneProcessing()
                    manager.play()
                    print("change to detect")
                }else{
                    self.startProcesingAudioFileForPlayback()
                    manager.play()
                    print("change to play")
                }
            }else{
                manager.play()
                print("fist time to play")
            }
        }
    }
    
}
