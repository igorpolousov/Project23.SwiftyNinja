//
//  GameScene.swift
//  Project23.SwiftyNinja
//
//  Created by Igor Polousov on 07.01.2022.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    override func didMove(to view: SKView) {
    let background = SKSpriteNode(fileNamed: "sliceBackground")
        background?.position = CGPoint(x: 512, y: 384)
    }

}
