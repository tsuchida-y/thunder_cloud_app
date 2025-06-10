"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculateDirectionCoordinates = calculateDirectionCoordinates;
// functions/src/coordinate_utils.ts - 既存のDartロジックを移植
function calculateDirectionCoordinates(direction, currentLatitude, currentLongitude, distanceKm) {
    // ✅ Dartの LatLngUtil.calculateDirectionCoordinates と同じロジック
    const latitudePerDegreeKm = 111.0;
    let latitudeOffset = 0.0;
    let longitudeOffset = 0.0;
    switch (direction.toLowerCase()) {
        case "north":
            latitudeOffset = distanceKm / latitudePerDegreeKm;
            break;
        case "south":
            latitudeOffset = -distanceKm / latitudePerDegreeKm;
            break;
        case "east":
            longitudeOffset = distanceKm / (latitudePerDegreeKm * Math.cos(currentLatitude * Math.PI / 180.0));
            break;
        case "west":
            longitudeOffset = -distanceKm / (latitudePerDegreeKm * Math.cos(currentLatitude * Math.PI / 180.0));
            break;
    }
    return {
        latitude: currentLatitude + latitudeOffset,
        longitude: currentLongitude + longitudeOffset,
    };
}
//# sourceMappingURL=coordinate_utils.js.map