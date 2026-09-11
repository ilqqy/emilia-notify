import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root
    required property var notification
    readonly property bool hovered: hoverHandler.hovered
    signal dismissRequested()

    readonly property bool isLow: !!notification && notification.urgency === NotificationUrgency.Low
    readonly property bool isCritical: !!notification && notification.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: notification
        ? Array.from(notification.actions).find(action => action.identifier === "default") || null : null
    readonly property var buttonActions: notification
        ? Array.from(notification.actions).filter(action => action.identifier !== "default"
            && (action.text || "").trim().toLowerCase() !== "mark as read") : []
    readonly property real horizontalInset: NotificationConfig.cardPadding + NotificationConfig.cardGripInset
    readonly property real topInset: NotificationConfig.cardPadding + NotificationConfig.cardTopGripInset
    onButtonActionsChanged: actionStrip.contentX = 0

    function resolveIcon(value): url {
        if (!value) return "";
        if (value.startsWith("/") || value.startsWith("file:")) return Qt.resolvedUrl(value);
        // Missing theme icons return a checkerboard, not Image.Error.
        return Quickshell.iconPath(value, true);
    }

    function resolveImage(value): url {
        if (!value) return "";
        if (value.startsWith("image://icon/")) return resolveIcon(value.slice("image://icon/".length));
        return value;
    }

    function invokeDefault(): void {
        if (enabled && defaultAction) defaultAction.invoke();
    }

    implicitWidth: NotificationConfig.cardWidth
    implicitHeight: Math.min(NotificationConfig.cardMaxHeight, Math.max(
        NotificationConfig.cardMinHeight, NotificationConfig.cardHeight,
        topInset + content.implicitHeight + NotificationConfig.cardPadding))

    Rectangle {
        y: 4
        width: parent.width
        height: parent.height
        radius: surface.radius
        color: NotificationTheme.shadow
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: NotificationConfig.cardRadius
        color: root.isLow ? NotificationTheme.cardLow : NotificationTheme.card
        border.width: root.isCritical ? 2 : 1
        border.color: root.isCritical ? NotificationTheme.critical : NotificationTheme.border
        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.invokeDefault()
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.topMargin: root.topInset
            anchors.bottomMargin: NotificationConfig.cardPadding
            anchors.leftMargin: root.horizontalInset
            anchors.rightMargin: root.horizontalInset
            spacing: NotificationConfig.contentSpacing

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                spacing: NotificationConfig.contentSpacing * 3

                Item {
                    Layout.preferredWidth: NotificationConfig.imageSize
                    Layout.preferredHeight: NotificationConfig.imageSize
                    Layout.alignment: Qt.AlignVCenter
                    visible: attachment.status === Image.Ready || appIcon.status === Image.Ready

                    Image {
                        id: appIcon
                        objectName: "appIcon"
                        anchors.fill: parent
                        visible: attachment.status !== Image.Ready && status === Image.Ready
                        source: root.resolveIcon(root.notification ? root.notification.appIcon : "")
                        sourceSize: Qt.size(NotificationConfig.imageSize * 2, NotificationConfig.imageSize * 2)
                        asynchronous: true
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                    }
                    Image {
                        id: attachment
                        objectName: "attachment"
                        anchors.fill: parent
                        visible: status === Image.Ready
                        source: root.resolveImage(root.notification ? root.notification.image : "")
                        sourceSize: Qt.size(NotificationConfig.imageSize * 2, NotificationConfig.imageSize * 2)
                        asynchronous: true
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    Layout.minimumHeight: 0
                    spacing: NotificationConfig.contentSpacing
                    Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
                    Text {
                        Layout.fillWidth: true
                        text: root.notification ? (root.notification.summary || root.notification.appName) : ""
                        textFormat: Text.PlainText
                        color: NotificationTheme.foreground
                        font.family: NotificationTheme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        maximumLineCount: NotificationConfig.titleMaxLines
                        elide: Text.ElideRight
                    }
                    Text {
                        id: bodyText
                        objectName: "bodyText"
                        Layout.fillWidth: true
                        Layout.minimumHeight: 0
                        visible: text !== ""
                        text: root.notification ? root.notification.body : ""
                        textFormat: Text.PlainText
                        color: NotificationTheme.foreground
                        opacity: root.isLow ? 0.78 : 0.9
                        font.family: NotificationTheme.fontFamily
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        maximumLineCount: NotificationConfig.bodyMaxLines
                        elide: Text.ElideRight
                        clip: true
                    }
                    Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
                }
                Rectangle {
                    objectName: "closeButton"
                    Layout.preferredWidth: NotificationConfig.closeSize
                    Layout.preferredHeight: NotificationConfig.closeSize
                    Layout.alignment: Qt.AlignTop
                    radius: width / 2
                    color: closeArea.containsMouse ? NotificationTheme.accentSoft : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: NotificationTheme.foreground
                        font.pixelSize: 17
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissRequested()
                    }
                }
            }
            // Every non-default action remains reachable in a fixed-height row.
            // Drag or scroll sideways when the buttons exceed the card width.
            Flickable {
                id: actionStrip
                objectName: "actionStrip"
                Layout.fillWidth: true
                Layout.preferredHeight: NotificationConfig.actionHeight
                Layout.minimumHeight: NotificationConfig.actionHeight
                visible: root.buttonActions.length > 0
                contentWidth: Math.max(width, actionRow.width)
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                WheelHandler {
                    target: null
                    onWheel: event => {
                        const delta = event.angleDelta.x || event.angleDelta.y;
                        actionStrip.contentX = Math.max(0, Math.min(
                            actionStrip.contentWidth - actionStrip.width, actionStrip.contentX - delta / 3));
                    }
                }
                Row {
                    id: actionRow
                    x: Math.max(0, (actionStrip.width - width) / 2)
                    spacing: NotificationConfig.actionSpacing
                    Repeater {
                        model: root.buttonActions
                        Rectangle {
                            id: actionButton
                            required property var modelData
                            required property int index
                            objectName: "actionButton" + index
                            width: Math.min(actionStrip.width, actionLabel.implicitWidth
                                + 2 * NotificationConfig.actionHorizontalPadding)
                            height: NotificationConfig.actionHeight
                            radius: NotificationConfig.actionRadius
                            color: actionArea.containsMouse ? NotificationTheme.accentSoft
                                : Qt.rgba(NotificationTheme.foreground.r, NotificationTheme.foreground.g,
                                    NotificationTheme.foreground.b, 0.04)
                            border.width: actionArea.containsMouse ? 1 : 0
                            border.color: NotificationTheme.border
                            Text {
                                id: actionLabel
                                anchors.fill: parent
                                anchors.leftMargin: NotificationConfig.actionHorizontalPadding
                                anchors.rightMargin: NotificationConfig.actionHorizontalPadding
                                text: actionButton.modelData ? actionButton.modelData.text : ""
                                textFormat: Text.PlainText
                                color: NotificationTheme.foreground
                                font.family: NotificationTheme.fontFamily
                                font.pixelSize: NotificationConfig.actionFontSize
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            MouseArea {
                                id: actionArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.enabled && actionButton.modelData) actionButton.modelData.invoke();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    HoverHandler { id: hoverHandler }
}
