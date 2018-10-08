/*

The MIT License (MIT)

Copyright (c) 2015 Danil Gontovnik

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

import UIKit
import ObjectiveC

// MARK: - (UIScrollView) Extension
public extension UIScrollView {
    
    // MARK: - Vars
    fileprivate struct dg_associatedKeys {
        static var pullToRefreshView = "pullToRefreshView"
        static var pullToLoadMoreView = "pullToLoadMoreView"
    }

    fileprivate var pullToRefreshView: DGElasticPullView? {
        get {
            return objc_getAssociatedObject(self, &dg_associatedKeys.pullToRefreshView) as? DGElasticPullView
        }
        set {
            objc_setAssociatedObject(self, &dg_associatedKeys.pullToRefreshView, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    fileprivate var pullToLoadMoreView: DGElasticPullView? {
        get {
            return objc_getAssociatedObject(self, &dg_associatedKeys.pullToLoadMoreView) as? DGElasticPullView
        }
        set {
            objc_setAssociatedObject(self, &dg_associatedKeys.pullToLoadMoreView, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public var maximumOffset: CGFloat {
        guard self.contentSize.height > 0 else { return self.bounds.height }
        return self.contentSize.height - self.bounds.height
    }
    
    // MARK: - Methods (Public)
    public func dg_addPullToRefresh(loadingView: DGElasticPullToRefreshLoadingView? = DGElasticPullToRefreshLoadingViewCircle(),
                                    actionHandler: @escaping () -> Void) {
        dg_addElasticPullView(style: .refresh, loadingView: loadingView, actionHandler: actionHandler)
    }
    
    public func dg_addPullToLoadMore(loadingView: DGElasticPullToRefreshLoadingView? = DGElasticPullToRefreshLoadingViewCircle(),
                                     actionHandler: @escaping () -> Void) {
        dg_addElasticPullView(style: .loadMore, loadingView: loadingView, actionHandler: actionHandler)
    }
    
    public func dg_removePullToRefresh() {
        pullToRefreshView?.destroy()
    }
    
    public func dg_removePullToLoadMore() {
        pullToLoadMoreView?.destroy()
    }
    
    public func dg_startRefreshing() {
        pullToRefreshView?.start()
    }
    
    public func dg_stopRefreshing() {
        pullToRefreshView?.stop()
    }

    public func dg_stopLoading() {
        pullToLoadMoreView?.stop()
    }
    
    public func dg_setPullToRefreshFillColor(_ color: UIColor) {
        pullToRefreshView?.fillColor = color
    }
    
    public func dg_setPullToLoadMoreFillColor(_ color: UIColor) {
        pullToLoadMoreView?.fillColor = color
    }
    
    public func dg_setPullToRefreshBackgroundColor(_ color: UIColor) {
        pullToRefreshView?.backgroundColor = color
    }
    
    public func dg_setPullToLoadMoreBackgroundColor(_ color: UIColor) {
        pullToLoadMoreView?.backgroundColor = color
    }
    
    public func dg_setPullToRefreshLoadingViewTintColor(_ color: UIColor) {
        pullToRefreshView?.loadingView?.tintColor = color
    }
    
    public func dg_setPullToLoadMoreLoadingViewTintColor(_ color: UIColor) {
        pullToLoadMoreView?.loadingView?.tintColor = color
    }
    
    // MARK: Methods (Private)
    fileprivate func dg_addElasticPullView(style: DGElasticPullView.DGElasticPullStyle,
                                           loadingView: DGElasticPullToRefreshLoadingView?,
                                           actionHandler: @escaping () -> Void) {
        isMultipleTouchEnabled = false
        panGestureRecognizer.maximumNumberOfTouches = 1
        
        let elasticPullView = DGElasticPullView()
        elasticPullView.style = style
        elasticPullView.actionHandler = actionHandler
        elasticPullView.loadingView = loadingView
        elasticPullView.backgroundColor = self.backgroundColor
        if style == .refresh {
            self.pullToRefreshView = elasticPullView
        } else {
            self.pullToLoadMoreView = elasticPullView
        }
        addSubview(elasticPullView)
        elasticPullView.observing = true
    }
}

// MARK: - (NSObject) Extension
public extension NSObject {
    
    // MARK: - Vars
    fileprivate struct dg_associatedKeys {
        static var observersArray = "observers"
    }
    
    fileprivate var dg_observers: [[String : NSObject]] {
        get {
            if let observers = objc_getAssociatedObject(self, &dg_associatedKeys.observersArray) as? [[String : NSObject]] {
                return observers
            } else {
                let observers = [[String : NSObject]]()
                self.dg_observers = observers
                return observers
            }
        } set {
            objc_setAssociatedObject(self, &dg_associatedKeys.observersArray, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - Methods
    public func dg_addObserver(_ observer: NSObject, forKeyPath keyPath: String) {
        let observerInfo = [keyPath : observer]
        
        if dg_observers.index(where: { $0 == observerInfo }) == nil {
            dg_observers.append(observerInfo)
            addObserver(observer, forKeyPath: keyPath, options: .new, context: nil)
        }
    }
    
    public func dg_removeObserver(_ observer: NSObject, forKeyPath keyPath: String) {
        let observerInfo = [keyPath : observer]
        
        if let index = dg_observers.index(where: { $0 == observerInfo}) {
            dg_observers.remove(at: index)
            removeObserver(observer, forKeyPath: keyPath)
        }
    }
}

// MARK: - (UIView) Extension
public extension UIView {
    func dg_center(_ usePresentationLayerIfPossible: Bool) -> CGPoint {
        if usePresentationLayerIfPossible, let presentationLayer = layer.presentation() {
            // Position can be used as a center, because anchorPoint is (0.5, 0.5)
            return presentationLayer.position
        }
        return center
    }
}

// MARK: - (UIPanGestureRecognizer) Extension
public extension UIPanGestureRecognizer {
    func dg_resign() {
        isEnabled = false
        isEnabled = true
    }
}

// MARK: - (UIGestureRecognizerState) Extension
public extension UIGestureRecognizer.State {
    func dg_isAnyOf(_ values: [UIGestureRecognizer.State]) -> Bool {
        return values.contains(where: { $0 == self })
    }
}
