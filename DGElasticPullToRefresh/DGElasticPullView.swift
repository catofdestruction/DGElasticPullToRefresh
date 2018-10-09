//
//  DGElasticPullView.swift
//  DGElasticPullToRefreshExample
//
//  Created by XY on 2018/9/28.
//  Copyright © 2018 Danil Gontovnik. All rights reserved.
//

import UIKit

open class DGElasticPullView: UIView {
    
    public enum DGElasticPullStyle {
        case refresh
        case loadMore
    }
    
    // MARK: - DGElasticPullState
    public enum DGElasticPullState: Int {
        case stopped
        case dragging
        case animatingBounce
        case loading
        case animatingToStopped
        
        func isAnyOf(_ values: [DGElasticPullState]) -> Bool {
            return values.contains(where: { $0 == self })
        }
    }
    
    // MARK: - Vars
    fileprivate var _state: DGElasticPullState = .stopped
    fileprivate(set) var state: DGElasticPullState {
        get { return _state }
        set {
            let previousValue = state
            _state = newValue
            
            if previousValue == .dragging && newValue == .animatingBounce {
                didStartAnimation(automatically: false)
            } else if previousValue == .stopped && newValue == .animatingBounce {
                didStartAnimation(automatically: true)
            } else if newValue == .loading {
                loading()
            } else if newValue == .animatingToStopped {
                willStopAnimation()
            } else if newValue == .stopped {
                didStopAnimation(previousState: previousValue)
            }
        }
    }
    
    public var style: DGElasticPullStyle!
    public var actionHandler: (() -> Void)!
    public var observing: Bool = false {
        didSet {
            if observing {
                self.scrollView.dg_addObserver(self, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.ContentOffset)
                self.scrollView.dg_addObserver(self, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.ContentInset)
                self.scrollView.dg_addObserver(self, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.PanGestureRecognizerState)
                self.scrollView.dg_addObserver(self, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.SafeAreaInsets)
            } else {
                self.scrollView.dg_removeObserver(self, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.ContentOffset)
                self.scrollView.dg_removeObserver(self, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.ContentInset)
                self.scrollView.dg_removeObserver(self, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.PanGestureRecognizerState)
                self.scrollView.dg_removeObserver(self, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.SafeAreaInsets)
            }
        }
    }

    public var fillColor: UIColor = .clear {
        didSet {
            shapeLayer.fillColor = fillColor.cgColor
        }
    }
    
    private var scrollView: UIScrollView!
    private let shapeLayer = CAShapeLayer()
    private var displayLink: CADisplayLink!
    private var originalContentInset: UIEdgeInsets = .zero
    private var scrollViewSafeAreaInsets: UIEdgeInsets = .zero
    
    // MARK: - Views
    public var loadingView: DGElasticPullToRefreshLoadingView? {
        willSet {
            loadingView?.removeFromSuperview()
            if let newValue = newValue {
                addSubview(newValue)
            }
        }
    }
    
    private let bounceAnimationHelperView = UIView()
    private let cControlPointView = UIView()
    private let l1ControlPointView = UIView()
    private let l2ControlPointView = UIView()
    private let l3ControlPointView = UIView()
    private let r1ControlPointView = UIView()
    private let r2ControlPointView = UIView()
    private let r3ControlPointView = UIView()
    
