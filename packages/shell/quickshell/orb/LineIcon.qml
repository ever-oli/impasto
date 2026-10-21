// Ported from tcballard/omarchy-plugin-orb (MIT, (c) 2026 Tom Ballard). See orb/LICENSE.
import QtQuick

Canvas {
    id: icon
    property string name: "browser"
    property color ink: "white"
    onNameChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    antialiasing: true
    onPaint: {
        var c = getContext("2d"); c.reset();
        c.scale(width / 24, height / 24);
        c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = 1.6;
        c.lineCap = "round"; c.lineJoin = "round";
        function line(points) { c.beginPath(); c.moveTo(points[0], points[1]); for (var i = 2; i < points.length; i += 2) c.lineTo(points[i], points[i+1]); c.stroke(); }
        function circle(x,y,r) { c.beginPath(); c.arc(x,y,r,0,Math.PI*2); c.stroke(); }
        if (name === "arrow-undo") {
            line([8,4,3,9,8,14]);
            c.beginPath(); c.moveTo(3,9); c.lineTo(14,9);
            c.bezierCurveTo(23,9,23,20,14,20); c.stroke();
        } else if (name === "browser") {
            circle(12,12,9); line([3,12,21,12]);
            c.beginPath(); c.ellipse(8,3,8,18); c.stroke();
        } else if (name === "terminal") {
            c.strokeRect(2.5,4,19,16); line([6,9,9,12,6,15]); line([12,15,17,15]);
        } else if (name === "files") {
            line([3,20,3,5,9,5,11,8,21,8,21,20,3,20]); line([3,11,21,11]);
        } else if (name === "screenshot") {
            line([8,3,3,3,3,8]); line([16,3,21,3,21,8]);
            line([3,16,3,21,8,21]); line([21,16,21,21,16,21]); c.strokeRect(7,7,10,10);
        } else if (name === "postcard") {
            c.strokeRect(2.5,4,19,16); circle(16,8,1.5); line([3,17,8,10,13,16,16,13,21,18]);
        } else if (name === "create") {
            line([10,3,12,9,18,11,12,13,10,19,8,13,2,11,8,9,10,3]);
            line([19,2,20,5,23,6,20,7,19,10,18,7,15,6,18,5,19,2]);
        } else if (name === "app") {
            c.strokeRect(3,3,7,7); c.strokeRect(14,3,7,7); c.strokeRect(3,14,7,7); c.strokeRect(14,14,7,7);
        } else if (name === "themes") {
            circle(12,12,9); circle(8,9,1); circle(13,7,1); circle(17,11,1);
            line([6,17,11,12,16,17]);
        } else if (name === "agents") {
            c.strokeRect(4,7,16,13); line([12,3,12,7]); circle(12,3,1);
            circle(8,12,1); circle(16,12,1); line([9,17,15,17]);
        } else if (name === "settings") {
            line([3,6,21,6]); line([3,12,21,12]); line([3,18,21,18]);
            c.fillStyle = ink; c.fillRect(7,3,3,6); c.fillRect(15,9,3,6); c.fillRect(8,15,3,6);
        } else {
            line([3,9,9,9,9,4,15,4,15,9,21,9,21,15,16,15,16,21,9,21,9,15,3,15,3,9]);
        }
    }
}
