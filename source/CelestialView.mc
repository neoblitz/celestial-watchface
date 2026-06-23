using Toybox.WatchUi;
using Toybox.Lang;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;
using Toybox.Math;
using Toybox.ActivityMonitor;
using Toybox.Activity;
using Toybox.Position;

class CelestialView extends WatchUi.WatchFace {

    // Palette
    const C_MARS    = 0xCC4422;   // rust accent / Mars hour hand
    const C_EARTH   = 0x5090E0;   // blue accent / Earth hour hand
    const C_DAYARC  = 0xFFA040;   // daytime arc (amber)
    const C_NIGHTARC= 0x35466B;   // nighttime arc (dim blue)
    const C_SUN     = 0xFFC24D;
    const C_TEXT    = 0xFFFFFF;
    const C_DIM     = 0x9A8E86;
    const C_STAR    = 0x6A6F86;
    const C_PHOBOS  = 0xE8CBA6;   // pale tan
    const C_DEIMOS  = 0xAEB6C8;   // pale blue-grey

    var mSleeping = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc) {}
    function onShow() {}
    function onEnterSleep() { mSleeping = true; WatchUi.requestUpdate(); }
    function onExitSleep()  { mSleeping = false; WatchUi.requestUpdate(); }

    // Map an LMST hour [0,24) to a screen angle (deg, CCW from +x, noon at top).
    function angleForHour(hr) {
        var a = 270.0 - 15.0 * hr;
        return a - 360.0 * Math.floor(a / 360.0);
    }

    function pointOnCircle(cx, cy, r, angleDeg) as Lang.Array<Lang.Numeric> {
        var t = angleDeg * Math.PI / 180.0;
        return [cx + r * Math.cos(t), cy - r * Math.sin(t)];
    }

    function drawSun(dc, x, y, r) {
        if (r < 4) {
            // Distant sun: just a bright pinprick with a small halo.
            dc.setColor(0xC8662A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r + 2);
            dc.setColor(0xFFE6B0, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r);
            return;
        }
        dc.setColor(0xC8662A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r + 5);
        dc.setColor(C_SUN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        if (r > 6) {
            dc.setColor(0xFFE6B0, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r - 6);
        }
    }

    // Single watch hand drawn as a thick line, with a small overhang behind
    // the center hub (gives a balanced classical look).
    function drawHand(dc, cx, cy, lengthPx, widthPx, angleDeg, color) {
        var rad = (angleDeg - 90.0) * Math.PI / 180.0;
        var ct = Math.cos(rad);
        var st = Math.sin(rad);
        var tipX  = cx + lengthPx * ct;
        var tipY  = cy + lengthPx * st;
        var backX = cx - 10 * ct;
        var backY = cy - 10 * st;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(widthPx);
        dc.drawLine(backX, backY, tipX, tipY);
    }

    // Analog hour/minute hands, planet-colored hour, white minute, center hub.
    function drawClockHands(dc, cx, cy, hourLen, minuteLen, hourColor) {
        var clk = System.getClockTime();
        var hr12 = clk.hour % 12;
        var mn = clk.min;
        // Smooth hour-hand position between hours.
        var hourAngle = hr12 * 30.0 + mn * 0.5;
        var minAngle  = mn * 6.0;
        drawHand(dc, cx, cy, hourLen,   8, hourAngle, hourColor);
        drawHand(dc, cx, cy, minuteLen, 5, minAngle,  0xFFFFFF);
        // Center hub: white outer + planet-colored inner.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 6);
        dc.setColor(hourColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 3);
    }

    // Small heart icon: two lobes + a triangular point. ~14px wide, ~12 tall.
    function drawHeart(dc, x, y, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - 3, y - 1, 4);
        dc.fillCircle(x + 3, y - 1, 4);
        dc.fillPolygon([[x - 6, y + 1], [x + 6, y + 1], [x, y + 8]]);
    }

    // Place a moon in the sky band from its altitude/azimuth.
    function drawMoonDot(dc, m, cx, w, horizonY, coreR, coreColor, haloColor) {
        if (!m.up) { return; }
        var x = cx + Math.sin(m.az * Math.PI / 180.0) * (w * 0.32);
        if (x < 45) { x = 45; }
        if (x > w - 45) { x = w - 45; }
        var y = horizonY - (m.alt / 90.0) * (horizonY - 50);
        dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, coreR + 2);
        dc.setColor(coreColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, coreR);
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        var now = Time.now().value();

        // ---- Planet selection: which world is the observer on? ----
        var planetIdx = Bodies.MARS;
        var piv = Application.Properties.getValue("planetIndex");
        if (piv != null) { planetIdx = piv; }
        if (planetIdx < 0 || planetIdx > 8) { planetIdx = Bodies.MARS; }
        var mode = (planetIdx == Bodies.EARTH) ? "earth" : "mars";

        // Observer location per planet. Earth uses live GPS; others use the
        // landmark site defined in Bodies.SITES.
        var lat; var lonE;
        if (planetIdx == Bodies.EARTH) {
            lat = 0.0; lonE = 0.0;
            var pinfo = Position.getInfo();
            if (pinfo != null && pinfo.position != null) {
                var loc = pinfo.position.toDegrees();
                lat = loc[0]; lonE = loc[1];
            }
        } else {
            lat  = Bodies.SITES[planetIdx][0];
            lonE = Bodies.SITES[planetIdx][1];
        }

        // Sun + local-time state via the generic Site module.
        var sst = Site.sunState(planetIdx, lat, lonE, now);
        var alt = sst.alt;
        var sunAz = sst.az;
        var lmstHr = sst.localSolar;
        var sunriseHr = sst.sunrise;
        var sunsetHr = sst.sunset;
        var polar = sst.polar;
        var isDay = sst.isDay;
        var lstHours = sst.lstHours;

        // Mars moons only when observing from Mars.
        var mn = null;
        if (planetIdx == Bodies.MARS) {
            var pcal = 0.0; var dcal = 0.0;
            var pv = Application.Properties.getValue("phobosCal");
            var dv = Application.Properties.getValue("deimosCal");
            if (pv != null) { pcal = pv; }
            if (dv != null) { dcal = dv; }
            mn = MarsMoons.compute(now, Bodies.SITES[Bodies.MARS][0], Bodies.SITES[Bodies.MARS][1],
                                   pcal, dcal);
        }

        var horizonY = h * 82 / 100;

        // ---- Sky + terrain palette, mode-aware ----
        var skyCol; var terr; var glow;
        if (mSleeping) {
            skyCol = 0x000000; terr = 0x000000; glow = -1;
        } else if (mode.equals("earth")) {
            if (alt >= 8.0) {                // Earth day: blue sky
                skyCol = 0x0C2440; terr = 0x101830; glow = 0x4080C0;
            } else if (alt > -8.0) {         // Earth twilight: warm horizon
                skyCol = 0x140820; terr = 0x180820; glow = 0xB04030;
            } else {                          // Earth night
                skyCol = 0x000006; terr = 0x080814; glow = -1;
            }
        } else {                              // Mars (Gale)
            if (alt >= 8.0) {
                skyCol = 0x1E140C; terr = 0x301A12; glow = 0x6A3818;
            } else if (alt > -8.0) {
                skyCol = 0x10101C; terr = 0x1C100A; glow = 0x223860;
            } else {
                skyCol = 0x040408; terr = 0x100806; glow = -1;
            }
        }
        dc.setColor(skyCol, skyCol);
        dc.clear();

        if (glow >= 0) {
            dc.setColor(glow, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, horizonY - 22, w, 22);
        }

        // Sun glyph at its actual alt/az. Observer faces the cardinal direction
        // the sun crosses the meridian on — i.e. south when the sun's
        // declination is south of the observer (the usual case for the NH and
        // for summer in the SH), north otherwise.
        if (!mSleeping && alt > -2.0) {
            var facing = (sst.sunDec < lat) ? 180.0 : 0.0;
            var relAz = sunAz - facing;
            if (relAz >  180.0) { relAz -= 360.0; }
            if (relAz < -180.0) { relAz += 360.0; }
            if (relAz >= -90.0 && relAz <= 90.0) {
                // Linear angular projection: full horizon span = ±90° around facing.
                var sunX = cx + (relAz / 90.0) * (w * 0.42);
                var sa = (alt < 0.0) ? 0.0 : alt;
                // Vertical: alt=0 → horizon, alt=90 → just above the heart row.
                var topY = h * 30 / 100;
                var sunY = horizonY - (sa / 90.0) * (horizonY - topY);
                // Sun's angular size scales as 1 / distance. Anchor: 12 px at 1 AU.
                var sunR = (12.0 / sst.dist).toNumber();
                if (sunR < 2)  { sunR = 2;  }
                if (sunR > 32) { sunR = 32; }
                // Keep the sun (including its halo) inside the round dial edge.
                var dx = sunX - cx; var dy = sunY - cy;
                var rMax = (w / 2) - 26 - sunR / 2;
                var d = Math.sqrt(dx * dx + dy * dy);
                if (d > rMax) {
                    sunX = cx + dx * rMax / d;
                    sunY = cy + dy * rMax / d;
                }
                drawSun(dc, sunX, sunY, sunR);
            }
        }

        // Foreground terrain / hill silhouette.
        var ground = [[0, horizonY], [w * 15 / 100, horizonY - 16],
                      [w * 32 / 100, horizonY - 4], [w / 2, horizonY - 20],
                      [w * 68 / 100, horizonY - 6], [w * 85 / 100, horizonY - 14],
                      [w, horizonY - 2], [w, h], [0, h]];
        dc.setColor(terr, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(ground);

        // Night sky: real stars from the Gale-Crater Mars sky, then the moons.
        if (!mSleeping && alt < -2.0) {
            // Zenith-projected dome: center of face = straight up at Gale,
            // ring inner edge = the horizon. Azimuth 0=N up the screen.
            var sky = Site.stars(planetIdx, lat, lonE, lstHours);
            var rSky = (w / 2) - 24;
            // Track screen coords of stars eligible for labeling.
            var labelables = [];
            for (var i = 0; i < sky.size(); i += 1) {
                var s = sky[i];
                if (s.alt <= 0.0) { continue; }
                var ar = s.az * Math.PI / 180.0;
                var rr = rSky * (1.0 - s.alt / 90.0);
                var sx = cx + rr * Math.sin(ar);
                var sy = cy - rr * Math.cos(ar);
                if (s.r >= 3) {
                    dc.setColor(0x3A4055, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(sx, sy, s.r + 2);
                }
                dc.setColor(C_STAR, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(sx, sy, s.r);
                // 1st-magnitude (r>=2) stars are eligible for labels. The label
                // placement loop below uses bbox collisions to avoid the UI.
                if (s.r >= 2) {
                    labelables.add([sx, sy, s.r, s.name]);
                }
            }
            if (planetIdx == Bodies.MARS && mn != null) {
                drawMoonDot(dc, mn.deimos, cx, w, horizonY, 2, C_DEIMOS, 0x3A4055);
                drawMoonDot(dc, mn.phobos, cx, w, horizonY, 4, C_PHOBOS, 0x6A5A44);
            }

            // Other planets in the sky, drawn on top of stars in their colors.
            var planets = Site.planets(planetIdx, lat, lonE, lstHours, now);
            for (var i = 0; i < planets.size(); i += 1) {
                var p = planets[i];
                if (p.alt <= 0.0) { continue; }
                var par = p.az * Math.PI / 180.0;
                var prr = rSky * (1.0 - p.alt / 90.0);
                var psx = cx + prr * Math.sin(par);
                var psy = cy - prr * Math.cos(par);
                dc.setColor(0x1C2030, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(psx, psy, p.r + 2);
                dc.setColor(p.color, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(psx, psy, p.r);
                // Priority 9 so planets are sorted ahead of stars (max r=3).
                // Bbox collisions in the placement loop handle UI avoidance.
                labelables.add([psx, psy, 9, p.name]);
            }

            // Label up to the 5 brightest visible stars. Skip any that would
            // collide with a label we've already placed.
            // Sort: brightest (highest r) first via a tiny selection-sort.
            for (var i = 0; i < labelables.size() - 1; i += 1) {
                var bestJ = i;
                for (var j = i + 1; j < labelables.size(); j += 1) {
                    if (labelables[j][2] > labelables[bestJ][2]) { bestJ = j; }
                }
                if (bestJ != i) {
                    var tmp = labelables[i];
                    labelables[i] = labelables[bestJ];
                    labelables[bestJ] = tmp;
                }
            }
            dc.setColor(0x8A8FA0, Graphics.COLOR_TRANSPARENT);
            // Pre-reserve UI bboxes so labels never overlap them. Each bbox
            // is the actual rendered text bounds with a couple of pixels'
            // padding. Compass markers and analog hand hub are also reserved.
            var rMarkPre = rSky + 4;
            var sitePre = h * 78 / 454;
            var heartPre = h * 110 / 454;
            var marsLinePre = h * 274 / 454;
            // FONT_XTINY rendered text height is ~14 px (y..y+14). Sites/
            // labels can be up to ~21 chars wide ("EARTH · San Francisco")
            // → ~150 px. Site label centered, so half-width = 75.
            var placed = [
                // Site label
                [cx - 80, sitePre - 2,    cx + 80, sitePre + 16],
                // Heart row (heart icon + HR text)
                [cx - 40, heartPre - 4,   cx + 40, heartPre + 18],
                // Analog hub + immediate center (hands draw on top anyway)
                [cx - 20, cy - 20,        cx + 20, cy + 20],
                // Compass N
                [cx - 10, cy - rMarkPre - 4,  cx + 10, cy - rMarkPre + 12],
                // Compass E
                [cx + rMarkPre - 14, cy - 14,   cx + rMarkPre + 4, cy + 4],
                // Compass W
                [cx - rMarkPre - 4,  cy - 14,   cx - rMarkPre + 14, cy + 4],
                // Compass S
                [cx - 10, cy + rMarkPre - 42, cx + 10, cy + rMarkPre - 26]
            ];
            // Optional local-time line.
            var smvPre = Application.Properties.getValue("showMarsTime");
            if (smvPre != null && smvPre && planetIdx != Bodies.EARTH) {
                placed.add([cx - 80, marsLinePre - 2, cx + 80, marsLinePre + 24]);
            }
            var maxLabels = 8;
            var drawnLabels = 0;
            var fontH = dc.getFontHeight(Graphics.FONT_XTINY);
            var rDial = (w / 2) - 14;
            for (var i = 0; i < labelables.size() && drawnLabels < maxLabels; i += 1) {
                var lx = labelables[i][0];
                var ly = labelables[i][1];
                var name = labelables[i][3];
                var txtW = dc.getTextWidthInPixels(name, Graphics.FONT_XTINY);
                // Label is drawn one font-height above the star, justified to
                // whichever side has room inside the round dial.
                var ty = ly - fontH;
                var labelRight = (lx >= cx);
                // Round-dial chord at the most restrictive y (top vs bottom
                // of the label text). 14 px inward safety margin.
                var dyTop = ty - cy;
                var dyBot = ty + fontH - cy;
                var dyA = (dyTop < 0) ? -dyTop : dyTop;
                var dyB = (dyBot < 0) ? -dyBot : dyBot;
                var dyMax = (dyB > dyA) ? dyB : dyA;
                var rr2 = rDial * rDial - dyMax * dyMax;
                var halfChord = (rr2 > 0) ? Math.sqrt(rr2).toNumber() : 0;
                var xMin = cx - halfChord + 14;
                var xMax = cx + halfChord - 14;
                if (labelRight && lx + 8 + txtW > xMax) { labelRight = false; }
                if (!labelRight && lx - 8 - txtW < xMin) { labelRight = true; }
                // If neither side fits, skip this label.
                if ( labelRight && lx + 8 + txtW > xMax) { continue; }
                if (!labelRight && lx - 8 - txtW < xMin) { continue; }
                var ox = labelRight ?  8 : -8;
                var tx = lx + ox;
                var just = labelRight
                    ? Graphics.TEXT_JUSTIFY_LEFT
                    : Graphics.TEXT_JUSTIFY_RIGHT;
                // Bbox of THIS label (with 2 px padding all around).
                var bx0 = labelRight ? (tx - 2)        : (tx - txtW - 2);
                var bx1 = labelRight ? (tx + txtW + 2) : (tx + 2);
                var by0 = ty - 2;
                var by1 = ty + fontH + 2;
                // Reject if overlapping any already-placed bbox.
                var collides = false;
                for (var k = 0; k < placed.size(); k += 1) {
                    var px0 = placed[k][0]; var py0 = placed[k][1];
                    var px1 = placed[k][2]; var py1 = placed[k][3];
                    if (bx0 < px1 && bx1 > px0 && by0 < py1 && by1 > py0) {
                        collides = true; break;
                    }
                }
                if (collides) { continue; }
                dc.drawText(tx, ty, Graphics.FONT_XTINY, name, just);
                placed.add([bx0, by0, bx1, by1]);
                drawnLabels += 1;
            }

            // Cardinal compass markers + "GALE" site label at the horizon edge.
            var rMark = rSky + 4;
            dc.setColor(0x707582, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - rMark - 2, Graphics.FONT_XTINY, "N",
                        Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx + rMark - 4, cy - 12, Graphics.FONT_XTINY, "E",
                        Graphics.TEXT_JUSTIFY_RIGHT);
            dc.drawText(cx - rMark + 4, cy - 12, Graphics.FONT_XTINY, "W",
                        Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(cx, cy + rMark - 40, Graphics.FONT_XTINY, "S",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ---- Day/Night ring dial ----
        var rRing = (w / 2) - 14;
        dc.setPenWidth(12);
        dc.setColor(mSleeping ? 0x20283D : C_NIGHTARC, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rRing);
        if (polar >= 0) {
            var startA = angleForHour(sunriseHr);
            var endA   = angleForHour(sunsetHr);
            if (polar == 1) { startA = 0; endA = 359.999; }
            dc.setColor(mSleeping ? 0x6E5028 : C_DAYARC, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, rRing, Graphics.ARC_CLOCKWISE, startA, endA);
        }
        var mk = pointOnCircle(cx, cy, rRing, angleForHour(lmstHr));
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mk[0], mk[1], 8);
        dc.setColor(isDay ? C_SUN : 0xCFD6E6, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mk[0], mk[1], 5);

        // ---- Analog clock hands (planet-colored hour) ----
        var handHourColor = Bodies.COLORS[planetIdx];
        var rRingInner = (w / 2) - 22;       // just inside the day/night ring
        var minuteLen  = rRingInner - 8;
        var hourLen    = minuteLen * 60 / 100;
        drawClockHands(dc, cx, cy, hourLen, minuteLen, handHourColor);

        // ---- Local solar time on the observer planet — opt-in via setting ----
        var showLocal = false;
        var smv = Application.Properties.getValue("showMarsTime");
        if (smv != null && smv) { showLocal = true; }
        if (showLocal && planetIdx != Bodies.EARTH) {
            var mh = lmstHr.toNumber();
            var mm = ((lmstHr - mh) * 60.0).toNumber();
            var prefix = Bodies.NAMES[planetIdx].toUpper();
            dc.setColor(handHourColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 274 / 454, Graphics.FONT_SMALL,
                        Lang.format("$1$  $2$:$3$",
                            [prefix, mh.format("%02d"), mm.format("%02d")]),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ---- Heart Rate (heart icon + number) at the top of the face ----
        if (!mSleeping) {
            var hr = "--";
            var ai = Activity.getActivityInfo();
            if (ai != null && ai.currentHeartRate != null) {
                hr = ai.currentHeartRate.format("%d");
            }
            var ry = h * 110 / 454;
            var heartW = 14;
            var gap    = 4;
            var wHr    = dc.getTextWidthInPixels(hr, Graphics.FONT_XTINY);
            var totalW = heartW + gap + wHr;
            var sx     = cx - totalW / 2;
            var heartCx = sx + heartW / 2;
            var heartCy = ry + dc.getFontHeight(Graphics.FONT_XTINY) / 2 - 1;
            drawHeart(dc, heartCx, heartCy, C_MARS);
            dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sx + heartW + gap, ry, Graphics.FONT_XTINY, hr,
                        Graphics.TEXT_JUSTIFY_LEFT);
        }

        // ---- Site label (always visible): identifies planet + location ----
        var siteLabel;
        if (planetIdx == Bodies.EARTH) {
            if (lat == 0.0 && lonE == 0.0) {
                siteLabel = "EARTH · GPS pending";
            } else {
                var near = Cities.nearest(lat, lonE);
                siteLabel = Lang.format("EARTH · $1$", [near[0]]);
            }
        } else {
            var pname = Bodies.NAMES[planetIdx].toUpper();
            var sname = Bodies.SITE_NAMES[planetIdx];
            siteLabel = (sname.length() > 0) ? (pname + " · " + sname) : pname;
        }
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 78 / 454, Graphics.FONT_XTINY, siteLabel,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}