    // MARK: - Constructors
    init() {
        super.init(frame: CGRect.zero)
        
        displayLink = CADisplayLink(target: self, selector: #selector(DGElasticPullView.displayLinkTick))
        displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
        displayLink.isPaused = true
        
        shapeLayer.backgroundColor = UIColor.clear.cgColor
        shapeLayer.fillColor = UIColor.black.cgColor
        shapeLayer.actions = ["path" : NSNull(), "position" : NSNull(), "bounds" : NSNull()]
        layer.addSublayer(shapeLayer)
        
        addSubview(bounceAnimationHelperView)
        addSubview(cControlPointView)
        addSubview(l1ControlPointView)
        addSubview(l2ControlPointView)
        addSubview(l3ControlPointView)
        addSubview(r1ControlPointView)
        addSubview(r2ControlPointView)
        addSubview(r3ControlPointView)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(DGElasticPullView.applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        observing = false
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Public
extension DGElasticPullView {
    
    func start() {
        // add start loading
        if state != .stopped {
            return
        }
        state = .animatingBounce
    }
    
    func stop() {
        // Prevent stop close animation
        if state == .animatingToStopped {
            return
        }
        state = .animatingToStopped
    }
    
    func destroy() {
        self.disassociateDisplayLink()
        self.observing = false
        self.removeFromSuperview()
    }
}

// MARK: - Layout
extension DGElasticPullView {
    
    override open func didMoveToSuperview() {
        super.didMoveToSuperview()
        if self.scrollView == nil {
            if let scrollView = self.superview as? UIScrollView {
                self.scrollView = scrollView
            } else {
                fatalError("DGElasticPullView must be subview of UIScrollView")
            }
        }
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        guard self.shouldHandleDGElasticPullView else { return }
        
        if state != .animatingBounce {
            var y: CGFloat = 0.0
            let width = scrollView.bounds.width
            let height: CGFloat = self.pullViewHeight
            if style == .refresh {
                y = -height
            } else {
                y = scrollView.contentSize.height + height
                if #available(iOS 11.0, *) {
                    y += scrollView.safeAreaInsets.bottom
                }
            }
            frame = CGRect(x: 0.0, y: y, width: width, height: height)
            if self.isStartLoading {
                cControlPointView.center = CGPoint(x: width / 2.0, y: height)
                l1ControlPointView.center = CGPoint(x: 0.0, y: height)
                l2ControlPointView.center = CGPoint(x: 0.0, y: height)
                l3ControlPointView.center = CGPoint(x: 0.0, y: height)
                r1ControlPointView.center = CGPoint(x: width, y: height)
                r2ControlPointView.center = CGPoint(x: width, y: height)
                r3ControlPointView.center = CGPoint(x: width, y: height)
            } else { // show elastic shapeLayer
                let locationX = scrollView.panGestureRecognizer.location(in: scrollView).x
                
                let waveHeight = currentWaveHeight()
                let baseHeight = bounds.height - waveHeight
                
                let minLeftX = min((locationX - width / 2.0) * 0.28, 0.0)
                let maxRightX = max(width + (locationX - width / 2.0) * 0.28, width)
                
                let leftPartWidth = locationX - minLeftX
                let rightPartWidth = maxRightX - locationX
                
                var cCenterY = baseHeight + waveHeight * 1.36
                var l1CenterY = baseHeight + waveHeight * 0.64
                var l2l3CenterY = baseHeight
                if style == .loadMore {
                    cCenterY = -cCenterY
                    l1CenterY = -l1CenterY
                    l2l3CenterY = -l2l3CenterY
                }
                cControlPointView.center = CGPoint(x: locationX , y: cCenterY)
                l1ControlPointView.center = CGPoint(x: minLeftX + leftPartWidth * 0.71, y: l1CenterY)
                l2ControlPointView.center = CGPoint(x: minLeftX + leftPartWidth * 0.44, y: l2l3CenterY)
                l3ControlPointView.center = CGPoint(x: minLeftX, y: l2l3CenterY)
                r1ControlPointView.center = CGPoint(x: maxRightX - rightPartWidth * 0.71, y: l1CenterY)
                r2ControlPointView.center = CGPoint(x: maxRightX - (rightPartWidth * 0.44), y: l2l3CenterY)
                r3ControlPointView.center = CGPoint(x: maxRightX, y: l2l3CenterY)
                
                layoutLoadingView()
            }
            shapeLayer.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
            shapeLayer.path = currentPath()
        }
    }
    
    fileprivate func layoutLoadingView() {
        guard let loadingView = self.loadingView else { return }
        let width = bounds.width
        let height: CGFloat = bounds.height
        var frame: CGRect = .zero
        let loadingViewSize: CGFloat = DGElasticPullToRefreshConstants.LoadingViewSize
        let minOriginY = (DGElasticPullToRefreshConstants.LoadingContentInset - loadingViewSize) / 2.0
        var originY: CGFloat = 0
        
        if style == .refresh {
            originY = max(min((height - loadingViewSize) / 2.0, minOriginY), 0.0)
        } else {
            originY = max(min(-(height - loadingViewSize) / 2.0, -loadingViewSize), -minOriginY - loadingViewSize)
            if state == .animatingBounce { originY = minOriginY }
        }
        
        frame = CGRect(x: (width - loadingViewSize) / 2.0, y: originY, width: loadingViewSize, height: loadingViewSize)
        loadingView.frame = state == .stopped ? .zero : frame
        loadingView.maskLayer.frame = convert(shapeLayer.frame, to: loadingView)
        loadingView.maskLayer.path = shapeLayer.path
    }
}

// MARK: - State & Animation
extension DGElasticPullView {
    
    fileprivate func didStartAnimation(automatically: Bool) {
        if automatically {
            self.loadingView?.setPullProgress(1.0)
        }
        self.loadingView?.startAnimating()
        self.scrollView.isScrollEnabled = false
        animateBounce()
    }
    
    fileprivate func loading() {
        self.actionHandler?()
    }
    
    fileprivate func willStopAnimation() {
        resetScrollViewContentInset(shouldAddObserverWhenFinished: true, animated: true) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.state = .stopped
        }
        self.scrollView.isScrollEnabled = true
    }
    
    fileprivate func didStopAnimation(previousState: DGElasticPullState) {
        self.loadingView?.stopLoading()
        if style == .loadMore && previousState == .animatingToStopped {
            let offsetY = self.scrollView.contentOffset.y + DGElasticPullToRefreshConstants.MinOffsetToPull
            self.scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: true)
        }
    }
    
    fileprivate func handleStateForUserInteraction() {
        if self.isUserStartInteracting {
            state = .dragging
            if style == .loadMore { self.alpha = 1.0 }
        } else if self.isUserStopInteracting {
            state = self.shouldStartAnimating ? .animatingBounce : .stopped
        }
        if self.isInteractionEnabled {
            let pullProgress: CGFloat = self.pullViewHeight / DGElasticPullToRefreshConstants.MinOffsetToPull
            loadingView?.setPullProgress(pullProgress)
        }
    }
    
    fileprivate func changeOffsetIfNeeded() {
        if style == .refresh {
            var contentInsetTop: CGFloat = 0
            if #available(iOS 11.0, *) {
                // correct scrollview content offset when stopped
                contentInsetTop = self.scrollViewSafeAreaInsets.top
            } else {
                contentInsetTop = scrollView.contentInset.top
            }
            if scrollView.contentOffset.y < -contentInsetTop {
                scrollView.contentOffset.y = -contentInsetTop
            }
        } else {
            if scrollView.contentOffset.y < scrollView.maximumOffset {
                scrollView.contentOffset.y = scrollView.maximumOffset
            }
        }
    }
    
