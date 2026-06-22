using Toybox.Math;
using Toybox.Lang;

// Generic "observer on a planet" astronomy. Given a planet index from Bodies
// plus the observer's latitude / east longitude, computes:
//   - sun altitude, local solar hour, sunrise / sunset, polar flag
//   - alt/az of every star in the catalog (bright-star projection)
//   - alt/az of every other tracked planet
//
// The math mirrors the Mars/Earth-specific modules but parameterized on the
// planet's IAU pole and rotation. Accuracy ~1 degree, suitable for a watch.
module Site {

    function d2r(x) { return x * Math.PI / 180.0d; }
    function r2d(x) { return x * 180.0d / Math.PI; }
    function norm360(x) { return x - 360.0d * Math.floor(x / 360.0d); }

    // Earth-equatorial -> planet-equatorial rotation matrix (3x3).
    function frameMatrix(poleRA, poleDec) {
        var paR = d2r(poleRA);
        var pdR = d2r(poleDec);
        var zx = Math.cos(pdR) * Math.cos(paR);
        var zy = Math.cos(pdR) * Math.sin(paR);
        var zz = Math.sin(pdR);
        var nR = d2r(poleRA + 90.0d);
        var xx = Math.cos(nR);
        var xy = Math.sin(nR);
        var xz = 0.0d;
        var yx = zy*xz - zz*xy;
        var yy = zz*xx - zx*xz;
        var yz = zx*xy - zy*xx;
        return [[xx, xy, xz], [yx, yy, yz], [zx, zy, zz]];
    }

    // Ecliptic -> Earth-equatorial rotation (about X by obliquity).
    function eclipticToEquatorial(v) {
        var ce = Math.cos(d2r(23.4393d));
        var se = Math.sin(d2r(23.4393d));
        return [v[0], v[1]*ce - v[2]*se, v[1]*se + v[2]*ce];
    }

    // Apply a 3x3 row-major matrix to a 3-vector.
    function applyR(R, v) {
        return [
            R[0][0]*v[0] + R[0][1]*v[1] + R[0][2]*v[2],
            R[1][0]*v[0] + R[1][1]*v[1] + R[1][2]*v[2],
            R[2][0]*v[0] + R[2][1]*v[1] + R[2][2]*v[2]
        ];
    }

    // ---- Sun + local-time state at an observer on a planet ----

    class SunState {
        var alt;          // solar altitude (deg)
        var sunRA;        // sun RA in planet frame (deg)
        var sunDec;       // sun declination in planet frame (deg)
        var lstHours;     // local sidereal time (hours)
        var localSolar;   // local mean solar hour, [0,24)
        var sunrise;      // sunrise in local solar hours
        var sunset;       // sunset
        var polar;        // 0 normal, +1 no sunset, -1 no sunrise
        var isDay;
    }

    function sunState(planetIdx, latDeg, eastLonDeg, unixSeconds) {
        var s = unixSeconds.toDouble();
        var jdtt = 2440587.5d + s / 86400.0d + 69.184d / 86400.0d;
        var d = jdtt - 2451545.0d;

        // Planet helio ecliptic position via Kepler (delegates to MarsPlanets).
        var helio = MarsPlanets.helioEcliptic(Bodies.ELEM[planetIdx], d);
        var dist = Math.sqrt(helio[0]*helio[0] + helio[1]*helio[1] + helio[2]*helio[2]);
        // Sun direction from planet = -helio_unit (ecliptic frame).
        var sunEcl = [-helio[0] / dist, -helio[1] / dist, -helio[2] / dist];
        var sunEq  = eclipticToEquatorial(sunEcl);

        // Rotate sun direction into the planet's equatorial frame.
        var pole = Bodies.POLES[planetIdx];
        var R = frameMatrix(pole[0], pole[1]);
        var sunPlanet = applyR(R, sunEq);
        var sunRA  = norm360(r2d(Math.atan2(sunPlanet[1], sunPlanet[0])));
        var sunDec = r2d(Math.asin(sunPlanet[2]));

        // Local sidereal time at observer (deg, hours).
        var rot = Bodies.ROT[planetIdx];
        var W = norm360(rot[0] + rot[1] * d);
        var lstDeg   = norm360(W + eastLonDeg);
        var lstHours = lstDeg / 15.0d;

        // Solar hour angle, altitude.
        var Hdeg = lstDeg - sunRA;
        Hdeg = Hdeg - 360.0d * Math.round(Hdeg / 360.0d);
        var H = d2r(Hdeg);
        var lat = d2r(latDeg);
        var dec = d2r(sunDec);
        var sinAlt = Math.sin(lat) * Math.sin(dec) + Math.cos(lat) * Math.cos(dec) * Math.cos(H);
        var alt = r2d(Math.asin(sinAlt));

        // Local mean solar time (hours, 0-24): "noon = sun at upper transit".
        // localSolar = 12 + hour_angle_hours.
        var localSolar = 12.0d + Hdeg / 15.0d;
        localSolar = localSolar - 24.0d * Math.floor(localSolar / 24.0d);

        // Sunrise/sunset via cos(H0) = -tan(lat) * tan(dec). In planet hours.
        var sunrise = 0.0d; var sunset = 0.0d; var polar = 0;
        var cosH0 = -Math.tan(lat) * Math.tan(dec);
        if (cosH0 >= 1.0d)       { polar = -1; }
        else if (cosH0 <= -1.0d) { polar =  1; sunset = 24.0d; }
        else {
            var h0h = r2d(Math.acos(cosH0)) / 15.0d;
            sunrise = 12.0d - h0h;
            sunset  = 12.0d + h0h;
            if (sunrise < 0)  { sunrise += 24.0d; }
            if (sunset > 24)  { sunset  -= 24.0d; }
        }

        var st = new SunState();
        st.alt = alt; st.sunRA = sunRA; st.sunDec = sunDec;
        st.lstHours = lstHours; st.localSolar = localSolar;
        st.sunrise = sunrise; st.sunset = sunset; st.polar = polar;
        st.isDay = (alt > 0.0d);
        return st;
    }

