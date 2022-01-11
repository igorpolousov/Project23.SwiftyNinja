//
//  GameScene.swift
//  Project23.SwiftyNinja
//  Days 77-79
//  Created by Igor Polousov on 07.01.2022.
//

import AVFoundation
import SpriteKit

// Перечисление для метода createEnemy(forceBomb: ForceBomb) в котром будет указываться какой тип объекта будет создаваться для отображения. Всего может появиться два объекта: бомба или пингвин
enum ForceBomb {
    case never, always, random
}
// Перечисление для метода tossEnemies() используется для выбора какие объекты появятся и сколько
enum SequenceType: CaseIterable {
    case oneNoBomb, one, twoWithOneBomb, two, three, four, chain, fastChain
}

class GameScene: SKScene {
    
    // MARK: всего объявлено 15 переменных
    
    // MARK: for createScore()
    // Отображение надписи с количеством очков
    var gameScore: SKLabelNode!
    // Переменная для подстчёта очков
    var score = 0 {
        didSet{
            gameScore.text = "Score: \(score)"
        }
    }
    
    // MARK: for createLives()
    // Массивы для отображения количества жизней: красный крест или пустой белый крест. Всего 3 шт
    var livesImages = [SKSpriteNode]()
    
    // MARK: for subtractLives()
    // Переменная для подстчета жизней
    var lives = 3
    
    // MARK: for createSlices() - сделаны две чтобы сделать утолщение полоски(две линии) одна поверх другой для красоты
    // Активный слайс на заднем фоне
    var activeSliceBG: SKShapeNode!
    // Активный слайс на переднем фоне
    var activeSliceFG: SKShapeNode!
    
    // MARK: for redrawActiveSlice()
    // Активные (массив)точки слайса(нож) на экране для построения линии касания к экрану
    var activeSlicePoints = [CGPoint]()
    
    // MARK: for playSwooshSound()
    // Активен звук ножа или нет
    var isSwooshSoundActive = false
    
    // MARK: for createEnemy() update()
    // Действующие предметы на экране
    var activeEnemies = [SKSpriteNode]()
    // Звуковой эффект бомбы
    var bombSoundEffect: AVAudioPlayer?
    
    // MARK: for update()
    // Время появления
    var popupTime = 0.9
    // Есть следующая последовательность или нет в очереди?
    var nextSequenceQueued = true
    
    // MARK: for didMove()
    // Массив последовательностей появления предметов
    var sequence = [SequenceType]()
    
    // MARK: for tossEnemy()
    // ??Место положения последовательностей??
    var sequencePosition = 0
    // Задержка в цепи последовательностей
    var chainDelay = 3.0
    
    // MARK: for touchesMoved() and endGame()
    // Закончилась игра или нет
    var isGameEnded = false
    
    // Основной метод при загрузке игры
    override func didMove(to view: SKView) {
        // Установлен фон игрового поля
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
        
        // ??Установлена гравитация с указанием вектора гравитации, по оси Х остается стандартной, по оси Y есть смещение
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        // Скорость с которой будут выполняться события, установлено замедление
        physicsWorld.speed = 0.85
        createScore()
        createLives()
        createSlices()
        
        // Задана начальная последовательность появления предметов при старте игры для разогрева игрока
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]
        
        //  Цикл из 1000 итераций который будет выбирать следующую последовательность из всего списка последовательностей случайным образом и добавлять в массив последовательностей, для этого использовался протокол CaseIterable. Таким образом будем иметь начальный массив + еще 1000 элементов в массиве
        for _ in 1...1000 {
            if let nextSequence = SequenceType.allCases.randomElement() {
                sequence.append(nextSequence)
            }
        }
        