    fileprivate func animateBounce() {
        if (!self.observing) { return }

        resetScrollViewContentInset(shouldAddObserverWhenFinished: false, animated: false, completion: nil)
        
        let centerY = DGElasticPullToRefreshConstants.LoadingContentInset
        let duration = 0.9
        startDisplayLink()
        scrollView.dg_removeObserver(self, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.ContentOffset)
        scrollView.dg_removeObserver(self, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.ContentInset)
        UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: 0.45, initialSpringVelocity: 0.0, options: [], animations: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.cControlPointView.center.y = centerY
            strongSelf.l1ControlPointView.center.y = centerY
            strongSelf.l2ControlPointView.center.y = centerY
            strongSelf.l3ControlPointView.center.y = centerY
            strongSelf.r1ControlPointView.center.y = centerY
            strongSelf.r2ControlPointView.center.y = centerY
            strongSelf.r3ControlPointView.center.y = centerY
            }, completion: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.stopDisplayLink()
                strongSelf.resetScrollViewContentInset(shouldAddObserverWhenFinished: true, animated: false, completion: nil)
                strongSelf.scrollView.dg_addObserver(strongSelf, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.ContentOffset)
                strongSelf.state = .loading
        })
        
        let helperViewBeginCenterY = style == .refresh ?
            originalContentInset.top + self.pullViewHeight :
            originalContentInset.bottom + self.pullViewHeight
        let helperViewEndCenterY = style == .refresh ?
            originalContentInset.top + DGElasticPullToRefreshConstants.LoadingContentInset :
            originalContentInset.bottom + DGElasticPullToRefreshConstants.LoadingContentInset
        bounceAnimationHelperView.center = CGPoint(x: 0.0, y: helperViewBeginCenterY)
        UIView.animate(withDuration: duration * 0.4, animations: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.bounceAnimationHelperView.center = CGPoint(x: 0.0, y: helperViewEndCenterY)
        }, completion: nil)
    }
    
    fileprivate func resetScrollViewContentInset(shouldAddObserverWhenFinished: Bool, animated: Bool, completion: (() -> ())?) {
        
        var contentInset = scrollView.contentInset
        if style == .refresh {
            contentInset.top = self.originalContentInset.top
            switch state {
            case .animatingBounce:
                contentInset.top += self.pullViewHeight
                if #available(iOS 11.0, *) {
                    // correct the animation bounce position
                    contentInset.top -= self.scrollViewSafeAreaInsets.top
                }
            case .loading:
                contentInset.top += DGElasticPullToRefreshConstants.LoadingContentInset
            case .animatingToStopped:
                if #available(iOS 11.0, *) {
                    // correct the scorll view content inset when animatingToStopped
                    contentInset.top -= self.scrollViewSafeAreaInsets.top
                }
            default:
                break
            }
        } else {
            switch state {
            case .animatingBounce:
                contentInset.bottom += self.pullViewHeight
            case .loading:
                contentInset.bottom -= DGElasticPullToRefreshConstants.LoadingContentInset
            case .animatingToStopped:
                contentInset.bottom = self.originalContentInset.bottom
                UIView.animate(withDuration: 0.54) { self.alpha = 0.0 }
            default:
                break
            }
        }

        scrollView.dg_removeObserver(self, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.ContentInset)
        let animationBlock = {
            self.scrollView.contentInset = contentInset
        }
        
        let completionBlock = { () -> Void in
            if shouldAddObserverWhenFinished && self.observing {
                self.scrollView.dg_addObserver(self, forKeyPath: DGElasticPullToRefreshConstants.KeyPaths.ContentInset)
            }
            completion?()
        }
        
        if animated {
            startDisplayLink()
            UIView.animate(withDuration: 0.4, animations: animationBlock, completion: { _ in
                self.stopDisplayLink()
                completionBlock()
            })
        } else {
            animationBlock()
            completionBlock()
        }
    }
}

