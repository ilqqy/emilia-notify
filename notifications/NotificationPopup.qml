import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var queue

    property var targetScreen: null
    property string animationState: "hidden"
    readonly property bool usingX11: (Quickshell.env("QT_QPA_PLATFORM") || "").startsWith("xcb")

    function screenForMonitor(monitor: var): var {
        if (!monitor)
            return null;

        const screens = Quickshell.screens;
        for (let index = 0; index < screens.length; ++index) {
            const mapped = Hyprland.monitorFor(screens[index]);
            if (mapped && (mapped === monitor || mapped.name === monitor.name))
                return screens[index];
        }
        return null;
    }

    function bestScreen(): var {
        const focused = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
            && !root.usingX11
            ? root.screenForMonitor(Hyprland.focusedMonitor) : null;
        if (focused)
            return focused;
        if (root.targetScreen && Quickshell.screens.indexOf(root.targetScreen) !== -1)
            return root.targetScreen;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function showNotification(): void {
        if (!root.queue.currentNotification)
            return;

        root.targetScreen = root.bestScreen();
        root.animationState = "showing";
        composition.x = NotificationConfig.hiddenOffsetX;
        composition.opacity = 0;
        root.visible = true;
        Qt.callLater(() => {
            if (root.animationState === "showing" && !root.queue.waitingForHide)
                showAnimation.restart();
        });
    }

    function hideNotification(): void {
        if (root.animationState === "hidden" || root.animationState === "hiding")
            return;

        root.animationState = "hiding";
        showAnimation.stop();
        hideAnimation.restart();
    }

    visible: false
    screen: targetScreen
    color: "transparent"
    implicitWidth: NotificationConfig.popupWidth
    implicitHeight: NotificationConfig.popupHeight

    anchors {
        top: true
        right: true
    }

    margins {
        top: 0
        right: NotificationConfig.popupRightMargin
    }

    focusable: false
    exclusionMode: ExclusionMode.Ignore
    Component.onCompleted: {
        // Do not create a Wayland attached object on the virtual X11 display
        // used by integration tests. The normal Wayland panel is still hidden
        // here, so its namespace and layer are set before its first mapping.
        if (!root.usingX11) {
            root.WlrLayershell.layer = WlrLayer.Overlay;
            root.WlrLayershell.namespace = "notifications";
            root.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None;
        }
    }

    // Follow the animated card in window coordinates. Region.item alone would
    // not observe the ancestor's movement. Decorative pixels pass clicks through.
    mask: Region {
        x: composition.x + card.x
        y: composition.y + card.y
        width: card.enabled ? card.width : 0
        height: card.enabled ? card.height : 0
        radius: NotificationConfig.cardRadius
    }

    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            root.targetScreen = root.bestScreen();
        }
    }

    Connections {
        target: root.queue

        function onCurrentAvailable(notification): void {
            root.showNotification();
        }

        function onCurrentClosed(reason): void {
            root.hideNotification();
        }

        function onCurrentUpdated(): void {
            if (root.animationState === "visible")
                lifetime.reset();
        }
    }

    NotificationTimeout {
        id: lifetime
        objectName: "notificationLifetime"
        notification: root.queue.currentNotification
        active: root.animationState === "visible" && !root.queue.waitingForHide
        paused: card.hovered
        onExpired: root.queue.expireCurrent()
    }

    ParallelAnimation {
        id: showAnimation

        NumberAnimation {
            target: composition
            property: "x"
            from: NotificationConfig.hiddenOffsetX
            to: NotificationConfig.shownOffsetX
            duration: NotificationConfig.showDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: composition
            property: "opacity"
            from: 0
            to: 1
            duration: Math.round(NotificationConfig.showDuration * 0.72)
            easing.type: Easing.OutCubic
        }

        onFinished: {
            if (root.animationState !== "showing")
                return;
            root.animationState = "visible";
        }
    }

    ParallelAnimation {
        id: hideAnimation

        NumberAnimation {
            target: composition
            property: "x"
            to: NotificationConfig.hiddenOffsetX
            duration: NotificationConfig.hideDuration
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: composition
            property: "opacity"
            to: 0
            duration: NotificationConfig.hideDuration
            easing.type: Easing.InQuad
        }

        onFinished: {
            if (root.animationState !== "hiding")
                return;
            root.animationState = "hidden";
            root.visible = false;
            root.queue.finishCurrentHide();
        }
    }

    Item {
        id: composition
        objectName: "notificationComposition"

        x: NotificationConfig.hiddenOffsetX
        y: NotificationConfig.popupTopMargin
        width: NotificationConfig.popupWidth
        height: NotificationConfig.popupHeight - NotificationConfig.popupTopMargin

        // z: 0 — right-side character, behind the live sign.
        Image {
            x: NotificationConfig.emiliaX
            y: NotificationConfig.emiliaY
            width: NotificationConfig.bodyWidth
            height: NotificationConfig.bodyHeight
            z: 0
            source: NotificationConfig.emiliaSource
            sourceClipRect: NotificationConfig.bodySourceRect
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            mipmap: true
            smooth: true
        }

        // z: 1 — live QML card.
        NotificationCard {
            id: card
            objectName: "notificationCard"

            x: NotificationConfig.cardX
            y: NotificationConfig.cardY
            width: NotificationConfig.cardWidth
            height: implicitHeight
            z: 1
            notification: root.queue.currentNotification
            enabled: !root.queue.waitingForHide && root.animationState !== "hidden"

            onDismissRequested: root.queue.dismissCurrent()
        }

        // z: 2 — upper grip. Crops preserve source alpha.
        // A registered foreground PNG can replace the crop without changing the card.
        Image {
            visible: !NotificationConfig.handSource.toString()
            x: NotificationConfig.handX + NotificationConfig.upperHandSourceRect.x * NotificationConfig.handScale
            y: NotificationConfig.handY + NotificationConfig.upperHandSourceRect.y * NotificationConfig.handScale
            width: NotificationConfig.upperHandSourceRect.width * NotificationConfig.handScale
            height: NotificationConfig.upperHandSourceRect.height * NotificationConfig.handScale
            z: 2
            source: NotificationConfig.emiliaSource
            sourceClipRect: NotificationConfig.upperHandSourceRect
            mipmap: true
        }
        Image {
            visible: !!NotificationConfig.handSource.toString()
            x: NotificationConfig.handX
            y: NotificationConfig.handY
            width: NotificationConfig.bodySourceRect.width * NotificationConfig.handScale
            height: NotificationConfig.bodySourceRect.height * NotificationConfig.handScale
            z: 2
            source: NotificationConfig.handSource
            mipmap: true
        }
    }
}