    // ---- Stars from the observer's perspective ----

    class StarPos { var alt; var az; var r; var name; }

    function stars(planetIdx, latDeg, eastLonDeg, lstHours) {
        var pole = Bodies.POLES[planetIdx];
        var R = frameMatrix(pole[0], pole[1]);
        var lat = d2r(latDeg);
        var sinLat = Math.sin(lat); var cosLat = Math.cos(lat);
        var th = d2r(norm360(lstHours * 15.0d));
        var sinT = Math.sin(th); var cosT = Math.cos(th);
        var ux = cosLat * cosT; var uy = cosLat * sinT; var uz = sinLat;
        var ex = -sinT; var ey = cosT;
        var nx = -sinLat * cosT; var ny = -sinLat * sinT; var nz = cosLat;

        var out = [];
        for (var i = 0; i < MarsSky.STARS.size(); i += 1) {
            var sra = MarsSky.STARS[i][0]; var sdec = MarsSky.STARS[i][1];
            var rad = MarsSky.STARS[i][2];
            var cd = Math.cos(d2r(sdec));
            var ev = [cd * Math.cos(d2r(sra)), cd * Math.sin(d2r(sra)), Math.sin(d2r(sdec))];
            var pv = applyR(R, ev);
            var u = pv[0]*ux + pv[1]*uy + pv[2]*uz;
            var e = pv[0]*ex + pv[1]*ey;
            var n = pv[0]*nx + pv[1]*ny + pv[2]*nz;
            var sp = new StarPos();
            sp.alt  = r2d(Math.asin(u));
            sp.az   = norm360(r2d(Math.atan2(e, n)));
            sp.r    = rad;
            sp.name = MarsSky.NAMES[i];
            out.add(sp);
        }
        return out;
    }

    // ---- Other planets seen from this observer planet ----

    class PlanetPos { var name; var alt; var az; var r; var color; }

    function planets(observerIdx, latDeg, eastLonDeg, lstHours, unixSeconds) {
        var s = unixSeconds.toDouble();
        var jdtt = 2440587.5d + s / 86400.0d + 69.184d / 86400.0d;
        var d = jdtt - 2451545.0d;

        var obsHelio = MarsPlanets.helioEcliptic(Bodies.ELEM[observerIdx], d);
        var pole = Bodies.POLES[observerIdx];
        var R = frameMatrix(pole[0], pole[1]);
        var lat = d2r(latDeg);
        var sinLat = Math.sin(lat); var cosLat = Math.cos(lat);
        var th = d2r(norm360(lstHours * 15.0d));
        var sinT = Math.sin(th); var cosT = Math.cos(th);
        var ux = cosLat * cosT; var uy = cosLat * sinT; var uz = sinLat;
        var ex = -sinT; var ey = cosT;
        var nx = -sinLat * cosT; var ny = -sinLat * sinT; var nz = cosLat;

        var out = [];
        for (var i = 0; i < Bodies.NAMES.size(); i += 1) {
            if (i == observerIdx) { continue; }   // can't see yourself
            var helio = MarsPlanets.helioEcliptic(Bodies.ELEM[i], d);
            var rel = [helio[0] - obsHelio[0], helio[1] - obsHelio[1], helio[2] - obsHelio[2]];
            var relEq = eclipticToEquatorial(rel);
            var relP = applyR(R, relEq);
            var u = relP[0]*ux + relP[1]*uy + relP[2]*uz;
            var e = relP[0]*ex + relP[1]*ey;
            var n = relP[0]*nx + relP[1]*ny + relP[2]*nz;
            var mag = Math.sqrt(relP[0]*relP[0] + relP[1]*relP[1] + relP[2]*relP[2]);
            var p = new PlanetPos();
            p.name  = Bodies.NAMES[i];
            p.alt   = r2d(Math.asin(u / mag));
            p.az    = norm360(r2d(Math.atan2(e, n)));
            // Reuse the colors from Bodies; inner planets render bigger.
            var r;
            if (i == Bodies.VENUS)        { r = 4; }
            else if (i == Bodies.EARTH)   { r = 4; }
            else if (i == Bodies.MARS)    { r = 4; }
            else if (i == Bodies.JUPITER) { r = 4; }
            else if (i == Bodies.SATURN)  { r = 3; }
            else                          { r = 2; }
            p.r     = r;
            p.color = Bodies.COLORS[i];
            out.add(p);
        }
        return out;
    }
}
