using Toybox.Math;

// Earth astronomy: solar position, sunrise/sunset, Local Sidereal Time, and
// alt/az projection of any equatorial (RA/Dec) target from the user's location.
//
// Standard low-precision algorithms (NOAA / Meeus), accurate to ~0.01 deg for
// the Sun, ~1 deg or better for arbitrary stars at watch-screen resolution.
module EarthTime {

    const OBLIQUITY = 23.4393d;

    function d2r(x) { return x * Math.PI / 180.0d; }
    function r2d(x) { return x * 180.0d / Math.PI; }
    function fmod(a, b) {
        var r = a - b * Math.floor(a / b);
        if (r < 0) { r += b; }
        return r;
    }

    class SunState {
        var alt;          // solar altitude at observer (deg)
        var ra;           // sun RA (deg)
        var dec;          // sun declination (deg)
        var lstHours;     // local sidereal time, hours [0,24)
        var sunriseLocal; // local solar time of sunrise, hours [0,24)
        var sunsetLocal;  // local solar time of sunset, hours [0,24)
        var isDay;
        var polar;        // 0 normal, 1 no sunset, -1 no sunrise
    }

    // unixSeconds UTC, latitude deg, east-longitude deg.
    function compute(unixSeconds, latDeg, eastLonDeg) {
        var s = unixSeconds.toDouble();
        var jd = 2440587.5d + s / 86400.0d;
        var d  = jd - 2451545.0d;

        // Sun position (low-precision NOAA).
        var Ldeg = fmod(280.460d + 0.9856474d * d, 360.0d);
        var gDeg = fmod(357.528d + 0.9856003d * d, 360.0d);
        var g    = d2r(gDeg);
        var lamDeg = Ldeg + 1.915d * Math.sin(g) + 0.020d * Math.sin(2.0d * g);
        var lam = d2r(lamDeg);
        var eps = d2r(OBLIQUITY);
        var ra  = fmod(r2d(Math.atan2(Math.cos(eps) * Math.sin(lam),
                                      Math.cos(lam))), 360.0d);
        var dec = r2d(Math.asin(Math.sin(eps) * Math.sin(lam)));

        // GMST at this instant (hours), then LST.
        var gmstHours = fmod(18.697374558d + 24.06570982441908d * d, 24.0d);
        var lstHours  = fmod(gmstHours + eastLonDeg / 15.0d, 24.0d);

        // Hour angle of the Sun, then alt.
        var H = d2r(fmod((lstHours * 15.0d) - ra + 540.0d, 360.0d) - 180.0d);
        var lat = d2r(latDeg);
        var sinAlt = Math.sin(lat) * Math.sin(d2r(dec))
                   + Math.cos(lat) * Math.cos(d2r(dec)) * Math.cos(H);
        var alt = r2d(Math.asin(sinAlt));

        // Sunrise/sunset by solving alt=0 for H.
        var cosH0 = -Math.tan(lat) * Math.tan(d2r(dec));
        var sunrise = 0.0d;
        var sunset  = 0.0d;
        var polar   = 0;
        if (cosH0 >= 1.0d)       { polar = -1; }
        else if (cosH0 <= -1.0d) { polar =  1; sunset = 24.0d; }
        else {
            var h0h = r2d(Math.acos(cosH0)) / 15.0d;
            sunrise = fmod(12.0d - h0h, 24.0d);
            sunset  = fmod(12.0d + h0h, 24.0d);
        }

        var st = new SunState();
        st.alt = alt;
        st.ra = ra;
        st.dec = dec;
        st.lstHours = lstHours;
        st.sunriseLocal = sunrise;
        st.sunsetLocal  = sunset;
        st.isDay = (alt > 0.0d);
        st.polar = polar;
        return st;
    }

    // Local-time hour [0,24) for the dial marker: use mean solar time at the
    // observer's longitude (close enough to wall-clock time for the dial).
    function localSolarHour(unixSeconds, eastLonDeg) {
        var s = unixSeconds.toDouble();
        var jd = 2440587.5d + s / 86400.0d;
        var d  = jd - 2451545.0d;
        var gmstHours = fmod(18.697374558d + 24.06570982441908d * d, 24.0d);
        // Mean solar time = UT + lon/15, modulo 24, offset by -12 so noon=12.
        var ut = fmod(s / 3600.0d, 24.0d);
        return fmod(ut + eastLonDeg / 15.0d, 24.0d);
    }

    // Project an RA/Dec (J2000, deg) to alt/az at the observer.
    // Returns [alt_deg, az_deg]. az measured from N, clockwise.
    function altAzFromRaDec(raDeg, decDeg, lstHours, latDeg) {
        var H = d2r(fmod((lstHours * 15.0d) - raDeg + 540.0d, 360.0d) - 180.0d);
        var lat = d2r(latDeg);
        var dec = d2r(decDeg);
        var sinAlt = Math.sin(lat) * Math.sin(dec)
                   + Math.cos(lat) * Math.cos(dec) * Math.cos(H);
        var alt = r2d(Math.asin(sinAlt));
        var az  = r2d(Math.atan2(Math.sin(H),
                       Math.cos(H) * Math.sin(lat) - Math.tan(dec) * Math.cos(lat)));
        // atan2 form above gives az measured westward from south; convert to
        // azimuth from north, clockwise.
        az = fmod(az + 180.0d, 360.0d);
        return [alt, az];
    }
}
