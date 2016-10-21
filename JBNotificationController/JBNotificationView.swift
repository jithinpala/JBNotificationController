//
//  JBNotificationView.swift
//  JBNotificationCenter
//
//  Created by Jithin B on 14/10/16.
//  Copyright © 2016 Jithin B. All rights reserved.
//

import UIKit
import Foundation


private let NOTIFICATION_VIEW_FRAME_HEIGHT              = 64
private let LABEL_TITLE_FONT_SIZE                       = 14.0
private let LABEL_MESSAGE_FONT_SIZE                     = 13.0
private let IMAGE_VIEW_ICON_CORNER_RADIUS               = 3
private let LABEL_MESSAGE_FRAME_HEIGHT                  = 35
private let NOTIFICATION_VIEW_SHOWING_ANIMATION_TIME    = 0.5
private let NOTIFICATION_VIEW_SHOWING_DURATION          = 5.0
private let IMAGE_VIEW_ICON_FRAME                       = CGRectMake(15.0, 8.0, 20.0, 20.0)
private let LABEL_TITLE_FRAME                           = CGRectMake(45.0, 3.0, UIScreen.mainScreen().bounds.size.width - 45.0, 26.0)
private let LABEL_MESSAGE_FRAME                         = CGRectMake(45.0, 25.0, UIScreen.mainScreen().bounds.size.width - 45.0,CGFloat(LABEL_MESSAGE_FRAME_HEIGHT))
private let DRAG_HANDLER_FRAME                          = CGRectMake((UIScreen.mainScreen().bounds.size.width / 2) - 20,CGFloat(NOTIFICATION_VIEW_FRAME_HEIGHT) - 6,40,3)
private let LABEL_TITLE_FRAME_WITHOUT_IMAGE             = CGRectMake(5.0, 3.0, UIScreen.mainScreen().bounds.size.width - 5, 26.0)
private let LABEL_MESSAGE_FRAME_WITHOUT_IMAGE           = CGRectMake(5.0, 25.0, UIScreen.mainScreen().bounds.size.width - 5, CGFloat(LABEL_MESSAGE_FRAME_HEIGHT))
typealias notificationCompletionHandlerBlock            = (results: String) -> Void

class JBNotificationView: UIToolbar, UIGestureRecognizerDelegate {
    
    var imageIcon:                      UIImageView!
    var labelTitle:                     UILabel!
    var labelMessage:                   UILabel!
    var timerAutoHide                   = NSTimer()
    var dragHandler:                    UIView!
    var isDragging                      = Bool()
    var isVerticalPan:                  Bool!
    var completionBlock:                notificationCompletionHandlerBlock!
    var animator: UIDynamicAnimator     = UIDynamicAnimator()
    var gravityAnimation: Bool          = true
    
    class var sharedInstance: JBNotificationView {
        struct Static {
            static var onceToken: dispatch_once_t = 0
            static var instance: JBNotificationView? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.instance = JBNotificationView()
        }
        return Static.instance!
    }
    
