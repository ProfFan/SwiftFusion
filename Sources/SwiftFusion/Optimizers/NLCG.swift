// Copyright 2019 The SwiftFusion Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// Non-Linear Conjugate Gradient (NLCG) optimizer.
///
/// An optimizer that implements NLCG second order optimizer
/// It is generic over all differentiable models that is `KeyPathIterable`
/// This loosely follows `Nocedal06book_numericalOptimization`, page 121
public class NLCG<Model: Differentiable & KeyPathIterable>
  where Model.TangentVector: VectorProtocol & ElementaryFunctions & KeyPathIterable,
Model.TangentVector.VectorSpaceScalar == Double {
  public typealias Model = Model
  /// The set of steps taken.
  public var step: Int = 0
  public var precision: Double = 1e-10
  public var max_iteration: Int = 400
  
  public init(
    for _: __shared Model, precision p: Double = 1e-10, max_iteration maxiter: Int = 400) {
    
    precision = p
    max_iteration = maxiter
  }
  
  func dot<T: Differentiable>(_ for: T, _ a: T.TangentVector, _ b: T.TangentVector) -> Double where T.TangentVector: KeyPathIterable {
    a.recursivelyAllWritableKeyPaths(to: Double.self).map { a[keyPath: $0] * b[keyPath: $0] }.reduce(0.0, {$0 + $1})
  }
  
  public func optimize(loss f: @differentiable @escaping (Model) -> Model.TangentVector.VectorSpaceScalar, model x_in: inout Model) {
    step = 0
    
    let x_0 = x_in
    
    let dx_0 = gradient(at: x_0, in: f)
    
    let a_0 = 1.0
    // a_0 = argmin(f(x_0+a*dx_0))
    
    var x_1 = x_0
    x_1.move(along: dx_0.scaled(by: a_0))
    
    var x_n = x_1
    var dx_n_1 = dx_0
    var s = dx_0
    
    while step < max_iteration {
      let dx = gradient(at: x_n, in: f)
      
      // Fletcher-Reeves
      // TODO: `.dot` needs to be implemented by iterating over keyPath
      let beta: Double = dot(x_in, dx, dx) / dot(x_in, dx_n_1, dx_n_1)
      
      // s_n = \delta x_n + \beta_n s_{n-1}
      s = dx + s.scaled(by: beta)
      
      // Line search
      // let a = argmin(f(x_n + a * s))
      
      // TODO(fan): Replace this with a *proper* line search :-(
      var a = 0.0
      
      var min = 1.0e20
      for i in -100..<100 {
        let a_n = 0.01 * Double(i)
        var x = x_n
        x.move(along: (s.scaled(by: a_n)).withDerivative({ $0.scale(by: a_n) }))
        
        let f_n = f(x)
        
        // print("a = \(a_n), current_los = \(f_n)")
        if min > f_n {
          min = f_n
          a = a_n
        }
      }
      //      /// This is an attempt to *chain* optimizers to do the line search which failed
      //      /// it appears to be hard to differentiate on operations on the tangent vectors
      //      let f_a: @differentiable (_ a: Double) -> Model.TangentVector.VectorSpaceScalar = { a in
      //        var x = x_n
      //        x.move(along: (s.scaled(by: a)).withDerivative({ $0.scale(by: a) }))
      //
      //        return f(x)
      //      }
      //      var a = 1.0
      //
      //      let sgd = SGD(for: a)
      //      for _ in 0..<100 {
      //        let 𝛁loss = gradient(at: a, in: f_a)
      //        sgd.update(&a, along: 𝛁loss)
      //      }
      let delta = s.scaled(by: a)
      
      x_n.move(along: delta) // update the estimate
      
      // Exit when delta is too small
      if dot(x_n, delta, delta) < precision {
        break
      }
      
      dx_n_1 = dx
      step += 1
    }
    
    // Finally, assign back to the value passed in
    x_in = x_n
  }
}