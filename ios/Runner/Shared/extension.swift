//
//  extension.swift
//  Runner
//
//  Created by 정민호 on 12/11/23.
//

import SceneKit


extension SCNVector3 {
    static func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
    }
    
    var length: Float {
        return sqrt(x * x + y * y + z * z)
    }

    var simdTransform: matrix_float4x4 {
        return matrix_float4x4(columns: (
            simd_float4(x, 0, 0, 0),
            simd_float4(0, y, 0, 0),
            simd_float4(0, 0, z, 0),
            simd_float4(0, 0, 0, 1)
        ))
    }
    func normalized() -> SCNVector3 {
        let length = sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
        guard length != 0 else {
            return SCNVector3(0, 0, 0)
        }
        return SCNVector3(self.x / length, self.y / length, self.z / length)
    }
}