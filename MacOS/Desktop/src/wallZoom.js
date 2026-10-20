export const wallZoomStops = [60, 70, 80, 90, 100, 110, 120];

export function nextWallZoomStop(scale, direction) {
  const percent = scale * 100;
  const stops = direction > 0 ? wallZoomStops : [...wallZoomStops].reverse();
  const next = stops.find(stop => direction > 0 ? stop > percent + .01 : stop < percent - .01);
  return (next ?? (direction > 0 ? 120 : 60)) / 100;
}
