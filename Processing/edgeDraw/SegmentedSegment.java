import java.util.Vector;
import processing.core.PVector;

class SegmentedSegment extends MotionSegment {
  private Vector<MotionSegment> segments;
  private Vector<Float> lengths;
  private float totalLength;

  public SegmentedSegment() {
    this.segments = new Vector<MotionSegment>();
    this.lengths = new Vector<Float>();
    this.totalLength = 0;
  }

  public void add(MotionSegment segment) {
    PVector newStart = segment.getPoint(0);

    if (!isEmpty()) {
      PVector lastEnd = segments.lastElement().getPoint(1);

      if (!near(lastEnd, newStart, NEAR_DISTANCE)) {
        throw new RuntimeException("New segment does not connect");
      }
    }

    PVector newEnd = segment.getPoint(1);

    // Keep track of lengths so we can index segments by them
    float length = dist(newStart.x, newStart.y, newEnd.x, newEnd.y);
    lengths.add(length);
    totalLength += length;

    segments.add(segment);
  }

  public PVector getPoint(float ratioComplete) {
    if (isEmpty()) {
      throw new RuntimeException("Have no segments to get points from");
    }

    if (ratioComplete < 0 || ratioComplete > 1) {
      throw new RuntimeException("Ratio must be between 0 and 1");
    }

    float targetLength = totalLength * ratioComplete;
    float lengthPreviousSegments = 0;

    for (int i = 0; i < lengths.size(); i++) {
      float segmentLength = lengths.get(i);

      if (lengthPreviousSegments + segmentLength > targetLength) {
        MotionSegment segment = segments.get(i);
        return segment.getPoint((targetLength - lengthPreviousSegments) / segmentLength);
      }

      lengthPreviousSegments += segmentLength;
    }

    return segments.lastElement().getPoint(1);
  }

  public float length() {
    float total = 0;

    for (MotionSegment segment : segments) {
      total += segment.length();
    }

    return total;
  }

  public boolean isEmpty() {
    return segments.isEmpty();
  }

  public static boolean near(float x1, float y1, float x2, float y2, float distance) {
    return dist(x1, y1, x2, y2) < distance;
  }

  public static boolean near(PVector a, PVector b, float distance) {
    return near(a.x, a.y, b.x, b.y, distance);
  }
}