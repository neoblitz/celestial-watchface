using Toybox.Math;

// Apparent positions of Venus, Mars, Jupiter, Saturn, Neptune as seen from the
// observer's location on Earth. Same Keplerian propagation as MarsPlanets,
// but the position vector is subtracted from Earth and projected straight to
// the observer's local horizon (no Mars-frame transform needed).
module EarthPlanets {

    function d2r(x) { return x * Math.PI / 180.0d; }
    function r2d(x) { return x * 180.0d / Math.PI; }
    function norm360(x) { return x - 360.0d * Math.floor(x / 360.0d); }

    class PlanetPos {
        var name;
        var alt;
        var az;
        var r;
        var color;
    }

    function compute(unixSeconds, latDeg, eastLonDeg, lstHours) {
        var s = unixSeconds.toDouble();
        var jdtt = 2440587.5d + s / 86400.0d + 69.184d / 86400.0d;
        var d = jdtt - 2451545.0d;

        var earthHelio = MarsPlanets.helioEcliptic(MarsPlanets.EARTH, d);

        var out = [];
        addOne(out, "Mercury", 0xC0B090, 2, MarsPlanets.MERCURY, d, earthHelio, latDeg, lstHours);
        addOne(out, "Venus",   0xE0E8FF, 4, MarsPlanets.VENUS,   d, earthHelio, latDeg, lstHours);
        addOne(out, "Mars",    0xE65A2A, 4, MarsPlanets.MARS,    d, earthHelio, latDeg, lstHours);
        addOne(out, "Jupiter", 0xD8C898, 4, MarsPlanets.JUPITER, d, earthHelio, latDeg, lstHours);
        addOne(out, "Saturn",  0xE0D080, 3, MarsPlanets.SATURN,  d, earthHelio, latDeg, lstHours);
        addOne(out, "Uranus",  0x80D0E0, 2, MarsPlanets.URANUS,  d, earthHelio, latDeg, lstHours);
        addOne(out, "Neptune", 0x6088FF, 2, MarsPlanets.NEPTUNE, d, earthHelio, latDeg, lstHours);
        return out;
    }

    function addOne(out, name, color, rad, elem, d, earthHelio, latDeg, lstHours) {
        var helio = MarsPlanets.helioEcliptic(elem, d);
        // Geocentric ecliptic position.
        var dx = helio[0] - earthHelio[0];
        var dy = helio[1] - earthHelio[1];
        var dz = helio[2] - earthHelio[2];
        // Ecliptic -> Earth equatorial.
        var ce = Math.cos(d2r(23.4393d));
        var se = Math.sin(d2r(23.4393d));
        var qx = dx;
        var qy = dy * ce - dz * se;
        var qz = dy * se + dz * ce;
        // Equatorial RA/Dec from the geocentric vector.
        var ra  = norm360(r2d(Math.atan2(qy, qx)));
        var mag = Math.sqrt(qx * qx + qy * qy + qz * qz);
        var dec = r2d(Math.asin(qz / mag));
        // Project to observer's local horizon via EarthTime.
        var aa = EarthTime.altAzFromRaDec(ra, dec, lstHours, latDeg);
        var p = new PlanetPos();
        p.name  = name;
        p.alt   = aa[0];
        p.az    = aa[1];
        p.r     = rad;
        p.color = color;
        out.add(p);
    }
}
