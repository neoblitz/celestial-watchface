using Toybox.Math;
using Toybox.Time;

// Mars timekeeping based on the NASA GISS "Mars24" algorithm.
// Reference: Allison & McEwen (2000); https://www.giss.nasa.gov/tools/mars24/help/algorithm.html
//
// Computes Coordinated Mars Time (MTC), Local Mean/True Solar Time for a site,
// the Mars Sol Date, the areocentric solar longitude (season, Ls), the solar
// declination, and whether the Sun is above the horizon at the site (day/night).
module MarsTime {

    // --- Gale Crater (Curiosity rover landing site) ---
    // Planetographic latitude and EAST longitude in degrees.
    const SITE_LAT   = -4.5895d;     // degrees (south)
    const SITE_EAST  = 137.4417d;    // degrees east
    // Mars24 / LMST convention uses WEST longitude.
    const SITE_WEST  = 360.0d - SITE_EAST;

    const MARS_OBLIQUITY = 25.19d;   // degrees

    // TT - UTC, in seconds. = (TAI - UTC) + 32.184 = 37 + 32.184 (valid 2017-->; 2026).
    const TT_MINUS_UTC = 69.184d;

    // Result holder.
    class MarsState {
        var mtc;        // Coordinated Mars Time, hours [0,24)
        var lmst;       // Local Mean Solar Time at site, hours [0,24)
        var ltst;       // Local True Solar Time at site, hours [0,24)
        var msd;        // Mars Sol Date (fractional)
        var ls;         // Areocentric solar longitude (season), degrees [0,360)
        var decl;       // Subsolar latitude / solar declination, degrees
        var altitude;   // Solar altitude at site, degrees (>0 => day)
        var isDay;      // Boolean
        var dayFrac;    // LMST fraction of sol [0,1) for dial drawing
        var sunriseLmst; // Sunrise in Local Mean Solar Time, hours
        var sunsetLmst;  // Sunset in Local Mean Solar Time, hours
        var polar;      // 0 normal, 1 polar day (no sunset), -1 polar night
    }

    function deg2rad(d) { return d * Math.PI / 180.0d; }
    function rad2deg(r) { return r * 180.0d / Math.PI; }

    // Floating modulo that always returns a non-negative result in [0,b).
    function fmod(a, b) {
        var r = a - b * Math.floor(a / b);
        if (r < 0) { r += b; }
        return r;
    }

    // unixSeconds: seconds since the Unix epoch (UTC).
    function compute(unixSeconds) {
        var s = unixSeconds.toDouble();

        // Julian Date (UT), then Terrestrial Time.
        var jdut = 2440587.5d + s / 86400.0d;
        var jdtt = jdut + TT_MINUS_UTC / 86400.0d;
        var dt   = jdtt - 2451545.0d;            // days since J2000 epoch (TT)

        // Mars mean anomaly (deg) and angle of the Fictitious Mean Sun (deg).
        var mDeg     = MarsTime.fmod(19.3871d + 0.52402073d * dt, 360.0d);
        var alphaFMS = MarsTime.fmod(270.3871d + 0.524038496d * dt, 360.0d);
        var m = deg2rad(mDeg);

        // Planetary perturbations (deg).
        var pbs =
            0.0071d * Math.cos(deg2rad(MarsTime.fmod(0.985626d * dt / 2.2353d  + 49.409d,  360.0d))) +
            0.0057d * Math.cos(deg2rad(MarsTime.fmod(0.985626d * dt / 2.7543d  + 168.173d, 360.0d))) +
            0.0039d * Math.cos(deg2rad(MarsTime.fmod(0.985626d * dt / 1.1177d  + 191.837d, 360.0d))) +
            0.0037d * Math.cos(deg2rad(MarsTime.fmod(0.985626d * dt / 15.7866d + 21.736d,  360.0d))) +
            0.0021d * Math.cos(deg2rad(MarsTime.fmod(0.985626d * dt / 2.1354d  + 15.704d,  360.0d))) +
            0.0020d * Math.cos(deg2rad(MarsTime.fmod(0.985626d * dt / 2.4694d  + 95.528d,  360.0d))) +
            0.0018d * Math.cos(deg2rad(MarsTime.fmod(0.985626d * dt / 32.8493d + 49.095d,  360.0d)));

        // Equation of center: (true - mean) anomaly, nu - M (deg).
        var nuMinusM =
            (10.691d + 0.0000003d * dt) * Math.sin(m) +
            0.6230d * Math.sin(2.0d * m) +
            0.0500d * Math.sin(3.0d * m) +
            0.0050d * Math.sin(4.0d * m) +
            0.0005d * Math.sin(5.0d * m) +
            pbs;

        // Areocentric solar longitude (season), deg.
        var ls = MarsTime.fmod(alphaFMS + nuMinusM, 360.0d);
        var lsr = deg2rad(ls);

        // Equation of time (deg), then hours.
        var eotDeg = 2.861d * Math.sin(2.0d * lsr)
                   - 0.071d * Math.sin(4.0d * lsr)
                   + 0.002d * Math.sin(6.0d * lsr)
                   - nuMinusM;
        var eotHours = eotDeg / 15.0d;

        // Mars Sol Date and Coordinated Mars Time (hours).
        var msd = (dt - 4.5d) / 1.0274912517d + 44796.0d - 0.0009626d;
        var mtc = MarsTime.fmod(24.0d * msd, 24.0d);

        // Local mean & true solar time at the site (hours).
        var lmst = MarsTime.fmod(mtc - MarsTime.SITE_WEST * (24.0d / 360.0d), 24.0d);
        var ltst = MarsTime.fmod(lmst + eotHours, 24.0d);

        // Solar declination (subsolar latitude), deg.
        var decl = rad2deg(Math.asin(Math.sin(deg2rad(MARS_OBLIQUITY)) * Math.sin(lsr)));

        // Hour angle from local true solar time, then solar altitude.
        var hDeg = (ltst - 12.0d) * 15.0d;
        var latr = deg2rad(SITE_LAT);
        var declr = deg2rad(decl);
        var sinAlt = Math.sin(latr) * Math.sin(declr)
                   + Math.cos(latr) * Math.cos(declr) * Math.cos(deg2rad(hDeg));
        var altitude = rad2deg(Math.asin(sinAlt));

        // Sunrise / sunset: solve solar altitude = 0 for the hour angle H0.
        var cosH0 = -Math.tan(latr) * Math.tan(declr);
        var sunrise = 0.0d;
        var sunset = 0.0d;
        var polar = 0;
        if (cosH0 >= 1.0d) {
            polar = -1;                       // Sun never rises (polar night)
        } else if (cosH0 <= -1.0d) {
            polar = 1;                        // Sun never sets (polar day)
            sunset = 24.0d;
        } else {
            var h0h = rad2deg(Math.acos(cosH0)) / 15.0d;   // half-day length, hours
            sunrise = MarsTime.fmod((12.0d - h0h) - eotHours, 24.0d);
            sunset  = MarsTime.fmod((12.0d + h0h) - eotHours, 24.0d);
        }

        var st = new MarsState();
        st.mtc      = mtc;
        st.lmst     = lmst;
        st.ltst     = ltst;
        st.msd      = msd;
        st.ls       = ls;
        st.decl     = decl;
        st.altitude = altitude;
        st.isDay    = (sinAlt > 0.0d);
        st.dayFrac  = lmst / 24.0d;
        st.sunriseLmst = sunrise;
        st.sunsetLmst  = sunset;
        st.polar    = polar;
        return st;
    }
}
