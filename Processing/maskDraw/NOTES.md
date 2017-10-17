# NOTES

Build the path out of MotionSegments which can be parameterized by distance
Make it easy to recalculate the path from a JS function

## EFFECTS

Effects that do not modify path:
  * dotted line
  * thick at segment ends, thin in center
  * paint size depends on shadowed pixel value in underlying image>q

Effects that modify path:
  * gravity: all lines bend toward attractors
    - attraction depends on local image intensity
  * confine to preset corridors
    - grid
    - city streets
    - small, touching circles
  * inertial brush: simulate very heavy brush that takes a while to stop
  * sinewave with random amplitude
  * fat raster line: zig back and forth to make line larger
  * fat dithered line: raster line while flipping air on/off based on line darkness

## BRUSHES

Triggers
  * ever

Function gets called with a context object. Return value is a set of points with the format: { x, y, z, paint, air }. 

Available inputs:
  * state (initialized from JSON file)
  * aspect ratio
  * points in path so far
  * time since last point

API
  * velocity vector

*/