    init() {
        super.init(frame: CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, CGFloat(NOTIFICATION_VIEW_FRAME_HEIGHT)))
        self.setUpNotificationUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUpNotificationUI() {
        
        if (Double(UIDevice.currentDevice().systemVersion) >= 7.0) {
            self.barTintColor = nil
            self.translucent  = true
            self.barStyle     = UIBarStyle.Black
        } else {
            self.tintColor    = UIColor(red: 5, green: 31, blue: 75, alpha: 1)
        }
        
        self.layer.zPosition  = CGFloat(FLT_MAX)//CGFloat.max
        self.backgroundColor  = UIColor.clearColor()
        self.multipleTouchEnabled = false
        self.exclusiveTouch =   true
        self.frame = CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, CGFloat(NOTIFICATION_VIEW_FRAME_HEIGHT))
        
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1) {
            let visualEffect = UIBlurEffect(style: .Light)
            let blurView = UIVisualEffectView(effect: visualEffect)
            blurView.frame = self.bounds
            self.addSubview(blurView)
        }
        
        
        //***** Add image icon *****//
        if (imageIcon == nil) {
            imageIcon = UIImageView()
        }
        imageIcon.frame = IMAGE_VIEW_ICON_FRAME
        imageIcon.contentMode = UIViewContentMode.ScaleAspectFill
        imageIcon.layer.cornerRadius = CGFloat(IMAGE_VIEW_ICON_CORNER_RADIUS)
        imageIcon.clipsToBounds = true
        if ((imageIcon.superview) == nil) {
            self.addSubview(imageIcon)
        }
        
        
        //***** Add Title label *****//
        if (labelTitle == nil) {
            labelTitle = UILabel()
        }
        labelTitle.frame = LABEL_TITLE_FRAME
        labelTitle.textColor = UIColor.whiteColor()
        labelTitle.font = UIFont(name: "HelveticaNeue-Bold", size: CGFloat(LABEL_TITLE_FONT_SIZE))
        labelTitle.numberOfLines = 1
        if ((labelTitle.superview) == nil ) {
            self.addSubview(labelTitle)
        }
        
        //***** Add Message label *****//
        if (labelMessage == nil) {
            labelMessage = UILabel()
        }
        labelMessage.frame = LABEL_MESSAGE_FRAME
        labelMessage.textColor = UIColor.whiteColor()
        labelMessage.font = UIFont(name: "HelveticaNeue", size: CGFloat(LABEL_MESSAGE_FONT_SIZE))
        labelMessage.numberOfLines = 2
        labelMessage.lineBreakMode = NSLineBreakMode.ByTruncatingTail
        if ((labelMessage.superview) == nil) {
            self.addSubview(labelMessage)
        }
        
        self.fixLabelMessageSize()
        
        //***** Add Drag handler *****//
        if (dragHandler == nil) {
            dragHandler = UIView()
            self.addSubview(dragHandler)
        }
        dragHandler.frame = DRAG_HANDLER_FRAME
        dragHandler.layer.cornerRadius = 2
        dragHandler.backgroundColor = UIColor.lightGrayColor()
        if ((dragHandler.superview) == nil) {
            self.addSubview(dragHandler)
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(JBNotificationView.notificationViewDidTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        self.addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(JBNotificationView.notificationViewDidPan(_:)))
        panGesture.delegate = self
        self.addGestureRecognizer(panGesture)
        
        
        
    }
    
    //MARK:- NotificationView Methods
    
    func showNotificationView(image: UIImage?, titleLabel title: String?, messageLabel message: String?) {
        self.showNotificationView(image, titleLabel: title, messageLabel: message, isAutoHide: true, completionHandler: nil)
    }
    
    func showNotificationView(image: UIImage?, titleLabel title: String?, messageLabel message: String?, isAutoHide: Bool) {
        self.showNotificationView(image, titleLabel: title, messageLabel: message, isAutoHide: isAutoHide, completionHandler: nil)
    }
    
    func showNotificationView(image: UIImage?, titleLabel title: String?, messageLabel message: String?, isAutoHide: Bool, completionHandler: notificationCompletionHandlerBlock?) {
        
        //***** Invalidate autoTimer *****//
        timerAutoHide.invalidate()
        if (isAutoHide) {
            timerAutoHide = NSTimer.scheduledTimerWithTimeInterval(NOTIFICATION_VIEW_SHOWING_DURATION, target: self, selector: #selector(JBNotificationView.autoHideTimerAction), userInfo: nil, repeats: false)
        }
        //***** Call touch handler *****//
        /***** Check completion handler *****/
        if (completionHandler != nil) {
            completionBlock = completionHandler
        }else {
            completionBlock = nil
        }
        
        
        //***** Show Image *****//
        if image != nil {
            imageIcon.image = image
        } else {
            imageIcon.image = nil
            labelTitle.frame = LABEL_TITLE_FRAME_WITHOUT_IMAGE
            labelMessage.frame = LABEL_MESSAGE_FRAME_WITHOUT_IMAGE
        }
        
        //***** Show Title Label *****//
        if title != nil {
            labelTitle.text = title
        } else {
            labelTitle.text = ""
        }
        
        //***** Show Message Label *****//
        if message != nil {
            labelMessage.text = message
        } else {
            labelMessage.text = ""
        }
        
        self.fixLabelMessageSize()
        
        //***** Prepare frame *****//
        var frame = self.frame
        frame.origin.y = -frame.size.height
        self.frame = frame
        
        UIApplication.sharedApplication().keyWindow?.windowLevel = UIWindowLevelStatusBar
        UIApplication.sharedApplication().keyWindow?.addSubview(self)
        
        if gravityAnimation {
            animator = UIDynamicAnimator(referenceView: UIApplication.sharedApplication().keyWindow!)
            let gravity = UIGravityBehavior(items: [self])
            animator.addBehavior(gravity)
            let collision = UICollisionBehavior(items: [self])
            collision.translatesReferenceBoundsIntoBoundary = false
            collision.addBoundaryWithIdentifier("notificationEnd", fromPoint: CGPointMake(0, NOTIFICATION_VIEW_FRAME_HEIGHT.toFloat()), toPoint: CGPointMake(UIScreen.mainScreen().bounds.size.width, NOTIFICATION_VIEW_FRAME_HEIGHT.toFloat()))
            animator.addBehavior(collision)
            let elasticityBehavior = UIDynamicItemBehavior.init(items: [self])
            elasticityBehavior.elasticity = 0.3
            animator.addBehavior(elasticityBehavior)
            
        } else {
            UIView.animateWithDuration(NOTIFICATION_VIEW_SHOWING_ANIMATION_TIME, delay: 0.0, options: .CurveEaseOut, animations: {
                var frame = self.frame
                frame.origin.y = frame.origin.y + frame.size.height
                self.frame = frame
                }, completion: nil)
        }
        
        
    }
    
    
    /*******************************************************************************************
     * Description      :  Time action
     * Parameters       :  timer: NSTimer
     * Return           :  Nil
     *******************************************************************************************/
    func autoHideTimerAction() {
        self.hideNotificationViewOnComplete(nil)
    }
    
    /*******************************************************************************************
     * Description      :  Hide notificationview
     * Parameters       :  completionHandler
     * Return           :  Nil
     *******************************************************************************************/
    func hideNotificationViewOnComplete(completionHandler: notificationCompletionHandlerBlock?) {
        
        
        //***** check gravity animation *****//
        if gravityAnimation {
            self.animator.removeAllBehaviors()
        }
        //***** check isDragging *****//
        if (!isDragging) {
            UIView.animateWithDuration(NOTIFICATION_VIEW_SHOWING_ANIMATION_TIME, delay: 0.0, options: .CurveEaseOut, animations: {
                var frame = self.frame;
                frame.origin.y = frame.origin.y - frame.size.height
                self.frame = frame;
            }) { (finish: Bool) in
                self.removeFromSuperview()
                UIApplication.sharedApplication().keyWindow?.windowLevel = UIWindowLevelNormal
                self.timerAutoHide.invalidate()
                // Call completionHandler
                if (self.completionBlock != nil) {
                    self.completionBlock(results: "notification tap completed")
                }
            }
        } else {
            timerAutoHide.invalidate()
        }
        
    }
    
    /*******************************************************************************************
     * Description      :  Notification tap event
     * Parameters       :  sender: UITapGestureRecognizer
     * Return           :  Nil
     *******************************************************************************************/
    func notificationViewDidTap(sender: UITapGestureRecognizer? = nil) {
        timerAutoHide.invalidate()
        self.hideNotificationViewOnComplete(nil)
        if ((sender?.isKindOfClass(UITapGestureRecognizer)) != nil) {
            if completionBlock != nil {
                completionBlock(results: "notification tap completed")
            }
        }
    }
    
    /*******************************************************************************************
     * Description      :  Notification tap event
     * Parameters       :  sender: UITapGestureRecognizer
     * Return           :  Nil
     *******************************************************************************************/
    func notificationViewDidPan(sender: UIPanGestureRecognizer? = nil) {
        
        if (sender?.state == UIGestureRecognizerState.Ended) {
            isDragging = false
            if self.frame.origin.y < 0 || (timerAutoHide.valid == false) {
                self.autoHideTimerAction()
            }
        } else if (sender?.state == UIGestureRecognizerState.Began) {
            isDragging = true
        } else if (sender?.state == UIGestureRecognizerState.Changed) {
            let translation = sender?.translationInView(self.superview)
            //***** Figure out where the user is trying to drag the view *****//
            let newCenter   = CGPointMake(CGFloat((self.superview?.bounds.size.width)! / 2), (sender?.view?.center.y)! + (translation?.y)!)
            //***** See if the new position is in bounds *****//
            if (Int(newCenter.y) >= (-1 * NOTIFICATION_VIEW_FRAME_HEIGHT / 2) && Int(newCenter.y) <= NOTIFICATION_VIEW_FRAME_HEIGHT / 2) {
                sender?.view?.center = newCenter
                sender?.setTranslation(CGPointZero, inView: self.superview)
                
            }
        }
        
    }
    
    
    //MARK:- Helper
    func fixLabelMessageSize() {
        
        let size = labelMessage.sizeThatFits(CGSizeMake(UIScreen.mainScreen().bounds.size.width - 45, CGFloat(MAXFLOAT)))
        var frame = labelMessage.frame
        frame.size.height = Int(size.height) > LABEL_MESSAGE_FRAME_HEIGHT ? CGFloat(LABEL_MESSAGE_FRAME_HEIGHT) : size.height
        labelMessage.frame = frame
        
    }
    
    //MARK:- GESTURE DELEGATE
    override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if (gestureRecognizer.isKindOfClass(UIPanGestureRecognizer)) {
            let panGestureRecognizer = gestureRecognizer as! UIPanGestureRecognizer
            let translation = panGestureRecognizer.translationInView(self)
            isVerticalPan = fabs(translation.y) > fabs(translation.x)
            return true
        } else if (gestureRecognizer.isKindOfClass(UITapGestureRecognizer)) {
            let tapGestureRecognizer = gestureRecognizer as! UITapGestureRecognizer
            self.notificationViewDidTap(tapGestureRecognizer)
            return false
        } else {
            return false
        }
    }
    
    
}

extension Int {
    func toFloat() -> CGFloat {
        return CGFloat(self)
    }
}
