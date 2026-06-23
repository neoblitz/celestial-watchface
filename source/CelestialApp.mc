using Toybox.Application;
using Toybox.WatchUi;

class CelestialApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {}

    function onStop(state) {}

    function getInitialView() {
        return [ new CelestialView() ];
    }

    // Redraw immediately when calibration settings change on the phone.
    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}
