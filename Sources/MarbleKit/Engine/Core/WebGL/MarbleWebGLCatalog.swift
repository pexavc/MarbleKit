//
//  File.swift
//  
//
//  Created by PEXAVC on 8/13/23.
//

import Foundation

public class MarbleWebGLCatalog {
    static public var shared: MarbleWebGLCatalog = .init()
    
    public enum FX: String, Equatable, Hashable, CaseIterable, Identifiable {
        case amsterdam
        case andromeda
        case aura
        case bankai
        case bedazzled
        case black_diamond
        case carbon
        case constellation
        case dairy
        case discotech
        case glitch
        case godrays
        case kami
        case latte
        case m1lky_way
        case magma
        case marble
        case oculus
        case satin
        case temple
        case vinyl
        case voronoise
        case waves
        case granite
        
        public var id: String {
            self.rawValue
        }
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    public func load(_ fx: FX) -> String? {
        guard let path = Bundle.module.path(forResource: fx.rawValue, ofType: "txt") else {
            MarbleLog("failed to get webGL shader", logLevel: .error)
            return nil
        }
        
        let file = try? String(contentsOfFile: path)
        if file == nil {
            MarbleLog("no file: \(path)", logLevel: .error)
        }
        return file
    }
}
