//
//  ViewController.swift
//  Vehicle
//
//  Created by Benjamin Salter on 8/25/20.
//  Copyright © 2020 Benjamin Salter. All rights reserved.
//

import UIKit
import ARKit
import CoreMotion

class ViewController: UIViewController {
    @IBOutlet weak var sceneView: ARSCNView!
    let configuration = ARWorldTrackingConfiguration()
    let motionManager = CMMotionManager()
    var vehicle = SCNPhysicsVehicle()
    var orientation: CGFloat = 0
    var touched: Int = 0
    var accelerationValues = [UIAccelerationValue(0), UIAccelerationValue(0)]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        self.configuration.planeDetection = .horizontal
        self.sceneView.session.run(configuration)
        self.sceneView.delegate = self
        self.sceneView.showsStatistics = true
        self.setupAccelerometer()
    }
    
    func createConcrete(planeAnchor: ARPlaneAnchor) -> SCNNode {
        let concreteNode = SCNNode(geometry: SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z)))
        concreteNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "Concrete")
        concreteNode.geometry?.firstMaterial?.isDoubleSided = true
        concreteNode.position = SCNVector3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        concreteNode.eulerAngles = SCNVector3(90.degreesToRadians, 0, 0)
        let staticBody = SCNPhysicsBody.static()
        concreteNode.physicsBody = staticBody
        return concreteNode
    }
    
    @IBAction func addCar(_ sender: UIButton) {
        guard let pointOfView = sceneView.pointOfView else { return }
        let transform = pointOfView.transform
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let currentPositionOfCamera = orientation + location
        let scene = SCNScene(named: "Car-Scene.scn")
        let chassis = (scene?.rootNode.childNode(withName: "chassis", recursively: false))!
        chassis.position = currentPositionOfCamera
        
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: chassis, options: [SCNPhysicsShape.Option.keepAsCompound: true]))
        body.mass = 1
        chassis.physicsBody = body
        
        let frontLeftWheel = chassis.childNode(withName: "frontLeftParent", recursively: false)!
        let frontRightWheel = chassis.childNode(withName: "frontRightParent", recursively: false)!
        let rearLeftWheel = chassis.childNode(withName: "rearLeftParent", recursively: false)!
        let rearRightWheel = chassis.childNode(withName: "rearRightParent", recursively: false)!
       
        let v_frontLeftWheel = SCNPhysicsVehicleWheel(node: frontLeftWheel)
        let v_frontRightWheel = SCNPhysicsVehicleWheel(node: frontRightWheel)
        let v_rearLeftWheel = SCNPhysicsVehicleWheel(node: rearLeftWheel)
        let v_rearRightWheel = SCNPhysicsVehicleWheel(node: rearRightWheel)
        
        vehicle = SCNPhysicsVehicle(chassisBody: chassis.physicsBody!, wheels: [v_rearLeftWheel, v_rearRightWheel, v_frontLeftWheel, v_frontRightWheel])
        sceneView.scene.physicsWorld.addBehavior(vehicle)
        sceneView.scene.rootNode.addChildNode(chassis)
    }
    
    func setupAccelerometer() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1/60
            motionManager.startAccelerometerUpdates(to: .main) { (accelerometerData, error) in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                if let accelData = accelerometerData {
                    self.accelerometerDidChange(acceleration: accelData.acceleration)
                }
            }
        } else {
            print("Accelerometer not available")
        }
    }
    
    func accelerometerDidChange(acceleration: CMAcceleration) {
        accelerationValues[1] = filtered(currentAcceleration: accelerationValues[1], UpdatedAcceleration: acceleration.y)
        accelerationValues[0] = filtered(currentAcceleration: accelerationValues[0], UpdatedAcceleration: acceleration.x)
        if accelerationValues[0] > 0 {
            orientation = -CGFloat(accelerationValues[1])
        } else {
            orientation = CGFloat(accelerationValues[1])
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let _ = touches.first else { return }
        touched += touches.count
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touched = 0
    }
    
}

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        let conreteNode = createConcrete(planeAnchor: planeAnchor)
        node.addChildNode(conreteNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        node.enumerateChildNodes { (childNode, _) in
            childNode.removeFromParentNode()
        }
        let concreteNode = createConcrete(planeAnchor: planeAnchor)
        node.addChildNode(concreteNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let _ = anchor as? ARPlaneAnchor else {
            return
        }
        node.enumerateChildNodes { (childNode, _) in
            childNode.removeFromParentNode()
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        var engineForce: CGFloat = 0
        var brakingForce: CGFloat = 0
        vehicle.setSteeringAngle(-orientation, forWheelAt: 2)
        vehicle.setSteeringAngle(-orientation, forWheelAt: 3)
        if touched == 1 {
            engineForce = 5
        } else if touched == 2 {
            engineForce = -5
        } else if touched == 3 {
            brakingForce = 100
        } 
        vehicle.applyEngineForce(engineForce, forWheelAt: 0)
        vehicle.applyEngineForce(engineForce, forWheelAt: 1)
        vehicle.applyBrakingForce(brakingForce, forWheelAt: 0)
        vehicle.applyBrakingForce(brakingForce, forWheelAt: 1)
    }
}

extension Int {
    var degreesToRadians: CGFloat {
        return CGFloat(Double(self) * .pi/180)
    }
}

func +(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}

func filtered(currentAcceleration: Double, UpdatedAcceleration: Double) -> Double {
    let kfilteringFactor = 0.5
    return UpdatedAcceleration * kfilteringFactor + currentAcceleration * (1-kfilteringFactor)
}