// MARK: - CADisplayLink
extension DGElasticPullView {
    
    fileprivate func startDisplayLink() {
        displayLink.isPaused = false
    }
    
    fileprivate func stopDisplayLink() {
        displayLink.isPaused = true
    }
    
    @objc fileprivate func displayLinkTick() {
        let width = bounds.width
        var height: CGFloat = 0.0
        if style == .refresh {
            if state == .animatingBounce {
                scrollView.contentInset.top = bounceAnimationHelperView.dg_center(self.isAnimating).y
                scrollView.contentOffset.y = -scrollView.contentInset.top
                height = scrollView.contentInset.top - self.originalContentInset.top
                frame = CGRect(x: 0.0, y: -height - 1.0, width: width, height: height)
            }
        } else {
            if state == .animatingBounce {
                scrollView.contentInset.bottom = bounceAnimationHelperView.dg_center(self.isAnimating).y
                scrollView.contentOffset.y = scrollView.maximumOffset + DGElasticPullToRefreshConstants.LoadingContentInset + originalContentInset.bottom
                height = scrollView.contentInset.bottom - self.originalContentInset.bottom
                frame = CGRect(x: 0.0, y: scrollView.contentSize.height, width: width, height: height)
            }
        }
        shapeLayer.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        shapeLayer.path = currentPath()
        layoutLoadingView()
    }
    
    /**
     Has to be called when the receiver is no longer required. Otherwise the main loop holds a reference to the receiver which in turn will prevent the receiver from being deallocated.
     */
    fileprivate func disassociateDisplayLink() {
        displayLink?.invalidate()
    }
}

// MARK: - Observer
extension DGElasticPullView {
    
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard self.shouldHandleDGElasticPullView else { return }

