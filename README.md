# MarbleKit (iOS/iPadOS & macOS)

Process & manipulate audio/video in realtime using Swift/SwiftUI.

![Preview](https://stoic-static-files.s3.us-west-1.amazonaws.com/marblekit/marblekit_intro.gif)

> The preview and this README uses my open-source application [Bitsy](https://github.com/pexavc/Bitsy) for demonstration.

**Table of Contents**
- [Requirements](#requirements)
- [Guide Engine](#guide-engine)
  - [Basic Usage](#Basic-Usage)
  - [Tips](#Tips)
- [Guide Player](#guide-player)
  - [Player Initialization](#Player-Initialization)
  - [Player Options](#Player-Options)
  - [Changing Marble Effects](#Changing-Marble-Effects)
- [Guide Effects](#guide-effects)
  - [Adding a New Marble Effect](#Adding-a-new-Marble-Effect)
- [Guide CoreML](#guide)
  - [Intercepting Audio Buffers](#Intercepting-Audio-Buffers) [WIP]
  - [CoreML inferencing (Audio)](#CoreML-inferencing-(Audio)) [WIP]
  - [CoreML inferencing (Video)](#CoreML-inferencing-(Video)) [WIP]

## Requirements

- `iOS 14+`  ***Build passing*** 🟢 
- `macOS 12.4+`  ***Build passing*** 🟢 

**Installation**

Build locally using `XCode 14.2` or download the latest *notarized* build [here](https://github.com/pexavc/Bitsy/releases).                

## Swift Packages

- [FFmpegKit](https://github.com/pexavc/FFmpegKit) by [@kingslay](https://github.com/kingslay)

## Guide Engine

The `MarblePlayer`, specifically [MarbleRemote](https://github.com/pexavc/MarbleKit/blob/main/Sources/MarbleKit/Player/MarbleRemote/MarbleRemote.swift), is in itself a great guide on how to add an instance of `MarbleEngine` for direct effect application.

```swift
public var metalContext: MetalContext = .init()
private let marble: MarbleEngine = .init()
```

An engine will need MarbleKit's metalContext to be used when compiling effects onto an input texture.


### Basic Usage

```swift
public var fx: [MarbleEffect] = [.godRay, ink]

let context = self.metalContext
    
//Create layers
let layers: [MarbleLayer] = fx.map {
    .init($0.getLayer(audioSample.amplitude, threshold: 1.0))
}
    
//Create the composite from an inputTexture (MTLTexture, bgra8Unorm)
let composite: MarbleComposite = .init(
    resource: .init(
        textures: .init(main: inputTexture),
        size: inputTexture),
    layers: layers)

//Compile
let compiled = marble.compile(
    fromContext: context,
    forComposite: composite)

//Return for display
if let filteredTexture = compiled.resource?.textures?.main {
    return filteredTexture
} else {
    return texture
}

```

> [Basic effect compiling flow](https://github.com/pexavc/MarbleKit/blob/main/Sources/MarbleKit/Player/MarbleRemote/MarbleRemote.swift#L286-L321)


### Tips

- All input textures should be `.bgra8Unorm` ordering prior to compilation. 

**MTLDrawable**

If you have your own `MTKView` to render metal textures. An easy way to render filtered textures onto your drawable for the front-end to update accordingly, is to use the downsample kernel apart of `MetalContext`.

```swift
metalContext
    .kernels
    .downsample
    .encode(
        commandBuffer: commandBuffer,
        inputTexture: filteredTexture,
        outputTexture: drawable.texture)
```

> [MTKViewDelegate draw callback usage](https://github.com/pexavc/MarbleKit/blob/main/Sources/MarbleKit/Player/MarbleRemote/MarbleRemote.swift#L191-L226) with a filtered texture.


**Extensions**

[MTLTexture -> CVPixelBuffer](https://github.com/pexavc/MarbleKit/blob/main/Sources/MarbleKit/Engine/Core/Metal/Helpers/Extension/MTLTexture/MTLTexture.swift#L34-L64)

```swift
texture.pixelBuffer?
```

[CVPixelBuffer -> MTLTexture] (https://github.com/pexavc/MarbleKit/blob/main/Sources/MarbleKit/Engine/Core/Metal/Helpers/Extension/CVPixelBuffer/CVPixelBuffer.swift#L81-L107)

```swift
//context is a reference to a local MetalContext if one is available
//device refers to a MTLDevice
texture(context.device, pixelFormat: .bgra8Unorm)?
```

> MetalContext as seen in [Basic Usage](#Basic-Usage) has a `MTLDevice` that can be re-used for the above logic.


## Guide Player

> MarblePlayer was initially inspired heavily by an amazing Open-Source player known as [KSPlayer](https://github.com/kingslay/KSPlayer) by [@kingslay](https://github.com/kingslay). Helping provide a path when dealing with HLS livestreams.

The `MarblePlayerView` requires a `MarbleRemoteConfig` to initilize playback setting. Using a `MetalView` as backing to render the video and audio output data automatically. Playback controls are exposed as static functions and/or variables that can be triggered from your front-end.


### Player Initialization


> For now, only HLS streams with `.m3u` playlist file links have been tested. Local video data support will come in a future update.

1. Create a `MarbleRemoteConfig`

```swift
public struct MarbleRemoteConfig: Equatable, Codable, Identifiable, Hashable {
    public var id: String {
        "\(date.timeIntervalSince1970)"
    }
    
    public var date: Date = .init()
    public var name: String
    public var kind: MarbleRemoteConfig.StreamConfig.Kind
    public var streams: [StreamConfig]
    
    public init(name: String,
                kind: MarbleRemoteConfig.StreamConfig.Kind,
                streams: [StreamConfig]) {
        self.name = name
        self.kind = kind
        self.streams = streams
    }
    
    public var description: String {
        name + "'s Stream on " + kind.rawValue.capitalized
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    ...
}
```

2. Set the config within a [MarblePlayerView](https://github.com/pexavc/Bitsy/blob/main/Shared/Components/Canvas/Canvas%2BView.swift).

```swift
extension Canvas {
    public var view: some View {
        ZStack {
            MarblePlayerView(config)
        }
    }
}
```


### [Player Options](https://github.com/pexavc/MarbleKit/blob/main/Sources/MarbleKit/Player/MarblePlayer/Models/MarblePlayerOptions.swift)


Example options that can be adjusted to modify the HLS stream properties prior to initialization of the MarblePlayerView.


```swift
MarbleRemote.enableFX = true     
MarblePlayerOptions.isAutoPlay = false
MarblePlayerOptions.isSeekedAutoPlay = false
MarblePlayerOptions.preferredForwardBufferDuration = 4
MarblePlayerOptions.maxBufferDuration = 48
MarblePlayerOptions.dropVideoFrame = false
MarblePlayerOptions.forcePreferredFPS = false
MarblePlayerOptions.preferredFramesPerSecond = 60
MarblePlayerOptions.isVideoClippingEnabled = false
```


### Changing Marble Effects

[Here](https://github.com/pexavc/MarbleKit/blob/a3196174421940ddf778d6033453f7038bf774ad/Sources/MarbleKit/Engine/Core/Catalog/FilterType.swift#L44-L110) is a list of current FX supported. Simply adjust this static variable anywhere to change the fx yourself programmatically. 


```swift
MarbleRemote.fx = [.ink]
```

## Guide Effects


> This will updated heavily to adhere to proper protocol inheritance and re-usability.


### Adding a New Marble Effect


1. All effects start as an enum param of [EffectType](https://github.com/pexavc/MarbleKit/blob/main/Sources/MarbleKit/Engine/Core/Catalog/FilterType.swift). They can have 2 possible values in their enum's closure. The left pertaining to the loudness (should be passed in as the sound sample's decibal value). The right pertains to the threshold. So a user could potentially increase or decrease the intensity applied to the effect, a layer ontop of the passed in loudness. The threshold value should be a Float in the `[0-1]` range.

2. The [Effects directory](https://github.com/pexavc/MarbleKit/tree/main/Sources/MarbleKit/Engine/Core/Catalog/Effects) gives an inside look on how each are structured and prepared prior to pipeline creation.

3. Marble's [MetalContext](https://github.com/pexavc/MarbleKit/blob/main/Sources/MarbleKit/Engine/Core/Metal/MetalContext.swift#L75-L117) is the core behind filter access and initializing. After adding the kernel to the effects directory a reference should be made in similar fashion [here](https://github.com/pexavc/MarbleKit/blob/main/Sources/MarbleKit/Engine/Core/Metal/MetalContext.swift#L75-L117).

4. The `MarbleEngine` will then apply the filter accordingly [here](https://github.com/pexavc/MarbleKit/blob/main/Sources/MarbleKit/Engine/MarbleEngine.swift#L38-L73). Which is another location you will have to modify with your new filter.


## Guide CoreML

A basic speech to text CoreML model will be added for real-time closed captioning. Proper pipelines will be put into place to allow for custom model insertions and output retrieval. Agnostic to a specific set of input and output types. Since MarbleKit is a renderer in itself, the input type will be a controlled variable, while the output will be customizable. (Image to Text, Image to Image, etc.)


***WIP***


## TODO
- [ ] Stress testing and stability
- [ ] Vague audio channel layouts not being compatible with MarblePlayer
- [ ] Memory Leaks (Packet/Frame decoding primarily)
