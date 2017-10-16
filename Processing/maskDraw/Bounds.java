public class Bounds {
  public final float left, top, width, height;

  public Bounds(float left, float top, float width, float height) {
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
  }

  public Bounds(float width, float height) {
    this(0.0f, 0.0f, width, height);
  }
}
