//
//  ViewController.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import UIKit
import Metal





class ViewController: UIViewController {
    
    

    @IBOutlet weak var userView: UIView!
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*4
        static let EQUALIZER_SIZE:Int = 20
    }
    
    // setup audio model
    //let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE) // original init
    
    // MARK: Assignment  using sharedinstance for audio init
    //use singleton to init the audio for the pause and replay
    var audio=AudioModel.ShareInstance;
   
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        if let graph = self.graph{
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            
            // add in graphs for display
            // note that we need to normalize the scale of this graph
            // becasue the fft is returned in dB which has very large negative values and some large positive values
            graph.addGraph(withName: "fft",
                            shouldNormalizeForFFT: true,
                            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
            
            graph.addGraph(withName: "time",
                numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
            
            // MARK: Assignment add Graph
            //add new 20point grah
            graph.addGraph(withName: "equalizer", shouldNormalizeForFFT: true, numPointsInGraph: AudioConstants.EQUALIZER_SIZE)
            
            graph.makeGrids() // add grids to graph
        }
        
        // start up the audio model here, querying microphone
        //audio.startMicrophoneProcessing() // preferred number of FFT calculations per second
        audio.startProcesingAudioFileForPlayback()

        audio.play()
        print(audio.isFileReaded)
        print("VC didloaded and audio.play")
        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
       
    }
    
    // MARK: Assignment add disapper func
    //Add the override func to pause the audioManger object
    override func viewDidDisappear(_ animated: Bool) {
        print("VC did disappear and audio.pause")
        audio.pause()
    }
    
    
    // MARK: Assignment add button func
    // start play local song
    @IBAction func playSong(_ sender: Any) {
       // audio.startProcesingAudioFileForPlayback()
        audio.togglePlaying()
    }
    
    
    // periodically, update the graph with refreshed FFT Data
    func updateGraph(){
        
        if let graph = self.graph{
            graph.updateGraph(
                data: self.audio.fftData,
                forKey: "fft"
            )
            
            graph.updateGraph(
                data: self.audio.timeData,
                forKey: "time"
            )
            
            
            // MARK: Assignment add updateGraph
            //add this to update the graph of 20 grahic of the max of windows
            graph.updateGraph(data: self.audio.equalizedData, forKey: "equalizer")
        }
        
    }
    
    

}

