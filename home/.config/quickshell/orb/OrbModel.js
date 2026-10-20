// Geometry from tcballard/omarchy-plugin-orb Model.js (MIT, (c) 2026 Tom Ballard).
.pragma library
function hit(x, y, diameter, count) {
    if (count < 1) return -1;
    var dx = x - diameter / 2, dy = y - diameter / 2;
    var r = Math.sqrt(dx * dx + dy * dy) / diameter;
    if (r < 0.18 || r > 0.48) return -1;
    var step = 360 / count;
    var angle = (Math.atan2(dy, dx) * 180 / Math.PI + 90 + step / 2 + 360) % 360;
    return Math.floor(angle / step) % count;
}
function placement(px, py, width, height, top, preferred) {
    var pad = 12, footer = 38;
    var size = Math.max(1, Math.min(preferred, width - pad * 2, height - top - pad * 2 - footer));
    return { size: size, footer: footer,
        x: Math.max(pad, Math.min(px - size / 2, width - pad - size)),
        y: Math.max(top + pad, Math.min(py - size / 2, height - pad - size - footer)) };
}
