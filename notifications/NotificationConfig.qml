pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Transparent side-pose art; the card is always live QML.
    readonly property url emiliaSource: Qt.resolvedUrl("../assets/emilia_side_body.png")
    // Optional registered transparent foreground layer. Empty uses hand crops
    // from the body, so final layered artwork can be swapped without UI edits.
    property url handSource: ""
    readonly property rect bodySourceRect: Qt.rect(0, 0, 1024, 1536)
    readonly property rect upperHandSourceRect: Qt.rect(402, 430, 112, 110)
    // Contact points in the artwork. Fit the intact pose between card edges.
    property real gripRightX: 536
    property real gripTopY: 472
    property real gripBottomY: 810
    readonly property real maxPoseScale: cardMaxHeight / (gripBottomY - gripTopY)

    property real emiliaScale: 0.25
    property real emiliaX: 284
    property real emiliaY: 0
    // Match Mako's default notification geometry: 300 px wide and at most
    // 100 px tall. Keep the right edge at x=418 so Emilia's grip stays aligned.
    property real cardX: 118
    property real cardY: Math.ceil(gripTopY * maxPoseScale)
    property real cardWidth: 300
    property real cardHeight: 0
    property real cardMinHeight: 62
    property real cardMaxHeight: 100
    property real handX: emiliaX
    property real handY: emiliaY
    property real handScale: emiliaScale

    property int popupTopMargin: 12
    property int popupRightMargin: 0
    property real shownOffsetX: 0
    property real hiddenOffsetX: popupWidth + Math.max(0, popupRightMargin)

    // Motion and lifetime tuning.
    property int showDuration: 340
    property int hideDuration: 270
    property int defaultTimeout: 5000
    property int lowTimeout: 4200
    property int criticalTimeout: 15000
    property int minimumRequestedTimeout: 1500
    property int maximumRequestedTimeout: 30000

    // Card metrics.
    property int cardPadding: 8
    property int cardGripInset: 8
    property int cardTopGripInset: 3
    property int cardRadius: 18
    property int iconSize: 18
    property int closeSize: 18
    property int imageSize: 32
    property int actionHeight: 16
    property int actionFontSize: 10
    property int actionHorizontalPadding: 6
    property int actionRadius: 4
    property int actionSpacing: 5
    property int contentSpacing: 3
    property int titleMaxLines: 1
    property int bodyMaxLines: 2

    readonly property real bodyWidth: bodySourceRect.width * emiliaScale
    readonly property real bodyHeight: bodySourceRect.height * emiliaScale
    readonly property real popupWidth: Math.ceil(Math.max(
        emiliaX + bodyWidth, cardX + cardWidth))
    readonly property real popupHeight: Math.ceil(Math.max(
        cardY + emiliaY + (bodySourceRect.height - gripTopY) * maxPoseScale,
        cardY + cardMaxHeight) + popupTopMargin + 8)
}
