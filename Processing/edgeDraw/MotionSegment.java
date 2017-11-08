import processing.core.PVector;

abstract class MotionSegment {
  public static final float NEAR_DISTANCE = 0.001f;
  private final int ITERATION_MAX = 1000;
  private final int LENGTH_SAMPLES = 100;

  public abstract PVector getPoint(float ratioComplete);

  public PVector getPointByDistance(PVector start, float targetDistance) {
    float ratio = 0;
    float lowerBound = 0;
    float upperBound = 1;

    for (int i = 0; i < ITERATION_MAX; i++) {
      PVector currentPoint = getPoint(ratio);
      float delta = dist(start.x, start.y, currentPoint.x, currentPoint.y) - targetDistance;

      if (Math.abs(delta) < NEAR_DISTANCE) {
        return currentPoint;
      }

      // Update the bounds

      if (delta > 0) {
        // We went too far
        upperBound = ratio;
      } else {
        // We didn't go far enough
        lowerBound = ratio;
      }

      // Set ratio to the halfway point between the two new bounds
      ratio = lowerBound + (upperBound - lowerBound) / 2.0f;
    }

    throw new RuntimeException("Failed to converge");
  }

  public static float dist(float x1, float y1, float x2, float y2) {
    return (float)Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2));
  }

  public static float dist(PVector a, PVector b) {
    return dist(a.x, a.y, b.x, b.y);
  }

  // Approximate length by sampling many points
  public float length() {
    float total = 0;

    float slice = 1 / (float)LENGTH_SAMPLES;

    for (float ratio = slice; ratio < 1; ratio += slice) {
      total += dist(getPoint(ratio - slice), getPoint(ratio));
    }

    return total;
  }
}