        if keyPath == DGElasticPullToRefreshConstants.KeyPaths.ContentOffset {
            if self.isStartLoading {
                changeOffsetIfNeeded()
            } else {
                handleStateForUserInteraction()
            }
            layoutSubviews()
        } else if keyPath == DGElasticPullToRefreshConstants.KeyPaths.ContentInset {
            if let newContentInset = change?[NSKeyValueChangeKey.newKey] as? UIEdgeInsets {
                self.originalContentInset = newContentInset
            }
        } else if keyPath == DGElasticPullToRefreshConstants.KeyPaths.SafeAreaInsets {
            if let newSafeAreaInsets = change?[NSKeyValueChangeKey.newKey] as? UIEdgeInsets {
                self.originalContentInset = newSafeAreaInsets
                self.scrollViewSafeAreaInsets = newSafeAreaInsets
            }
        } else if keyPath == DGElasticPullToRefreshConstants.KeyPaths.PanGestureRecognizerState {
            handleStateForUserInteraction()
        }
    }
    
    @objc func applicationWillEnterForeground() {
        if state == .loading {
            layoutSubviews()
        }
    }
}

// MARK: - Helper
extension DGElasticPullView {
    
    fileprivate var isUserStartInteracting: Bool {
        let dragging = scrollView.isDragging &&
            !scrollView.panGestureRecognizer.state.dg_isAnyOf([.ended, .cancelled, .failed])
        return state == .stopped && dragging
    }
    
    fileprivate var isUserStopInteracting: Bool {
        let dragging = scrollView.isDragging &&
            !scrollView.panGestureRecognizer.state.dg_isAnyOf([.ended, .cancelled, .failed])
        return state == .dragging && !dragging
    }
    
    fileprivate var isInteractionEnabled: Bool {
        return state.isAnyOf([.dragging, .stopped])
    }
    
    fileprivate var shouldStartAnimating: Bool {
        return self.pullViewHeight >= DGElasticPullToRefreshConstants.MinOffsetToPull
    }
    
    fileprivate var isAnimating: Bool {
        return state.isAnyOf([.animatingBounce, .animatingToStopped])
    }
    
    fileprivate var isStartLoading: Bool {
        return state.isAnyOf([.loading, .animatingToStopped])
    }
    
    fileprivate func currentWaveHeight() -> CGFloat {
        return min(bounds.height / 3.0 * 1.6, DGElasticPullToRefreshConstants.WaveMaxHeight)
    }
    
    fileprivate func currentPath() -> CGPath {
        let width: CGFloat = self.scrollView?.bounds.width ?? 0.0
        let bezierPath = UIBezierPath()
        let animating = self.isAnimating
        bezierPath.move(to: CGPoint(x: 0.0, y: 0.0))
        bezierPath.addLine(to: CGPoint(x: 0.0, y: l3ControlPointView.dg_center(animating).y))
        bezierPath.addCurve(to: l1ControlPointView.dg_center(animating),
                            controlPoint1: l3ControlPointView.dg_center(animating),
                            controlPoint2: l2ControlPointView.dg_center(animating))
        bezierPath.addCurve(to: r1ControlPointView.dg_center(animating),
                            controlPoint1: cControlPointView.dg_center(animating),
                            controlPoint2: r1ControlPointView.dg_center(animating))
        bezierPath.addCurve(to: r3ControlPointView.dg_center(animating),
                            controlPoint1: r1ControlPointView.dg_center(animating),
                            controlPoint2: r2ControlPointView.dg_center(animating))
        bezierPath.addLine(to: CGPoint(x: width, y: 0.0))
        bezierPath.close()
        return bezierPath.cgPath
    }
    
    private var pullViewHeight: CGFloat {
        if style == .refresh {
            return max(-scrollView.contentOffset.y - self.originalContentInset.top, 0)
        } else {
            var maximumOffset = scrollView.maximumOffset
            if #available(iOS 11.0, *) {
                maximumOffset += scrollView.safeAreaInsets.bottom
            } else {
                maximumOffset += scrollView.contentInset.bottom
            }
            return max(scrollView.contentOffset.y - maximumOffset, 0)
        }
    }
    
    fileprivate var shouldHandleDGElasticPullView: Bool {
        return style == .refresh ?
            scrollView.contentOffset.y < 1 :
            scrollView.contentOffset.y > scrollView.maximumOffset
    }
}
