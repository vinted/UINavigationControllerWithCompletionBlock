//
//  UINavigationController+CompletionBlock.m
//  NavigationControllerWithBlocks
//
//  Created by Jerome Morissard on 4/26/14.
//  Copyright (c) 2014 Jerome Morissard. All rights reserved.
//

#import "UINavigationController+CompletionBlock.h"
#import "JRSwizzle.h"
#import <objc/runtime.h>

@implementation UINavigationController (CompletionBlock)

#pragma mark - Swizzled methods

+ (void)activateSwizzling
{
 	[UINavigationController jr_swizzleMethod:@selector(setDelegate:)
                                  withMethod:@selector(_swizzleSetDelegate:) error:nil];
    [UINavigationController jr_swizzleMethod:@selector(pushViewController:animated:)
                                  withMethod:@selector(_swizzlePushViewController:animated:) error:nil];
    [UINavigationController jr_swizzleMethod:@selector(popViewControllerAnimated:)
                                  withMethod:@selector(_swizzlePopViewControllerAnimated:) error:nil];
}

- (void)_swizzleSetDelegate:(id<UINavigationControllerDelegate>)delegate
{
    if (self != delegate) {
        [self setNextDelegate:delegate];
    }
 	[UINavigationController jr_swizzleMethod:@selector(setDelegate:) withMethod:@selector(_swizzleSetDelegate:) error:nil];
    [self setDelegate:self];
    [UINavigationController jr_swizzleMethod:@selector(setDelegate:) withMethod:@selector(_swizzleSetDelegate:) error:nil];
}

- (void)_swizzlePushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [self pushViewController:viewController animated:animated withCompletionBlock:NULL];
}

- (UIViewController *)_swizzlePopViewControllerAnimated:(BOOL)animated
{
    UIViewController *vc = [self popViewControllerAnimated:animated withCompletionBlock:NULL];
    return vc;
}

#pragma mark - accessories

- (id<UINavigationControllerDelegate>)nextDelegate
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setNextDelegate:(id<UINavigationControllerDelegate>)nextDelegate
{
    objc_setAssociatedObject(self, @selector(nextDelegate),nextDelegate, OBJC_ASSOCIATION_ASSIGN);
}