        // Создание новой группы предметов с задержкой 2 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            [weak self] in self?.tossEnemies()
        }
    }
    
    // Инициализация переменной gameScore и указание её характеристик + инициализация переменной score
    func createScore() {
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.horizontalAlignmentMode = .left
        gameScore.fontSize = 48
        addChild(gameScore)
        
        gameScore.position = CGPoint(x: 8, y: 8)
        score = 0
    }
    
    // Создание 3-х изображений пустых крестов для отображения оставшихся жизней и добавления в массив
    func createLives() {
        for i in 0 ..< 3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
            addChild(spriteNode)
            livesImages.append(spriteNode)
        }
    }
    
    //  Созданы два вида нод для отображения полос на экране повторяющих движение пальца по экрану
    func createSlices() {
        // Указана разная толщина и zPozition чтобы одна полоска была над другой
        activeSliceBG = SKShapeNode()
        activeSliceBG.zPosition = 2
        
        activeSliceFG = SKShapeNode()
        activeSliceFG.zPosition = 3
        
        activeSliceBG.strokeColor = UIColor(displayP3Red: 1, green: 0.9, blue: 0, alpha: 1)
        activeSliceBG.lineWidth = 9
        
        activeSliceFG.strokeColor = UIColor.white
        activeSliceFG.lineWidth = 5
        
        addChild(activeSliceFG)
        addChild(activeSliceBG)
    }
    
    // Метод для определения касаний на экране в процессе: линия взмаха ножа, взаимодействие с пингвином или бомбой
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Проверка что игра не закончена
        guard isGameEnded == false else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        // Добавляем точку в массив для отображения линии в массив точек
        activeSlicePoints.append(location)
        // Нарисовали линию
        redrawActiveSlice()
        
        // Звук взмаха ножом
        if !isSwooshSoundActive {
            playSwooshSound()
        }
        
        // Массив нод в точке касания
        let nodesAtPoint = nodes(at: location)
        
        for case let node as SKSpriteNode in nodesAtPoint {
            // Если имя ноды enemy ПИНГВИН
            if node.name == "enemy" {
                // destroy the penguin with animation
                if let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy") {
                    emitter.position = node.position
                    addChild(emitter)
                }
                // удалили имя ноды и прекратили взаимодействие с другими предметами
                node.name = ""
                node.physicsBody?.isDynamic = false
                
                // Заданы константы для действий с удаляемой нодой: уменьшили, исчезла с затуханием
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                // Создана группа последовательностей
                let group = SKAction.group([scaleOut, fadeOut])
                let seq = SKAction.sequence([group, .removeFromParent()])
                node.run(seq)
                
                // Изменение количества очков
                score += 1
                // Удаление ноды из массива созданных нод
                if let index = activeEnemies.firstIndex(of: node) {
                    activeEnemies.remove(at: index)
                }
                // Проиграть звук
                run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
                // Если БОМБА, то игра будет завершена
            } else if node.name == "bomb" {
                // destroy the bomb
                guard let bombContainer = node.parent as? SKSpriteNode else { continue }
                if let emitter = SKEmitterNode(fileNamed: "sliceHitBomb") {
                    emitter.position = bombContainer.position
                    addChild(emitter)
                }
                node.name = ""
                bombContainer.physicsBody?.isDynamic = false
                
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([scaleOut, fadeOut])
                let seq = SKAction.sequence([group, .removeFromParent()])
                bombContainer.run(seq)
                
                if let index = activeEnemies.firstIndex(of: bombContainer) {
                    activeEnemies.remove(at: index)
                }
                
                run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
                endGame(triggeredByBomb: true)
            }
        }
    }
    
    // Завершение игры: отключили звук бомбы, скорость мира = 0, взаимодействие пользователя = false, установили все кресты на красный
    func endGame(triggeredByBomb: Bool) {
        guard isGameEnded == false else { return }
        isGameEnded = true
        physicsWorld.speed = 0
        isUserInteractionEnabled = false
        bombSoundEffect?.stop()
        bombSoundEffect = nil
        // Если при вызове метода будет указано true, то все кресты обозначающие жизнь будут заменены на красные
        if triggeredByBomb {
            livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
        }
    }
    
    // Проигрывание звука взмаха ножа: выбирается случайным образом один из трех звуков
    func playSwooshSound() {
        isSwooshSoundActive = true
        let randomNumber = Int.random(in: 1 ... 3)
        let soundName = "swoosh\(randomNumber).caf"
        
        // Задано ожидание конца при проигрывании звука, чтобы не было наложения звуковых дорожек
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        run(swooshSound) { [weak self] in
            self?.isSwooshSoundActive = false
        }
    }
    
    // Завершение касания: установлено затухание для линий взмаха ножа(линий касания на экране)
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
        
    }
    
    // Начало касания: оистили массив с точками для взмаха ножа, добавили начальную точку в массив, нарисовали линию
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        activeSlicePoints.removeAll(keepingCapacity: true)
        
        let location = touch.location(in: self)
        activeSlicePoints.append(location)
        
        redrawActiveSlice()
        // Если произошел отрыв пальца от экрана и появилось новое касание, то все предыдущие действия останавливаются
        activeSliceBG.removeAllActions()
        activeSliceFG.removeAllActions()
        
        activeSliceBG.alpha = 1
        activeSliceFG.alpha = 1
    }
    
    // Нарисовать новую линию
    func redrawActiveSlice() {
        // Проверка Если количество точек в массиве для линии взмаха ножа меньше двух, то линию не рисовать
        if activeSlicePoints.count < 2 {
            activeSliceBG.path = nil
            activeSliceFG.path = nil
            return
        }
        // Если количество точек для линии больше 12, то удалить первые точки -12, таким образом остается минимум 12 точек и определенная длина линии взмаха ножа
        if activeSlicePoints.count > 12 {
            activeSlicePoints.removeFirst(activeSlicePoints.count - 12)
        }
        // Первая точка в виде нулевого элемента в массиве
        let path = UIBezierPath()
        path.move(to: activeSlicePoints[0])
        // Рисовать линию от нулевого элемента в массиве до следующего элемента в массиве начиная с первого
        for i in 1 ..< activeSlicePoints.count {
            path.addLine(to: activeSlicePoints[i])
        }
        activeSliceBG.path = path.cgPath
        activeSliceFG.path = path.cgPath
    }
    
    // Создание врага(предмета на экране): выбирается создать пингвина или бомбу в зависимости от принятого параметра, задается положение появления, скорость вращения, направление движения
    func createEnemy(forceBomb: ForceBomb = .random) {
        let enemy: SKSpriteNode
        //ХЗ зачем было указано от 0 до 6
        var enemyType = Int.random(in: 0...6)
        // Если запустить бомбу указано как never то тип enemy будет 1
        if forceBomb == .never {
            enemyType = 1
        // Если запустить бомбу указано как always то тип врага будет 0 - бомба
        } else if forceBomb == .always {
            enemyType = 0
        }
        // Если бомба
        if enemyType == 0 {
            // Создали ноду enemy(предмет) как контейнер для бомбы, контейнер нужен чтобы в дальнейшем создать ноду бомбы и к ней добавить анимацию огонька на фитиле
            enemy = SKSpriteNode()
            enemy.zPosition = 1
            enemy.name = "bombContainer"
            // Создали ноду бомбы
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb"
            // Добавили к ноде enemy
            enemy.addChild(bombImage)
            // Убрали звук бомбы
            if bombSoundEffect != nil {
                bombSoundEffect?.stop()
                bombSoundEffect = nil
            }
            // Указание пути и проигрывание звука горящего фитиля
            if let path = Bundle.main.url(forResource: "sliceBombFuse", withExtension: "caf") {
                if let sound = try? AVAudioPlayer(contentsOf: path) {
                    bombSoundEffect = sound
                    sound.play()
                }
            }
            // Указание анимации для фитиля и добавление анимации
            if let emitter = SKEmitterNode(fileNamed: "sliceFuse") {
                emitter.position = CGPoint(x: 76, y: 64)
                // Добавили анимации к enemy
                enemy.addChild(emitter)
            }
            
        } else {
            // Если не бомба, то создать пингвина
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemy"
        }
        
        // Указание места появления enemy
        let randomPosition = CGPoint(x: Int.random(in: 64...960), y: -128)
        enemy.position = randomPosition
        
        // Указание скорости вращения и скорости по вектору по Х
        let randomAngularVelocity = CGFloat.random(in: -3...3)
        let randomXvelocity: Int
        
        // Скорость по Х задается в зависимости от места появления enemy
        if randomPosition.x < 256 {
            randomXvelocity = Int.random(in: 8...15)
        } else if randomPosition.x < 512 {
            randomXvelocity = Int.random(in: 3...5)
        } else if randomPosition.x < 768 {
            randomXvelocity = -Int.random(in: 3...5)
        } else {
            randomXvelocity = -Int.random(in: 8...15)
        }
        // Скорость по вектору Y задается случайным образом
        let randomYvelocity = Int.random(in: 24...32)
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
        enemy.physicsBody?.velocity = CGVector(dx: randomXvelocity * 40, dy: randomYvelocity * 40)
        enemy.physicsBody?.angularVelocity = randomAngularVelocity
        enemy.physicsBody?.collisionBitMask = 0
        
        
        addChild(enemy)
        activeEnemies.append(enemy)
    }
    
    // Уменьшение количества жизней и замена белого креста жизней на красный
    func sabtractLife() {
        // Если пнигвин не был сбит
        lives -= 1
        run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        var life: SKSpriteNode
        // Если количество жизней уменьшилось, то заменить жлемент в массиве с крестами с белого на заполненный красный
        if lives == 2 {
            life = livesImages[0]
        } else if lives == 1 {
            life = livesImages[1]
        } else {
            life = livesImages[2]
            endGame(triggeredByBomb: false)
        }
        
        // Картнка белого креста меняется на красный крест сначала большая и потом до обычного размера
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        life.xScale = 1.3
        life.yScale = 1.3
        life.run(SKAction.scaleX(to: 1, duration: 0.1))
    }
    
    // Отслеживает изменения в процессе игры: если игрок попал на пингвина, то убрать пингвина и уменьшить количество жизней, запустить следующую очередь с enemy, проверить бомбы, и если нет, то отключить звук фитиля
    override func update(_ currentTime: TimeInterval) {
        // Если количество enemy больше 0 и если enemy это пингвин и он вышел за пределы экрана, то уменьшить количество жизней и удалить ноду
        if activeEnemies.count > 0 {
            for (index, node) in activeEnemies.enumerated().reversed() {
                if node.position.y < -140 {
                    node.removeAllActions()
                    if node.name == "enemy" {
                        node.name = ""
                        sabtractLife()
                        
                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                    } else if node.name == "bombContainer" {
                        node.name = ""
                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                    }
                }
            }
        } else {
            // Если не запланированна следующая очередь, то есть предыдущая выполнена полностью
            if !nextSequenceQueued {
                // Вызвать последовательность создания enemy
                DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) {
                    [weak self] in
                    self?.tossEnemies()
                }
                nextSequenceQueued = true
            }
        }
        // Проверка на наличии бомбы на экране и в случае если бомбы нет то отключить звук фитиля
        var bombCount = 0
        // Если есть нода бомбы то увеличить количество бомб на 1
        for node in activeEnemies {
            if node.name == "bombContainer" {
                bombCount += 1
                break
            }
        }
        // Если такой ноды нет, то отключить звук фитиля в бомбе
        if bombCount == 0 {
            bombSoundEffect?.stop()
            bombSoundEffect = nil
        }
    }
    
    // Появление врагов в зависимости от последовательности
    func tossEnemies() {
        guard isGameEnded == false else { return }
        popupTime *= 0.991
        chainDelay *= 0.99
        physicsWorld.speed *= 1.02
        // Получаем тип последовательности из массива последовательностей начиная с нулевой и добавляется +1 после каждого выполнения для перехода к другой последовательности
        let sequenceType = sequence[sequencePosition]
        
        // Перечисление действий в зависимости от типа последовательности
        switch sequenceType {
        case .oneNoBomb:
            createEnemy(forceBomb: .never)
        case .one:
            createEnemy()
        case .twoWithOneBomb:
            createEnemy(forceBomb: .never)
            createEnemy(forceBomb: .always)
        case .two:
            createEnemy()
            createEnemy()
        case .three:
            createEnemy()
            createEnemy()
            createEnemy()
        case .four:
            createEnemy()
            createEnemy()
            createEnemy()
            createEnemy()
        case .chain:
            createEnemy()
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) {
                [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) {
                [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) {
                [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) {
                [weak self] in self?.createEnemy() }
        case .fastChain:
            createEnemy()
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) {
                [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) {
                [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) {
                [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) {
                [weak self] in self?.createEnemy() }
        }
        sequencePosition += 1
        nextSequenceQueued = false
    }
}
