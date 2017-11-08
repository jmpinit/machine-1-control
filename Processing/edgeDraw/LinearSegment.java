import processing.core.PVector;

class LinearSegment extends MotionSegment {
  private float startX, startY, endX, endY;

  public LinearSegment(float x1, float y1, float x2, float y2) {
    this.startX = x1;
    this.startY = y1;

    this.endX = x2;
    this.endY = y2;
  }

  public LinearSegment(PVector a, PVector b) {
    this(a.x, a.y, b.x, b.y);
  }

  public PVector getPoint(float ratioComplete) {
    float distanceX = endX - startX;
    float distanceY = endY - startY;

    return new PVector(startX + distanceX * ratioComplete, startY + distanceY * ratioComplete);
  }

  public float length() {
    return dist(getPoint(0), getPoint(1));
  }
}