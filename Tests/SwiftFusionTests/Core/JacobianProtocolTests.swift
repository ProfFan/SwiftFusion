import Foundation
import XCTest

@testable import SwiftFusion

class JacobianProtocolTests: XCTestCase {
  static var allTests = [
    ("testJacobianPose2Identity", testJacobianPose2Identity),
    ("testJacobianPose2Trivial", testJacobianPose2Trivial),
  ]

  /// tests a simple identity Jacobian for Pose2
  func testJacobianPose2Identity() {
    let wT1 = Pose2(1, 0, 3.1415926 / 2.0), wT2 = Pose2(1, 0, 3.1415926 / 2.0)
    let pts: [Pose2] = [wT1, wT2]

    let f: @differentiable(_ pts: [Pose2]) -> Double = { (_ pts: [Pose2]) -> Double in
      let d = between(pts[0], pts[1])

      return d.rot_.theta * d.rot_.theta + d.t_.x * d.t_.x + d.t_.y * d.t_.y
    }

    let j = jacobian(of: f, at: pts)
    // print("J(f) = \(j[0].base as AnyObject)")
    for item in j[0] {
      XCTAssertEqual(item, Pose2.TangentVector.zero)
    }
  }

  func testJacobianPose2Trivial() {
    // Values taken from GTSAM `testPose2.cpp`
    let wT1 = Pose2(1, 2, .pi/2.0), wT2 = Pose2(-1, 4, .pi)
    let pts: [Pose2] = [wT1, wT2]

    let f: @differentiable(_ pts: [Pose2]) -> Pose2 = { (_ pts: [Pose2]) -> Pose2 in
      let d = between(pts[0], pts[1])

      return d
    }

    XCTAssertEqual(f(pts), Pose2(2, 2, .pi/2))
    let j = jacobian(of: f, at: pts)
    
    /// expected is a 3x2 matrix, values in Pose2's tangent space
    /// In GTSAM, it corresponds to
    /// ```
    /// Matrix expectedH1 = (Matrix(3,3) <<
    ///     0.0,-1.0,-2.0,
    ///     1.0, 0.0,-2.0,
    ///     0.0, 0.0,-1.0
    /// ).finished();
    /// ```
    /// In current SwiftFusion, it is
    /// ```
    /// [0.0, -1.0,  2.0]
    /// [1.0,  0.0, -2.0]
    /// [0.0,  0.0, -1.0]
    /// ```
    /// ```
    /// Matrix expectedH2 = (Matrix(3,3) <<
    ///      1.0, 0.0, 0.0,
    ///      0.0, 1.0, 0.0,
    ///      0.0, 0.0, 1.0
    /// ).finished();
    /// ```
    /// In current SwiftFusion, it is
    /// ```
    ///  0.0, 1.0, 0.0
    /// -1.0, 0.0, 0.0
    ///  0.0, 0.0, 1.0
    /// ```
    let expected: [Array<Pose2>.TangentVector] = [
      [Pose2.TangentVector(t_: Point2.TangentVector(x: 0, y: -1.0), rot_: 2.0), Pose2.TangentVector(t_: Point2.TangentVector(x: 0, y: 1.0), rot_: 0.0)],
      [Pose2.TangentVector(t_: Point2.TangentVector(x: 1.0, y: 0), rot_: -2.0), Pose2.TangentVector(t_: Point2.TangentVector(x: -1.0, y: 0), rot_: 0.0)],
      [Pose2.TangentVector(t_: Point2.TangentVector(x: 0.0, y: 0.0), rot_: -1.0), Pose2.TangentVector(t_: Point2.TangentVector(x: 0.0, y: 0.0), rot_: 1.0)]
    ]
    
    print(Pose2.TangentVector.basisVectors())
    for i in 0..<3 {
      print(j[i][1].recursivelyAllKeyPaths(to:Double.self).map { j[i][1][keyPath: $0] })
    }
    // TODO(fan): Find a better way to do approximate comparison
    XCTAssert(
      expected.recursivelyAllKeyPaths(to:Double.self)
        .map {j[keyPath: $0] - expected[keyPath: $0]}
        .reduce(0.0, {$0 + abs($1)}) < 1e-10
    )
  }
  
  /// tests the Jacobian of a 2D function
  func testJacobian2D() {
    let p1 = Point2(0, 1), p2 = Point2(0,0), p3 = Point2(0,0);
    let pts: [Point2] = [p1, p2, p3]

    // TODO(fan): Find a better way to do this
    // If we remove the type we will have:
    // a '@differentiable' function can only be formed from
    // a reference to a 'func' or a literal closure
    let f: @differentiable (_ pts: [Point2]) -> Point2 = { pts in
      let d = pts[1] - pts[0]

      return d
    }

    let j = jacobian(of: f, at: pts)
    
    // Forward-mode (JVP)
    // Does not work at the moment
//     let (_, d) = valueWithDifferential(at: pts, in: f)
//     print("g(f) = \(d as AnyObject)")

    // print("Point2.TangentVector.basisVectors() = \(Point2.TangentVector.basisVectors() as AnyObject)")
    
    /* Example output:
      J(f) = [
      [ [-1.0, 0.0],
        [1.0, 0.0],
        [0.0, 0.0] ]
      [ [0.0, -1.0],
        [0.0, 1.0],
        [0.0, 0.0] ]
      ]
     So this is 2x3 but the data type is Point2.TangentVector.
     In "normal" Jacobian notation, we should have a 2x6.
     [ [-1.0, 0.0, 1.0, 0.0, 0.0, 0.0]
       [0.0, -1.0, 0.0, 1.0, 0.0, 0.0] ]
    */
    
    let expected: [Array<Point2>.TangentVector] = [
        [Point2.TangentVector(x: -1.0, y: 0.0), Point2.TangentVector(x: 1.0, y: 0.0), Point2.TangentVector(x: 0.0, y: 0.0)],
        [Point2.TangentVector(x: 0.0, y: -1.0), Point2.TangentVector(x: 0.0, y: 1.0), Point2.TangentVector(x: 0.0, y: 0.0)]
    ]
    /*
    print("J_f(p) = [")
    for c in j {
      print("[")
      for r in c {
        print(r.recursivelyAllKeyPaths(to:Double.self).map {r[keyPath: $0]})
        print(",")
      }
      print("]")
    }
    print("]")
    */
    XCTAssertEqual(expected, j)
  }
  
// Removed as forward mode is not in CI
//  /// Simplest forward mode autodiff
//  /// This works but more complicated examples fail
//  func testForwardDiff() {
//
//    let func_to_diff: @differentiable (_ x: Float) -> Float = { x in
//      return x
//    }
//    let (y, differential) = valueWithDifferential(at: 4, in: func_to_diff)
//    XCTAssertEqual(4, y)
//    XCTAssertEqual(1, differential(1))
//  }
    
  func testMiscScratchPad() {
    let f: @differentiable (_ x: [Point2]) -> Point2 = { x in
      return x[1] - x[0]
    }
    let pts = [Point2(0,0), Point2(1,1)]
    print(jacobian(of:f, at: pts))
  }
}