- (NSArray *)actionsQueue
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setActionsQueue:(NSArray *)actions
{
    objc_setAssociatedObject(self, @selector(actionsQueue),actions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UINavigationControllerState)currentAction
{
    return [objc_getAssociatedObject(self, _cmd) intValue];
}

- (void)setCurrentAction:(UINavigationControllerState)action
{
    if (action == UINavigationControllerStateNeutral) {
        [self setTargetedViewController:nil];
    }
    objc_setAssociatedObject(self, @selector(currentAction), @(action), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (JMONavCompletionBlock)completionBlock
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setCompletionBlock:(JMONavCompletionBlock)completionBlock
{
    objc_setAssociatedObject(self, @selector(completionBlock), completionBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (UIViewController *)targetedViewController
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setTargetedViewController:(UIViewController *)vc
{
    objc_setAssociatedObject(self, @selector(targetedViewController), vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - UINavigationController delegate

// Called when the navigation controller shows a new top view controller via a push, pop or setting of the view controller stack.
- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    //Call nextDelegate
    if([[self nextDelegate] respondsToSelector:@selector(navigationController:willShowViewController:animated:)]) {
        [[self nextDelegate] navigationController:navigationController willShowViewController:viewController animated:animated];
    }
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (viewController == [self targetedViewController]) {
        //if we are poping to root, continue
        if ([self currentAction] == UINavigationControllerStatePopToRootInProgress) {
            [self popViewControllerAnimated:animated withCompletionBlock:NULL];
        } else {
            
            //if we have push or pop something, use completionBlock and finish
            [self consumeCompletionBlock];
            [self setCurrentAction:UINavigationControllerStateNeutral];

            //nextAction
            [self performNextActionInQueue];
        }
    }
    
    //Call nextDelegate
    if([[self nextDelegate] respondsToSelector:@selector(navigationController:didShowViewController:animated:)]) {
        [[self nextDelegate] navigationController:navigationController didShowViewController:viewController animated:animated];
    }
}

- (id <UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                          interactionControllerForAnimationController:(id <UIViewControllerAnimatedTransitioning>) animationController
{
    //Call nextDelegate
    if([[self nextDelegate] respondsToSelector:@selector(navigationController:interactionControllerForAnimationController:)]) {
        return [[self nextDelegate] navigationController:navigationController
             interactionControllerForAnimationController:animationController];
    }
    
    return nil;
}

- (id <UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                   animationControllerForOperation:(UINavigationControllerOperation)operation
                                                fromViewController:(UIViewController *)fromVC
                                                  toViewController:(UIViewController *)toVC
{
    //Call nextDelegate
    if ([[self nextDelegate] respondsToSelector:@selector(navigationController:animationControllerForOperation:fromViewController:toViewController:)]) {
        [[self nextDelegate] navigationController:navigationController
                  animationControllerForOperation:operation
                               fromViewController:fromVC
                                 toViewController:toVC];
    }
    
    return nil;
}

#pragma mark -

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated withCompletionBlock:(JMONavCompletionBlock)completionBlock
{
    if (nil == self.delegate) {
        self.delegate = self;
    }
    
    if ([self currentAction] == UINavigationControllerStatePushInProgress) {
        JMONavigationAction *action = [JMONavigationAction actionTye:JMONavigationActionTypePush completionBlock:completionBlock animated:animated viewController:viewController];
        [self addActionToQueue:action];
    } else {
        [self setCompletionBlock:completionBlock];
        [self setCurrentAction:UINavigationControllerStatePushInProgress];
        [self setTargetedViewController:viewController];
        
        [UINavigationController jr_swizzleMethod:@selector(pushViewController:animated:)
                                      withMethod:@selector(_swizzlePushViewController:animated:) error:nil];
        [self pushViewController:viewController animated:animated];
        [UINavigationController jr_swizzleMethod:@selector(pushViewController:animated:)
                                      withMethod:@selector(_swizzlePushViewController:animated:) error:nil];
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated withCompletionBlock:(JMONavCompletionBlock)completionBlock
{
    if (nil == self.delegate) {
        self.delegate = self;
    }
    
    if ([self currentAction] == UINavigationControllerStatePopInProgress) {
        JMONavigationAction *action = [JMONavigationAction actionTye:JMONavigationActionTypePop completionBlock:completionBlock animated:animated];
        [self addActionToQueue:action];
        return nil;
    } else if ([self currentAction] != UINavigationControllerStatePopToRootInProgress){
        [self setCurrentAction:UINavigationControllerStatePopInProgress];
        [self setCompletionBlock:completionBlock];
    } else {
        //We are UINavigationControllerPopToRootInProgress, we keep the final completionBlock
    }
    
    UIViewController *targetedVc = [self estimateTargetedViewController];
    if (nil != targetedVc) { //There is a controller before the current
        [self setTargetedViewController:targetedVc];
        
        [UINavigationController jr_swizzleMethod:@selector(popViewControllerAnimated:)
                                      withMethod:@selector(_swizzlePopViewControllerAnimated:) error:nil];
        [self popViewControllerAnimated:animated];
        [UINavigationController jr_swizzleMethod:@selector(popViewControllerAnimated:)
                                      withMethod:@selector(_swizzlePopViewControllerAnimated:) error:nil];
    } else {
        //Nothing to pop, execute completion block and finish
        [self consumeCompletionBlock];
        [self setCurrentAction:UINavigationControllerStateNeutral];
    }
    
    return targetedVc;
}

- (void)popToRootViewControllerAnimated:(BOOL)animated withCompletionBlock:(JMONavCompletionBlock)completionBlock
{
    if (nil == self.delegate) {
        self.delegate = self;
    }
    
    [self setCurrentAction:UINavigationControllerStatePopToRootInProgress];
    [self setCompletionBlock:completionBlock];
    [self popViewControllerAnimated:animated withCompletionBlock:NULL];
}

#pragma mark - Manage actions queue

- (JMONavigationAction *)nextAction
{
    NSArray *actions = [self actionsQueue];
    if(actions.count > 0) {
        return [actions firstObject];
    }
    return nil;
}

- (void)removActionToQueue:(JMONavigationAction *)action
{
    NSMutableArray *actions = [[self actionsQueue] mutableCopy];
    [actions removeObject:action];
    [self setActionsQueue:actions];
}

- (void)addActionToQueue:(JMONavigationAction *)action
{
    NSMutableArray *actions = [[self actionsQueue] mutableCopy];
    if(nil == actions) {
        actions = [NSMutableArray new];
    }
        
    [actions addObject:action];
    [self setActionsQueue:actions];
}

#pragma mark - Helpers

- (UIViewController *)estimateTargetedViewController
{
    NSInteger nbControllers = self.viewControllers.count;
    if ((nbControllers-2) >= 0) {
        return self.viewControllers[nbControllers-2];
    } else {
        return nil;
    }
}

- (void)performNextActionInQueue
{
    JMONavigationAction *nextAction = [self nextAction];
    if (nil != nextAction) {
        [self removActionToQueue:nextAction];
        [self setCurrentAction:UINavigationControllerStateNeutral];
        if (nextAction.type == JMONavigationActionTypePop) {
            [self popViewControllerAnimated:nextAction.animated withCompletionBlock:nextAction.completionBlock];
        } else {
            [self pushViewController:nextAction.viewController animated:nextAction.animated withCompletionBlock:nextAction.completionBlock];
        }
    }
}

- (void)consumeCompletionBlock
{
    if ([self completionBlock]) {
        JMONavCompletionBlock block = [self completionBlock];
        block();
        [self setCompletionBlock:NULL];
    }
}

@end